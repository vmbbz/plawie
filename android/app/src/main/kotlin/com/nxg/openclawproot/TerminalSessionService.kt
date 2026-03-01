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
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class TerminalSessionService : Service() {
    companion object {
        const val CHANNEL_ID = "openclaw_terminal"
        const val NOTIFICATION_ID = 1
        var isRunning = false
            private set
        private var instance: TerminalSessionService? = null

        fun start(context: Context) {
            val intent = Intent(context, TerminalSessionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, TerminalSessionService::class.java)
            context.stopService(intent)
        }

        fun getInstance(): TerminalSessionService? = instance
    }

    private val activeSessions = ConcurrentHashMap<String, TerminalSession>()
    private lateinit var notificationManager: NotificationManager

    override fun onCreate() {
        super.onCreate()
        instance = this
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        Log.d("TerminalSessionService", "TerminalSessionService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("TerminalSessionService", "TerminalSessionService starting")
        
        when (intent?.action) {
            "CREATE_SESSION" -> {
                val sessionId = intent.getStringExtra("sessionId") ?: generateSessionId()
                val command = intent.getStringExtra("command") ?: "/bin/bash"
                val workingDir = intent.getStringExtra("workingDir") ?: "/data/data/com.nxg.openclawproot/files"
                createSession(sessionId, command, workingDir)
            }
            "EXECUTE_COMMAND" -> {
                val sessionId = intent.getStringExtra("sessionId")
                val command = intent.getStringExtra("command")
                if (sessionId != null && command != null) {
                    executeCommand(sessionId, command)
                }
            }
            "DESTROY_SESSION" -> {
                val sessionId = intent.getStringExtra("sessionId")
                if (sessionId != null) {
                    destroySession(sessionId)
                }
            }
            "STOP_SERVICE" -> {
                stopService()
            }
        }
        
        return START_STICKY
    }

    private fun createSession(sessionId: String, command: String, workingDir: String) {
        try {
            val session = TerminalSession(sessionId, command, workingDir)
            activeSessions[sessionId] = session
            session.start()
            
            updateNotification("${activeSessions.size} active terminal sessions")
            Log.d("TerminalSessionService", "Created session: $sessionId")
            
        } catch (e: Exception) {
            Log.e("TerminalSessionService", "Failed to create session", e)
        }
    }

    private fun executeCommand(sessionId: String, command: String) {
        val session = activeSessions[sessionId]
        if (session != null) {
            session.executeCommand(command)
            Log.d("TerminalSessionService", "Executed command in session $sessionId: $command")
        } else {
            Log.w("TerminalSessionService", "Session not found: $sessionId")
        }
    }

    private fun destroySession(sessionId: String) {
        val session = activeSessions.remove(sessionId)
        if (session != null) {
            session.destroy()
            updateNotification("${activeSessions.size} active terminal sessions")
            Log.d("TerminalSessionService", "Destroyed session: $sessionId")
        }
    }

    private fun stopService() {
        activeSessions.values.forEach { it.destroy() }
        activeSessions.clear()
        
        stopForeground(true)
        stopSelf()
        isRunning = false
        Log.d("TerminalSessionService", "TerminalSessionService stopped")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OpenClaw Terminal",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "OpenClaw Terminal Sessions"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun updateNotification(text: String) {
        if (activeSessions.isNotEmpty()) {
            val notification = createNotification(text)
            notificationManager.notify(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OpenClaw Terminal")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun generateSessionId(): String {
        return "session_${System.currentTimeMillis()}_${(1000..9999).random()}"
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        activeSessions.values.forEach { it.destroy() }
        activeSessions.clear()
        Log.d("TerminalSessionService", "TerminalSessionService destroyed")
    }
}

class TerminalSession(
    private val sessionId: String,
    private val command: String,
    private val workingDir: String
) {
    private var process: Process? = null
    private var isDestroyed = false

    fun start() {
        try {
            val processBuilder = ProcessBuilder(command.split(" "))
            processBuilder.directory(File(workingDir))
            processBuilder.environment()["TERM"] = "xterm-256color"
            processBuilder.environment()["HOME"] = workingDir
            
            process = processBuilder.start()
            Log.d("TerminalSession", "Started process for session $sessionId")
            
        } catch (e: Exception) {
            Log.e("TerminalSession", "Failed to start process for session $sessionId", e)
        }
    }

    fun executeCommand(command: String) {
        try {
            process?.outputStream?.write("$command\n".toByteArray())
            process?.outputStream?.flush()
            Log.d("TerminalSession", "Executed command in session $sessionId: $command")
            
        } catch (e: Exception) {
            Log.e("TerminalSession", "Failed to execute command in session $sessionId", e)
        }
    }

    fun destroy() {
        if (isDestroyed) return
        
        try {
            process?.destroy()
            process = null
            isDestroyed = true
            Log.d("TerminalSession", "Destroyed session $sessionId")
            
        } catch (e: Exception) {
            Log.e("TerminalSession", "Failed to destroy session $sessionId", e)
        }
    }
}
