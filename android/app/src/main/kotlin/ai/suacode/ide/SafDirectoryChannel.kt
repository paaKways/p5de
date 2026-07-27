package ai.suacode.ide

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.Executors

class SafDirectoryChannel(private val activity: Activity) {
    private val channelName = "ai.suacode.ide/saf_directory"
    private val requestCode = 4817
    private val preferencesName = "p5de_saf_directory"
    private val treeUriKey = "tree_uri"
    private val executor = Executors.newSingleThreadExecutor()
    private var pendingPickerResult: MethodChannel.Result? = null

    private val resolver
        get() = activity.contentResolver

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDirectory" -> runIo(result) { selectedDirectoryPayload() }
                "pickDirectory" -> pickDirectory(result)
                "list" -> runIo(result) {
                    listChildren(call.argument<String>("path").orEmpty())
                }
                "readText" -> runIo(result) {
                    readText(requiredPath(call.argument<String>("path")))
                }
                "writeText" -> runIo(result) {
                    writeText(
                        requiredPath(call.argument<String>("path")),
                        call.argument<String>("content").orEmpty(),
                        call.argument<String>("mimeType") ?: "text/plain",
                    )
                    null
                }
                "createDirectory" -> runIo(result) {
                    ensureDirectory(requiredPath(call.argument<String>("path")))
                    null
                }
                "rename" -> runIo(result) {
                    rename(
                        requiredPath(call.argument<String>("path")),
                        requiredName(call.argument<String>("newName")),
                    )
                }
                "delete" -> runIo(result) {
                    delete(requiredPath(call.argument<String>("path")))
                    null
                }
                "exists" -> runIo(result) {
                    resolve(requiredPath(call.argument<String>("path"))) != null
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onActivityResult(request: Int, resultCode: Int, data: Intent?): Boolean {
        if (request != requestCode) {
            return false
        }
        val pending = pendingPickerResult ?: return true
        pendingPickerResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(null)
            return true
        }

        try {
            val flags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            resolver.takePersistableUriPermission(uri, flags)
            preferences().edit().putString(treeUriKey, uri.toString()).apply()
            runIo(pending) { selectedDirectoryPayload() }
        } catch (error: Exception) {
            pending.error("directory_permission_failed", error.message, null)
        }
        return true
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("picker_active", "A folder picker is already open", null)
            return
        }
        pendingPickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, requestCode)
    }

    private fun selectedDirectoryPayload(): Map<String, Any?>? {
        val tree = selectedTreeUri() ?: return null
        val root = rootDocumentUri(tree)
        val name = queryDocument(root)?.name ?: "Selected folder"
        return mapOf("uri" to tree.toString(), "name" to name)
    }

    private fun listChildren(path: String): List<Map<String, Any?>> {
        val parent = if (path.isBlank()) {
            rootDocumentUri(requiredTreeUri())
        } else {
            resolve(path) ?: throw FileNotFoundException(path)
        }
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            parent,
            DocumentsContract.getDocumentId(parent),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        val entries = mutableListOf<Map<String, Any?>>()
        resolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            )
            val nameIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            )
            val mimeIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            )
            val modifiedIndex = cursor.getColumnIndex(
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            )
            val sizeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
            while (cursor.moveToNext()) {
                val id = cursor.getString(idIndex)
                val name = cursor.getString(nameIndex)
                val mimeType = cursor.getString(mimeIndex)
                entries.add(
                    mapOf(
                        "name" to name,
                        "path" to joinPath(path, name),
                        "uri" to DocumentsContract
                            .buildDocumentUriUsingTree(parent, id)
                            .toString(),
                        "isDirectory" to
                            (mimeType == DocumentsContract.Document.MIME_TYPE_DIR),
                        "mimeType" to mimeType,
                        "lastModified" to
                            if (modifiedIndex >= 0 && !cursor.isNull(modifiedIndex)) {
                                cursor.getLong(modifiedIndex)
                            } else {
                                0L
                            },
                        "size" to
                            if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                                cursor.getLong(sizeIndex)
                            } else {
                                0L
                            },
                    ),
                )
            }
        }
        return entries
    }

    private fun readText(path: String): String {
        val document = resolve(path) ?: throw FileNotFoundException(path)
        return resolver.openInputStream(document)?.bufferedReader(Charsets.UTF_8)?.use {
            it.readText()
        } ?: throw FileNotFoundException(path)
    }

    private fun writeText(path: String, content: String, mimeType: String) {
        val segments = pathSegments(path)
        val fileName = segments.last()
        val parentPath = segments.dropLast(1).joinToString("/")
        val parent = ensureDirectory(parentPath)
        val existing = findChild(parent, fileName)
        val document = existing ?: DocumentsContract.createDocument(
            resolver,
            parent,
            mimeType,
            fileName,
        ) ?: throw IllegalStateException("Unable to create $path")
        resolver.openOutputStream(document, "wt")?.bufferedWriter(Charsets.UTF_8)?.use {
            it.write(content)
        } ?: throw FileNotFoundException(path)
    }

    private fun ensureDirectory(path: String): Uri {
        var current = rootDocumentUri(requiredTreeUri())
        for (segment in pathSegments(path, allowEmpty = true)) {
            val existing = findChild(current, segment)
            current = if (existing != null) {
                val info = queryDocument(existing)
                if (info?.isDirectory != true) {
                    throw IllegalStateException("$segment is not a directory")
                }
                existing
            } else {
                DocumentsContract.createDocument(
                    resolver,
                    current,
                    DocumentsContract.Document.MIME_TYPE_DIR,
                    segment,
                ) ?: throw IllegalStateException("Unable to create $segment")
            }
        }
        return current
    }

    private fun rename(path: String, newName: String): String {
        val document = resolve(path) ?: throw FileNotFoundException(path)
        DocumentsContract.renameDocument(resolver, document, newName)
            ?: throw IllegalStateException("Unable to rename $path")
        val parentPath = pathSegments(path).dropLast(1).joinToString("/")
        return joinPath(parentPath, newName)
    }

    private fun delete(path: String) {
        val document = resolve(path) ?: throw FileNotFoundException(path)
        if (!DocumentsContract.deleteDocument(resolver, document)) {
            throw IllegalStateException("Unable to delete $path")
        }
    }

    private fun resolve(path: String): Uri? {
        var current = rootDocumentUri(requiredTreeUri())
        for (segment in pathSegments(path, allowEmpty = true)) {
            current = findChild(current, segment) ?: return null
        }
        return current
    }

    private fun findChild(parent: Uri, name: String): Uri? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            parent,
            DocumentsContract.getDocumentId(parent),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        )
        resolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            )
            val nameIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            )
            while (cursor.moveToNext()) {
                if (cursor.getString(nameIndex) == name) {
                    return DocumentsContract.buildDocumentUriUsingTree(
                        parent,
                        cursor.getString(idIndex),
                    )
                }
            }
        }
        return null
    }

    private fun queryDocument(uri: Uri): DocumentInfo? {
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        resolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) {
                return null
            }
            val name = cursor.getString(
                cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            )
            val mimeType = cursor.getString(
                cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE),
            )
            return DocumentInfo(
                name = name,
                isDirectory = mimeType == DocumentsContract.Document.MIME_TYPE_DIR,
            )
        }
        return null
    }

    private fun selectedTreeUri(): Uri? {
        val raw = preferences().getString(treeUriKey, null) ?: return null
        val uri = Uri.parse(raw)
        val hasPermission = resolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        if (!hasPermission) {
            preferences().edit().remove(treeUriKey).apply()
            return null
        }
        return uri
    }

    private fun requiredTreeUri(): Uri {
        return selectedTreeUri()
            ?: throw IllegalStateException("No sketch directory has been selected")
    }

    private fun rootDocumentUri(treeUri: Uri): Uri {
        return DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
    }

    private fun requiredPath(path: String?): String {
        if (path.isNullOrBlank()) {
            throw IllegalArgumentException("Missing path")
        }
        pathSegments(path)
        return path
    }

    private fun requiredName(name: String?): String {
        val value = name?.trim().orEmpty()
        if (value.isEmpty() || value == "." || value == ".." ||
            value.contains('/') || value.contains('\\')
        ) {
            throw IllegalArgumentException("Invalid document name")
        }
        return value
    }

    private fun pathSegments(path: String, allowEmpty: Boolean = false): List<String> {
        if (path.isBlank()) {
            if (allowEmpty) {
                return emptyList()
            }
            throw IllegalArgumentException("Missing path")
        }
        return path.split('/').map(::requiredName)
    }

    private fun joinPath(parent: String, child: String): String {
        return if (parent.isBlank()) child else "$parent/$child"
    }

    private fun preferences() =
        activity.getSharedPreferences(preferencesName, Activity.MODE_PRIVATE)

    private fun runIo(result: MethodChannel.Result, operation: () -> Any?) {
        executor.execute {
            try {
                val value = operation()
                activity.runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.error(
                        "saf_operation_failed",
                        error.message ?: "Storage operation failed",
                        null,
                    )
                }
            }
        }
    }

    private data class DocumentInfo(
        val name: String,
        val isDirectory: Boolean,
    )
}
