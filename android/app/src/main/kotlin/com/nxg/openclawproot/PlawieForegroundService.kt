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
 * - Watchdog: health-checks gateway every 30s; only restarts on sustained failure
 * - Notification: shows gateway status with uptime chronometer
 */
class PlawieForegroundService : Service() {
    companion object {
        private const val TAG = "PlawieService"
        const val CHANNEL_ID = "plawie_local_agent"
        const val NOTIFICATION_ID = 4
        
        // Actions
        const val ACTION_STOP = "com.nxg.openclawproot.ACTION_STOP"
        const val ACTION_RESTART = "com.nxg.openclawproot.ACTION_RESTART"
        
        // Watchdog configuration (matching SeekerClaw patterns)
        private const val WATCHDOG_INTERVAL_MS = 30_000L    // 30 seconds
        private const val HEALTH_TIMEOUT_MS = 20_000         // A busy mobile gateway can stall /health during agent work
        private const val MAX_CONSECUTIVE_HTTP_FAILURES = 10 // Report busy, but do not kill a live process mid-run
        private const val MAX_CONSECUTIVE_PROCESS_DOWN = 2   // Fast restart when process is truly dead
        private const val STARTUP_GRACE_MS = 180_000L        // 3 min grace after start/restart
        private const val MAX_RESTARTS_PER_HOUR = 3          // Cap restarts to avoid loops
        private const val GATEWAY_PORT = 18789

        var isRunning = false
            private set
        private var instance: PlawieForegroundService? = null

        fun start(context: Context) {
            val intent = Intent(context, PlawieForegroundService::class.java)
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
            val intent = Intent(context, PlawieForegroundService::class.java)
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
    private var consecutiveHttpFailures = 0
    private var consecutiveProcessDown = 0
    private val restartTimestamps = mutableListOf<Long>()
    private var watchdogActive = false
    private lateinit var processManager: ProcessManager
    private lateinit var nativeNodeSmokeProcess: NativeNodeSmokeProcess

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val nativeLibDir = applicationInfo.nativeLibraryDir
        processManager = ProcessManager(applicationContext, filesDir.absolutePath, nativeLibDir)
        nativeNodeSmokeProcess = NativeNodeSmokeProcess(applicationContext, nativeLibDir)
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
                if (!SetupGuards.canAutomateGateway(this)) {
                    Log.i(TAG, "Restart ignored while setup is incomplete or in progress")
                    updateNotification("Setup in progress")
                    return START_STICKY
                }
                attemptRestart()
                return START_STICKY
            }
        }

        isRunning = true
        instance = this
        startTime = System.currentTimeMillis()
        startForeground(NOTIFICATION_ID, buildNotification("Plawie Local Agent Running"))
        acquireWakeLock()
        
        // The app-native skill bridge is now owned by Dart AgentSkillServer on
        // 127.0.0.1:8765. Starting the legacy Kotlin NanoHTTPD server here races
        // for the same port and creates noisy EADDRINUSE logs on every gateway
        // start, so keep it disabled unless we intentionally move it to a new
        // port in a future bridge refactor.
        
