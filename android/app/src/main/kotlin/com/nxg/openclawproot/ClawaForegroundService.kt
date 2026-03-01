package com.nxg.openclawproot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

class ClawaForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "clawa_local_agent"
        const val NOTIFICATION_ID = 4
        var isRunning = false
            private set
        private var instance: ClawaForegroundService? = null

        fun start(context: Context) {
            val intent = Intent(context, ClawaForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, ClawaForegroundService::class.java)
            context.stopService(intent)
        }

        fun updateStatus(text: String) {
            instance?.updateNotification(text)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var startTime: Long = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        instance = this
        startTime = System.currentTimeMillis()
        startForeground(NOTIFICATION_ID, buildNotification("Clawa Local Agent Running"))
        acquireWakeLock()
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        releaseWakeLock()
        super.onDestroy()
    }

    private fun updateNotification(text: String) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Exception) {}
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "OpenClaw::AgentWakeLock"
        )
        wakeLock?.acquire(24 * 60 * 60 * 1000L) // 24 hours max
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Clawa Local Agent",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the Clawa environment running in the background"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder.setContentTitle("Clawa Local Agent")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(pendingIntent)
            .setOngoing(true)

        if (startTime > 0) {
            builder.setWhen(startTime)
            builder.setShowWhen(true)
            builder.setUsesChronometer(true)
        }

        return builder.build()
    }
}
