package com.leoassociation.app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val downloadsChannel = "app.trinex/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deletePublicPdf" -> {
                        val filename = call.argument<String>("filename")?.trim()
                        if (filename.isNullOrEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            val resolver = applicationContext.contentResolver
                            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                            val relativePath = Environment.DIRECTORY_DOWNLOADS + "/TRINEX/"
                            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${MediaStore.MediaColumns.DISPLAY_NAME}=?"
                            var deleted = false
                            resolver.query(
                                collection,
                                arrayOf(MediaStore.MediaColumns._ID),
                                selection,
                                arrayOf(relativePath, filename),
                                null
                            )?.use { cursor ->
                                while (cursor.moveToNext()) {
                                    val id = cursor.getLong(0)
                                    deleted = resolver.delete(android.content.ContentUris.withAppendedId(collection, id), null, null) > 0 || deleted
                                }
                            }
                            result.success(deleted)
                        } catch (error: Exception) {
                            result.error("DOWNLOAD_CLEANUP_FAILED", error.message ?: "تعذر حذف النسخة المكررة.", null)
                        }
                    }
                    "savePdf" -> {
                        val filename = call.argument<String>("filename")?.trim()
                        val bytes = call.argument<ByteArray>("bytes")
                        if (filename.isNullOrEmpty() || bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_FILE", "اسم الملف أو محتواه غير صالح.", null)
                            return@setMethodCallHandler
                        }
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            val resolver = applicationContext.contentResolver
                            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                            val relativePath = Environment.DIRECTORY_DOWNLOADS + "/TRINEX/"
                            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${MediaStore.MediaColumns.DISPLAY_NAME}=?"
                            resolver.query(
                                collection,
                                arrayOf(MediaStore.MediaColumns._ID),
                                selection,
                                arrayOf(relativePath, filename),
                                null
                            )?.use { cursor ->
                                while (cursor.moveToNext()) {
                                    val id = cursor.getLong(0)
                                    resolver.delete(android.content.ContentUris.withAppendedId(collection, id), null, null)
                                }
                            }

                            val values = ContentValues().apply {
                                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                                put(MediaStore.MediaColumns.IS_PENDING, 1)
                            }
                            val uri = resolver.insert(collection, values)
                                ?: throw IllegalStateException("تعذر إنشاء الملف في التنزيلات.")
                            try {
                                resolver.openOutputStream(uri, "w")?.use { output -> output.write(bytes) }
                                    ?: throw IllegalStateException("تعذر كتابة الملف في التنزيلات.")
                                val ready = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
                                resolver.update(uri, ready, null, null)
                                result.success(true)
                            } catch (error: Exception) {
                                resolver.delete(uri, null, null)
                                throw error
                            }
                        } catch (error: Exception) {
                            result.error("DOWNLOAD_SAVE_FAILED", error.message ?: "تعذر الحفظ في التنزيلات.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
