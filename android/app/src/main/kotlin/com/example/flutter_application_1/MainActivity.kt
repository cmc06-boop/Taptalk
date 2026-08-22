package com.example.flutter_application_1

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var speechCapture: SpeechCapture? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val speechChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.taptalk/speech",
        )
        speechCapture = SpeechCapture(this, speechChannel)
        speechCapture?.prepare()
        speechChannel.setMethodCallHandler { call, result ->
            val capture = speechCapture
            if (capture == null) {
                result.error("NO_CAPTURE", "Speech capture is not ready", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "isAvailable" -> result.success(true)
                "hasPack" -> result.success(
                    capture.hasPack(call.argument<String>("locale")),
                )
                "start" -> {
                    capture.start(call.argument<String>("locale"))
                    result.success(true)
                }
                "prefetch" -> {
                    capture.prefetch(call.argument<String>("locale"))
                    result.success(true)
                }
                "stop" -> {
                    capture.stop()
                    result.success(true)
                }
                "cancel" -> {
                    capture.cancel()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

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

    override fun onDestroy() {
        speechCapture?.destroy()
        speechCapture = null
        super.onDestroy()
    }
}
