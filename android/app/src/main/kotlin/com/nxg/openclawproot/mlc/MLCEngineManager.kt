package com.nxg.openclawproot.mlc

import android.content.Context
import android.util.Log

/**
 * Manages the MLC-LLM native GPU inference engine lifecycle.
 *
 * MLC-LLM uses the ChatModule API (org.apache.tvm.contrib.android)
 * for GPU-accelerated inference via OpenCL on Adreno/Mali GPUs.
 *
 * IMPORTANT: To use this, you must:
 * 1. Pre-compile models with `mlc_llm package` on your dev machine
 * 2. Place compiled model artifacts in assets/mlc-models/
 * 3. Add mlc4j (tvm4j_core.jar + libtvm4j_runtime_packed.so) to libs/
 *
 * The engine exposes an OpenAI-compatible HTTP server on 127.0.0.1:8000
 * via LocalOpenAIServer, so OpenClaw in PRoot can connect to it
 * identically to how it connects to Ollama.
 */
object MLCEngineManager {
    private const val TAG = "MLCEngineManager"
    private var server: LocalOpenAIServer? = null
    private var isStarted = false

    // TODO: Replace with actual ChatModule when mlc4j is integrated
    // private var chatModule: ChatModule? = null

    /**
     * Start the MLC engine with the given model and spin up the
     * OpenAI-compatible HTTP proxy on port 8000.
     */
    fun start(context: Context, modelId: String) {
        if (isStarted) {
            Log.w(TAG, "MLC engine already running")
            return
        }

        Log.i(TAG, "Starting MLC engine with model: $modelId")

        try {
            // Step 1: Initialize the MLC ChatModule with GPU backend
            // When mlc4j is integrated, this becomes:
            //   chatModule = ChatModule()
            //   chatModule!!.reload(modelId, context.applicationInfo.nativeLibraryDir)
            //
            // For now, we create the proxy server in stub mode

            // Step 2: Start the OpenAI-compatible HTTP server
            server = LocalOpenAIServer(modelId)
            server!!.start()

            isStarted = true
            Log.i(TAG, "MLC engine started — OpenAI proxy listening on http://127.0.0.1:8000")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start MLC engine", e)
            stop()
            throw e
        }
    }

    /**
     * Stop the MLC engine and its HTTP proxy.
     */
    fun stop() {
        try {
            server?.stop()
            // chatModule?.unload()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping MLC engine", e)
        } finally {
            server = null
            // chatModule = null
            isStarted = false
            Log.i(TAG, "MLC engine stopped")
        }
    }

    fun isRunning(): Boolean = isStarted
}
