package com.nxg.openclawproot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Boot receiver — auto-starts the Clawa foreground service after device reboot.
 * Only starts if the user has enabled auto-start in preferences.
 * 
 * directBootAware=false: starts after first unlock (not during Direct Boot).
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
        private const val PREF_NAME = "FlutterSharedPreferences"
        private const val PREF_AUTO_START = "flutter.auto_start_gateway"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        // Check if user has opted into auto-start
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val autoStart = prefs.getBoolean(PREF_AUTO_START, false)

        if (autoStart) {
            Log.i(TAG, "Boot completed — auto-starting Clawa services")
            try {
                ClawaForegroundService.start(context)
                NodeForegroundService.start(context)
            } catch (e: Exception) {
                // Android 14+ may block foreground service start from a broadcast receiver.
                // The service will start when the user opens the app.
                Log.w(TAG, "Boot auto-start blocked by OS: ${e.message}")
            }
        } else {
            Log.i(TAG, "Boot completed — auto-start disabled, skipping")
        }
    }
}
