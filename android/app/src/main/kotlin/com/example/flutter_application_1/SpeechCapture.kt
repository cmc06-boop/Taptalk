package com.example.flutter_application_1

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
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
 * Google speech API for live STT when online (unchanged).
 * Offline uses in-app Vosk (Filipino + small English) — no phone Settings packs.
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
    private var offlineMode = false
    private var switchedToOffline = false
    private var muted = false
    private var savedSystem = -1
    private var savedNotification = -1
    private val vosk = VoskOfflineEngine(
        activity,
        onResult = { words, isFinal ->
            if (sessionActive) {
                notify(
                    "onResult",
                    hashMapOf(
                        "words" to words,
                        "final" to isFinal,
                        "full" to true,
                    ),
                )
            }
        },
        onStatus = { status ->
            if (sessionActive || status == "done") {
                notify("onStatus", status)
            }
        },
        onError = { error ->
            if (sessionActive) notify("onError", error)
        },
    )

    fun isAvailable(): Boolean = true

    fun hasPack(locale: String?): Boolean = vosk.hasPack()

    fun prepare() {
        vosk.prepare()
    }

    fun start(locale: String?) {
        val generation = ++startGeneration
        sessionActive = true
        lastWords = ""
        languageMode = 0
        switchedToOffline = false
        val wantOffline = !hasInternet()
        main.post {
            if (!stillThisStart(generation)) return@post
            offlineMode = wantOffline
            Log.d(TAG, "start offlineMode=$offlineMode")
            if (offlineMode) {
                releaseGoogleRecognizer()
                vosk.start()
                return@post
            }
            vosk.stop()
            ensureRecognizer()
            beginListening(generation)
        }
    }

    fun prefetch(locale: String?) {
        vosk.prepare()
    }

    fun stop() {
        sessionActive = false
        startGeneration++
        listening = false
        vosk.stop()
        main.post {
            try {
                recognizer?.stopListening()
            } catch (_: Exception) {
            }
            restoreBeeps()
            notify("onStatus", "done")
        }
    }

    fun cancel() {
        sessionActive = false
        startGeneration++
        listening = false
        vosk.stop()
        main.post {
            try {
                recognizer?.cancel()
            } catch (_: Exception) {
            }
            restoreBeeps()
            notify("onStatus", "done")
        }
    }

    fun destroy() {
        sessionActive = false
        startGeneration++
        listening = false
        vosk.destroy()
        main.post {
            restoreBeeps()
            releaseGoogleRecognizer()
        }
    }

    private fun ensureRecognizer() {
        if (recognizer != null) return
        recognizer = createOnlineRecognizer()
        recognizer?.setRecognitionListener(this)
    }

    private fun createOnlineRecognizer(): SpeechRecognizer {
        val google = findGoogleRecognizer()
        return if (google != null) {
            Log.d(TAG, "Using Google recognizer ${google.packageName}/${google.className}")
            SpeechRecognizer.createSpeechRecognizer(activity, google)
        } else {
            Log.d(TAG, "Using default SpeechRecognizer")
            SpeechRecognizer.createSpeechRecognizer(activity)
        }
    }

    private fun resetRecognizer() {
        releaseGoogleRecognizer()
        ensureRecognizer()
    }

    private fun releaseGoogleRecognizer() {
        try {
            recognizer?.destroy()
        } catch (_: Exception) {
        }
        recognizer = null
        listening = false
    }

    private fun switchToOffline() {
        if (offlineMode && switchedToOffline) return
        offlineMode = true
        switchedToOffline = true
        languageMode = 0
        releaseGoogleRecognizer()
        vosk.start()
        Log.d(TAG, "Switched to in-app Vosk offline recognition")
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

    private fun hasInternet(): Boolean {
        return try {
            val cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork ?: return false
            val caps = cm.getNetworkCapabilities(network) ?: return false
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        } catch (_: Exception) {
            false
        }
    }

    private fun muteBeeps() {
        if (muted) return
        try {
            val am = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            savedSystem = am.getStreamVolume(AudioManager.STREAM_SYSTEM)
            savedNotification = am.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
            am.setStreamVolume(AudioManager.STREAM_SYSTEM, 0, 0)
            am.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)
            muted = true
        } catch (e: Exception) {
            Log.w(TAG, "muteBeeps failed", e)
        }
    }

    private fun restoreBeeps() {
        if (!muted) return
        try {
            val am = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (savedSystem >= 0) {
                am.setStreamVolume(AudioManager.STREAM_SYSTEM, savedSystem, 0)
            }
            if (savedNotification >= 0) {
                am.setStreamVolume(AudioManager.STREAM_NOTIFICATION, savedNotification, 0)
            }
        } catch (e: Exception) {
            Log.w(TAG, "restoreBeeps failed", e)
        }
        muted = false
        savedSystem = -1
        savedNotification = -1
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
        Log.d(TAG, "onError $msg offlineMode=$offlineMode")
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
        val networkError = error == SpeechRecognizer.ERROR_NETWORK ||
            error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT ||
            error == SpeechRecognizer.ERROR_SERVER
        if (networkError) {
            if (!offlineMode) {
                switchToOffline()
            }
            return
        }
        val restartable = error == SpeechRecognizer.ERROR_NO_MATCH ||
            error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT ||
            error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY ||
            error == SpeechRecognizer.ERROR_CLIENT
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
