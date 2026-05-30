package com.nxg.openclawproot

import android.app.Application
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.Process
import android.os.SystemClock
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger

class NativeNodeEmbeddedService : Service() {
    private val startedAtMs = SystemClock.elapsedRealtime()

    private data class PreflightBundle(
        val root: File,
        val manifest: File
    )

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

        val preflight = preparePreflightBundle()
        val script = writeSmokeScript(preflight)
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

    private fun preparePreflightBundle(): PreflightBundle {
        val dir = File(workDir(applicationContext), "mobile-openclaw-preflight")
        if (dir.exists()) dir.deleteRecursively()
        dir.mkdirs()

        val copied = JSONObject()
        val missing = mutableListOf<String>()

        fun copyAsset(assetPath: String, target: File) {
            try {
                target.parentFile?.mkdirs()
                assets.open(assetPath).use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
                copied.put(assetPath, target.relativeTo(dir).path.replace(File.separatorChar, '/'))
            } catch (e: Exception) {
                missing.add(assetPath)
                appendLog("preflight asset missing $assetPath: ${e.message}")
            }
        }

        fun assetExists(assetPath: String): Boolean {
            return try {
                assets.open(assetPath).use { true }
            } catch (_: Exception) {
                false
            }
        }

        copyAsset(
            "flutter_assets/assets/openclaw/android_bridge_tools.js",
            File(dir, "android_bridge_tools.js")
        )
        copyAsset(
            "flutter_assets/assets/openclaw/mobile_gateway_probe.js",
            File(dir, "mobile_gateway_probe.js")
        )

        listOf("avatar_forge.md", "battery.md", "sensors.md", "vibrate.md").forEach { name ->
            copyAsset(
                "flutter_assets/assets/openclaw/skills/$name",
                File(File(dir, "skills"), name)
            )
        }

        val manifest = File(dir, "preflight_manifest.json")
        manifest.writeText(
            JSONObject()
                .put("bundleKind", "mobile-openclaw-preflight")
                .put("bundleRoot", dir.absolutePath)
                .put("copiedAssets", copied)
                .put("missingAssets", JSONArray(missing))
                .put(
                    "nodeModulesTarAssetPresent",
                    assetExists("flutter_assets/assets/openclaw-node-modules.tar.gz")
                )
                .put("productionGatewayPort", 18789)
                .put("smokePort", PORT)
                .toString()
        )

        appendLog(
            "prepared mobile OpenClaw preflight bundle copied=${copied.length()} " +
                "missing=${missing.size}"
        )
        return PreflightBundle(dir, manifest)
    }

    private fun writeSmokeScript(preflight: PreflightBundle): File {
        val dir = workDir(applicationContext)
        dir.mkdirs()
        val script = File(dir, "server.mjs")
        val bundleRoot = JSONObject.quote(preflight.root.absolutePath)
        val manifestPath = JSONObject.quote(preflight.manifest.absolutePath)
        script.writeText(
            """
            import http from "node:http";
            import fs from "node:fs";
            import path from "node:path";
            import process from "node:process";
            import { createRequire } from "node:module";

            const require = createRequire(import.meta.url);
            const bundleRoot = $bundleRoot;
            const manifestPath = $manifestPath;
            const { createMobileGatewayProbe } = require(path.join(bundleRoot, "mobile_gateway_probe.js"));

            const host = "$HOST";
            const port = $PORT;
            const startedAt = Date.now();

            function versionAtLeast(actual, minimum) {
              const parse = (value) => String(value).replace(/^v/, "").split(".").map((part) => Number.parseInt(part, 10) || 0);
              const a = parse(actual);
              const b = parse(minimum);
              for (let i = 0; i < Math.max(a.length, b.length); i += 1) {
                const left = a[i] || 0;
                const right = b[i] || 0;
                if (left > right) return true;
                if (left < right) return false;
              }
              return true;
            }

            function runPreflight() {
              const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
              const skillsDir = path.join(bundleRoot, "skills");
              const skillFiles = fs.existsSync(skillsDir)
                ? fs.readdirSync(skillsDir).filter((name) => name.endsWith(".md")).sort()
                : [];

              let bridgeToolsLoaded = false;
              let bridgeToolNames = [];
              let bridgeToolsError = null;
              try {
                const bridgeTools = require(path.join(bundleRoot, "android_bridge_tools.js"));
                bridgeToolNames = Object.keys(bridgeTools).sort();
                bridgeToolsLoaded = ["get_battery", "read_sensor", "vibrate"]
                  .every((name) => typeof bridgeTools[name] === "function");
              } catch (error) {
                bridgeToolsError = error?.message || String(error);
              }

              const builtinModules = {
                fs: typeof fs.readFileSync === "function",
                http: typeof http.createServer === "function",
                crypto: typeof require("node:crypto").createHash === "function",
                module: typeof createRequire === "function"
              };

              const intlOk = typeof Intl?.DateTimeFormat === "function" &&
                new Intl.DateTimeFormat("en-US", { timeZone: "UTC" }).format(new Date(0)).length > 0;

              const missingAssets = Array.isArray(manifest.missingAssets) ? manifest.missingAssets : [];
              const engineOk = versionAtLeast(process.versions.node, "22.19.0");
              const passed = engineOk &&
                bridgeToolsLoaded &&
                skillFiles.length >= 4 &&
                missingAssets.length === 0 &&
                manifest.nodeModulesTarAssetPresent === true &&
                Object.values(builtinModules).every(Boolean) &&
                intlOk === true;

              return {
                passed,
                kind: manifest.bundleKind,
                bundleRoot,
                engineOk,
                minimumNode: "22.19.0",
                node: process.version,
                platform: process.platform,
                arch: process.arch,
                skillCount: skillFiles.length,
                skillFiles,
                bridgeToolsLoaded,
                bridgeToolNames,
                bridgeToolsError,
                builtinModules,
                intlOk,
                nodeModulesTarAssetPresent: manifest.nodeModulesTarAssetPresent === true,
                missingAssets,
                productionGatewayPort: manifest.productionGatewayPort,
                smokePort: manifest.smokePort,
                openclawStarted: false
              };
            }

            const preflight = runPreflight();
            const gatewayProbe = createMobileGatewayProbe({
              preflight,
              host,
              port,
              productionGatewayPort: 18789,
              startedAt
            });

            const server = http.createServer((req, res) => {
              const requestUrl = new URL(req.url || "/", `http://${'$'}{host}:${'$'}{port}`);
              const pathname = requestUrl.pathname;

              if (gatewayProbe.handle(req, res, pathname)) {
                return;
              }

              if (pathname === "/health" || pathname === "/" || pathname === "/preflight") {
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
                  preflight,
                  gatewayProbe: gatewayProbe.summary(),
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
