package com.example.freelance_tracker

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "com.example.freelance_tracker/invoice_files"
        const val WRITE_PERMISSION_REQUEST = 4817
    }

    private var pendingSave: PendingSave? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "savePdfToDownloads" -> savePdfToDownloads(call, result)
                    "openPdf" -> openPdf(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun savePdfToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val fileName = call.argument<String>("fileName")?.let(::safePdfName)
        val bytes = call.argument<ByteArray>("bytes")
        if (fileName == null || bytes == null || bytes.isEmpty()) {
            result.error("INVALID_PDF", "A PDF name and non-empty file data are required.", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                result.success(saveWithMediaStore(fileName, bytes).toString())
            } catch (error: Exception) {
                result.error("SAVE_FAILED", error.message ?: "Could not save the PDF.", null)
            }
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingSave != null) {
                result.error("SAVE_IN_PROGRESS", "A file save is already waiting for permission.", null)
                return
            }
            pendingSave = PendingSave(fileName, bytes, result)
            requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), WRITE_PERMISSION_REQUEST)
            return
        }

        saveLegacy(fileName, bytes, result)
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveWithMediaStore(fileName: String, bytes: ByteArray): Uri {
        val resolver = contentResolver
        val uniqueName = uniqueMediaStoreName(fileName)
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, uniqueName)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
            put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("Android could not create the downloaded file.")
        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IOException("Android could not write the downloaded file.")
            val ready = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
            resolver.update(uri, ready, null, null)
            return uri
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun uniqueMediaStoreName(originalName: String): String =
        uniqueName(originalName) { candidate ->
            val projection = arrayOf(MediaStore.MediaColumns._ID)
            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} = ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
            contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                arrayOf("${Environment.DIRECTORY_DOWNLOADS}/", candidate),
                null
            )?.use { it.moveToFirst() } == true
        }

    private fun saveLegacy(fileName: String, bytes: ByteArray, result: MethodChannel.Result) {
        try {
            val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if ((!downloads.exists() && !downloads.mkdirs()) || !downloads.isDirectory) {
                throw IOException("The Downloads folder is unavailable.")
            }
            val file = File(downloads, uniqueName(fileName) { File(downloads, it).exists() })
            file.writeBytes(bytes)
            MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf("application/pdf")) { _, uri ->
                if (uri == null) {
                    result.error("SAVE_FAILED", "The file was saved but could not be opened by Android.", null)
                } else {
                    result.success(uri.toString())
                }
            }
        } catch (error: Exception) {
            result.error("SAVE_FAILED", error.message ?: "Could not save the PDF.", null)
        }
    }

    private fun uniqueName(originalName: String, exists: (String) -> Boolean): String {
        if (!exists(originalName)) return originalName
        val extensionIndex = originalName.lastIndexOf('.')
        val stem = if (extensionIndex > 0) originalName.substring(0, extensionIndex) else originalName
        val extension = if (extensionIndex > 0) originalName.substring(extensionIndex) else ""
        var suffix = 1
        var candidate: String
        do {
            candidate = "$stem ($suffix)$extension"
            suffix++
        } while (exists(candidate))
        return candidate
    }

    private fun safePdfName(name: String): String? {
        val safe = name.substringAfterLast('/').substringAfterLast('\\')
            .replace(Regex("[^A-Za-z0-9._() -]"), "_")
            .trim()
        if (safe.isEmpty()) return null
        return if (safe.endsWith(".pdf", ignoreCase = true)) safe else "$safe.pdf"
    }

    private fun openPdf(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")?.let(Uri::parse)
        if (uri == null) {
            result.error("INVALID_URI", "The saved invoice location is unavailable.", null)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("NO_PDF_VIEWER", "No PDF viewer is installed on this device.", null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != WRITE_PERMISSION_REQUEST) return
        val save = pendingSave ?: return
        pendingSave = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            saveLegacy(save.fileName, save.bytes, save.result)
        } else {
            save.result.error(
                "STORAGE_PERMISSION_DENIED",
                "Storage permission was denied. No file was saved.",
                null
            )
        }
    }

    private data class PendingSave(
        val fileName: String,
        val bytes: ByteArray,
        val result: MethodChannel.Result
    )
}
