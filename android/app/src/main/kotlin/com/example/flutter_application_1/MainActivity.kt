package com.example.flutter_application_1

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.taptalk/direct_sms",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val to = call.argument<String>("to")
                    val message = call.argument<String>("message")
                    if (to.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Missing phone number or message", null)
                        return@setMethodCallHandler
                    }
                    DirectSmsSender.send(this, to.trim(), message, result)
                }
                "sendSmsBatch" -> {
                    val recipients = call.argument<List<String>>("recipients")
                    val message = call.argument<String>("message")
                    if (recipients.isNullOrEmpty() || message.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Missing recipients or message", null)
                        return@setMethodCallHandler
                    }
                    DirectSmsSender.sendBatch(this, recipients, message, result)
                }
                "openSmsApp" -> {
                    val to = call.argument<String>("to")
                    val message = call.argument<String>("message")
                    if (to.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Missing phone number or message", null)
                        return@setMethodCallHandler
                    }
                    DirectSmsSender.openSmsApp(this, to.trim(), message, result)
                }
                else -> result.notImplemented()
            }
        }
    }
}
