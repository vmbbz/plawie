package com.nxg.openclawproot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

/**
 * Foreground service that keeps the OpenClaw gateway alive.
 * 
 * Features (inspired by SeekerClaw's architecture):
 * - START_STICKY: OS restarts service if killed
 * - Partial wake lock: prevents CPU from sleeping
 * - Watchdog: health-checks gateway every 30s, auto-restarts after 2 failures
 * - Notification: shows gateway status with uptime chronometer
 */
class ClawaForegroundService : Service() {
    companion object {
        private const val TAG = "ClawaService"
        const val CHANNEL_ID = "clawa_local_agent"
        const val NOTIFICATION_ID = 4
        
        // Actions
        const val ACTION_STOP = "com.nxg.openclawproot.ACTION_STOP"
        const val ACTION_RESTART = "com.nxg.openclawproot.ACTION_RESTART"
        
        // Watchdog configuration (matching SeekerClaw patterns)
        private const val WATCHDOG_INTERVAL_MS = 30_000L    // 30 seconds
        private const val HEALTH_TIMEOUT_MS = 10_000        // 10 second timeout for HTTP check
        private const val MAX_CONSECUTIVE_FAILURES = 2       // Restart after 2 missed checks
        private const val MAX_RESTARTS_PER_HOUR = 3          // Cap restarts to avoid loops
        private const val GATEWAY_PORT = 18789

        var isRunning = false
            private set
        private var instance: ClawaForegroundService? = null

        fun start(context: Context) {
            val intent = Intent(context, ClawaForegroundService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Android 14+ may throw ForegroundServiceStartNotAllowedException
                // if the app window isn't fully visible yet.
                Log.w(TAG, "startForegroundService blocked, retrying in 500ms: ${e.message}")
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(intent)
                        } else {
                            context.startService(intent)
                        }
                    } catch (e2: Exception) {
                        Log.e(TAG, "Retry also failed: ${e2.message}")
                        // Fall back to regular startService — won't have fg notification
                        // but at least won't crash
                        try { context.startService(intent) } catch (_: Exception) {}
                    }
                }, 500)
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

    // Watchdog state
    private val handler = Handler(Looper.getMainLooper())
    private var consecutiveFailures = 0
    private val restartTimestamps = mutableListOf<Long>()
    private var watchdogActive = false
    private lateinit var processManager: ProcessManager

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val nativeLibDir = applicationInfo.nativeLibraryDir
        processManager = ProcessManager(filesDir.absolutePath, nativeLibDir)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Log.i(TAG, "Notification ACTION_STOP received")
                stop(this)
                return START_NOT_STICKY
            }
            ACTION_RESTART -> {
                Log.i(TAG, "Notification ACTION_RESTART received")
                attemptRestart()
                return START_STICKY
            }
        }

        isRunning = true
        instance = this
        startTime = System.currentTimeMillis()
        startForeground(NOTIFICATION_ID, buildNotification("Clawa Local Agent Running"))
        acquireWakeLock()
        
        // Start the localhost HTTP bridge for Node.js
        AndroidBridgeServer.startServer(applicationContext)
        
        startWatchdog()
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        stopWatchdog()
        AndroidBridgeServer.stopServer()
        releaseWakeLock()
        super.onDestroy()
    }

    // ================================================================
    // Watchdog — health-checks the gateway, auto-restarts on failure
    // ================================================================

    private val watchdogRunnable = object : Runnable {
        override fun run() {
            if (!watchdogActive) return
            
            Thread {
                val healthy = checkGatewayHealth()
                handler.post {
                    if (!watchdogActive) return@post
                    
                    if (healthy) {
                        if (consecutiveFailures > 0) {
                            Log.i(TAG, "Gateway recovered after $consecutiveFailures failures")
                        }
                        consecutiveFailures = 0
                        updateNotification("Gateway running")
                    } else {
                        consecutiveFailures++
                        Log.w(TAG, "Watchdog: health check failed ($consecutiveFailures/$MAX_CONSECUTIVE_FAILURES)")
                        updateNotification("Gateway check failed ($consecutiveFailures)")
                        
                        if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
                            attemptRestart()
                        }
                    }
                    
                    // Schedule next check
                    handler.postDelayed(this, WATCHDOG_INTERVAL_MS)
                }
            }.start()
        }
    }

    private fun startWatchdog() {
        if (watchdogActive) return
        watchdogActive = true
        consecutiveFailures = 0
        // First check after a delay to let gateway finish starting
        handler.postDelayed(watchdogRunnable, WATCHDOG_INTERVAL_MS)
        Log.i(TAG, "Watchdog started (${WATCHDOG_INTERVAL_MS / 1000}s interval)")
    }

    private fun stopWatchdog() {
        watchdogActive = false
        handler.removeCallbacks(watchdogRunnable)
        Log.i(TAG, "Watchdog stopped")
    }

    /**
     * HTTP HEAD check against the gateway port.
     * Returns true if the gateway responds (any status code).
     */
    private fun checkGatewayHealth(): Boolean {
        return try {
            val url = URL("http://127.0.0.1:$GATEWAY_PORT")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "HEAD"
            conn.connectTimeout = HEALTH_TIMEOUT_MS
            conn.readTimeout = HEALTH_TIMEOUT_MS
            conn.connect()
            val code = conn.responseCode
            conn.disconnect()
            code in 100..599  // Any HTTP response means gateway is alive
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Restart the gateway process, with rate limiting to avoid crash loops.
     */
    private fun attemptRestart() {
        val now = System.currentTimeMillis()
        
        // Prune timestamps older than 1 hour
        restartTimestamps.removeAll { now - it > 3_600_000L }
        
        if (restartTimestamps.size >= MAX_RESTARTS_PER_HOUR) {
            Log.e(TAG, "Watchdog: restart cap reached ($MAX_RESTARTS_PER_HOUR/hr). Gateway may need manual intervention.")
            updateNotification("Gateway failed — restart cap reached")
            return
        }
        
        Log.i(TAG, "Watchdog: restarting gateway (attempt ${restartTimestamps.size + 1}/$MAX_RESTARTS_PER_HOUR)")
        updateNotification("Restarting gateway...")
        consecutiveFailures = 0
        restartTimestamps.add(now)
        
        Thread {
            try {
                // Kill existing gateway process
                processManager.stopGateway()
                Thread.sleep(2000)
                // Start fresh
                val success = processManager.startGateway()
                handler.post {
                    if (success) {
                        Log.i(TAG, "Watchdog: gateway restarted successfully")
                        updateNotification("Gateway restarted")
                    } else {
                        Log.e(TAG, "Watchdog: gateway restart failed")
                        updateNotification("Gateway restart failed")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Watchdog: restart error", e)
                handler.post { updateNotification("Restart error: ${e.message}") }
            }
        }.start()
    }

    // ================================================================
    // Wake lock management
    // ================================================================

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

    // ================================================================
    // Notification
    // ================================================================

    private fun updateNotification(text: String) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Exception) {}
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

        // Add Action Buttons (Surgical upgrade for production control)
        val stopIntent = Intent(this, ClawaForegroundService::class.java).apply { action = ACTION_STOP }
        val stopPendingIntent = PendingIntent.getService(this, 1, stopIntent, PendingIntent.FLAG_IMMUTABLE)
        builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "STOP", stopPendingIntent)

        val restartIntent = Intent(this, ClawaForegroundService::class.java).apply { action = ACTION_RESTART }
        val restartPendingIntent = PendingIntent.getService(this, 2, restartIntent, PendingIntent.FLAG_IMMUTABLE)
        builder.addAction(android.R.drawable.ic_menu_rotate, "RESTART", restartPendingIntent)

        if (startTime > 0) {
            builder.setWhen(startTime)
            builder.setShowWhen(true)
            builder.setUsesChronometer(true)
        }

        return builder.build()
    }
}
