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
import android.util.Log
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.URL
import java.util.zip.ZipInputStream

/**
 * Background foreground service that listens for the wake word "Plawie" using
 * the Vosk offline speech recognizer.
 *
 * Flow:
 *   Service starts → ensure Vosk model downloaded → load model → start SpeechService
 *   → on "plawie" detected → send LocalBroadcast (ACTION_WAKE_WORD_DETECTED)
 *   → MainActivity BroadcastReceiver → EventChannel → Flutter ChatScreen
 *
 * Modes (set via ACTION_SET_MODE intent extra "mode"):
 *   "off"        — stop recognition, stop service
 *   "foreground" — active only while app is in foreground (default)
 *   "always"     — always active (keep service running even when app is backgrounded)
 *
 * 5-minute watchdog: if no recognition events for 5 min, restart SpeechService.
 */
class HotwordService : Service(), RecognitionListener {

    companion object {
        const val TAG = "HotwordService"
        const val CHANNEL_ID = "hotword_channel"
        const val NOTIFICATION_ID = 5

        const val ACTION_WAKE_WORD_DETECTED = "com.nxg.openclawproot.WAKE_WORD_DETECTED"
        const val ACTION_SET_MODE = "com.nxg.openclawproot.HOTWORD_SET_MODE"
        const val ACTION_STOP = "com.nxg.openclawproot.HOTWORD_STOP"

        private const val MODEL_DIR_NAME = "vosk_model"
        private const val MODEL_URL =
            "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"
        private const val WATCHDOG_INTERVAL_MS = 5 * 60 * 1000L // 5 minutes
        private val WAKE_WORDS = listOf("plawie", "hey plawie", "ok plawie", "play we")

        var isRunning = false
            private set
    }

    private var speechService: SpeechService? = null
    private var model: Model? = null
    private val handler = Handler(Looper.getMainLooper())
    private var lastEventTime = System.currentTimeMillis()
    private var watchdogActive = false

