package com.example.deedwise

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.io.File
import androidx.core.content.FileProvider
import android.content.Intent
import android.app.Activity
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var matcher: OfflineMatcher? = null
    private var photoResult: MethodChannel.Result? = null
    private var cameraFile: File? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cameraFile = File(cacheDir, "deedwise-camera.jpg")
    }

    @Deprecated("Android activity result callback used by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7101 && requestCode != 7102) return
        val reply = photoResult ?: return
        photoResult = null
        if (resultCode != Activity.RESULT_OK) { reply.success(null); return }
        worker.execute {
            try {
                val bytes = if (requestCode == 7102) cameraFile!!.inputStream().use {
                    it.readBytesLimited()
                } else contentResolver.openInputStream(data?.data
                    ?: throw IllegalArgumentException("No photo selected"))!!.use { it.readBytesLimited() }
                runOnUiThread { reply.success(bytes) }
            } catch (e: Exception) {
                runOnUiThread { reply.error("PHOTO_FAILED", "Could not read this photo. Choose a photo under 20 MB.", null) }
            } finally {
                cameraFile?.delete()
            }
        }
    }

    private fun java.io.InputStream.readBytesLimited(): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val count = read(buffer)
            if (count < 0) break
            if (output.size() + count > 20 * 1024 * 1024) throw IllegalArgumentException("Photo too large")
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "deedwise/local_photos")
            .setMethodCallHandler { call, result ->
                if (call.method != "pick") { result.notImplemented(); return@setMethodCallHandler }
                if (photoResult != null) { result.error("BUSY", "Photo picker already open", null); return@setMethodCallHandler }
                photoResult = result
                try {
                    if (call.arguments == "camera") {
                        val file = File(cacheDir, "deedwise-camera.jpg").also { cameraFile = it }
                        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                        val capture = Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE).apply {
                            putExtra(android.provider.MediaStore.EXTRA_OUTPUT, uri)
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            clipData = android.content.ClipData.newRawUri("Photo", uri)
                        }
                        startActivityForResult(capture, 7102)
                    } else {
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }, 7101)
                    }
                } catch (e: Exception) {
                    photoResult = null
                    result.error("PHOTO_FAILED", "No photo app is available.", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "deedwise/offline_matcher")
            .setMethodCallHandler { call, result ->
                if (call.method != "match") { result.notImplemented(); return@setMethodCallHandler }
                val text = call.argument<String>("text") ?: ""
                val rules = call.argument<List<Map<String, Any>>>("rules") ?: emptyList()
                worker.execute {
                    try {
                        val engine = matcher ?: OfflineMatcher(applicationContext).also { matcher = it }
                        val match = engine.match(text, rules)
                        runOnUiThread { result.success(match) }
                    } catch (e: TextTooLongException) {
                        runOnUiThread { result.error("TEXT_TOO_LONG", "Describe one deed more briefly.", null) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("MODEL_UNAVAILABLE", "Offline model setup required.", null) }
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "deedwise/share_card")
            .setMethodCallHandler { call, result ->
                if (call.method == "shareText") {
                    try {
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, call.argument<String>("text") ?: "")
                        }
                        startActivity(Intent.createChooser(send, "Share invitation"))
                        result.success(null)
                    } catch (e: Exception) { result.error("SHARE_FAILED", "Could not open sharing.", null) }
                    return@setMethodCallHandler
                }
                if (call.method != "shareImage") { result.notImplemented(); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.isEmpty()) {
                    result.error("EMPTY_IMAGE", "The share card image is empty.", null)
                    return@setMethodCallHandler
                }
                try {
                    val file = File(cacheDir, "deedwise-share.png")
                    file.writeBytes(bytes)
                    val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "image/png"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_TEXT, call.argument<String>("text") ?: "A good deed I recorded in DeedWise")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(send, "Share your deed"))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SHARE_FAILED", e.message ?: "Could not share the card.", null)
                }
            }
    }
    override fun onDestroy() {
        worker.execute { matcher?.close() }
        worker.shutdown()
        super.onDestroy()
    }
}
