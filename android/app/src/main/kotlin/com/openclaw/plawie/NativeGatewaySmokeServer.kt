package com.openclaw.plawie

import android.content.Context
import android.os.Process
import android.os.SystemClock
import android.util.Log
import fi.iki.elonen.NanoHTTPD
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentLinkedDeque

/**
 * Phase 2 native-runtime smoke endpoint.
 *
 * This intentionally does not run OpenClaw and never binds the production
 * Gateway port. It proves native lifecycle, loopback HTTP health, and log
 * plumbing before a real native Node binary is introduced.
 */
class NativeGatewaySmokeServer private constructor(
    private val appContext: Context
) : NanoHTTPD(HOST, PORT) {

    private val startedAtMs = SystemClock.elapsedRealtime()

    companion object {
        private const val TAG = "NativeGatewaySmoke"
        const val HOST = "127.0.0.1"
        const val PORT = 18790
        private const val PRODUCTION_GATEWAY_PORT = 18789
        private const val MAX_LOG_LINES = 200

        private val logs = ConcurrentLinkedDeque<String>()
        @Volatile
        private var instance: NativeGatewaySmokeServer? = null

        fun startServer(context: Context): Boolean {
            val existing = instance
            if (existing?.isAlive == true) {
                appendLog("start ignored; smoke runtime already alive on $HOST:$PORT")
                return true
            }

            return try {
                val server = NativeGatewaySmokeServer(context.applicationContext)
                server.start(SOCKET_READ_TIMEOUT, false)
                instance = server
                appendLog("started smoke runtime on http://$HOST:$PORT")
                true
            } catch (e: Exception) {
                appendLog("start failed: ${e.message}")
                Log.e(TAG, "Failed to start native smoke runtime", e)
                false
            }
        }

        fun stopServer(): Boolean {
            val server = instance
            if (server == null) {
                appendLog("stop ignored; smoke runtime was not running")
                return true
            }

            return try {
                server.stop()
                instance = null
                appendLog("stopped smoke runtime")
                true
            } catch (e: Exception) {
                appendLog("stop failed: ${e.message}")
                Log.e(TAG, "Failed to stop native smoke runtime", e)
                false
            }
        }

        fun isRunning(): Boolean = instance?.isAlive == true

        fun getRecentLogs(): String {
            return if (logs.isEmpty()) {
                "Native Gateway smoke runtime has no logs yet."
            } else {
                logs.joinToString("\n")
            }
        }

        private fun appendLog(message: String) {
            val stamp = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
            val line = "[$stamp] [NATIVE-SMOKE] $message"
            logs.add(line)
            while (logs.size > MAX_LOG_LINES) logs.poll()
            Log.i(TAG, line)
        }
    }

    override fun serve(session: IHTTPSession): Response {
        appendLog("${session.method} ${session.uri}")
        return when (session.uri) {
            "/", "/health" -> healthResponse()
            "/logs" -> newFixedLengthResponse(
                Response.Status.OK,
                MIME_PLAINTEXT,
                getRecentLogs()
            )
            else -> newFixedLengthResponse(
                Response.Status.NOT_FOUND,
                "application/json",
                JSONObject()
                    .put("ok", false)
                    .put("error", "not_found")
                    .put("path", session.uri)
                    .toString()
            )
        }
    }

    private fun healthResponse(): Response {
        val json = JSONObject()
            .put("ok", true)
            .put("runtime", "native-gateway-smoke")
            .put("engine", "android-nanohttpd")
            .put("host", HOST)
            .put("port", PORT)
            .put("productionGatewayPort", PRODUCTION_GATEWAY_PORT)
            .put("openclawStarted", false)
            .put("nodeStarted", false)
            .put("pid", Process.myPid())
            .put("packageName", appContext.packageName)
            .put("uptimeMs", SystemClock.elapsedRealtime() - startedAtMs)

        return newFixedLengthResponse(
            Response.Status.OK,
            "application/json",
            json.toString()
        ).apply {
            addHeader("Cache-Control", "no-store")
        }
    }
}
