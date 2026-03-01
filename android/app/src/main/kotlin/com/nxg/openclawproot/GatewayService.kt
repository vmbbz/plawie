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
import android.util.Log
import androidx.core.app.NotificationCompat

import io.flutter.plugin.common.EventChannel

class GatewayService : Service() {
    companion object {
        const val CHANNEL_ID = "openclaw_gateway"
        const val NOTIFICATION_ID = 2
        var isRunning = false
            private set
        private var instance: GatewayService? = null
        var logSink: EventChannel.EventSink? = null

        fun start(context: Context) {
            val intent = Intent(context, GatewayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, GatewayService::class.java)
            context.stopService(intent)
        }

        fun getInstance(): GatewayService? = instance
    }

    private lateinit var notificationManager: NotificationManager
    private lateinit var powerManager: PowerManager
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        createNotificationChannel()
        Log.d("GatewayService", "GatewayService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("GatewayService", "GatewayService starting")
        
        when (intent?.action) {
            "START_GATEWAY" -> {
                startGateway()
            }
            "STOP_GATEWAY" -> {
                stopGateway()
            }
            else -> {
                startGateway()
            }
        }
        
        return START_STICKY
    }

    private fun startGateway() {
        if (isRunning) {
            Log.d("GatewayService", "Gateway already running")
            return
        }

        try {
            // Acquire wake lock to keep service running
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "OpenClaw:GatewayService"
            ).apply {
                acquire(10*60*1000L) // 10 minutes
            }

            // Start foreground service
            startForeground(NOTIFICATION_ID, createNotification("OpenClaw Gateway Running"))
            
            isRunning = true
            Log.d("GatewayService", "Gateway started successfully")
            
        } catch (e: Exception) {
            Log.e("GatewayService", "Failed to start gateway", e)
            stopSelf()
        }
    }

    private fun stopGateway() {
        if (!isRunning) {
            Log.d("GatewayService", "Gateway not running")
            return
        }

        try {
            // Release wake lock
            wakeLock?.release()
            wakeLock = null
            
            isRunning = false
            Log.d("GatewayService", "Gateway stopped")
            
            stopForeground(true)
            stopSelf()
            
        } catch (e: Exception) {
            Log.e("GatewayService", "Failed to stop gateway", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OpenClaw Gateway",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "OpenClaw AI Gateway Service"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OpenClaw Gateway")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        wakeLock?.release()
        Log.d("GatewayService", "GatewayService destroyed")
    }
}
