package ai.suacode.ide

import android.content.ContentUris
import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "ai.suacode.ide/user_visible_sketches"
    private val publicRootLabel = "Documents/SuaCode IDE/sketches"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncSketchesDirectory" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        if (sourcePath.isNullOrBlank()) {
                            result.error("invalid_source", "Missing sourcePath", null)
                            return@setMethodCallHandler
                        }
                        try {
                            syncSketchesDirectory(File(sourcePath))
                            result.success(publicRootLabel)
                        } catch (error: Exception) {
                            result.error(
                                "sync_failed",
                                error.message ?: "Unable to sync sketches",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun syncSketchesDirectory(sourceRoot: File) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            syncWithMediaStore(sourceRoot)
        } else {
            syncWithPublicFiles(sourceRoot)
        }
    }

    private fun syncWithMediaStore(sourceRoot: File) {
        val resolver = applicationContext.contentResolver
        val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val baseRelativePath = "${Environment.DIRECTORY_DOCUMENTS}/SuaCode IDE/sketches/"
        deleteMediaStoreMirror(collection, baseRelativePath)
        if (!sourceRoot.exists()) {
            return
        }
        sourceRoot.walkTopDown()
            .filter { it.isFile && !it.name.startsWith(".") }
            .forEach { sourceFile ->
                val relativePath = sourceRoot.toPath().relativize(sourceFile.toPath())
                    .parent
                    ?.toString()
                    ?.replace(File.separatorChar, '/')
                    ?.trim('/')
                    .orEmpty()
                val mediaRelativePath = if (relativePath.isEmpty()) {
                    baseRelativePath
                } else {
                    "$baseRelativePath$relativePath/"
                }
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, sourceFile.name)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeTypeFor(sourceFile.name))
                    put(MediaStore.MediaColumns.RELATIVE_PATH, mediaRelativePath)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = resolver.insert(collection, values)
                    ?: throw IllegalStateException("Unable to create ${sourceFile.name}")
                resolver.openOutputStream(uri, "w")?.use { output ->
                    sourceFile.inputStream().use { input -> input.copyTo(output) }
                } ?: throw IllegalStateException("Unable to open ${sourceFile.name}")
                val publishedValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, publishedValues, null, null)
            }
    }

    private fun deleteMediaStoreMirror(collection: Uri, baseRelativePath: String) {
        val resolver = applicationContext.contentResolver
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
        val selectionArgs = arrayOf("$baseRelativePath%")
        resolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            while (cursor.moveToNext()) {
                val uri = ContentUris.withAppendedId(collection, cursor.getLong(idColumn))
                resolver.delete(uri, null, null)
            }
        }
    }

    private fun syncWithPublicFiles(sourceRoot: File) {
        @Suppress("DEPRECATION")
        val targetRoot = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
            "SuaCode IDE/sketches",
        )
        if (targetRoot.exists()) {
            targetRoot.deleteRecursively()
        }
        if (!sourceRoot.exists()) {
            return
        }
        sourceRoot.copyRecursively(targetRoot, overwrite = true)
    }

    private fun mimeTypeFor(fileName: String): String {
        return when (fileName.substringAfterLast('.', "").lowercase()) {
            "js" -> "application/javascript"
            else -> "application/octet-stream"
        }
    }
}
