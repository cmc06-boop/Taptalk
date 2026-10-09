package com.example.flutter_application_1

import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var speechCapture: SpeechCapture? = null
    private var emailLinkChannel: MethodChannel? = null
    private var pendingEmailLink: String? = null
    private val warningFeedbackHandler = Handler(Looper.getMainLooper())
    private var warningTone: ToneGenerator? = null
    private var releaseWarningTone: Runnable? = null

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.taptalk/app_check",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "debugToken" -> {
                    val id = resources.getIdentifier(
                        "taptalk_app_check_debug_token",
                        "string",
                        packageName,
                    )
                    result.success(if (id == 0) "" else getString(id))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.taptalk/warning_feedback",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val durationMs =
                        (call.argument<Number>("durationMs")?.toLong() ?: 3_000L)
                            .coerceIn(100L, 10_000L)
                    playWarningFeedback(durationMs)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        emailLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.taptalk/email_links",
        )
        emailLinkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> result.success(takeEmailLink())
                else -> result.notImplemented()
            }
        }
        rememberEmailLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        rememberEmailLink(intent)
        takeEmailLink()?.let { emailLinkChannel?.invokeMethod("onLink", it) }
    }

    private fun playWarningFeedback(durationMs: Long) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as? Vibrator
        }
        if (vibrator?.hasVibrator() == true) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createOneShot(
                        durationMs,
                        VibrationEffect.DEFAULT_AMPLITUDE,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(durationMs)
            }
        }

        releaseWarningTone?.let(warningFeedbackHandler::removeCallbacks)
        warningTone?.stopTone()
        warningTone?.release()
        warningTone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100).also {
            it.startTone(ToneGenerator.TONE_SUP_RINGTONE, durationMs.toInt())
        }
        releaseWarningTone = Runnable {
            warningTone?.stopTone()
            warningTone?.release()
            warningTone = null
            releaseWarningTone = null
        }.also {
            warningFeedbackHandler.postDelayed(it, durationMs + 100L)
        }
    }

    private fun rememberEmailLink(intent: Intent?) {
        val data = intent?.dataString ?: return
        if (data.startsWith("taptalk://") ||
            data.contains("oobCode") ||
            data.contains("mode=signIn") ||
            data.contains("mode=verifyEmail") ||
            data.contains("email-verified") ||
            data.contains("caregiver-recovery")
        ) {
            pendingEmailLink = data
        }
    }

    private fun takeEmailLink(): String? {
        val link = pendingEmailLink
        pendingEmailLink = null
        return link
    }

    override fun onDestroy() {
        releaseWarningTone?.let(warningFeedbackHandler::removeCallbacks)
        warningTone?.stopTone()
        warningTone?.release()
        warningTone = null
        releaseWarningTone = null
        speechCapture?.destroy()
        speechCapture = null
        emailLinkChannel?.setMethodCallHandler(null)
        emailLinkChannel = null
        super.onDestroy()
    }
}
