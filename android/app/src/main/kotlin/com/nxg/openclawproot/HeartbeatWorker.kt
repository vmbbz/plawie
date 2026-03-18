package com.nxg.openclawproot

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class HeartbeatWorker(appContext: Context, workerParams: WorkerParameters) :
    CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        Log.i("HeartbeatWorker", "Running background heartbeat check...")
        
        // Ensure the foreground service is active
        if (!ClawaForegroundService.isRunning) {
            Log.w("HeartbeatWorker", "Service NOT running, restarting ClawaForegroundService...")
            ClawaForegroundService.start(applicationContext)
        } else {
            Log.i("HeartbeatWorker", "Service is healthy.")
        }

        return Result.success()
    }

    companion object {
        private const val WORK_NAME = "clawa_heartbeat_work"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<HeartbeatWorker>(15, TimeUnit.MINUTES)
                .setInitialDelay(5, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
            Log.i("HeartbeatWorker", "Scheduled 15-minute periodic heartbeat.")
        }
    }
}
