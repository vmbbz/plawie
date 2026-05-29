package com.nxg.openclawproot

import android.app.Application
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.Process
import android.os.SystemClock
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger

class NativeNodeEmbeddedService : Service() {
    private val startedAtMs = SystemClock.elapsedRealtime()

    companion object {
        private const val TAG = "NativeNodeEmbedded"
        private const val ACTION_START = "com.nxg.openclawproot.native_node.START"
        private const val ACTION_STOP = "com.nxg.openclawproot.native_node.STOP"
        const val HOST = "127.0.0.1"
        const val PORT = 18790
        private val lifecycleGeneration = AtomicInteger(0)

        fun start(context: Context) {
            context.startService(Intent(context, NativeNodeEmbeddedService::class.java).apply {
                action = ACTION_START
            })
        }

        fun stop(context: Context) {
            context.startService(Intent(context, NativeNodeEmbeddedService::class.java).apply {
                action = ACTION_STOP
            })
        }

        fun workDir(context: Context): File =
            File(context.filesDir, "native-node-embedded")

        fun logFile(context: Context): File =
            File(workDir(context), "runtime.log")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopEmbeddedRuntime(startId)
            else -> startEmbeddedRuntime()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        appendLog("service destroyed")
        super.onDestroy()
    }

    private fun startEmbeddedRuntime() {
        lifecycleGeneration.incrementAndGet()

        if (NativeNodeBridge.running()) {
            appendLog("start ignored; embedded Node already running")
            return
        }

        val script = writeSmokeScript()
        appendLog("starting embedded Node health runtime on http://$HOST:$PORT")

        val args = arrayOf("plawie-native-node", script.absolutePath)
        val result = NativeNodeBridge.start(args)
        appendLog("bridge start result code=${result.code} message=${result.message}")

        if (result.code < 0) {
            stopSelf()
        }
    }

    private fun stopEmbeddedRuntime(startId: Int) {
        val stopGeneration = lifecycleGeneration.incrementAndGet()
        appendLog("stop requested; terminating isolated native Node process")
        stopSelf(startId)

        if (Application.getProcessName().contains(":native_node_smoke")) {
            Thread {
                Thread.sleep(150)
                if (lifecycleGeneration.get() == stopGeneration) {
                    Process.killProcess(Process.myPid())
                } else {
                    appendLog("stop kill cancelled because a newer start arrived")
                }
            }.apply {
                name = "NativeNodeEmbedded-kill"
                isDaemon = true
                start()
            }
        } else {
            appendLog("stop did not kill process because current process is ${Application.getProcessName()}")
        }
    }

    private fun writeSmokeScript(): File {
        val dir = workDir(applicationContext)
        dir.mkdirs()
        val script = File(dir, "server.mjs")
        script.writeText(
            """
            import http from "node:http";
            import process from "node:process";

            const host = "$HOST";
            const port = $PORT;
            const startedAt = Date.now();

            const server = http.createServer((req, res) => {
              if (req.url === "/health" || req.url === "/") {
                const body = JSON.stringify({
                  ok: true,
                  runtime: "native-node-embedded",
                  node: process.version,
                  platform: process.platform,
                  arch: process.arch,
                  host,
                  port,
                  productionGatewayPort: 18789,
                  openclawStarted: false,
                  pid: process.pid,
                  uptimeMs: Date.now() - startedAt
                });
                res.writeHead(200, {
                  "content-type": "application/json",
                  "cache-control": "no-store"
                });
                res.end(body);
                return;
              }

              res.writeHead(404, { "content-type": "application/json" });
              res.end(JSON.stringify({ ok: false, error: "not_found", path: req.url }));
            });

            server.listen(port, host, () => {
              console.log(`[NATIVE-NODE-EMBEDDED] listening on http://${'$'}{host}:${'$'}{port}`);
            });
            """.trimIndent()
        )
        return script
    }

    private fun appendLog(message: String) {
        val stamp = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val payload = JSONObject()
            .put("time", stamp)
            .put("tag", "NATIVE-NODE-EMBEDDED")
            .put("message", message)
            .put("pid", Process.myPid())
            .put("process", Application.getProcessName())
            .put("elapsedMs", SystemClock.elapsedRealtime() - startedAtMs)
            .toString()

        try {
            val file = logFile(applicationContext)
            file.parentFile?.mkdirs()
            file.appendText(payload + "\n")
        } catch (e: Exception) {
            Log.w(TAG, "Could not append native Node log", e)
        }
        Log.i(TAG, payload)
    }
}
