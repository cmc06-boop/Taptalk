package com.example.flutter_application_1

import android.content.Context
import android.util.Log
import org.vosk.Model
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap

/**
 * English (small) + Filipino Vosk models shipped in the APK, copied once
 * into app storage. Not phone Settings packs.
 */
class SpeechPackStore(private val context: Context) {
    data class Pack(
        val id: String,
        val assetFolder: String,
        val label: String,
    )

    fun isReady(pack: Pack): Boolean = findModelRoot(modelDir(pack)) != null

    fun areBothReady(): Boolean = isReady(ENGLISH) && isReady(FILIPINO)

    fun ensureUnpacked(pack: Pack) {
        synchronized(lockFor(pack.id)) {
            if (isReady(pack)) return
            val dest = modelDir(pack)
            if (dest.exists()) dest.deleteRecursively()
            dest.mkdirs()
            copyAssetFolder(pack.assetFolder, dest)
            if (findModelRoot(dest) == null) {
                throw IllegalStateException("Unpacked ${pack.label} model is incomplete")
            }
            Log.d(TAG, "Unpacked ${pack.label} model to ${dest.absolutePath}")
        }
    }

    fun openModel(pack: Pack): Model {
        ensureUnpacked(pack)
        val root = findModelRoot(modelDir(pack))
            ?: throw IllegalStateException("${pack.label} model not found")
        return Model(root.absolutePath)
    }

    private fun modelDir(pack: Pack): File = File(context.filesDir, "stt/${pack.id}")

    private fun findModelRoot(dir: File): File? {
        if (!dir.exists()) return null
        if (looksLikeModel(dir)) return dir
        return dir.listFiles()?.firstOrNull { it.isDirectory && looksLikeModel(it) }
    }

    private fun looksLikeModel(dir: File): Boolean {
        return dir.resolve("am").exists() && dir.resolve("conf").exists()
    }

    private fun copyAssetFolder(assetFolder: String, dest: File) {
        val names = context.assets.list(assetFolder)
            ?: throw IllegalStateException("Missing asset folder $assetFolder")
        if (names.isEmpty()) {
            throw IllegalStateException("Empty asset folder $assetFolder")
        }
        dest.mkdirs()
        for (name in names) {
            val child = "$assetFolder/$name"
            val nested = context.assets.list(child)
            if (nested.isNullOrEmpty()) {
                context.assets.open(child).use { input ->
                    FileOutputStream(File(dest, name)).use { output ->
                        input.copyTo(output)
                    }
                }
            } else {
                copyAssetFolder(child, File(dest, name))
            }
        }
    }

    companion object {
        private const val TAG = "SpeechPackStore"
        val ENGLISH = Pack("en", "model-en", "English")
        val FILIPINO = Pack("tl", "model-tl", "Filipino")
        private val locks = ConcurrentHashMap<String, Any>()
        fun lockFor(id: String): Any = locks.getOrPut(id) { Any() }
    }
}
