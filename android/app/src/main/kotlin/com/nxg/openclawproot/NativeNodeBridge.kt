package com.nxg.openclawproot

import android.util.Log

data class NativeNodeBridgeStartResult(
    val code: Int,
    val message: String
)

object NativeNodeBridge {
    private const val TAG = "NativeNodeBridge"

    private var loadFailure: String? = null

    init {
        try {
            System.loadLibrary("node")
            System.loadLibrary("plawie_node_bridge")
            Log.i(TAG, "Loaded libnode.so and libplawie_node_bridge.so")
        } catch (e: Throwable) {
            loadFailure = e.message ?: e.javaClass.simpleName
            Log.e(TAG, "Failed to load embedded Node libraries", e)
        }
    }

    fun start(args: Array<String>): NativeNodeBridgeStartResult {
        val failure = loadFailure
        if (failure != null) {
            return NativeNodeBridgeStartResult(-1, failure)
        }

        return try {
            when (val code = startNode(args)) {
                0 -> NativeNodeBridgeStartResult(code, "started")
                1 -> NativeNodeBridgeStartResult(code, "already running")
                -2 -> NativeNodeBridgeStartResult(code, "libnode.so missing at bridge build time")
                -3 -> NativeNodeBridgeStartResult(code, "no argv supplied")
                else -> NativeNodeBridgeStartResult(code, "start failed")
            }
        } catch (e: Throwable) {
            NativeNodeBridgeStartResult(-4, e.message ?: e.javaClass.simpleName)
        }
    }

    fun running(): Boolean {
        val failure = loadFailure
        if (failure != null) return false
        return try {
            isRunning()
        } catch (_: Throwable) {
            false
        }
    }

    fun exitCode(): Int {
        val failure = loadFailure
        if (failure != null) return -997
        return try {
            lastExitCode()
        } catch (_: Throwable) {
            -996
        }
    }

    private external fun startNode(args: Array<String>): Int
    private external fun isRunning(): Boolean
    private external fun lastExitCode(): Int
}
