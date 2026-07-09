package com.openclaw.plawie

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
import java.net.InetSocketAddress
import java.net.Socket
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentLinkedDeque

class NativeNodeSkillRunnerService : Service() {
    private val startedAtMs = SystemClock.elapsedRealtime()

    companion object {
        private const val TAG = "NativeNodeSkillRunner"
        private const val ACTION_START = "com.openclaw.plawie.native_node_skill_runner.START"
        private const val ACTION_STOP = "com.openclaw.plawie.native_node_skill_runner.STOP"
        const val HOST = "127.0.0.1"
        const val PORT = 18791
        private const val MAX_LOG_LINES = 240
        private val logs = ConcurrentLinkedDeque<String>()

        fun start(context: Context): Boolean {
            return try {
                context.startService(Intent(context, NativeNodeSkillRunnerService::class.java).apply {
                    action = ACTION_START
                })
                true
            } catch (e: Exception) {
                appendStaticLog("start failed: ${e.message}")
                false
            }
        }

        fun stop(context: Context): Boolean {
            return try {
                context.startService(Intent(context, NativeNodeSkillRunnerService::class.java).apply {
                    action = ACTION_STOP
                })
                true
            } catch (e: Exception) {
                appendStaticLog("stop failed: ${e.message}")
                false
            }
        }

        fun workDir(context: Context): File =
            File(context.filesDir, "native-node-skill-runner")

        fun logFile(context: Context): File =
            File(workDir(context), "runtime.log")

        fun getRecentLogs(context: Context): String {
            val memoryLogs = logs.joinToString("\n")
            val fileLogs = try {
                val file = logFile(context)
                if (file.exists()) file.readLines().takeLast(MAX_LOG_LINES).joinToString("\n") else ""
            } catch (e: Exception) {
                "Could not read Native Node skill runner logs: ${e.message}"
            }
            return listOf(memoryLogs, fileLogs)
                .filter { it.isNotBlank() }
                .joinToString("\n")
                .ifBlank { "Native Node skill runner has no logs yet." }
        }

        private fun appendStaticLog(message: String) {
            val stamp = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
            val payload = JSONObject()
                .put("time", stamp)
                .put("tag", "NATIVE-NODE-SKILL-RUNNER")
                .put("message", message)
                .toString()
            logs.add(payload)
            while (logs.size > MAX_LOG_LINES) logs.poll()
            Log.i(TAG, payload)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopRunner(startId)
            else -> startRunner()
        }
        return START_NOT_STICKY
    }

    private fun startRunner() {
        if (isTcpListening(PORT)) {
            appendLog("start ignored; skill runner already listening on $HOST:$PORT")
            return
        }
        if (NativeNodeBridge.running()) {
            appendLog("start ignored; embedded Node bridge already running in this process")
            return
        }

        try {
            val script = writeRunnerScript()
            appendLog("starting Native Node skill runner script=${script.absolutePath}")
            val result = NativeNodeBridge.start(arrayOf("plawie-native-node-skill-runner", script.absolutePath))
            appendLog("bridge start result code=${result.code} message=${result.message}")
            if (result.code < 0) stopSelf()
        } catch (e: Exception) {
            appendLog("skill runner preparation failed: ${e.message}")
            Log.e(TAG, "Native Node skill runner preparation failed", e)
            stopSelf()
        }
    }

    private fun stopRunner(startId: Int) {
        appendLog("stop requested; terminating isolated Native Node skill runner")
        stopSelf(startId)
        if (Application.getProcessName().contains(":native_node_runner")) {
            Thread {
                Thread.sleep(150)
                Process.killProcess(Process.myPid())
            }.apply {
                name = "NativeNodeSkillRunner-kill"
                isDaemon = true
                start()
            }
        }
    }

