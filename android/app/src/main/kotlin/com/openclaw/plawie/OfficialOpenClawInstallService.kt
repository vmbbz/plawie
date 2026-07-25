package com.openclaw.plawie

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.Process
import android.os.SystemClock
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Runs the official OpenClaw npm transaction in its own Android process.
 *
 * libnode owns process-global state. Keeping npm out of the Flutter/UI process
 * means a Node shutdown or native dependency fault cannot take down setup UI.
 * Completion is persisted by [OfficialOpenClawProvisioner] before this process
 * is deliberately terminated.
 */
class OfficialOpenClawInstallService : Service() {
    private var activeRequestId: String? = null
    private var lastNotificationText: String? = null
    private var lastNotificationProgress: Int = Int.MIN_VALUE
    private var lastNotificationAtMs: Long = 0L

    companion object {
        private const val TAG = "OfficialOpenClawInstall"
        private const val LEGACY_NOTIFICATION_ID = 6
        private const val MIN_NOTIFICATION_UPDATE_INTERVAL_MS = 1_500L
        private const val ACTION_PROVISION =
            "com.openclaw.plawie.official_openclaw.PROVISION"
        private const val EXTRA_REQUEST_ID = "requestId"
        private val provisionInFlight = AtomicBoolean(false)

        fun start(context: Context, requestId: String) {
            val intent = Intent(context, OfficialOpenClawInstallService::class.java).apply {
                action = ACTION_PROVISION
                putExtra(EXTRA_REQUEST_ID, requestId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun clearLegacyNotification(context: Context) {
            context.getSystemService(NotificationManager::class.java)
                .cancel(LEGACY_NOTIFICATION_ID)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        // This service is isolated for libnode safety, but setup owns the
        // single user-visible setup notification.
        SetupService.ensureNotificationChannel(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(
            SetupService.NOTIFICATION_ID,
            buildNotification(
                "Resolving the latest official OpenClaw release…",
                0.02
            )
        )
        lastNotificationText = "Resolving the latest official OpenClaw release…"
        lastNotificationProgress = 2
        lastNotificationAtMs = SystemClock.elapsedRealtime()
        if (intent?.action != ACTION_PROVISION) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val requestId = intent.getStringExtra(EXTRA_REQUEST_ID)?.trim()
        if (requestId.isNullOrEmpty()) {
            Log.e(TAG, "Official installer start rejected: missing request id")
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (!provisionInFlight.compareAndSet(false, true)) {
            OfficialOpenClawProvisioner.markIsolatedProvisionFailed(
                applicationContext,
                requestId,
                IllegalStateException("Another official OpenClaw installation is already running.")
            )
            stopSelf(startId)
            return START_NOT_STICKY
        }

        activeRequestId = requestId
        Thread {
            try {
                OfficialOpenClawProvisioner.markIsolatedProvisionRunning(
                    applicationContext,
                    requestId
                )
                val result = OfficialOpenClawProvisioner(applicationContext) { status, progress ->
                    updateSetupNotification(status, progress)
                    OfficialOpenClawProvisioner.markIsolatedProvisionProgress(
                        applicationContext,
                        requestId,
                        status,
                        progress
                    )
                }.provisionLatest(requestId)
                updateSetupNotification(
                    "Official OpenClaw verified. Finalizing setup…",
                    0.99,
                    force = true
                )
                OfficialOpenClawProvisioner.markIsolatedProvisionSucceeded(
                    applicationContext,
                    requestId,
                    result
                )
            } catch (error: Throwable) {
                Log.e(TAG, "Official OpenClaw installation failed", error)
                runCatching {
                    OfficialOpenClawProvisioner.markIsolatedProvisionFailed(
                        applicationContext,
                        requestId,
                        error
                    )
                }
            } finally {
                activeRequestId = null
                provisionInFlight.set(false)
                @Suppress("DEPRECATION")
                stopForeground(false)
                stopSelf(startId)
                // Do not reuse a process that has run node::Start. A fresh
                // process is required for the later full gateway runtime.
                Thread {
                    Thread.sleep(250)
                    Process.killProcess(Process.myPid())
                }.apply {
                    name = "OfficialOpenClawInstall-stop"
                    isDaemon = true
                    start()
                }
            }
        }.apply {
            name = "OfficialOpenClawInstall"
            isDaemon = true
            start()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        val requestId = activeRequestId
        if (provisionInFlight.get() && !requestId.isNullOrBlank()) {
            runCatching {
                OfficialOpenClawProvisioner.markIsolatedProvisionFailed(
                    applicationContext,
                    requestId,
                    IllegalStateException("Official installer service stopped before completion.")
                )
            }
        }
        super.onDestroy()
    }

    private fun updateSetupNotification(
        text: String,
        progress: Double,
        force: Boolean = false
    ) {
        val boundedProgress = (progress.coerceIn(0.0, 1.0) * 100.0).toInt()
        val now = SystemClock.elapsedRealtime()
        val duplicate = text == lastNotificationText &&
            boundedProgress == lastNotificationProgress
        if (!force &&
            (duplicate || now - lastNotificationAtMs < MIN_NOTIFICATION_UPDATE_INTERVAL_MS)
        ) {
            return
        }

        runCatching {
            getSystemService(NotificationManager::class.java).notify(
                SetupService.NOTIFICATION_ID,
                buildNotification(text, progress)
            )
            lastNotificationText = text
            lastNotificationProgress = boundedProgress
            lastNotificationAtMs = now
        }.onFailure { error ->
            Log.w(TAG, "Could not update shared setup notification", error)
        }
    }

    private fun buildNotification(text: String, progress: Double): Notification {
        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, SetupService.CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("OpenClaw Setup")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setProgress(
                100,
                (progress.coerceIn(0.0, 1.0) * 100.0).toInt(),
                false
            )
            .build()
    }
}
