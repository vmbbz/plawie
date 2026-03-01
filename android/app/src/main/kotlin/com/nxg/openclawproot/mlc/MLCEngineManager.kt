// android/app/src/main/kotlin/com/nxg/openclawproot/mlc/MLCEngineManager.kt
package com.nxg.openclawproot.mlc

import android.content.Context
import java.io.File
import android.util.Log

/**
 * Manages the MLC-LLM native GPU inference engine lifecycle.
 * STUBBED: Currently disabled to bypass missing tvm4j_core.jar build failure.
 * Ollama/OpenClaw backends remain fully functional.
 */
object MLCEngineManager {
    private const val TAG = "MLCEngineManager"
    private var isStubEnabled = true

    fun start(context: Context, modelId: String) {
        Log.i(TAG, "MLC Engine started (STUB MODE). GPU acceleration is currently disabled.")
    }

    fun generateStream(
        prompt: String,
        onToken: (String) -> Unit,
        onComplete: () -> Unit,
        onError: (String) -> Unit
    ) {
        // Simple stub response for debugging if MLC is called
        onToken(" MLC GPU acceleration is currently disabled in this build. ")
        onToken(" Please use the Ollama or remote backends via the OpenClaw gateway. ")
        onComplete()
    }

    fun stop() {
        Log.i(TAG, "MLC Engine stopped.")
    }

    fun isRunning() = isStubEnabled

    private fun copyModelFromAssetsIfNeeded(context: Context, modelId: String): File {
        val dest = File(context.filesDir, "mlc_models/$modelId")
        if (dest.exists() && File(dest, "mlc-chat-config.json").exists()) {
            Log.i(TAG, "Model $modelId already exists at ${dest.absolutePath}")
            return dest
        }
        
        // Since we are no longer bundling 1GB+ models in assets:
        // We return the destination and let the LocalOpenAIServer or a front-end 
        // service handle the download if it's missing.
        Log.w(TAG, "Model $modelId not found. It needs to be downloaded to ${dest.absolutePath}")
        dest.mkdirs()
        return dest
    }

    private fun copyAssetsRecursive(context: Context, assetPath: String, destDir: File) {
        val assetManager = context.assets
        val files = assetManager.list(assetPath) ?: return
        destDir.mkdirs()
        for (file in files) {
            val fullAssetPath = if (assetPath.isEmpty()) file else "$assetPath/$file"
            val outFile = File(destDir, file)
            val children = assetManager.list(fullAssetPath)
            if (children != null && children.isNotEmpty()) {
                // directory
                copyAssetsRecursive(context, fullAssetPath, outFile)
            } else {
                // file
                try {
                    assetManager.open(fullAssetPath).use { input ->
                        java.io.FileOutputStream(outFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                } catch (e: java.io.IOException) {
                    // Fallback for empty directories or special asset types
                    Log.d(TAG, "Skipping or cannot open asset: $fullAssetPath")
                }
            }
        }
    }
}
