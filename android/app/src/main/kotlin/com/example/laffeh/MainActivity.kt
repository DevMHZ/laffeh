package com.example.laffeh

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "laffeh/app"

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