    // Watchdog: restart SpeechService if silent for WATCHDOG_INTERVAL_MS
    private val watchdogRunnable = object : Runnable {
        override fun run() {
            if (!watchdogActive) return
            val silentMs = System.currentTimeMillis() - lastEventTime
            if (silentMs >= WATCHDOG_INTERVAL_MS) {
                Log.w(TAG, "Watchdog: ${silentMs / 1000}s silence — restarting recognition")
                restartRecognition()
            }
            handler.postDelayed(this, WATCHDOG_INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        isRunning = true
        startForeground(NOTIFICATION_ID, buildNotification("Wake word: listening…"))
        // Download model + start recognition in background
        Thread { initModel() }.start()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SET_MODE -> {
                val mode = intent.getStringExtra("mode") ?: "foreground"
                handleModeChange(mode)
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        watchdogActive = false
        handler.removeCallbacks(watchdogRunnable)
        stopRecognition()
        model?.close()
        model = null
        super.onDestroy()
    }

    // ── Model init ────────────────────────────────────────────────────────────

    private fun initModel() {
        val modelDir = File(filesDir, MODEL_DIR_NAME)
        if (!modelDir.exists() || !modelDir.list()?.isNotEmpty()!!) {
            updateNotification("Wake word: downloading model…")
            if (!downloadModel(modelDir)) {
                updateNotification("Wake word: model download failed")
                Log.e(TAG, "Failed to download Vosk model")
                return
            }
        }
        try {
            Log.i(TAG, "Loading Vosk model from ${modelDir.absolutePath}")
            model = Model(modelDir.absolutePath)
            handler.post { startRecognition() }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load Vosk model", e)
            updateNotification("Wake word: model load failed")
        }
    }

    private fun downloadModel(targetDir: File): Boolean {
        return try {
            Log.i(TAG, "Downloading Vosk model from $MODEL_URL")
            val tmpZip = File(cacheDir, "vosk_model.zip")
            URL(MODEL_URL).openStream().use { input ->
                FileOutputStream(tmpZip).use { output -> input.copyTo(output) }
            }
            // Unzip into targetDir
            targetDir.mkdirs()
            ZipInputStream(tmpZip.inputStream()).use { zip ->
                var entry = zip.nextEntry
                while (entry != null) {
                    val entryPath = entry.name
                        .substringAfter('/') // strip top-level dir from zip
                        .ifEmpty { null }
                    if (entryPath != null) {
                        val outFile = File(targetDir, entryPath)
                        if (entry.isDirectory) {
                            outFile.mkdirs()
                        } else {
                            outFile.parentFile?.mkdirs()
                            FileOutputStream(outFile).use { zip.copyTo(it) }
                        }
                    }
                    zip.closeEntry()
                    entry = zip.nextEntry
                }
            }
            tmpZip.delete()
            Log.i(TAG, "Vosk model extracted to ${targetDir.absolutePath}")
            true
        } catch (e: IOException) {
            Log.e(TAG, "Model download/extract failed", e)
            false
        }
    }

    // ── Recognition lifecycle ─────────────────────────────────────────────────

    private fun startRecognition() {
        val m = model ?: return
        try {
            // Grammar-based recognizer: only listens for known wake words + [unk]
            // This dramatically reduces false positives compared to full speech recognition
            val grammar = """["plawie", "hey plawie", "ok plawie", "play we", "[unk]"]"""
            val recognizer = Recognizer(m, 16000.0f, grammar)
            speechService = SpeechService(recognizer, 16000.0f)
            speechService!!.startListening(this)
            lastEventTime = System.currentTimeMillis()
            startWatchdog()
            updateNotification("Wake word: listening for \"Plawie\"")
            Log.i(TAG, "Wake word recognition started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recognition", e)
            updateNotification("Wake word: mic error")
        }
    }

    private fun stopRecognition() {
        speechService?.stop()
        speechService = null
    }

    private fun restartRecognition() {
        handler.post {
            stopRecognition()
            startRecognition()
        }
    }

    private fun startWatchdog() {
        if (watchdogActive) return
        watchdogActive = true
        handler.postDelayed(watchdogRunnable, WATCHDOG_INTERVAL_MS)
    }

    private fun handleModeChange(mode: String) {
        when (mode) {
            "off" -> stopSelf()
            "foreground", "always" -> {
                if (speechService == null && model != null) startRecognition()
            }
        }
    }

    // ── RecognitionListener (Vosk callbacks) ─────────────────────────────────

    override fun onPartialResult(hypothesis: String?) {
        lastEventTime = System.currentTimeMillis()
        hypothesis ?: return
        val text = parseVoskText(hypothesis)
        if (isWakeWord(text)) {
            Log.i(TAG, "Wake word detected (partial): \"$text\"")
            broadcastWakeWord()
        }
    }

    override fun onResult(hypothesis: String?) {
        lastEventTime = System.currentTimeMillis()
        hypothesis ?: return
        val text = parseVoskText(hypothesis)
        if (isWakeWord(text)) {
            Log.i(TAG, "Wake word detected (final): \"$text\"")
            broadcastWakeWord()
        }
    }

    override fun onFinalResult(hypothesis: String?) {
        lastEventTime = System.currentTimeMillis()
    }

    override fun onError(exception: Exception?) {
        Log.e(TAG, "Vosk recognition error: ${exception?.message}")
        updateNotification("Wake word: recognition error — restarting…")
        handler.postDelayed({ restartRecognition() }, 2000)
    }

    override fun onTimeout() {
        Log.w(TAG, "Vosk recognition timeout — restarting")
        restartRecognition()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Parses Vosk JSON result: {"text": "..."} → the text value, lowercased. */
    private fun parseVoskText(json: String): String {
        return try {
            val start = json.indexOf('"', json.indexOf(':') + 1) + 1
            val end = json.lastIndexOf('"')
            if (start > 0 && end > start) json.substring(start, end).lowercase().trim()
            else ""
        } catch (_: Exception) { "" }
    }

    private fun isWakeWord(text: String) =
        WAKE_WORDS.any { text.contains(it) }

    private fun broadcastWakeWord() {
        val intent = Intent(ACTION_WAKE_WORD_DETECTED).apply {
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }

    // ── Notification ──────────────────────────────────────────────────────────

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
                "Wake Word Detection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Listens for the wake word \"Plawie\" to activate hands-free mode"
                setSound(null, null)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val tapIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = Intent(this, HotwordService::class.java).apply { action = ACTION_STOP }
        val stopPending = PendingIntent.getService(
            this, 1, stopIntent, PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Plawie — Wake Word")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPending)
            .build()
    }
}