    private fun writeRunnerScript(): File {
        val dir = workDir(applicationContext)
        dir.mkdirs()
        val script = File(dir, "skill_runner.mjs")
        val nativeStateRoot = JSONObject.quote(
            File(filesDir, "native-node-embedded/native-home/.openclaw").absolutePath
        )
        val nativeNodeModules = JSONObject.quote(
            File(filesDir, "native-node-embedded/native-home/.openclaw/node_modules").absolutePath
        )
        script.writeText(
            """
            import http from "node:http";
            import fs from "node:fs";
            import path from "node:path";
            import process from "node:process";
            import { pathToFileURL } from "node:url";
            import { createRequire } from "node:module";

            const require = createRequire(import.meta.url);
            const Module = require("node:module");
            const nativeStateRoot = $nativeStateRoot;
            const nativeNodeModules = $nativeNodeModules;
            const host = "$HOST";
            const port = $PORT;
            const startedAt = Date.now();

            process.env.NODE_PATH = [
              nativeNodeModules,
              process.env.NODE_PATH || ""
            ].filter(Boolean).join(path.delimiter);
            Module.Module?._initPaths?.();
            Module._initPaths?.();

            function sendJson(res, statusCode, payload) {
              res.writeHead(statusCode, {
                "content-type": "application/json",
                "cache-control": "no-store"
              });
              res.end(JSON.stringify(payload));
            }

            function readBody(req) {
              return new Promise((resolve, reject) => {
                let body = "";
                req.setEncoding("utf8");
                req.on("data", (chunk) => {
                  body += chunk;
                  if (body.length > 1024 * 1024) {
                    reject(new Error("request body too large"));
                    req.destroy();
                  }
                });
                req.on("end", () => resolve(body));
                req.on("error", reject);
              });
            }

            function assertInside(root, child, label) {
              const resolvedRoot = fs.realpathSync(root);
              const resolvedChild = fs.realpathSync(child);
              if (resolvedChild !== resolvedRoot &&
                  !resolvedChild.startsWith(resolvedRoot + path.sep)) {
                throw new Error(`${'$'}{label} escapes Native OpenClaw state root`);
              }
              return resolvedChild;
            }

            function sanitize(value) {
              if (value === undefined) return null;
              if (value === null) return null;
              if (typeof value === "bigint") return value.toString();
              if (typeof value === "function") return `[function ${'$'}{value.name || "anonymous"}]`;
              if (Array.isArray(value)) return value.map(sanitize);
              if (value && typeof value === "object") {
                const out = {};
                for (const [key, entry] of Object.entries(value)) {
                  out[key] = sanitize(entry);
                }
                return out;
              }
              return value;
            }

            async function loadModule(modulePath) {
              const url = pathToFileURL(modulePath).href + `?openclaw=${'$'}{Date.now()}`;
              return import(url);
            }

            function pickCallable(loaded, action) {
              const method = action?.method || action?.label || "execute";
              const candidates = [method, "execute", "default"];
              for (const name of candidates) {
                if (typeof loaded?.[name] === "function") return loaded[name].bind(loaded);
                if (loaded?.default && typeof loaded.default?.[name] === "function") {
                  return loaded.default[name].bind(loaded.default);
                }
              }
              if (typeof loaded?.default === "function") return loaded.default;
              throw new Error(`No callable export found for method ${'$'}{method}`);
            }

            async function executeSkill(payload) {
              const rootPath = String(payload.rootPath || payload.cwd || "");
              const entrypoint = String(payload.entrypoint || "");
              if (!rootPath || !entrypoint) {
                throw new Error("rootPath and entrypoint are required");
              }
              if (entrypoint.includes("..") || path.isAbsolute(entrypoint)) {
                throw new Error("entrypoint must be a relative path inside the skill");
              }
              assertInside(nativeStateRoot, rootPath, "rootPath");
              const modulePath = path.resolve(rootPath, entrypoint);
              assertInside(rootPath, modulePath, "entrypoint");
              const loaded = await loadModule(modulePath);
              const actions = Array.isArray(payload.actions) && payload.actions.length
                ? payload.actions
                : [{ method: "execute", args: {} }];
              const responses = [];
              for (const action of actions) {
                const callable = pickCallable(loaded, action);
                const args = action && typeof action.args === "object" && action.args !== null
                  ? action.args
                  : {};
                const value = await callable(args, {
                  skillId: payload.skillId || "",
                  rootPath,
                  entrypoint
                });
                responses.push({
                  label: action?.label || action?.method || "execute",
                  method: action?.method || "execute",
                  ok: true,
                  data: sanitize(value)
                });
              }
              return {
                ok: true,
                runtime: "native-node-skill-runner",
                skillId: payload.skillId || "",
                responses,
                data: {
                  responses,
                  result: responses.length === 1 ? responses[0].data : responses.map((item) => item.data)
                },
                durationMs: Date.now() - startedAt
              };
            }

            const server = http.createServer(async (req, res) => {
              try {
                const requestUrl = new URL(req.url || "/", `http://${'$'}{host}:${'$'}{port}`);
                if (req.method === "GET" && (requestUrl.pathname === "/" || requestUrl.pathname === "/health")) {
                  sendJson(res, 200, {
                    ok: true,
                    runtime: "native-node-skill-runner",
                    node: process.version,
                    nativeStateRoot,
                    nativeNodeModules,
                    uptimeMs: Date.now() - startedAt
                  });
                  return;
                }
                if (req.method === "POST" && requestUrl.pathname === "/execute") {
                  const body = await readBody(req);
                  const payload = body.trim() ? JSON.parse(body) : {};
                  const result = await executeSkill(payload);
                  sendJson(res, 200, result);
                  return;
                }
                sendJson(res, 404, { ok: false, error: "not_found", path: req.url });
              } catch (error) {
                sendJson(res, 400, {
                  ok: false,
                  runtime: "native-node-skill-runner",
                  error: error?.stack || error?.message || String(error)
                });
              }
            });

            server.listen(port, host, () => {
              console.log(`[NATIVE-NODE-SKILL-RUNNER] listening on http://${'$'}{host}:${'$'}{port}`);
            });
            """.trimIndent()
        )
        return script
    }

    private fun isTcpListening(port: Int): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress(HOST, port), 700)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun appendLog(message: String) {
        val stamp = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val payload = JSONObject()
            .put("time", stamp)
            .put("tag", "NATIVE-NODE-SKILL-RUNNER")
            .put("message", message)
            .put("elapsedMs", SystemClock.elapsedRealtime() - startedAtMs)
            .put("process", Application.getProcessName())
            .toString()
        logs.add(payload)
        while (logs.size > MAX_LOG_LINES) logs.poll()
        try {
            val file = logFile(applicationContext)
            file.parentFile?.mkdirs()
            file.appendText(payload + "\n")
        } catch (_: Exception) {}
        Log.i(TAG, payload)
    }
}
