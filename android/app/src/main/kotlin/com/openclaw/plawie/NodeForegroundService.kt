package com.openclaw.plawie

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
import android.util.Log

class NodeForegroundService : Service() {
    companion object {
        private const val TAG = "NodeForegroundService"
        const val CHANNEL_ID = "openclaw_node"
        const val NOTIFICATION_ID = 9
        var isRunning = false
            private set
        private var instance: NodeForegroundService? = null

        fun start(context: Context): Boolean {
            if (!SetupGuards.canAutomateGateway(context)) {
                Log.i(TAG, "Node foreground service deferred until setup completes")
                return false
            }
            val intent = Intent(context, NodeForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            return true
        }

        fun stop(context: Context) {
            val intent = Intent(context, NodeForegroundService::class.java)
            context.stopService(intent)
        }

        fun updateStatus(text: String) {
            instance?.updateNotification(text)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var startTime: Long = 0
    private var sharesNativeGatewayNotification = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!SetupGuards.canAutomateGateway(this)) {
            Log.i(TAG, "Stopping node foreground service while setup is incomplete")
            @Suppress("DEPRECATION")
            stopForeground(true)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        isRunning = true
        instance = this
        sharesNativeGatewayNotification =
            SetupGuards.isNativeGatewayOwner(applicationContext)
        if (startTime == 0L) {
            startTime = System.currentTimeMillis()
        }
        startForeground(activeNotificationId(), buildNotification("Node connected"))
        acquireWakeLock()
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        releaseWakeLock()
        releaseForegroundNotification()
        super.onDestroy()
    }

    private fun updateNotification(text: String) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(activeNotificationId(), buildNotification(text))
        } catch (_: Exception) {}
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) {
            return
        }
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "OpenClaw::NodeWakeLock"
        ).apply {
            setReferenceCounted(false)
        }
        wakeLock?.acquire(24 * 60 * 60 * 1000L) // 24 hours max
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun activeNotificationId(): Int =
        if (sharesNativeGatewayNotification) {
            NativeNodeEmbeddedService.GATEWAY_NOTIFICATION_ID
        } else {
            NOTIFICATION_ID
        }

    private fun activeChannelId(): String =
        if (sharesNativeGatewayNotification) {
            NativeNodeEmbeddedService.GATEWAY_NOTIFICATION_CHANNEL_ID
        } else {
            CHANNEL_ID
        }

    private fun releaseForegroundNotification() {
        @Suppress("DEPRECATION")
        if (sharesNativeGatewayNotification) {
            // NativeNodeEmbeddedService still owns this shared record. Detach
            // this service without cancelling the Gateway's notification.
            stopForeground(false)
        } else {
            stopForeground(true)
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val nodeChannel = NotificationChannel(
                CHANNEL_ID,
                "OpenClaw Node Connection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the OpenClawX Node connected in the background"
            }
            val gatewayChannel = NotificationChannel(
                NativeNodeEmbeddedService.GATEWAY_NOTIFICATION_CHANNEL_ID,
                "OpenClaw Gateway",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the official native OpenClaw gateway alive"
            }
            manager.createNotificationChannel(nodeChannel)
            manager.createNotificationChannel(gatewayChannel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, activeChannelId())
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val title =
            if (sharesNativeGatewayNotification) "OpenClaw Gateway" else "OpenClaw Node"
        val contentText =
            if (sharesNativeGatewayNotification) "Native gateway • $text" else text

        builder.setContentTitle(title)
            .setContentText(contentText)
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
