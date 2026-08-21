package ai.suacode.ide

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.Executors

class SafDirectoryChannel(private val activity: Activity) {
    private val channelName = "ai.suacode.ide/saf_directory"
    private val requestCode = 4817
    private val preferencesName = "p5de_saf_directory"
    private val treeUriKey = "tree_uri"
    private val defaultDirectoryPath = "SuaCode IDE/sketches"
    private val bootstrapMarkerName = ".suacode-directory"
    private val externalStorageProviderAuthority =
        "com.android.externalstorage.documents"
    private val executor = Executors.newSingleThreadExecutor()
    private val readExecutor = Executors.newFixedThreadPool(4)
    private val directoryCache = java.util.concurrent.ConcurrentHashMap<String, Uri>()
    private var pendingPickerResult: MethodChannel.Result? = null

    private val resolver
        get() = activity.contentResolver

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDirectory" -> runReadIo(result) { selectedDirectoryPayload() }
                "pickDirectory" -> pickDirectory(result)
                "list" -> runReadIo(result) {
                    listChildren(call.argument<String>("path").orEmpty())
                }
                "readText" -> runReadIo(result) {
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
                "exists" -> runReadIo(result) {
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
            directoryCache.clear()
            runIo(pending) {
                try {
                    removeBootstrapMarkerIfSelected(uri)
                } catch (_: Exception) {
                    // The marker is hidden and ignored by the catalog, so a
                    // provider-specific cleanup failure must not reject a
                    // successfully granted directory permission.
                }
                selectedDirectoryPayload()
            }
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
        executor.execute {
            val initialUri = try {
                prepareDefaultDirectoryInitialUri()
            } catch (_: Exception) {
                null
            }
            activity.runOnUiThread {
                if (pendingPickerResult !== result) {
                    return@runOnUiThread
                }
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && initialUri != null) {
                        putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri)
                    }
                }
                try {
                    activity.startActivityForResult(intent, requestCode)
                } catch (error: Exception) {
                    pendingPickerResult = null
                    result.error("directory_picker_failed", error.message, null)
                }
            }
        }
    }

    private fun prepareDefaultDirectoryInitialUri(): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return null
        }

        val collection = MediaStore.Downloads.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY,
        )
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/$defaultDirectoryPath/"
        findBootstrapMarker(collection, relativePath)
            ?: resolver.insert(
                collection,
                ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, bootstrapMarkerName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                },
            )
            ?: return null

        // ExternalStorageProvider is the local-files provider used by Android's
        // DocumentsUI. If an OEM does not expose it, DocumentsUI safely falls
        // back to its normal starting location.
        return DocumentsContract.buildDocumentUri(
            externalStorageProviderAuthority,
            "primary:${relativePath.trimEnd('/')}",
        )
    }

    private fun removeBootstrapMarkerIfSelected(treeUri: Uri) {
        val expectedDocumentId =
            "primary:${Environment.DIRECTORY_DOWNLOADS}/$defaultDirectoryPath"
        if (DocumentsContract.getTreeDocumentId(treeUri) != expectedDocumentId) {
            return
        }
        val root = rootDocumentUri(treeUri)
        val marker = findChild(root, bootstrapMarkerName) ?: return
        DocumentsContract.deleteDocument(resolver, marker)
    }

    private fun findBootstrapMarker(collection: Uri, relativePath: String): Uri? {
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection =
            "${MediaStore.MediaColumns.DISPLAY_NAME} = ? AND " +
                "${MediaStore.MediaColumns.RELATIVE_PATH} = ?"
        val selectionArgs = arrayOf(bootstrapMarkerName, relativePath)
        resolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(
                    cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID),
                )
                return ContentUris.withAppendedId(collection, id)
            }
        }
        return null
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
        val providerTextName = if (
            mimeType == "text/plain" && !fileName.endsWith(".txt", ignoreCase = true)
        ) {
            "$fileName.txt"
        } else {
            null
        }
        val existing = findChild(parent, fileName)
            ?: providerTextName?.let { findChild(parent, it) }
        var document = existing ?: DocumentsContract.createDocument(
            resolver,
            parent,
            mimeType,
            fileName,
        ) ?: throw IllegalStateException("Unable to create $path")

        // ExternalStorageProvider may append `.txt` to an unfamiliar source
        // extension (notably Processing's `.pde`) when the MIME type is
        // text/plain. Keep the requested source filename stable and also
        // repair files created by older app versions when they are rewritten.
        if (queryDocument(document)?.name != fileName) {
            document = DocumentsContract.renameDocument(resolver, document, fileName)
                ?: throw IllegalStateException("Unable to preserve filename for $path")
        }
        resolver.openOutputStream(document, "wt")?.bufferedWriter(Charsets.UTF_8)?.use {
            it.write(content)
        } ?: throw FileNotFoundException(path)
    }

    private fun ensureDirectory(path: String): Uri {
        val cached = directoryCache[path]
        if (cached != null) {
            return cached
        }
        var current = rootDocumentUri(requiredTreeUri())
        directoryCache.putIfAbsent("", current)
        var currentPath = ""
        for (segment in pathSegments(path, allowEmpty = true)) {
            currentPath = joinPath(currentPath, segment)
            val cachedChild = directoryCache[currentPath]
            if (cachedChild != null) {
                current = cachedChild
                continue
            }
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
            directoryCache[currentPath] = current
        }
        return current
    }

    private fun rename(path: String, newName: String): String {
        val document = resolve(path) ?: throw FileNotFoundException(path)
        val renamedDocument = DocumentsContract.renameDocument(resolver, document, newName)
            ?: throw IllegalStateException("Unable to rename $path")
        val parentPath = pathSegments(path).dropLast(1).joinToString("/")
        val targetPath = joinPath(parentPath, newName)
        invalidateDirectoryCache(path)
        directoryCache[targetPath] = renamedDocument
        return targetPath
    }

    private fun delete(path: String) {
        val document = resolve(path) ?: throw FileNotFoundException(path)
        if (!DocumentsContract.deleteDocument(resolver, document)) {
            throw IllegalStateException("Unable to delete $path")
        }
        invalidateDirectoryCache(path)
    }

    private fun resolve(path: String): Uri? {
        val cached = directoryCache[path]
        if (cached != null) {
            return cached
        }
        var current = rootDocumentUri(requiredTreeUri())
        directoryCache.putIfAbsent("", current)
        var currentPath = ""
        for (segment in pathSegments(path, allowEmpty = true)) {
            currentPath = joinPath(currentPath, segment)
            val cachedChild = directoryCache[currentPath]
            if (cachedChild != null) {
                current = cachedChild
                continue
            }
            current = findChild(current, segment) ?: return null
            directoryCache[currentPath] = current
        }
        return current
    }

    private fun invalidateDirectoryCache(path: String) {
        directoryCache.keys.removeAll { key -> key == path || key.startsWith("$path/") }
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
        runOnExecutor(executor, result, operation)
    }

    private fun runReadIo(result: MethodChannel.Result, operation: () -> Any?) {
        runOnExecutor(readExecutor, result, operation)
    }

    private fun runOnExecutor(
        targetExecutor: java.util.concurrent.Executor,
        result: MethodChannel.Result,
        operation: () -> Any?,
    ) {
        targetExecutor.execute {
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
