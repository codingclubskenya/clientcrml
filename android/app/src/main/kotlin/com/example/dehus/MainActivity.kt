package com.example.dehus

import android.app.DownloadManager
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.dehus/download"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                try {
                    val fileName = call.argument<String>("fileName") ?: "export.csv"
                    val bytes = call.argument<ByteArray>("bytes")
                    val mimeType = call.argument<String>("mimeType") ?: "text/csv"
                    if (bytes == null) {
                        result.error("NO_DATA", "No file bytes provided", null)
                        return@setMethodCallHandler
                    }
                    val saved = saveToDownloads(fileName, bytes, mimeType)
                    if (saved) {
                        result.success(true)
                    } else {
                        result.error("SAVE_FAILED", "Could not save to Downloads", null)
                    }
                } catch (e: Exception) {
                    result.error("SAVE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(fileName: String, bytes: ByteArray, mimeType: String): Boolean {
        val resolver = applicationContext.contentResolver
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val downloadsUri = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }
                val uri = resolver.insert(downloadsUri, values) ?: return false
                resolver.openOutputStream(uri)?.use { stream ->
                    stream.write(bytes)
                    stream.flush()
                } ?: return false
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                true
            } else {
                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (!downloadsDir.exists()) downloadsDir.mkdirs()
                val file = File(downloadsDir, fileName)
                file.writeBytes(bytes)
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
