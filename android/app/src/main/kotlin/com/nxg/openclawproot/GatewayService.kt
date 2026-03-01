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
    private var gatewayProcess: Process? = null
    private var logThread: Thread? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        createNotificationChannel()
        Log.d("GatewayService", "GatewayService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("GatewayService", "GatewayService onStartCommand")
        startGateway()
        return START_STICKY
    }

    private fun startGateway() {
        if (isRunning) {
            Log.d("GatewayService", "Gateway already running")
            return
        }

        Thread {
            try {
                // 1. Setup Environment
                val filesDir = applicationContext.filesDir.absolutePath
                val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir
                val processManager = ProcessManager(filesDir, nativeLibDir)

                // 2. Acquire wake lock
                wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "OpenClaw:GatewayService"
                ).apply {
                    acquire(24 * 60 * 60 * 1000L) // 24 hours
                }

                // 3. Start foreground
                startForeground(NOTIFICATION_ID, createNotification("Starting OpenClaw Gateway..."))

                // 4. Launch Process
                val command = "cd /root && openclaw gateway start"
                Log.d("GatewayService", "Launching gateway: $command")
                gatewayProcess = processManager.startProotProcess(command)

                isRunning = true
                Log.d("GatewayService", "Gateway process spawned")

                // 5. Stream Logs
                logThread = Thread {
                    try {
                        val reader = gatewayProcess?.inputStream?.bufferedReader()
                        var line: String?
                        while (reader?.readLine().also { line = it } != null) {
                            val l = line ?: continue
                            logSink?.let { sink ->
                                runOnUiThread { sink.success(l) }
                            }
                            Log.d("GatewayLog", l)
                            
                            if (l.contains("Gateway is listening")) {
                                updateNotification("OpenClaw Gateway: Running")
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("GatewayService", "Log stream error", e)
                    }
                }.also { it.start() }

                // 6. Monitor process
                val exitCode = gatewayProcess?.waitFor() ?: -1
                Log.d("GatewayService", "Gateway process exited with code $exitCode")
                stopGateway()

            } catch (e: Exception) {
                Log.e("GatewayService", "Failed to start gateway", e)
                isRunning = false
                stopSelf()
            }
        }.start()
    }

    private fun updateNotification(text: String) {
        notificationManager.notify(NOTIFICATION_ID, createNotification(text))
    }

    private fun stopGateway() {
        if (!isRunning) return

        try {
            gatewayProcess?.destroy()
            gatewayProcess = null
            logThread?.interrupt()
            logThread = null
            
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
            wakeLock = null
            
            isRunning = false
            Log.d("GatewayService", "Gateway stopped")
            
            stopForeground(true)
            stopSelf()
            
        } catch (e: Exception) {
            Log.e("GatewayService", "Failed to stop gateway", e)
        }
    }

    private fun runOnUiThread(action: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(action)
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

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopGateway()
        super.onDestroy()
        instance = null
        Log.d("GatewayService", "GatewayService destroyed")
    }
}
