package com.afdal.laffah

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "laffeh/app"

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
}