        startWatchdog()
        return START_STICKY
    }

    /**
     * Called when the user swipes the app away from Recents.
     * Re-deliver the start intent so the service restarts via START_STICKY.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.i(TAG, "onTaskRemoved: App swiped away — service will persist via START_STICKY")
        // Re-deliver start command to ensure onStartCommand fires again if OS kills us
        val restartIntent = Intent(applicationContext, PlawieForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(restartIntent)
        } else {
            startService(restartIntent)
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        stopWatchdog()
        // Legacy AndroidBridgeServer is intentionally not started; no-op here.
        releaseWakeLock()
        super.onDestroy()
    }

    // ================================================================
    // Watchdog — health-checks the gateway, auto-restarts on failure
    // ================================================================

    private val watchdogRunnable = object : Runnable {
        override fun run() {
            if (!watchdogActive) return

            if (!SetupGuards.canAutomateGateway(this@PlawieForegroundService)) {
                Log.i(TAG, "Watchdog standing down until setup completes")
                updateNotification("Setup in progress")
                handler.postDelayed(this, WATCHDOG_INTERVAL_MS)
                return
            }
            
            Thread {
                val healthy = checkGatewayHealth()
                handler.post {
                    if (!watchdogActive) return@post
                    
                    if (healthy) {
                        if (consecutiveHttpFailures > 0 || consecutiveProcessDown > 0) {
                            Log.i(
                                TAG,
                                "Gateway recovered (httpFailures=$consecutiveHttpFailures, processDown=$consecutiveProcessDown)"
                            )
                        }
                        consecutiveHttpFailures = 0
                        consecutiveProcessDown = 0
                        updateNotification("Gateway running")
                    } else {
                        val uptimeMs = System.currentTimeMillis() - startTime
                        val processAlive = if (SetupGuards.isProotGatewayOwner(this@PlawieForegroundService)) {
                            processManager.isGatewayRunning()
                        } else {
                            nativeNodeSmokeProcess.isFullGatewayProductionRunning()
                        }
                        if (processAlive) {
                            consecutiveProcessDown = 0
                            consecutiveHttpFailures++
                            Log.w(
                                TAG,
                                "Watchdog: HTTP health miss while process alive " +
                                    "($consecutiveHttpFailures/$MAX_CONSECUTIVE_HTTP_FAILURES)"
                            )
                            updateNotification("Gateway busy ($consecutiveHttpFailures)")

                            if (uptimeMs >= STARTUP_GRACE_MS &&
                                consecutiveHttpFailures >= MAX_CONSECUTIVE_HTTP_FAILURES
                            ) {
                                // A live OpenClaw process can stop answering /health while it is
                                // preparing tools, flushing session files, or waiting on a provider.
                                // Restarting here kills in-flight chat runs and creates WebSocket
                                // 1006 churn. Only auto-restart when the process is actually gone;
                                // keep sustained HTTP misses visible as "busy" for manual repair.
                                Log.w(
                                    TAG,
                                    "Watchdog: gateway process is alive but HTTP remains slow; " +
                                        "restart suppressed to protect in-flight agent work."
                                )
                                updateNotification("Gateway busy — preserving run")
                            }
                        } else {
                            consecutiveHttpFailures = 0
                            consecutiveProcessDown++
                            Log.w(
                                TAG,
                                "Watchdog: gateway process missing " +
                                    "($consecutiveProcessDown/$MAX_CONSECUTIVE_PROCESS_DOWN)"
                            )
                            updateNotification("Gateway process missing ($consecutiveProcessDown)")

                            if (consecutiveProcessDown >= MAX_CONSECUTIVE_PROCESS_DOWN) {
                                attemptRestart("process_missing")
                            }
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
        consecutiveHttpFailures = 0
        consecutiveProcessDown = 0
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
     * HTTP GET check against the gateway health route.
     * Returns true if the gateway responds (any status code).
     */
    private fun checkGatewayHealth(): Boolean {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL("http://127.0.0.1:$GATEWAY_PORT/health")
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = HEALTH_TIMEOUT_MS
            conn.readTimeout = HEALTH_TIMEOUT_MS
            conn.setRequestProperty("Connection", "close")
            conn.connect()
            val code = conn.responseCode
            code in 100..599  // Any HTTP response means gateway is alive
        } catch (e: Exception) {
            false
        } finally {
            conn?.disconnect()
        }
    }

    /**
     * Restart the gateway process, with rate limiting to avoid crash loops.
     */
    private fun attemptRestart(reason: String = "unknown") {
        if (!SetupGuards.canAutomateGateway(this)) {
            Log.i(TAG, "Watchdog restart suppressed until setup completes ($reason)")
            updateNotification("Setup in progress")
            return
        }

        val now = System.currentTimeMillis()
        
        // Prune timestamps older than 1 hour
        restartTimestamps.removeAll { now - it > 3_600_000L }
        
        if (restartTimestamps.size >= MAX_RESTARTS_PER_HOUR) {
            Log.e(TAG, "Watchdog: restart cap reached ($MAX_RESTARTS_PER_HOUR/hr). Gateway may need manual intervention.")
            updateNotification("Gateway failed — restart cap reached")
            return
        }
        
        Log.i(
            TAG,
            "Watchdog: restarting gateway ($reason) " +
                "(attempt ${restartTimestamps.size + 1}/$MAX_RESTARTS_PER_HOUR)"
        )
        updateNotification("Restarting gateway...")
        consecutiveHttpFailures = 0
        consecutiveProcessDown = 0
        restartTimestamps.add(now)
        
        Thread {
            try {
                if (SetupGuards.isNativeGatewayOwner(this@PlawieForegroundService)) {
                    nativeNodeSmokeProcess.stop()
                    Thread.sleep(2000)
                    val success = nativeNodeSmokeProcess.startFullGatewayProduction()
                    handler.post {
                        if (success) {
                            Log.i(TAG, "Watchdog: native gateway restarted successfully")
                            updateNotification("Native gateway restarted")
                        } else {
                            Log.e(TAG, "Watchdog: native gateway restart failed")
                            updateNotification("Native gateway restart failed")
                        }
                    }
                    return@Thread
                }

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
                "Plawie Local Agent",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the Plawie environment running in the background"
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

        builder.setContentTitle("Plawie Local Agent")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(pendingIntent)
            .setOngoing(true)

        // Add Action Buttons (Surgical upgrade for production control)
        val stopIntent = Intent(this, PlawieForegroundService::class.java).apply { action = ACTION_STOP }
        val stopPendingIntent = PendingIntent.getService(this, 1, stopIntent, PendingIntent.FLAG_IMMUTABLE)
        builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "STOP", stopPendingIntent)

        val restartIntent = Intent(this, PlawieForegroundService::class.java).apply { action = ACTION_RESTART }
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
