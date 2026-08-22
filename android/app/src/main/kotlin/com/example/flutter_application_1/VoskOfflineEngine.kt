package com.example.flutter_application_1

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import org.vosk.Recognizer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Offline STT: English and Filipino Vosk are equal bases. A whole
 * utterance uses one model when that language is clear; Taglish mixes
 * both by time. Online Google is not used here.
 */
class VoskOfflineEngine(
    private val activity: Activity,
    private val onResult: (words: String, isFinal: Boolean) -> Unit,
    private val onStatus: (status: String) -> Unit,
    private val onError: (error: String) -> Unit,
) {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val store = SpeechPackStore(activity.applicationContext)
    private val running = AtomicBoolean(false)
    private val modelsReady = AtomicBoolean(false)

    @Volatile private var enModel: org.vosk.Model? = null
    @Volatile private var tlModel: org.vosk.Model? = null
    @Volatile private var recorder: AudioRecord? = null
    @Volatile private var sessionId = 0

    fun prepare() {
        worker.execute {
            try {
                ensureModels()
            } catch (e: Exception) {
                Log.w(TAG, "prepare failed", e)
            }
        }
    }

    fun hasPack(): Boolean = store.areBothReady() || modelsReady.get()

    fun start() {
        val id = ++sessionId
        worker.execute {
            if (id != sessionId) return@execute
            try {
                if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                    != PackageManager.PERMISSION_GRANTED
                ) {
                    emitError("error_permission")
                    return@execute
                }
                emitStatus("loading")
                ensureModels()
                if (id != sessionId) return@execute
                startCapture(id)
            } catch (e: Exception) {
                Log.e(TAG, "Vosk start failed", e)
                emitError("error_pack_failed")
            }
        }
    }

    fun stop() {
        sessionId++
        running.set(false)
        releaseRecorder()
    }

    fun destroy() {
        stop()
        worker.execute {
            try {
                enModel?.close()
            } catch (_: Exception) {
            }
            try {
                tlModel?.close()
            } catch (_: Exception) {
            }
            enModel = null
            tlModel = null
            modelsReady.set(false)
        }
    }

    private fun ensureModels() {
        if (modelsReady.get() && enModel != null && tlModel != null) return
        synchronized(this) {
            if (modelsReady.get() && enModel != null && tlModel != null) return
            Log.d(TAG, "Loading English-small + Filipino Vosk models")
            store.ensureUnpacked(SpeechPackStore.ENGLISH)
            store.ensureUnpacked(SpeechPackStore.FILIPINO)
            if (enModel == null) enModel = store.openModel(SpeechPackStore.ENGLISH)
            if (tlModel == null) tlModel = store.openModel(SpeechPackStore.FILIPINO)
            modelsReady.set(true)
        }
    }

    private fun startCapture(id: Int) {
        val english = enModel
        val filipino = tlModel
        if (english == null || filipino == null) {
            emitError("error_pack_failed")
            return
        }

        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufferSize = (minBuf * 2).coerceAtLeast(4096)
        val record = openRecorder(bufferSize)
        if (record == null) {
            emitError("error_audio_error")
            return
        }

        val enRec = Recognizer(english, SAMPLE_RATE.toFloat())
        val tlRec = Recognizer(filipino, SAMPLE_RATE.toFloat())
        enRec.setWords(true)
        tlRec.setWords(true)
        try {
            enRec.setPartialWords(true)
            tlRec.setPartialWords(true)
        } catch (_: Exception) {
        }

        recorder = record
        running.set(true)
        record.startRecording()
        emitStatus("listening")
        Log.d(TAG, "Offline Vosk capture started")

        val buf = ByteArray(bufferSize / 2)
        var lastEmitted = ""
        var sessionText = ""
        var lastEnJson = ""
        var lastTlJson = ""
        var lock: String? = null
        var enEnded = false
        var tlEnded = false
        var waitChunks = 0
        try {
            while (running.get() && id == sessionId) {
                val n = record.read(buf, 0, buf.size)
                if (n <= 0) continue

                val enFinal = enRec.acceptWaveForm(buf, n)
                val tlFinal = tlRec.acceptWaveForm(buf, n)
                val enJson = if (enFinal) enRec.result else enRec.partialResult
                val tlJson = if (tlFinal) tlRec.result else tlRec.partialResult
                if (enJson.isNotBlank()) lastEnJson = enJson
                if (tlJson.isNotBlank()) lastTlJson = tlJson
                if (enFinal) enEnded = true
                if (tlFinal) tlEnded = true

                val enText = phraseText(lastEnJson)
                val tlText = phraseText(lastTlJson)
                val enWords = timedWords(lastEnJson, "en")
                val tlWords = timedWords(lastTlJson, "tl")
                val enScore = scoreEnglish(enText, enWords)
                val tlScore = scoreFilipino(tlText, tlWords)
                val nextLock = decideLock(lock, enText, tlText, enScore, tlScore)
                if (nextLock != lock && sessionText.isEmpty()) {
                    lastEmitted = ""
                }
                lock = nextLock
                val merged = hypothesis(lock, enText, tlText, enWords, tlWords)

                val ended = utteranceEnded(lock, enEnded, tlEnded, enText, tlText, waitChunks)
                if (!ended && (enEnded || tlEnded) && lock == "mix") waitChunks++
                if (ended) {
                    if (merged.isNotEmpty()) {
                        sessionText = joinUtterance(sessionText, merged)
                        lastEmitted = sessionText
                        Log.i(
                            TAG,
                            "final en='$enText'($enScore) tl='$tlText'($tlScore) lock=$lock -> '$sessionText'",
                        )
                        emitResult(sessionText, true)
                    }
                    enRec.reset()
                    tlRec.reset()
                    lastEnJson = ""
                    lastTlJson = ""
                    lock = null
                    enEnded = false
                    tlEnded = false
                    waitChunks = 0
                } else if (shouldEmitPartial(lastEmitted, joinUtterance(sessionText, merged))) {
                    val shown = joinUtterance(sessionText, merged)
                    lastEmitted = shown
                    Log.i(
                        TAG,
                        "partial en='$enText'($enScore) tl='$tlText'($tlScore) lock=$lock -> '$shown'",
                    )
                    emitResult(shown, false)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Offline capture loop failed", e)
            if (id == sessionId) emitError("error_audio_error")
        } finally {
            try {
                enRec.close()
            } catch (_: Exception) {
            }
            try {
                tlRec.close()
            } catch (_: Exception) {
            }
            releaseRecorder()
            if (id == sessionId) emitStatus("done")
        }
    }

    private fun openRecorder(bufferSize: Int): AudioRecord? {
        val sources = intArrayOf(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC,
        )
        for (source in sources) {
            try {
                val record = AudioRecord(
                    source,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize,
                )
                if (record.state == AudioRecord.STATE_INITIALIZED) return record
                record.release()
            } catch (e: Exception) {
                Log.w(TAG, "AudioRecord source $source failed", e)
            }
        }
        return null
    }

    private fun releaseRecorder() {
        val rec = recorder
        recorder = null
        if (rec == null) return
        try {
            if (rec.recordingState == AudioRecord.RECORDSTATE_RECORDING) rec.stop()
        } catch (_: Exception) {
        }
        try {
            rec.release()
        } catch (_: Exception) {
        }
    }

    private fun hypothesis(
        lock: String?,
        enText: String,
        tlText: String,
        enWords: List<SpkWord>,
        tlWords: List<SpkWord>,
    ): String {
        return when (lock) {
            "en" -> enText
            "tl" -> tlText
            "mix" -> mergeEqual(enWords, tlWords, enText, tlText)
            else -> ""
        }
    }

    private fun decideLock(
        current: String?,
        enText: String,
        tlText: String,
        enScore: Double,
        tlScore: Double,
    ): String? {
        val enTokens = wordsOf(enText)
        val tlTokens = wordsOf(tlText)
        val enContent = enTokens.count { it.length >= 4 && it in ENGLISH_MARKERS }
        val enMarkers = enTokens.count { it in ENGLISH_MARKERS }
        val tlContent = filipinoContentCount(tlTokens)
        val strongEn = enText.isNotEmpty() && enScore >= 0.42 && (
            enContent >= 2 ||
                (enContent >= 1 && enMarkers >= 2) ||
                (enMarkers >= 3 && tlTokens.isEmpty())
        )
        val strongTl = tlText.isNotEmpty() && (
            tlContent >= 1 || (tlTokens.count { isFilipinoWord(it) } >= 2 && tlTokens.size >= 2)
        ) && tlScore >= 0.42

        if (current == "mix") return "mix"
        if (current == "en" && !strongTl) return "en"
        if (current == "tl" && !strongEn) return "tl"

        if (strongEn && strongTl && enMarkers >= 2 && tlContent >= 1) return "mix"
        if (strongTl && enMarkers < 2) return "tl"
        if (strongEn && !strongTl) return "en"
        if (strongTl && !strongEn) return "tl"
        if (current != null) return current
        if (enContent >= 1 && enScore >= tlScore + 0.18 && tlContent == 0) return "en"
        if (tlScore >= enScore + 0.12 && tlContent >= 1) return "tl"
        if (tlText.isBlank() && enTokens.size >= 2) return "en"
        if (enText.isBlank() && tlTokens.size >= 2) return "tl"
        return current
    }

    private fun utteranceEnded(
        lock: String?,
        enEnded: Boolean,
        tlEnded: Boolean,
        enText: String,
        tlText: String,
        waitChunks: Int,
    ): Boolean {
        if (lock == null) return false
        return when (lock) {
            "en" -> enEnded || (tlEnded && enText.isEmpty())
            "tl" -> tlEnded || (enEnded && tlText.isEmpty())
            "mix" -> (enEnded && tlEnded) || waitChunks >= 8
            else -> false
        }
    }

    private fun scoreEnglish(text: String, words: List<SpkWord>): Double {
        if (text.isBlank()) return 0.0
        val tokens = wordsOf(text)
        if (tokens.isEmpty()) return 0.0
        val avgConf = if (words.isNotEmpty()) words.map { it.conf }.average() else 0.45
        val fil = tokens.count { isFilipinoWord(it) && it.length >= 3 }
        val markers = tokens.count { it.length >= 3 && it in ENGLISH_MARKERS }
        val markerRatio = markers.toDouble() / tokens.size
        val clean = 1.0 - fil.toDouble() / tokens.size
        return (avgConf * 0.45 + markerRatio * 0.30 + clean * 0.25).coerceIn(0.0, 1.0)
    }

    private fun scoreFilipino(text: String, words: List<SpkWord>): Double {
        if (text.isBlank()) return 0.0
        val tokens = wordsOf(text)
        if (tokens.isEmpty()) return 0.0
        val avgConf = if (words.isNotEmpty()) words.map { it.conf }.average() else 0.45
        val content = filipinoContentCount(tokens)
        val hits = tokens.count { isFilipinoWord(it) }
        if (content == 0 && hits <= 1) return avgConf * 0.18
        return (avgConf * 0.35 + (hits.toDouble() / tokens.size) * 0.40 +
            (content.coerceAtMost(2) / 2.0) * 0.25).coerceIn(0.0, 1.0)
    }

    private fun filipinoContentCount(tokens: List<String>): Int {
        return tokens.count { w ->
            (w in FILIPINO_MARKERS && w.length >= 4) || hasTagalogShape(w)
        }
    }

    private fun mergeEqual(
        enWords: List<SpkWord>,
        tlWords: List<SpkWord>,
        enText: String,
        tlText: String,
    ): String {
        if (enWords.isEmpty() && tlWords.isEmpty()) {
            return listOf(enText, tlText).maxByOrNull { it.length }.orEmpty()
        }
        if (tlWords.isEmpty()) return enText.ifEmpty { joinWords(enWords) }
        if (enWords.isEmpty()) return tlText.ifEmpty { joinWords(tlWords) }

        val chosen = ArrayList<SpkWord>()
        var i = 0
        var j = 0
        while (i < enWords.size || j < tlWords.size) {
            val en = enWords.getOrNull(i)
            val tl = tlWords.getOrNull(j)
            when {
                en == null -> {
                    chosen.add(tl!!)
                    j++
                }
                tl == null -> {
                    chosen.add(en)
                    i++
                }
                overlaps(en, tl) -> {
                    chosen.add(chooseWord(en, tl))
                    val picked = chosen.last()
                    while (i < enWords.size && overlaps(enWords[i], picked)) i++
                    while (j < tlWords.size && overlaps(tlWords[j], picked)) j++
                }
                tl.start <= en.start -> {
                    chosen.add(tl)
                    j++
                }
                else -> {
                    chosen.add(en)
                    i++
                }
            }
        }
        return joinWords(chosen)
    }

    private fun chooseWord(en: SpkWord, tl: SpkWord): SpkWord {
        val tlFil = isFilipinoWord(tl.word)
        val enEng = isLikelyEnglish(en)
        if (tlFil && tl.word.length >= 4) return tl
        if (enEng && en.word.length >= 4 && !tlFil) return en
        if (tlFil && en.word.length <= 3) return tl
        if (enEng && !tlFil) return en
        if (tlFil && !enEng) return tl
        return if (en.conf >= tl.conf) en else tl
    }

    private fun isLikelyEnglish(word: SpkWord): Boolean {
        if (isFilipinoWord(word.word)) return false
        if (word.word.lowercase() in ENGLISH_MARKERS) return word.conf >= 0.28
        return word.conf >= 0.55 && word.word.length >= 3
    }

    private fun shouldEmitPartial(previous: String, next: String): Boolean {
        val shown = next.trim()
        if (shown.isEmpty() || shown.equals(previous, ignoreCase = true)) return false
        if (previous.isBlank()) return looksUsable(shown)
        return shown.startsWith(previous, ignoreCase = true)
    }

    private fun looksUsable(text: String): Boolean {
        val words = wordsOf(text)
        if (words.isEmpty()) return false
        if (words.any { isFilipinoWord(it) && it.length >= 4 }) return true
        if (words.count { it.length >= 3 && it in ENGLISH_MARKERS } >= 1 && words.size >= 2) {
            return true
        }
        return words.size >= 3
    }

    private fun overlaps(a: SpkWord, b: SpkWord): Boolean {
        val overlap = minOf(a.end, b.end) - maxOf(a.start, b.start)
        if (overlap <= 0) return false
        val shorter = minOf(a.end - a.start, b.end - b.start).coerceAtLeast(0.04)
        return overlap >= shorter * 0.35
    }

    private fun timedWords(json: String, src: String): List<SpkWord> {
        if (json.isBlank()) return emptyList()
        return try {
            val obj = JSONObject(json)
            val array = when {
                obj.has("result") -> obj.optJSONArray("result")
                obj.has("partial_result") -> obj.optJSONArray("partial_result")
                else -> null
            } ?: return emptyList()
            parseWordArray(array, src)
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun parseWordArray(array: JSONArray, src: String): List<SpkWord> {
        val out = ArrayList<SpkWord>(array.length())
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            val word = item.optString("word", "")
                .replace("[unk]", "", ignoreCase = true)
                .trim()
            if (word.isEmpty()) continue
            out.add(
                SpkWord(
                    word = word,
                    start = item.optDouble("start", i.toDouble()),
                    end = item.optDouble("end", i + 0.4),
                    conf = item.optDouble("conf", 0.5),
                    src = src,
                ),
            )
        }
        return out
    }

    private fun joinWords(words: List<SpkWord>): String {
        return words.map { it.word }.filter { it.isNotBlank() }.joinToString(" ")
    }

    private fun phraseText(json: String): String {
        return textOf(json).ifEmpty { textOf(json, "partial") }
    }

    private fun textOf(json: String?, key: String = "text"): String {
        if (json.isNullOrBlank()) return ""
        return try {
            cleanText(JSONObject(json).optString(key, ""))
        } catch (_: Exception) {
            ""
        }
    }

    private fun cleanText(text: String): String {
        return text.replace("[unk]", " ", ignoreCase = true)
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private fun joinUtterance(session: String, next: String): String {
        val a = session.trim()
        val b = next.trim()
        if (a.isEmpty()) return b
        if (b.isEmpty()) return a
        if (b.startsWith(a, ignoreCase = true) || a.startsWith(b, ignoreCase = true)) {
            return if (b.length >= a.length) b else a
        }
        if (a.contains(b, ignoreCase = true)) return a
        return "$a $b"
    }

    private fun isFilipinoWord(word: String): Boolean {
        val w = word.lowercase()
        if (w in FILIPINO_MARKERS) return true
        return hasTagalogShape(w)
    }

    private fun isEnglishWord(word: String): Boolean {
        val w = word.lowercase()
        if (w in FILIPINO_MARKERS || hasTagalogShape(w)) return false
        return w in ENGLISH_MARKERS
    }

    private fun isEnglishPhrase(words: List<String>): Boolean {
        if (words.isEmpty()) return false
        val english = words.count { isEnglishWord(it) }
        val filipino = words.count { isFilipinoWord(it) }
        return english > 0 && filipino == 0
    }

    private fun hasTagalogShape(word: String): Boolean {
        if (word.length < 5) return false
        return TAGALOG_PREFIXES.any { prefix ->
            word.startsWith(prefix) && word.length >= prefix.length + 3
        }
    }

    private fun wordsOf(text: String): List<String> {
        return text.lowercase().split(Regex("[^a-z]+")).filter { it.length > 1 }
    }

    private fun emitResult(words: String, isFinal: Boolean) {
        main.post { onResult(words, isFinal) }
    }

    private fun emitStatus(status: String) {
        main.post { onStatus(status) }
    }

    private fun emitError(error: String) {
        main.post {
            onError(error)
            onStatus("done")
        }
    }

    companion object {
        private const val TAG = "VoskOffline"
        private const val SAMPLE_RATE = 16000
        private val TAGALOG_PREFIXES = listOf(
            "mag", "nag", "pag", "pinag", "naka", "maka", "pina", "nagpa", "magpa",
        )
        private val FILIPINO_MARKERS = setOf(
            "ako", "ikaw", "siya", "kami", "tayo", "kayo", "sila",
            "ang", "mga", "nang", "kay", "nina", "ngayon",
            "po", "opo", "hindi", "huwag",
            "gusto", "ayaw", "kailangan", "pwede", "puwede", "maaari",
            "salamat", "kumusta", "pasensya", "pakiusap", "paki",
            "paano", "bakit", "saan", "kailan", "alin", "sino", "ilan", "ano",
            "meron", "mayroon", "wala",
            "ito", "iyan", "iyon", "yan", "yun", "yung", "kana", "ka", "na",
            "naman", "lang", "lamang", "pala", "kasi", "talaga", "sige", "nga",
            "dito", "diyan", "doon", "rito", "riyan", "roon",
            "ate", "kuya", "nanay", "tatay", "lola", "lolo",
            "tubig", "pagkain", "kanin", "tulong", "masakit", "gutom", "uhaw",
            "bahay", "paaralan", "eskwela", "banyo", "maligo", "ligo",
            "kain", "inom", "tulog", "gising", "alis", "uwi", "pasok", "labas",
            "maganda", "mabuti", "masama",
        )
        private val ENGLISH_MARKERS = setOf(
            "the", "this", "that", "these", "those",
            "is", "are", "was", "were", "been",
            "you", "your", "we", "they", "he", "she", "my", "me",
            "hello", "please", "want", "need", "have", "has",
            "will", "would", "should", "could", "can", "go", "get", "like", "am",
            "with", "from", "what", "when", "where", "why", "how",
            "and", "for", "not", "because", "about",
            "help", "water", "food", "bathroom", "thanks", "thank",
            "yes", "stop", "eat", "drink", "sleep", "school", "teacher",
            "friend", "sorry", "okay", "wait", "come", "here",
            "there", "more", "pain", "hurt", "cold", "hot", "love",
            "hungry", "thirsty", "open", "close", "door", "please",
            "know", "think", "feel", "make", "take", "give", "look", "see",
            "going", "today", "now", "later",
        )
    }
}

private data class SpkWord(
    val word: String,
    val start: Double,
    val end: Double,
    val conf: Double,
    val src: String,
)
