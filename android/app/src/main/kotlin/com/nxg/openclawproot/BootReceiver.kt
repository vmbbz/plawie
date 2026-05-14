package com.nxg.openclawproot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Boot receiver — auto-starts the Plawie foreground service after device reboot.
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
        val action = intent.action
        Log.i(TAG, "Received broadcast: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED) {
            handleBoot(context)
        } else if (action == "com.nxg.openclawproot.ALARM_HEARTBEAT") {
            handleHeartbeat(context)
        }
    }

    private fun handleBoot(context: Context) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val autoStart = prefs.getBoolean(PREF_AUTO_START, false)

        if (autoStart) {
            Log.i(TAG, "Auto-starting Plawie services...")
            PlawieForegroundService.start(context)
            NodeForegroundService.start(context)
        }
    }

    private fun handleHeartbeat(context: Context) {
        Log.i(TAG, "Alarm Heartbeat triggered — ensuring service health")
        if (!PlawieForegroundService.isRunning) {
            Log.w(TAG, "Service was killed, restarting via Alarm...")
            PlawieForegroundService.start(context)
        }
        
        // Reschedule for 30 mins later
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val nextIntent = Intent(context, BootReceiver::class.java).apply {
                this.action = "com.nxg.openclawproot.ALARM_HEARTBEAT"
            }
            val pendingIntent = android.app.PendingIntent.getBroadcast(
                context, 100, nextIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            val triggerAt = android.os.SystemClock.elapsedRealtime() + 30 * 60 * 1000L
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(android.app.AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reschedule alarm", e)
        }
    }
}
