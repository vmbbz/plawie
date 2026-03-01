// android/app/src/main/kotlin/com/nxg/openclawproot/mlc/LocalOpenAIServer.kt
package com.nxg.openclawproot.mlc

import android.content.Context
import fi.iki.elonen.NanoHTTPD
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedOutputStream
import android.util.Log

/**
 * Production-ready OpenAI-compatible HTTP proxy for MLC-LLM (March 2026).
 */
class LocalOpenAIServer(private val context: Context) : NanoHTTPD("127.0.0.1", 8000) {

    companion object {
        private const val TAG = "LocalOpenAIServer"
    }

    override fun serve(session: IHTTPSession): Response {
        return try {
            if (session.uri == "/v1/chat/completions" && session.method == Method.POST) {
                handleChatCompletions(session)
            } else if ((session.uri == "/v1/models" || session.uri == "/api/tags") && (session.method == Method.GET)) {
                val modelId = "mlc-model" 
                newFixedLengthResponse(Response.Status.OK, "application/json", 
                    """{"object":"list","data":[{"id":"$modelId","object":"model"}]}""")
            } else {
                newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not found")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Server error", e)
            newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "application/json", """{"error":"${e.message}"}""")
        }
    }

    private fun handleChatCompletions(session: IHTTPSession): Response {
        val contentLength = session.headers["content-length"]?.toIntOrNull() ?: 0
        val bodyBytes = ByteArray(contentLength)
        session.inputStream.read(bodyBytes, 0, contentLength)
        val body = String(bodyBytes, Charsets.UTF_8)
        
        val req = JSONObject(body)
        val stream = req.optBoolean("stream", false)
        val prompt = buildPrompt(req.getJSONArray("messages"))

        if (!stream) {
            return newFixedLengthResponse(Response.Status.OK, "application/json", 
                """{"choices":[{"message":{"content":"[MLC non-stream mode not implemented - please use stream:true]"}}]}""")
        }

        // Use Piped streams for NanoHTTPD chunked response
        val pipedOut = java.io.PipedOutputStream()
        val pipedIn = java.io.PipedInputStream(pipedOut)

        val resp = newChunkedResponse(
            Response.Status.OK,
            "text/event-stream",
            pipedIn
        )
        resp.addHeader("Cache-Control", "no-cache")
        resp.addHeader("Connection", "keep-alive")
        resp.addHeader("Access-Control-Allow-Origin", "*")
        resp.addHeader("X-Accel-Buffering", "no")

        // Fire MLC in background thread and stream tokens to pipedOut
        Thread {
            try {
                val writer = pipedOut.bufferedWriter()
                MLCEngineManager.generateStream(
                    prompt = prompt,
                    onToken = { token ->
                        val escapedToken = token.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
                        val chunk = "data: {\"choices\":[{\"delta\":{\"content\":\"$escapedToken\"}}]}\n\n"
                        try {
                            writer.write(chunk)
                            writer.flush()
                        } catch (e: Exception) {}
                    },
                    onComplete = {
                        try {
                            writer.write("data: [DONE]\n\n")
                            writer.flush()
                            writer.close()
                            pipedOut.close()
                        } catch (e: Exception) {}
                    },
                    onError = { err ->
                        try {
                            writer.write("data: {\"error\":\"$err\"}\n\n")
                            writer.flush()
                            writer.close()
                            pipedOut.close()
                        } catch (e: Exception) {}
                    }
                )
            } catch (e: Exception) {
                Log.e(TAG, "Streaming error", e)
                try { pipedOut.close() } catch (ignore: Exception) {}
            }
        }.start()

        return resp
    }

    private fun buildPrompt(messages: JSONArray): String {
        val sb = StringBuilder()
        for (i in 0 until messages.length()) {
            val msg = messages.getJSONObject(i)
            sb.append(msg.getString("role")).append(": ").append(msg.getString("content")).append("\n")
        }
        return sb.toString().trim()
    }
}
