package com.afdal.laffah

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.CodingErrorAction
import java.nio.charset.Charset

class MainActivity : FlutterActivity() {
    private val channelName = "laffeh/app"

    /// The Dart side of a document pick that is still on screen. Held
    /// because the picker answers through onActivityResult, long after the
    /// method call returned.
    private var pendingCsvResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Counterpart to iOS's isIdleTimerDisabled: a driver reading the map
        // off a mount must not lose it to a screen timeout. The flag belongs
        // to this window, so Android clears it by itself whenever the app is
        // not in front — nothing to undo, and no drain in the background.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openWhatsapp" -> result.success(openWhatsapp())
                    "pickCsvFile" -> pickCsvFile(result)
                    else -> result.notImplemented()
                }
            }
    }

    /// Launches the WhatsApp app's main screen (not a specific chat) via its
    /// launcher intent. Tries consumer then business builds. Returns false if
    /// neither is installed so Dart can surface a friendly message.
    private fun openWhatsapp(): Boolean {
        for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            val intent = packageManager.getLaunchIntentForPackage(pkg)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            }
        }
        return false
    }

    /// Opens the system document picker and answers with the file's text.
    ///
    /// ACTION_OPEN_DOCUMENT rather than a storage permission: the user
    /// choosing the file is the grant, so the app asks for nothing and can
    /// read from Drive, Files, a mail attachment or an SD card alike.
    ///
    /// The MIME filter is deliberately loose. A .csv reaches a phone typed
    /// as text/csv, text/comma-separated-values, application/vnd.ms-excel
    /// or, from more than one mail client, as nothing at all — filtering
    /// tightly would show a driver an empty folder containing the file they
    /// are looking at.
    private fun pickCsvFile(result: MethodChannel.Result) {
        // One at a time; a second call while the picker is up is a double
        // tap, not a second import.
        if (pendingCsvResult != null) {
            result.success(null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "text/csv",
                    "text/comma-separated-values",
                    "text/plain",
                    "application/csv",
                    "application/vnd.ms-excel",
                ),
            )
        }
        try {
            pendingCsvResult = result
            startActivityForResult(intent, CSV_REQUEST_CODE)
        } catch (e: Exception) {
            pendingCsvResult = null
            result.error("no_picker", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != CSV_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingCsvResult ?: return
        pendingCsvResult = null

        // Backing out of a file picker is not an error, and must not put a
        // message on the driver's screen.
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            result.success(null)
            return
        }
        try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null) {
                result.error("unreadable", "The file could not be opened", null)
                return
            }
            result.success(decode(bytes))
        } catch (e: Exception) {
            result.error("read_failed", e.message, null)
        }
    }

    /// UTF-8 when the bytes really are UTF-8, and windows-1256 when they are
    /// not — an Arabic sheet saved out of an older Excel is the usual reason
    /// a file arrives in anything else, and decoding it as UTF-8 anyway
    /// would turn every name into replacement characters instead of failing.
    private fun decode(bytes: ByteArray): String {
        return try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(java.nio.ByteBuffer.wrap(bytes))
                .toString()
        } catch (_: Exception) {
            String(bytes, Charset.forName("windows-1256"))
        }
    }

    private companion object {
        const val CSV_REQUEST_CODE = 0x0C57
    }
}
