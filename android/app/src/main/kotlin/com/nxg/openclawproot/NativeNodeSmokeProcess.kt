package com.nxg.openclawproot

import android.content.Context
import android.os.SystemClock
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentLinkedDeque
import java.util.concurrent.TimeUnit

/**
 * Phase 3 native Node process slot.
 *
 * This does not ship a Node binary by itself. It defines the exact lifecycle
 * contract for a future Bionic-native Node executable packaged as a jniLibs
 * file named libplawie_node.so.
 */
class NativeNodeSmokeProcess(
    private val context: Context,
    private val nativeLibDir: String
) {
    private val workDir = File(context.filesDir, "native-node-smoke")
    private val scriptFile = File(workDir, "server.mjs")
    private val nodeExecutable = File(nativeLibDir, "libplawie_node.so")
    private val logs = ConcurrentLinkedDeque<String>()
    private val startedAtMs = SystemClock.elapsedRealtime()

    @Volatile
    private var process: Process? = null

    companion object {
        private const val TAG = "NativeNodeSmoke"
        const val HOST = "127.0.0.1"
        const val PORT = 18790
        private const val MAX_LOG_LINES = 300
    }

    fun start(): Boolean {
        val existing = process
        if (existing?.isAlive == true) {
            appendLog("start ignored; native Node smoke process already alive")
            return true
        }

        if (!nodeExecutable.exists()) {
            appendLog(
                "native Node executable missing at ${nodeExecutable.absolutePath}; " +
                    "package a Node >=22.19.0 Android arm64 binary as libplawie_node.so"
            )
            return false
        }

        return try {
            writeSmokeScript()
            if (!nodeExecutable.canExecute()) {
                nodeExecutable.setExecutable(true, false)
            }

            val pb = ProcessBuilder(nodeExecutable.absolutePath, scriptFile.absolutePath)
            pb.directory(workDir)
            pb.redirectErrorStream(false)
            pb.environment().apply {
                put("HOME", workDir.absolutePath)
                put("TMPDIR", context.cacheDir.absolutePath)
                put("NODE_ENV", "production")
                put("PLAWIE_NATIVE_SMOKE_HOST", HOST)
                put("PLAWIE_NATIVE_SMOKE_PORT", PORT.toString())
            }

            val child = pb.start()
            process = child
            appendLog(
                "started native Node smoke process on http://$HOST:$PORT"
            )
            streamProcessOutput(child)
            true
        } catch (e: Exception) {
            appendLog("start failed: ${e.message}")
            Log.e(TAG, "Failed to start native Node smoke process", e)
            process = null
            false
        }
    }

    fun stop(): Boolean {
        val child = process
        if (child == null) {
            appendLog("stop ignored; native Node smoke process was not running")
            return true
        }

        return try {
            child.destroy()
            if (!child.waitFor(2, TimeUnit.SECONDS)) {
                appendLog("native Node smoke process ignored SIGTERM; forcing kill")
                child.destroyForcibly()
                child.waitFor(2, TimeUnit.SECONDS)
            }
            appendLog("stopped native Node smoke process")
            process = null
            true
        } catch (e: Exception) {
            appendLog("stop failed: ${e.message}")
            Log.e(TAG, "Failed to stop native Node smoke process", e)
            false
        }
    }

    fun isRunning(): Boolean = process?.isAlive == true

    fun getRecentLogs(): String {
        return if (logs.isEmpty()) {
            "Native Node smoke process has no logs yet."
        } else {
            logs.joinToString("\n")
        }
    }

    private fun writeSmokeScript() {
        workDir.mkdirs()
        scriptFile.writeText(
            """
            import http from "node:http";
            import process from "node:process";

            const host = process.env.PLAWIE_NATIVE_SMOKE_HOST || "127.0.0.1";
            const port = Number(process.env.PLAWIE_NATIVE_SMOKE_PORT || "18790");
            const startedAt = Date.now();

            const server = http.createServer((req, res) => {
              if (req.url === "/health" || req.url === "/") {
                const body = JSON.stringify({
                  ok: true,
                  runtime: "native-node",
                  node: process.version,
                  platform: process.platform,
                  arch: process.arch,
                  host,
                  port,
                  productionGatewayPort: 18789,
                  openclawStarted: false,
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
              console.log(`[NATIVE-NODE] listening on http://${'$'}{host}:${'$'}{port}`);
            });

            const shutdown = () => {
              server.close(() => process.exit(0));
              setTimeout(() => process.exit(1), 1500).unref();
            };

            process.on("SIGTERM", shutdown);
            process.on("SIGINT", shutdown);
            """.trimIndent()
        )
    }

    private fun streamProcessOutput(child: Process) {
        Thread {
            child.inputStream.bufferedReader().useLines { lines ->
                lines.forEach { appendLog("stdout: $it") }
            }
        }.apply {
            name = "NativeNodeSmoke-stdout"
            isDaemon = true
            start()
        }

        Thread {
            child.errorStream.bufferedReader().useLines { lines ->
                lines.forEach { appendLog("stderr: $it") }
            }
        }.apply {
            name = "NativeNodeSmoke-stderr"
            isDaemon = true
            start()
        }

        Thread {
            val code = child.waitFor()
            appendLog("native Node smoke process exited code=$code")
            if (process == child) {
                process = null
            }
        }.apply {
            name = "NativeNodeSmoke-exit"
            isDaemon = true
            start()
        }
    }

    private fun appendLog(message: String) {
        val stamp = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val payload = JSONObject()
            .put("time", stamp)
            .put("tag", "NATIVE-NODE")
            .put("message", message)
            .put("elapsedMs", SystemClock.elapsedRealtime() - startedAtMs)
            .toString()
        logs.add(payload)
        while (logs.size > MAX_LOG_LINES) logs.poll()
        Log.i(TAG, payload)
    }
}
