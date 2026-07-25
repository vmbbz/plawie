package com.openclaw.plawie

import android.content.Context
import java.io.File

/**
 * Shared native setup gates.
 *
 * "Bootstrap complete" must mean the full Plawie setup sequence has landed,
 * not just that rootfs/node/openclaw binaries happen to exist. The watchdog,
 * boot receiver, and heartbeat worker all use this guard so they cannot start
 * or restart the gateway while setup is still writing config.
 */
object SetupGuards {
    private const val PREF_NAME = "FlutterSharedPreferences"
    private const val PREF_SETUP_IN_PROGRESS = "flutter.setup_in_progress"
    private const val PREF_SETUP_COMPLETE = "flutter.setup_complete"
    private const val PREF_GATEWAY_RUNTIME_OWNER = "flutter.gateway_runtime_owner"
    private const val OWNER_PROOT = "proot"
    private const val OWNER_NATIVE_PRODUCTION = "native-node-full-gateway-production"
    private const val SETUP_COMPLETE_MARKER = "setup/.bootstrap_complete"
    private const val LEGACY_SETUP_COMPLETE_MARKER =
        "rootfs/root/.clawa/.bootstrap_complete"

    fun isSetupInProgress(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        return SetupService.isRunning || prefs.getBoolean(PREF_SETUP_IN_PROGRESS, false)
    }

    fun hasSetupCompleteMarker(context: Context): Boolean {
        return File(context.filesDir, SETUP_COMPLETE_MARKER).exists() ||
            File(context.filesDir, LEGACY_SETUP_COMPLETE_MARKER).exists()
    }

    fun isMarkedSetupComplete(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        return hasSetupCompleteMarker(context) || prefs.getBoolean(PREF_SETUP_COMPLETE, false)
    }

    fun canAutomateGateway(context: Context): Boolean {
        return isMarkedSetupComplete(context) && !isSetupInProgress(context)
    }

    fun gatewayRuntimeOwner(context: Context): String {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        return prefs.getString(PREF_GATEWAY_RUNTIME_OWNER, null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: OWNER_NATIVE_PRODUCTION
    }

    fun isProotGatewayOwner(context: Context): Boolean {
        return gatewayRuntimeOwner(context) == OWNER_PROOT
    }

    fun isNativeGatewayOwner(context: Context): Boolean {
        return !isProotGatewayOwner(context)
    }
}
