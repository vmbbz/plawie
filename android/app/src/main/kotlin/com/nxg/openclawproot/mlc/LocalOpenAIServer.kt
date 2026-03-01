package com.nxg.openclawproot.mlc

import android.util.Log
import fi.iki.elonen.NanoHTTPD
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream

/**
 * A lightweight OpenAI-compatible HTTP server that proxies requests
 * to the MLC-LLM ChatModule running natively on the Android GPU.
 *
 * Listens on 127.0.0.1:8000 and implements:
 * - POST /v1/chat/completions  (streaming SSE + non-streaming)
 * - GET  /v1/models            (model list)
 * - GET  /api/tags             (Ollama-compatible model list)
 *
 * OpenClaw inside PRoot connects to this exactly like it would
 * connect to Ollama or any OpenAI-compatible API.
 *
 * Requires NanoHTTPD (nanohttpd-2.3.1.jar) in libs/.
 */
class LocalOpenAIServer(
    private val modelId: String
) : NanoHTTPD("127.0.0.1", 8000) {

    companion object {
        private const val TAG = "LocalOpenAIServer"
    }

    override fun serve(session: IHTTPSession): Response {
        return try {
            when {
                session.uri == "/v1/chat/completions" && session.method == Method.POST -> {
                    handleChatCompletion(session)
                }
                session.uri == "/v1/models" && session.method == Method.GET -> {
                    handleModelList()
                }
                session.uri == "/api/tags" && session.method == Method.GET -> {
                    handleOllamaModelList()
                }
                session.uri == "/health" || session.uri == "/" -> {
                    newFixedLengthResponse(Response.Status.OK, "application/json",
                        """{"status":"ok","engine":"mlc","model":"$modelId"}""")
                }
                else -> {
                    newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not found")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error serving request: ${session.uri}", e)
            newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "application/json",
                """{"error":{"message":"${e.message}","type":"server_error"}}""")
        }
    }

    /**
     * Handle POST /v1/chat/completions
     * Supports both streaming (SSE) and non-streaming responses.
     */
    private fun handleChatCompletion(session: IHTTPSession): Response {
        // Parse request body
        val contentLength = session.headers["content-length"]?.toIntOrNull() ?: 0
        val body = ByteArray(contentLength)
        session.inputStream.read(body, 0, contentLength)
        val requestJson = JSONObject(String(body))

        val messages = requestJson.getJSONArray("messages")
        val stream = requestJson.optBoolean("stream", false)
        val requestModel = requestJson.optString("model", modelId)

        // Extract the last user message for generation
        val lastMessage = messages.getJSONObject(messages.length() - 1)
        val prompt = lastMessage.getString("content")

        Log.d(TAG, "Chat completion request: stream=$stream, model=$requestModel, prompt_length=${prompt.length}")

        // TODO: When mlc4j is integrated, replace this with actual ChatModule inference:
        //   val chatModule = MLCEngineManager.getChatModule()
        //   chatModule.resetChat()
        //   for (i in 0 until messages.length()) {
        //       val msg = messages.getJSONObject(i)
        //       chatModule.prefill(msg.getString("content"), msg.getString("role"))
        //   }
        //   Full streaming with chatModule.decode() in a loop

        val completionId = "chatcmpl-${System.currentTimeMillis()}"
        val timestamp = System.currentTimeMillis() / 1000

        if (stream) {
            return handleStreamingResponse(completionId, timestamp, requestModel, prompt)
        } else {
            return handleNonStreamingResponse(completionId, timestamp, requestModel, prompt)
        }
    }

    /**
     * SSE streaming response — sends tokens as they're generated.
     * This is critical for tool-use with OpenClaw.
     */
    private fun handleStreamingResponse(
        completionId: String,
        timestamp: Long,
        model: String,
        prompt: String
    ): Response {
        // TODO: Replace stub with real MLC streaming inference
        val stubResponse = "[MLC Engine] Model '$modelId' ready. Awaiting mlc4j integration for GPU inference."

        val sseBuilder = StringBuilder()

        // Send role chunk
        val roleChunk = JSONObject().apply {
            put("id", completionId)
            put("object", "chat.completion.chunk")
            put("created", timestamp)
            put("model", model)
            put("choices", JSONArray().put(JSONObject().apply {
                put("index", 0)
                put("delta", JSONObject().put("role", "assistant"))
                put("finish_reason", JSONObject.NULL)
            }))
        }
        sseBuilder.append("data: ${roleChunk}\n\n")

        // Send content chunks (in real impl, each token gets its own chunk)
        val contentChunk = JSONObject().apply {
            put("id", completionId)
            put("object", "chat.completion.chunk")
            put("created", timestamp)
            put("model", model)
            put("choices", JSONArray().put(JSONObject().apply {
                put("index", 0)
                put("delta", JSONObject().put("content", stubResponse))
                put("finish_reason", JSONObject.NULL)
            }))
        }
        sseBuilder.append("data: ${contentChunk}\n\n")

        // Send finish chunk
        val finishChunk = JSONObject().apply {
            put("id", completionId)
            put("object", "chat.completion.chunk")
            put("created", timestamp)
            put("model", model)
            put("choices", JSONArray().put(JSONObject().apply {
                put("index", 0)
                put("delta", JSONObject())
                put("finish_reason", "stop")
            }))
        }
        sseBuilder.append("data: ${finishChunk}\n\n")
        sseBuilder.append("data: [DONE]\n\n")

        val responseBytes = sseBuilder.toString().toByteArray()
        return newFixedLengthResponse(
            Response.Status.OK,
            "text/event-stream",
            ByteArrayInputStream(responseBytes),
            responseBytes.size.toLong()
        ).apply {
            addHeader("Cache-Control", "no-cache")
            addHeader("Connection", "keep-alive")
        }
    }

    /**
     * Non-streaming response — returns the full completion at once.
     */
    private fun handleNonStreamingResponse(
        completionId: String,
        timestamp: Long,
        model: String,
        prompt: String
    ): Response {
        // TODO: Replace stub with real MLC inference
        val stubResponse = "[MLC Engine] Model '$modelId' ready. Awaiting mlc4j integration for GPU inference."

        val response = JSONObject().apply {
            put("id", completionId)
            put("object", "chat.completion")
            put("created", timestamp)
            put("model", model)
            put("choices", JSONArray().put(JSONObject().apply {
                put("index", 0)
                put("message", JSONObject().apply {
                    put("role", "assistant")
                    put("content", stubResponse)
                })
                put("finish_reason", "stop")
            }))
            put("usage", JSONObject().apply {
                put("prompt_tokens", prompt.length / 4)  // rough estimate
                put("completion_tokens", stubResponse.length / 4)
                put("total_tokens", (prompt.length + stubResponse.length) / 4)
            })
        }

        return newFixedLengthResponse(Response.Status.OK, "application/json", response.toString())
    }

    /**
     * GET /v1/models — OpenAI-compatible model list
     */
    private fun handleModelList(): Response {
        val response = JSONObject().apply {
            put("object", "list")
            put("data", JSONArray().put(JSONObject().apply {
                put("id", modelId)
                put("object", "model")
                put("created", System.currentTimeMillis() / 1000)
                put("owned_by", "mlc-llm")
            }))
        }
        return newFixedLengthResponse(Response.Status.OK, "application/json", response.toString())
    }

    /**
     * GET /api/tags — Ollama-compatible model list (for OpenClaw compatibility)
     */
    private fun handleOllamaModelList(): Response {
        val response = JSONObject().apply {
            put("models", JSONArray().put(JSONObject().apply {
                put("name", modelId)
                put("model", modelId)
                put("size", 0)
            }))
        }
        return newFixedLengthResponse(Response.Status.OK, "application/json", response.toString())
    }
}
