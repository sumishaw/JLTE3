package com.example.nihongolens

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "overlay_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "setLanguages" -> {
                        val source = call.argument<String>("source") ?: "auto"
                        val target = call.argument<String>("target") ?: "en"

                        CaptionAccessibilityService.sourceLang = source
                        CaptionAccessibilityService.targetLang = target

                        result.success(true)
                    }

                    "startOverlay" -> {
                        val intent = Intent(this, OverlayService::class.java)

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }

                        result.success(true)
                    }

                    "stopOverlay" -> {
                        stopService(Intent(this, OverlayService::class.java))
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
