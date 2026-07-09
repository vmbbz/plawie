package com.openclaw.plawie

import android.app.ActivityManager
import android.content.Context
import android.os.SystemClock
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.net.InetSocketAddress
import java.net.HttpURLConnection
import java.net.Socket
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentLinkedDeque

/**
 * Controller for the embedded libnode smoke lane.
 *
 * The actual Node runtime is loaded inside NativeNodeEmbeddedService, which is
 * declared in an isolated Android process. This keeps native crashes away from
 * Flutter and the production PRoot Gateway path.
 */
class NativeNodeSmokeProcess(
    private val context: Context,
    private val nativeLibDir: String
) {
    private val logs = ConcurrentLinkedDeque<String>()
    private val startedAtMs = SystemClock.elapsedRealtime()
    private val libnode = File(nativeLibDir, "libnode.so")
    private val bridge = File(nativeLibDir, "libplawie_node_bridge.so")

    companion object {
        private const val TAG = "NativeNodeSmoke"
        const val HOST = NativeNodeEmbeddedService.HOST
        const val PORT = NativeNodeEmbeddedService.PORT
        const val PRODUCTION_PORT = NativeNodeEmbeddedService.PRODUCTION_PORT
        private const val MAX_LOG_LINES = 300
    }

    fun start(): Boolean {
        return startOnPort(PORT, "embedded-smoke")
    }

    fun startProductionPortCanary(): Boolean {
        return startOnPort(PRODUCTION_PORT, "production-port-bind-canary")
    }

    fun startFullGatewayBootstrap(): Boolean {
        return startOnPort(PORT, "full-gateway-bootstrap")
    }

    fun startFullGatewayProduction(): Boolean {
        return startOnPort(PRODUCTION_PORT, "full-gateway-bootstrap")
    }

    fun startOnPort(port: Int, canaryMode: String): Boolean {
        if (isRunningOnPort(port)) {
            appendLog("start ignored; embedded Node smoke runtime already alive")
            return true
        }

        if (port != PORT && port != PRODUCTION_PORT) {
            appendLog("start rejected; unsupported embedded Node port=$port")
            return false
        }

        if (!libnode.exists()) {
            appendLog(
                "embedded libnode.so is not packaged at ${libnode.absolutePath}; " +
                    "package Node >=22.19.0 as jniLibs/arm64-v8a/libnode.so"
            )
            return false
        }

        if (!bridge.exists()) {
            appendLog(
                "embedded Node bridge is not packaged at ${bridge.absolutePath}; " +
                    "run a debug build so CMake emits libplawie_node_bridge.so"
            )
            return false
        }

        if (port == PRODUCTION_PORT || canaryMode == "full-gateway-bootstrap") {
            val legacySmokeListening = isTcpListening(PORT)
            val productionListening = isTcpListening(PRODUCTION_PORT)
            if (!legacySmokeListening || productionListening) {
                appendLog(
                    "production pre-start cleanup skipped " +
                        "legacySmokeListening=$legacySmokeListening " +
                        "productionListening=$productionListening " +
                        "port=$port canaryMode=$canaryMode"
                )
            } else {
                try {
                    NativeNodeEmbeddedService.stop(context.applicationContext)
                    appendLog(
                        "requested stale embedded Node service stop before production start " +
                            "port=$port canaryMode=$canaryMode"
                    )
                    Thread.sleep(600)
                    val deadline = SystemClock.elapsedRealtime() + 3000L
                    while (SystemClock.elapsedRealtime() < deadline) {
                        if (!isTcpListening(PORT) && !isTcpListening(PRODUCTION_PORT)) break
                        Thread.sleep(100)
                    }
                } catch (e: Exception) {
                    appendLog("production pre-start cleanup failed: ${e.message}")
                }
            }
        }

        return try {
            NativeNodeEmbeddedService.start(
                context.applicationContext,
                port = port,
                canaryMode = canaryMode
            )
            appendLog(
                "requested embedded Node service start port=$port canaryMode=$canaryMode"
            )
            true
        } catch (e: Exception) {
            appendLog("start failed: ${e.message}")
            Log.e(TAG, "Failed to start embedded Node smoke service", e)
            false
        }
    }

    fun stop(): Boolean {
        return try {
            NativeNodeEmbeddedService.stop(context.applicationContext)
            appendLog("requested embedded Node smoke service stop")

            val deadline = SystemClock.elapsedRealtime() + 3500L
            while (SystemClock.elapsedRealtime() < deadline) {
                if (!isRunningOnAnyKnownPort()) return true
                Thread.sleep(100)
            }

            appendLog("embedded Node service did not stop from intent; force killing isolated process")
            forceKillNativeNodeProcess()

            val killDeadline = SystemClock.elapsedRealtime() + 3500L
            while (SystemClock.elapsedRealtime() < killDeadline) {
                if (!isRunningOnAnyKnownPort()) return true
                Thread.sleep(100)
            }
            !isRunningOnAnyKnownPort()
        } catch (e: Exception) {
            appendLog("stop failed: ${e.message}")
            Log.e(TAG, "Failed to stop embedded Node smoke service", e)
            false
        }
    }

    fun isRunning(): Boolean {
        return isRunningOnPort(PORT)
    }

    fun isProductionPortCanaryRunning(): Boolean {
        return isTcpListening(PRODUCTION_PORT)
    }

    fun isFullGatewayBootstrapRunning(): Boolean {
        return isTcpListening(PORT)
    }

    fun isFullGatewayProductionRunning(): Boolean {
        val health = probeHealth(PRODUCTION_PORT)
        if (health != null) {
            val runtime = health.optString("runtime", "")
            val status = health.optString("status", "")
            val looksNative = runtime == "native-node-embedded"
            val looksLive = health.optBoolean("ok", false) ||
                status == "ok" ||
                status == "live"
            if (looksNative || (looksLive && isIsolatedProcessAlive())) {
                return true
            }
        }
        return isTcpListening(PRODUCTION_PORT) && isIsolatedProcessAlive()
    }

    fun isRunningOnPort(port: Int): Boolean {
        return probeHealth(port)?.optString("runtime") == "native-node-embedded"
    }

    private fun isRunningOnAnyKnownPort(): Boolean {
        return isTcpListening(PORT) || isTcpListening(PRODUCTION_PORT)
    }

    fun getRecentLogs(): String {
        val serviceLogs = readServiceLogs()
        val localLogs = if (logs.isEmpty()) "" else logs.joinToString("\n")
        return listOf(localLogs, serviceLogs)
            .filter { it.isNotBlank() }
            .joinToString("\n")
            .ifBlank { "Embedded native Node smoke runtime has no logs yet." }
    }

    private fun probeHealth(port: Int): JSONObject? {
        return try {
            val connection = URL("http://$HOST:$port/health").openConnection() as HttpURLConnection
            connection.connectTimeout = 1000
            connection.readTimeout = 1000
            connection.useCaches = false
            connection.inputStream.bufferedReader().use { reader ->
                if (connection.responseCode != 200) return null
                JSONObject(reader.readText())
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun isTcpListening(port: Int): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress(HOST, port), 1000)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    fun isIsolatedProcessAlive(): Boolean {
        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: return false
        val targetProcess = "${context.packageName}:native_node_smoke"
        val runningProcesses = activityManager.runningAppProcesses ?: return false
        return runningProcesses.any { process -> process.processName == targetProcess }
    }

    private fun forceKillNativeNodeProcess() {
        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: return
        val targetProcess = "${context.packageName}:native_node_smoke"
        val runningProcesses = activityManager.runningAppProcesses ?: return
        for (process in runningProcesses) {
            if (process.processName == targetProcess) {
                appendLog("force killing isolated native Node process pid=${process.pid}")
                android.os.Process.killProcess(process.pid)
            }
        }
    }

    private fun readServiceLogs(): String {
        val runtimeFile = NativeNodeEmbeddedService.logFile(context.applicationContext)
        val stdioFile = File(
            NativeNodeEmbeddedService.workDir(context.applicationContext),
            "native-home/.openclaw/native-full-gateway-bootstrap-stdio.log"
        )

        return try {
            val runtimeLines = if (runtimeFile.exists()) {
                runtimeFile.readLines()
                    .takeLast(MAX_LOG_LINES / 2)
                    .map(::formatRuntimeLogLine)
            } else {
                emptyList()
            }
            val stdioLines = if (stdioFile.exists()) {
                stdioFile.readLines()
                    .takeLast(MAX_LOG_LINES * 4)
                    .mapNotNull(::formatStdioLogLine)
                    .takeLast(MAX_LOG_LINES / 2)
            } else {
                emptyList()
            }
            val deduped = LinkedHashSet<String>()
            (runtimeLines + stdioLines)
                .takeLast(MAX_LOG_LINES * 2)
                .forEach { line -> deduped.add(line) }
            deduped.toList().takeLast(MAX_LOG_LINES).joinToString("\n")
        } catch (e: Exception) {
            "Could not read embedded native Node logs: ${e.message}"
        }
    }

    private fun formatRuntimeLogLine(raw: String): String {
        return try {
            val json = JSONObject(raw)
            val time = json.optString("time", "")
            val message = json.optString("message", raw)
            val process = json.optString("process", "")
            val suffix = if (process.isBlank()) "" else " ($process)"
            "[native][runtime] $time $message$suffix"
        } catch (_: Exception) {
            "[native][runtime] $raw"
        }
    }

    private fun formatStdioLogLine(raw: String): String? {
        val line = raw.trim()
        if (line.isBlank() || isNoisyNativeHeartbeat(line)) return null
        val category = nativeLogCategory(line)
        return "[native-stdio][$category] $line"
    }

    private fun isNoisyNativeHeartbeat(line: String): Boolean {
        val lower = line.lowercase(Locale.US)
        return lower.contains("[ws]") &&
            (lower.contains("event tick") || lower.contains("event health"))
    }

    private fun nativeLogCategory(line: String): String {
        val lower = line.lowercase(Locale.US)
        return when {
            lower.contains("iserror=false") -> "gateway"
            lower.contains("iserror=true") ||
                lower.contains("[error]") ||
                lower.contains("[err]") ||
                lower.contains("traceback") ||
                lower.contains("exception") ||
                lower.contains("fatal") -> "error"
            lower.contains("warn") || lower.contains("[warn]") -> "warn"
            lower.contains("plugin") -> "plugins"
            lower.contains("active skills") ||
                lower.contains("[skills]") ||
                lower.contains("skills.") -> "skills"
            lower.contains("[chat]") ||
                lower.contains("chat.send") ||
                lower.contains("processed message") ||
                lower.contains("send-to-provider") -> "chat"
            lower.contains("provider") ||
                lower.contains("openrouter") ||
                lower.contains("gemini") ||
                lower.contains("openai") -> "provider"
            lower.contains("[tts]") ||
                lower.contains("talk.") ||
                lower.contains("speech") -> "tts"
            lower.contains("tool") ||
                lower.contains("device") ||
                lower.contains("capabilit") -> "tools"
            lower.contains("gateway is healthy") ||
                lower.contains("health rpc") -> "health"
            lower.contains("startup") ||
                lower.contains("bootstrap") ||
                lower.contains("server listening") -> "startup"
            lower.contains("[ws]") -> "ws"
            else -> "gateway"
        }
    }

    private fun appendLog(message: String) {
        val stamp = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val payload = JSONObject()
            .put("time", stamp)
            .put("tag", "NATIVE-NODE-EMBEDDED")
            .put("message", message)
            .put("elapsedMs", SystemClock.elapsedRealtime() - startedAtMs)
            .toString()
        logs.add(payload)
        while (logs.size > MAX_LOG_LINES) logs.poll()
        Log.i(TAG, payload)
    }
}
