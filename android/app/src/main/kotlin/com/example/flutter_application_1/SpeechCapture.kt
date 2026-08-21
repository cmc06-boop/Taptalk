package com.example.flutter_application_1

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * Google speech API for live STT — the same family as Google TTS.
 * Always bilingual (Filipino + English), independent of the app language
 * setting and of whatever speech pack an OEM phone has installed.
 */
class SpeechCapture(
    private val activity: Activity,
    private val channel: MethodChannel,
) : RecognitionListener {
    private val main = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var listening = false
    @Volatile private var sessionActive = false
    @Volatile private var startGeneration = 0
    private var lastWords = ""
    private var languageMode = 0

    fun isAvailable(): Boolean = true

    fun hasPack(locale: String?): Boolean = true

    fun prepare() {
        // Google speech is an API, not an in-app model pack.
    }

    fun start(locale: String?) {
        val generation = ++startGeneration
        sessionActive = true
        lastWords = ""
        languageMode = 0
        main.post {
            if (!stillThisStart(generation)) return@post
            ensureRecognizer()
            beginListening(generation)
        }
    }

    fun prefetch(locale: String?) {
        prepare()
    }

    fun stop() {
        sessionActive = false
        startGeneration++
        listening = false
        main.post {
            try {
                recognizer?.stopListening()
            } catch (_: Exception) {
            }
            notify("onStatus", "done")
        }
    }

    fun cancel() {
        sessionActive = false
        startGeneration++
        listening = false
        main.post {
            try {
                recognizer?.cancel()
            } catch (_: Exception) {
            }
            notify("onStatus", "done")
        }
    }

    fun destroy() {
        sessionActive = false
        startGeneration++
        listening = false
        main.post {
            try {
                recognizer?.destroy()
            } catch (_: Exception) {
            }
            recognizer = null
        }
    }

    private fun ensureRecognizer() {
        if (recognizer != null) return
        val google = findGoogleRecognizer()
        recognizer = if (google != null) {
            Log.d(TAG, "Using Google recognizer ${google.packageName}/${google.className}")
            SpeechRecognizer.createSpeechRecognizer(activity, google)
        } else {
            Log.d(TAG, "Using default SpeechRecognizer")
            SpeechRecognizer.createSpeechRecognizer(activity)
        }
        recognizer?.setRecognitionListener(this)
    }

    private fun resetRecognizer() {
        try {
            recognizer?.destroy()
        } catch (_: Exception) {
        }
        recognizer = null
        ensureRecognizer()
    }

    private fun beginListening(generation: Int) {
        if (!stillThisStart(generation)) return
        try {
            if (listening) {
                try {
                    recognizer?.cancel()
                } catch (_: Exception) {
                }
            }
            listening = true
            recognizer?.startListening(buildIntent())
            notify("onStatus", "listening")
        } catch (e: Exception) {
            Log.e(TAG, "startListening failed", e)
            listening = false
            if (stillThisStart(generation)) {
                notify("onError", "error_client")
                notify("onStatus", "done")
            }
        }
    }

    private fun scheduleRestart(delayMs: Long = 180) {
        if (!sessionActive) return
        val generation = startGeneration
        main.postDelayed({
            if (!stillThisStart(generation)) return@postDelayed
            beginListening(generation)
        }, delayMs)
    }

    private fun findGoogleRecognizer(): ComponentName? {
        val list = activity.packageManager.queryIntentServices(
            Intent(RecognitionService.SERVICE_INTERFACE),
            0,
        )
        val preferred = list.mapNotNull { it.serviceInfo }.sortedBy { info ->
            val pkg = info.packageName.lowercase()
            when {
                pkg.contains("googlequicksearchbox") -> 0
                pkg.contains("google.android.tts") -> 1
                pkg.contains("google.android.as") -> 2
                pkg.contains("google") -> 3
                else -> 9
            }
        }
        val info = preferred.firstOrNull { it.packageName.contains("google", ignoreCase = true) }
            ?: return null
        return ComponentName(info.packageName, info.name)
    }

    private fun buildIntent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.packageName)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                2500,
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                2000,
            )
            when (languageMode) {
                0 -> {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "fil-PH")
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "fil-PH")
                    putExtra(
                        EXTRA_ADDITIONAL_LANGUAGES,
                        arrayOf("en-PH", "en-US", "tl-PH", "fil", "en"),
                    )
                }
                1 -> {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "tl-PH")
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "tl-PH")
                    putExtra(
                        EXTRA_ADDITIONAL_LANGUAGES,
                        arrayOf("en-PH", "en-US", "fil-PH", "fil", "en"),
                    )
                }
                else -> {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-PH")
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "en-PH")
                    putExtra(
                        EXTRA_ADDITIONAL_LANGUAGES,
                        arrayOf("fil-PH", "tl-PH", "en-US", "fil"),
                    )
                }
            }
        }
    }

    private fun sendResults(bundle: Bundle?, isFinal: Boolean) {
        val matches = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val words = matches?.firstOrNull { it.isNotBlank() }?.trim().orEmpty()
        if (words.isEmpty()) return
        if (!isFinal && words == lastWords) return
        lastWords = words
        notify(
            "onResult",
            hashMapOf(
                "words" to words,
                "final" to isFinal,
            ),
        )
    }

    private fun stillThisStart(generation: Int): Boolean {
        return sessionActive && generation == startGeneration
    }

    private fun notify(method: String, args: Any?) {
        main.post {
            try {
                channel.invokeMethod(method, args)
            } catch (e: Exception) {
                Log.w(TAG, "notify $method failed", e)
            }
        }
    }

    override fun onReadyForSpeech(params: Bundle?) {}
    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() {}
    override fun onEvent(eventType: Int, params: Bundle?) {}

    override fun onPartialResults(partialResults: Bundle?) {
        if (!sessionActive) return
        sendResults(partialResults, false)
    }

    override fun onResults(results: Bundle?) {
        listening = false
        if (!sessionActive) return
        sendResults(results, true)
        lastWords = ""
        scheduleRestart()
    }

    override fun onError(error: Int) {
        listening = false
        val msg = when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "error_audio_error"
            SpeechRecognizer.ERROR_CLIENT -> "error_client"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
            SpeechRecognizer.ERROR_NETWORK -> "error_network"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_network_timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_busy"
            SpeechRecognizer.ERROR_SERVER -> "error_server"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_speech_timeout"
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "error_language_not_supported"
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "error_language_unavailable"
            else -> "error_unknown ($error)"
        }
        Log.d(TAG, "onError $msg")
        if (!sessionActive) return
        val languageError = error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ||
            error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE
        if (languageError && languageMode < 2) {
            languageMode++
            Log.d(TAG, "Language fallback mode=$languageMode")
            resetRecognizer()
            scheduleRestart(200)
            return
        }
        val restartable = error == SpeechRecognizer.ERROR_NO_MATCH ||
            error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT ||
            error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY ||
            error == SpeechRecognizer.ERROR_CLIENT ||
            error == SpeechRecognizer.ERROR_NETWORK ||
            error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT ||
            error == SpeechRecognizer.ERROR_SERVER
        if (restartable) {
            if (error == SpeechRecognizer.ERROR_CLIENT ||
                error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY
            ) {
                resetRecognizer()
            }
            scheduleRestart(if (error == SpeechRecognizer.ERROR_CLIENT) 350 else 180)
            return
        }
        notify("onError", msg)
        notify("onStatus", "done")
    }

    companion object {
        private const val TAG = "SpeechCapture"
        private const val EXTRA_ADDITIONAL_LANGUAGES =
            "android.speech.extra.EXTRA_ADDITIONAL_LANGUAGES"
    }
}
