package com.nxg.openclawproot

import android.app.Application
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.Process
import android.os.SystemClock
import android.util.Log
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.zip.GZIPInputStream

class NativeNodeEmbeddedService : Service() {
    private val startedAtMs = SystemClock.elapsedRealtime()
    private var activePort = PORT
    private var activeCanaryMode = "embedded-smoke"
    private val fullGatewayBootstrapStartClaimed = AtomicBoolean(false)
    private var lastStartIgnoredMessage: String? = null
    private var lastStartIgnoredAtMs: Long = 0L
    private var suppressedStartIgnoredCount: Int = 0

    private data class PreflightBundle(
        val root: File,
        val manifest: File
    )

    private data class FullGatewayBundle(
        val root: File,
        val packageDir: File,
        val launcher: File,
        val manifest: File,
        val extractedNow: Boolean,
        val entryCount: Int,
        val fileCount: Int,
        val androidTmpPatchCount: Int
    )

    companion object {
        private const val TAG = "NativeNodeEmbedded"
        private const val FULL_GATEWAY_BOOTSTRAP_MODE = "full-gateway-bootstrap"
        private const val OPENCLAW_TARBALL_ASSET =
            "flutter_assets/assets/openclaw-node-modules.tar.gz"
        private const val ACTION_START = "com.nxg.openclawproot.native_node.START"
        private const val ACTION_STOP = "com.nxg.openclawproot.native_node.STOP"
        private const val EXTRA_PORT = "port"
        private const val EXTRA_CANARY_MODE = "canaryMode"
        const val HOST = "127.0.0.1"
        const val PORT = 18790
        const val PRODUCTION_PORT = 18789
        private val lifecycleGeneration = AtomicInteger(0)

        fun start(
            context: Context,
            port: Int = PORT,
            canaryMode: String = "embedded-smoke"
        ) {
            context.startService(Intent(context, NativeNodeEmbeddedService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_PORT, port)
                putExtra(EXTRA_CANARY_MODE, canaryMode)
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
            else -> startEmbeddedRuntime(intent)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        appendLog("service destroyed")
        super.onDestroy()
    }

    private fun startEmbeddedRuntime(intent: Intent?) {
        lifecycleGeneration.incrementAndGet()

        val requestedPort = intent?.getIntExtra(EXTRA_PORT, PORT) ?: PORT
        val requestedCanaryMode =
            intent?.getStringExtra(EXTRA_CANARY_MODE)?.takeIf { it.isNotBlank() }
                ?: "embedded-smoke"
        if (requestedPort != PORT && requestedPort != PRODUCTION_PORT) {
            appendLog("start rejected; unsupported port=$requestedPort mode=$requestedCanaryMode")
            stopSelf()
            return
        }

        if (
            activeCanaryMode == FULL_GATEWAY_BOOTSTRAP_MODE &&
            requestedCanaryMode != FULL_GATEWAY_BOOTSTRAP_MODE
        ) {
            appendStartIgnoredLog(
                "start ignored; full Gateway bootstrap is already preparing " +
                    "activePort=$activePort requestedPort=$requestedPort " +
                    "requestedMode=$requestedCanaryMode"
            )
            return
        }

        if (NativeNodeBridge.running()) {
            if (activePort != requestedPort || activeCanaryMode != requestedCanaryMode) {
                appendLog(
                    "start replacing stale embedded Node runtime " +
                        "activePort=$activePort activeMode=$activeCanaryMode " +
                        "requestedPort=$requestedPort requestedMode=$requestedCanaryMode"
                )
                fullGatewayBootstrapStartClaimed.set(false)
                stopSelf()
                if (Application.getProcessName().contains(":native_node_smoke")) {
                    Thread {
                        Thread.sleep(100)
                        Process.killProcess(Process.myPid())
                    }.apply {
                        name = "NativeNodeEmbedded-replace-stale-runtime"
                        isDaemon = true
                        start()
                    }
                }
                return
            }
            appendStartIgnoredLog(
                "start ignored; embedded Node already running " +
                    "activePort=$activePort activeMode=$activeCanaryMode " +
                    "requestedPort=$requestedPort requestedMode=$requestedCanaryMode"
            )
            return
        }

        activePort = requestedPort
        activeCanaryMode = requestedCanaryMode

        if (requestedCanaryMode == FULL_GATEWAY_BOOTSTRAP_MODE) {
            if (!fullGatewayBootstrapStartClaimed.compareAndSet(false, true)) {
                appendStartIgnoredLog(
                    "start ignored; full Gateway bootstrap already starting or started " +
                        "activePort=$activePort requestedPort=$requestedPort"
                )
                return
            }
            Thread {
                startFullGatewayBootstrapRuntime(requestedPort, requestedCanaryMode)
            }.apply {
                name = "NativeNodeEmbedded-full-gateway-bootstrap"
                isDaemon = true
                start()
            }
            return
        }

        startSmokeRuntime(requestedPort, requestedCanaryMode)
    }

    private fun startSmokeRuntime(requestedPort: Int, requestedCanaryMode: String) {
        val preflight = preparePreflightBundle(requestedPort, requestedCanaryMode)
        val script = writeSmokeScript(preflight, requestedPort, requestedCanaryMode)
        startNodeScript(
            script,
            requestedPort,
            requestedCanaryMode,
            "embedded Node health runtime"
        )
    }

    private fun startFullGatewayBootstrapRuntime(requestedPort: Int, requestedCanaryMode: String) {
        try {
            val bundle = prepareFullGatewayBundle(requestedPort, requestedCanaryMode)
            val script = writeFullGatewayBootstrapScript(bundle, requestedPort, requestedCanaryMode)
            appendLog(
                "prepared full OpenClaw bundle packageDir=${bundle.packageDir.absolutePath} " +
                    "launcher=${bundle.launcher.absolutePath} extractedNow=${bundle.extractedNow} " +
                    "entries=${bundle.entryCount} files=${bundle.fileCount}"
            )
            startNodeScript(
                script,
                requestedPort,
                requestedCanaryMode,
                "embedded Node full OpenClaw Gateway bootstrap"
            )
        } catch (e: Exception) {
            fullGatewayBootstrapStartClaimed.set(false)
            appendLog("full Gateway bootstrap preparation failed: ${e.message}")
            Log.e(TAG, "Full Gateway bootstrap preparation failed", e)
            stopSelf()
        }
    }

    private fun startNodeScript(
        script: File,
        requestedPort: Int,
        requestedCanaryMode: String,
        label: String
    ) {
        appendLog(
            "starting $label on $HOST:$requestedPort canaryMode=$requestedCanaryMode " +
                "script=${script.absolutePath}"
        )
        val args = arrayOf("plawie-native-node", script.absolutePath)
        val result = NativeNodeBridge.start(args)
        appendLog("bridge start result code=${result.code} message=${result.message}")

        if (result.code < 0) {
            stopSelf()
        }
    }

    private fun stopEmbeddedRuntime(startId: Int) {
        val stopGeneration = lifecycleGeneration.incrementAndGet()
        appendLog(
            "stop requested; terminating isolated native Node process " +
                "activePort=$activePort activeMode=$activeCanaryMode"
        )
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

    private fun preparePreflightBundle(port: Int, canaryMode: String): PreflightBundle {
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
        copyAsset(
            "flutter_assets/assets/openclaw/mobile_skill_registry.js",
            File(dir, "mobile_skill_registry.js")
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
                    assetExists(OPENCLAW_TARBALL_ASSET)
                )
                .put("productionGatewayPort", 18789)
                .put("smokePort", PORT)
                .put("bindPort", port)
                .put("canaryMode", canaryMode)
                .put("productionPortBindCanary", port == PRODUCTION_PORT)
                .toString()
        )

        appendLog(
            "prepared mobile OpenClaw preflight bundle copied=${copied.length()} " +
                "missing=${missing.size}"
        )
        return PreflightBundle(dir, manifest)
    }

    private fun prepareFullGatewayBundle(port: Int, canaryMode: String): FullGatewayBundle {
        val dir = File(workDir(applicationContext), "full-openclaw")
        val packageDir = File(dir, "lib/node_modules/openclaw")
        val launcher = File(packageDir, "openclaw.mjs")
        val packageJson = File(packageDir, "package.json")
        val runMainEntry = File(packageDir, "dist/cli/run-main.js")
        val typeboxPackage = File(packageDir, "node_modules/typebox/package.json")
        val requiredFiles = listOf(
            launcher,
            packageJson,
            runMainEntry,
            typeboxPackage
        )
        var extractedNow = false
        var entryCount = 0
        var fileCount = 0

        val missingRequiredFiles = requiredFiles.filterNot { it.exists() }
        if (missingRequiredFiles.isNotEmpty()) {
            appendLog(
                "full OpenClaw bundle cache invalid; missing=" +
                    missingRequiredFiles.joinToString(",") { it.relativeTo(dir).path }
            )
            if (dir.exists()) dir.deleteRecursively()
            dir.mkdirs()
            val counts = extractOpenClawTarball(dir)
            extractedNow = true
            entryCount = counts.first
            fileCount = counts.second
        } else {
            fileCount = countExistingFiles(dir)
            entryCount = fileCount
        }
        val androidTmpPatchCount = patchOpenClawAndroidTmpDirs(
            packageDir,
            File(workDir(applicationContext), "tmp/openclaw")
        )

        if (!launcher.exists()) {
            throw IllegalStateException("OpenClaw launcher missing after extraction: ${launcher.absolutePath}")
        }
        if (!packageJson.exists()) {
            throw IllegalStateException("OpenClaw package.json missing after extraction: ${packageJson.absolutePath}")
        }
        if (!runMainEntry.exists()) {
            throw IllegalStateException("OpenClaw mobile-safe run-main entry missing after extraction: ${runMainEntry.absolutePath}")
        }
        if (!typeboxPackage.exists()) {
            throw IllegalStateException("OpenClaw required dependency typebox missing after extraction: ${typeboxPackage.absolutePath}")
        }

        val manifest = File(dir, "full_gateway_manifest.json")
        manifest.writeText(
            JSONObject()
                .put("bundleKind", "full-openclaw-gateway")
                .put("bundleRoot", dir.absolutePath)
                .put("packageDir", packageDir.absolutePath)
                .put("launcher", launcher.absolutePath)
                .put("runMainEntry", runMainEntry.absolutePath)
                .put("packageJson", packageJson.absolutePath)
                .put("typeboxPackage", typeboxPackage.absolutePath)
                .put("asset", OPENCLAW_TARBALL_ASSET)
                .put("extractedNow", extractedNow)
                .put("entryCount", entryCount)
                .put("fileCount", fileCount)
                .put("androidTmpPatchCount", androidTmpPatchCount)
                .put("bindHost", HOST)
                .put("bindPort", port)
                .put("canaryMode", canaryMode)
                .put("productionGatewayPort", PRODUCTION_PORT)
                .put("smokePort", PORT)
                .toString()
        )

        return FullGatewayBundle(
            root = dir,
            packageDir = packageDir,
            launcher = launcher,
            manifest = manifest,
            extractedNow = extractedNow,
            entryCount = entryCount,
            fileCount = fileCount,
            androidTmpPatchCount = androidTmpPatchCount
        )
    }

    private fun patchOpenClawAndroidTmpDirs(packageDir: File, nativeTmpDir: File): Int {
        nativeTmpDir.mkdirs()
        val distDir = File(packageDir, "dist")
        if (!distDir.exists()) return 0

        val sourceLiteral = "const POSIX_OPENCLAW_TMP_DIR = \"/tmp/openclaw\";"
        val replacement = "const POSIX_OPENCLAW_TMP_DIR = ${JSONObject.quote(nativeTmpDir.absolutePath)};"
        var patchedCount = 0

        distDir.listFiles()
            ?.filter { file ->
                file.isFile &&
                    file.name.startsWith("tmp-openclaw-dir-") &&
                    file.name.endsWith(".js")
            }
            ?.forEach { file ->
                val raw = file.readText()
                if (raw.contains(sourceLiteral) && !raw.contains(replacement)) {
                    file.writeText(raw.replace(sourceLiteral, replacement))
                    patchedCount++
                }
            }

        if (patchedCount > 0) {
            appendLog(
                "patched OpenClaw Android tmp dir files=$patchedCount " +
                    "tmpDir=${nativeTmpDir.absolutePath}"
            )
        }
        return patchedCount
    }

    private fun extractOpenClawTarball(targetRoot: File): Pair<Int, Int> {
        val canonicalRoot = targetRoot.canonicalFile
        var entryCount = 0
        var fileCount = 0

        assets.open(OPENCLAW_TARBALL_ASSET).use { rawInput ->
            BufferedInputStream(rawInput, 256 * 1024).use { buffered ->
                GZIPInputStream(buffered).use { gzip ->
                    TarArchiveInputStream(gzip).use { tar ->
                        var entry: TarArchiveEntry? = tar.nextEntry
                        while (entry != null) {
                            entryCount++
                            val normalized = normalizeTarEntryName(entry.name)
                            if (normalized == null) {
                                appendLog("skipped unsafe OpenClaw tar entry name=${entry.name}")
                                entry = tar.nextEntry
                                continue
                            }

                            val outFile = File(canonicalRoot, normalized)
                            val canonicalOut = outFile.canonicalFile
                            if (!canonicalOut.path.startsWith(canonicalRoot.path + File.separator)) {
                                appendLog("skipped escaping OpenClaw tar entry name=${entry.name}")
                                entry = tar.nextEntry
                                continue
                            }

                            when {
                                entry.isDirectory -> canonicalOut.mkdirs()
                                entry.isSymbolicLink || entry.isLink -> {
                                    appendLog("skipped OpenClaw tar link entry name=${entry.name}")
                                }
                                entry.isFile -> {
                                    canonicalOut.parentFile?.mkdirs()
                                    FileOutputStream(canonicalOut).use { output ->
                                        tar.copyTo(output)
                                    }
                                    if ((entry.mode and 0b001_001_001) != 0) {
                                        canonicalOut.setExecutable(true, false)
                                    }
                                    fileCount++
                                }
                            }
                            entry = tar.nextEntry
                        }
                    }
                }
            }
        }

        if (fileCount == 0) {
            throw IllegalStateException("OpenClaw tarball extraction produced no files")
        }
        return Pair(entryCount, fileCount)
    }

    private fun normalizeTarEntryName(rawName: String): String? {
        val name = rawName
            .replace('\\', '/')
            .removePrefix("./")
            .trim()
        if (name.isEmpty()) return null
        if (name.startsWith("/") || name.contains("../") || name == ".." || name.contains(":")) {
            return null
        }
        return name
    }

    private fun countExistingFiles(root: File): Int {
        if (!root.exists()) return 0
        return root.walkTopDown().count { it.isFile }
    }

    private fun writeSmokeScript(
        preflight: PreflightBundle,
        port: Int,
        canaryMode: String
    ): File {
        val dir = workDir(applicationContext)
        dir.mkdirs()
        val script = File(dir, "server.mjs")
        val bundleRoot = JSONObject.quote(preflight.root.absolutePath)
        val manifestPath = JSONObject.quote(preflight.manifest.absolutePath)
        val prootSkillRoot = JSONObject.quote(
            File(filesDir, "rootfs/ubuntu/root/.openclaw/skills").absolutePath
        )
        val prootConfigPath = JSONObject.quote(
            File(filesDir, "rootfs/ubuntu/root/.openclaw/openclaw.json").absolutePath
        )
        val quotedCanaryMode = JSONObject.quote(canaryMode)
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
            const { inspectSkillRegistry } = require(path.join(bundleRoot, "mobile_skill_registry.js"));
            const productionSkillsRoot = $prootSkillRoot;
            const productionConfigPath = $prootConfigPath;

            const host = "$HOST";
            const port = $port;
            const canaryMode = $quotedCanaryMode;
            const productionPortBindCanary = port === 18789;
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
                bindPort: manifest.bindPort,
                canaryMode,
                productionPortBindCanary,
                openclawStarted: false
              };
            }

            const preflight = runPreflight();
            const skillRegistry = inspectSkillRegistry({
              skillsRoot: productionSkillsRoot,
              configPath: productionConfigPath
            });
            const gatewayProbe = createMobileGatewayProbe({
              preflight,
              skillRegistry,
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
                  smokePort: $PORT,
                  canaryMode,
                  productionPortBindCanary,
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

    private fun writeFullGatewayBootstrapScript(
        bundle: FullGatewayBundle,
        port: Int,
        canaryMode: String
    ): File {
        val dir = workDir(applicationContext)
        dir.mkdirs()

        val script = File(dir, "full_gateway_bootstrap.mjs")
        val packageDir = JSONObject.quote(bundle.packageDir.absolutePath)
        val launcherPath = JSONObject.quote(bundle.launcher.absolutePath)
        val manifestPath = JSONObject.quote(bundle.manifest.absolutePath)
        val nativeHome = JSONObject.quote(File(dir, "native-home").absolutePath)
        val nativeStateDir = JSONObject.quote(File(dir, "native-home/.openclaw").absolutePath)
        val prootStateDir = JSONObject.quote(
            File(filesDir, "rootfs/ubuntu/root/.openclaw").absolutePath
        )
        val nativeTmp = JSONObject.quote(File(dir, "tmp").absolutePath)
        val nativeCache = JSONObject.quote(File(dir, "cache").absolutePath)
        val quotedCanaryMode = JSONObject.quote(canaryMode)

        script.writeText(
            """
            import fs from "node:fs";
            import os from "node:os";
            import path from "node:path";
            import process from "node:process";
            import { createRequire, syncBuiltinESMExports } from "node:module";
            import { pathToFileURL } from "node:url";

            const packageDir = $packageDir;
            const require = createRequire(import.meta.url);
            const launcherPath = $launcherPath;
            const mobileRunMainPath = path.join(packageDir, "dist/cli/run-main.js");
            const manifestPath = $manifestPath;
            const nativeHome = $nativeHome;
            const nativeStateDir = $nativeStateDir;
            const prootStateDir = $prootStateDir;
            const nativeTmp = $nativeTmp;
            const nativeCache = $nativeCache;
            const nativeManagedBin = path.join(nativeStateDir, "bin");
            const nativeRuntimeRoot = path.join(nativeStateDir, "runtimes");
            const nativePythonRoot = path.join(nativeRuntimeRoot, "python");
            const nativePythonBin = path.join(nativePythonRoot, "bin");
            const nativePythonSitePackages = path.join(
              nativePythonRoot,
              "site-packages"
            );
            const host = "$HOST";
            const port = $port;
            const canaryMode = $quotedCanaryMode;

            for (const writableDir of [
              nativeHome,
              nativeStateDir,
              nativeManagedBin,
              nativeRuntimeRoot,
              nativePythonRoot,
              nativePythonBin,
              nativePythonSitePackages,
              nativeTmp,
              nativeCache
            ]) {
              fs.mkdirSync(writableDir, { recursive: true });
            }

            const readJsonFile = (filePath) => {
              try {
                if (!fs.existsSync(filePath)) return {};
                return JSON.parse(fs.readFileSync(filePath, "utf8"));
              } catch {
                return {};
              }
            };
            const deepMerge = (base, overlay) => {
              const out = { ...(base || {}) };
              for (const [key, value] of Object.entries(overlay || {})) {
                if (
                  value &&
                  typeof value === "object" &&
                  !Array.isArray(value) &&
                  out[key] &&
                  typeof out[key] === "object" &&
                  !Array.isArray(out[key])
                ) {
                  out[key] = deepMerge(out[key], value);
                } else {
                  out[key] = value;
                }
              }
              return out;
            };
            const rewriteRootBackedPaths = (value) => {
              if (typeof value === "string") {
                if (value === "/root") return nativeHome;
                if (value === "/root/.openclaw") return nativeStateDir;
                if (value.startsWith("/root/.openclaw/")) {
                  return path.join(nativeStateDir, value.slice("/root/.openclaw/".length));
                }
                return value;
              }
              if (Array.isArray(value)) {
                return value.map((entry) => rewriteRootBackedPaths(entry));
              }
              if (value && typeof value === "object") {
                const out = {};
                for (const [key, entry] of Object.entries(value)) {
                  out[key] = rewriteRootBackedPaths(entry);
                }
                return out;
              }
              return value;
            };
            const clampNativeOutputTokenCaps = (value, maxOutputTokens = 1024) => {
              const changes = [];
              const visit = (entry, location) => {
                if (!entry || typeof entry !== "object") return;
                if (Array.isArray(entry)) {
                  entry.forEach((child, index) => visit(child, location + "[" + index + "]"));
                  return;
                }
                for (const [key, child] of Object.entries(entry)) {
                  const childLocation = location ? location + "." + key : key;
                  if (key === "maxTokens" || key === "max_tokens") {
                    const numeric = Number(child);
                    if (Number.isFinite(numeric) && numeric > maxOutputTokens) {
                      changes.push({
                        path: childLocation,
                        from: numeric,
                        to: maxOutputTokens
                      });
                      entry[key] = maxOutputTokens;
                    }
                  } else {
                    visit(child, childLocation);
                  }
                }
              };
              visit(value, "config");
              return changes;
            };
            const makeGatewayToken = () =>
              "plawie-native-" +
              Date.now().toString(36) +
              "-" +
              Math.random().toString(36).slice(2, 18);
            const ensureNativeOpenClawConfig = () => {
              const prootConfigPath = path.join(prootStateDir, "openclaw.json");
              const nativeConfigPath = path.join(nativeStateDir, "openclaw.json");
              const prootEnvPath = path.join(prootStateDir, ".env");
              const nativeEnvPath = path.join(nativeStateDir, ".env");
              const prootConfig = readJsonFile(prootConfigPath);
              const existingNativeConfig = readJsonFile(nativeConfigPath);
              const existingNativeAuth =
                existingNativeConfig.gateway && existingNativeConfig.gateway.auth
                  ? existingNativeConfig.gateway.auth
                  : {};
              const config = rewriteRootBackedPaths(
                deepMerge(existingNativeConfig, prootConfig)
              );
              const outputCapClamp = clampNativeOutputTokenCaps(config);
              config.gateway = config.gateway && typeof config.gateway === "object"
                ? config.gateway
                : {};
              config.gateway.auth = config.gateway.auth && typeof config.gateway.auth === "object"
                ? config.gateway.auth
                : {};
              delete config.gateway.auth.unauthenticatedLocalhost;
              const prootGatewayAuth = prootConfig.gateway && prootConfig.gateway.auth
                ? prootConfig.gateway.auth
                : {};
              const configuredToken =
                existingNativeAuth.token ||
                prootGatewayAuth.token ||
                config.gateway.auth.token ||
                (prootConfig.auth && prootConfig.auth.token) ||
                makeGatewayToken();
              config.gateway.auth.token = configuredToken;
              config.gateway.auth.mode = "token";
              fs.writeFileSync(nativeConfigPath, JSON.stringify(config, null, 2));
              if (fs.existsSync(prootEnvPath)) {
                fs.copyFileSync(prootEnvPath, nativeEnvPath);
              }
              return {
                nativeConfigPath,
                prootConfigFound: fs.existsSync(prootConfigPath),
                nativeEnvSynced: fs.existsSync(nativeEnvPath),
                tokenConfigured: Boolean(config.gateway.auth.token),
                outputCapClampCount: outputCapClamp.length,
                outputCapClamp: outputCapClamp.slice(0, 12),
              };
            };
            const nativeConfigStatus = ensureNativeOpenClawConfig();

            process.env.HOME = nativeHome;
            process.env.OPENCLAW_HOME = nativeHome;
            process.env.OPENCLAW_STATE_DIR = nativeStateDir;
            process.env.XDG_CACHE_HOME = nativeCache;
            process.env.TMPDIR = nativeTmp;
            process.env.TEMP = nativeTmp;
            process.env.TMP = nativeTmp;
            process.env.PATH = [
              nativeManagedBin,
              nativePythonBin,
              process.env.PATH || "",
              "/system/bin"
            ].filter(Boolean).join(":");
            process.env.PYTHONHOME = nativePythonRoot;
            process.env.PYTHONPATH = [
              nativePythonSitePackages,
              process.env.PYTHONPATH || ""
            ].filter(Boolean).join(":");
            process.env.OPENCLAW_NATIVE_MANAGED_BIN = nativeManagedBin;
            process.env.OPENCLAW_NATIVE_PYTHON_HOME = nativePythonRoot;
            process.env.OPENCLAW_NATIVE_PYTHON_SITE_PACKAGES =
              nativePythonSitePackages;
            process.env.OPENCLAW_NATIVE_PYTHON_RUNNER =
              "http://127.0.0.1:8765/api/python/exec";
            process.env.OPENCLAW_NATIVE_PYTHON_BRIDGE = "chaquopy";
            process.env.NODE_DISABLE_COMPILE_CACHE = "1";
            process.env.OPENCLAW_GATEWAY_STARTUP_TRACE = "1";
            process.env.OPENCLAW_DISABLE_CLI_STARTUP_HELP_FAST_PATH = "1";
            process.env.NO_COLOR = "1";
            const installNativePythonBridge = () => {
              const childProcess = require("node:child_process");
              const http = require("node:http");
              const { EventEmitter } = require("node:events");
              const { PassThrough, Writable } = require("node:stream");
              const original = {
                spawn: childProcess.spawn,
                execFile: childProcess.execFile,
                exec: childProcess.exec,
                spawnSync: childProcess.spawnSync,
                execFileSync: childProcess.execFileSync,
                execSync: childProcess.execSync
              };
              const bridgeUrl = new URL(process.env.OPENCLAW_NATIVE_PYTHON_RUNNER);
              const tokenise = (command) => {
                const out = [];
                let current = "";
                let quote = null;
                let escaped = false;
                for (const ch of String(command || "")) {
                  if (escaped) {
                    current += ch;
                    escaped = false;
                  } else if (ch === "\\") {
                    escaped = true;
                  } else if (quote) {
                    if (ch === quote) quote = null;
                    else current += ch;
                  } else if (ch === "'" || ch === '"') {
                    quote = ch;
                  } else if (/\s/.test(ch)) {
                    if (current) {
                      out.push(current);
                      current = "";
                    }
                  } else {
                    current += ch;
                  }
                }
                if (current) out.push(current);
                return out;
              };
              const pythonKind = (command) => {
                if (!command) return null;
                const normalized = String(command).replace(/\\/g, "/");
                const base = path.basename(normalized).toLowerCase();
                if (base === "python" || base === "python3") return "python";
                if (base === "pip" || base === "pip3") return "pip";
                if (normalized.toLowerCase().endsWith("/.venv/bin/python3") ||
                    normalized.toLowerCase().endsWith("/.venv/bin/python")) {
                  return "python";
                }
                if (normalized.toLowerCase().endsWith("/.venv/bin/pip") ||
                    normalized.toLowerCase().endsWith("/.venv/bin/pip3")) {
                  return "pip";
                }
                return null;
              };
              const normalizePayloadArgs = (command, args) => {
                const list = Array.isArray(args) ? args.map((value) => String(value)) : [];
                return pythonKind(command) === "pip" ? ["-m", "pip", ...list] : list;
              };
              const bridgePython = (command, args, options = {}) => new Promise((resolve, reject) => {
                const payload = JSON.stringify({
                  command: String(command),
                  args: normalizePayloadArgs(command, args),
                  cwd: options && options.cwd ? String(options.cwd) : process.cwd(),
                  env: options && options.env ? options.env : process.env,
                  pythonPaths: [
                    nativePythonSitePackages,
                    path.join(nativeStateDir, "python", "site-packages")
                  ]
                });
                const request = http.request({
                  hostname: bridgeUrl.hostname,
                  port: Number(bridgeUrl.port || 80),
                  path: bridgeUrl.pathname,
                  method: "POST",
                  headers: {
                    "Content-Type": "application/json",
                    "Content-Length": Buffer.byteLength(payload)
                  },
                  timeout: 240000
                }, (response) => {
                  let body = "";
                  response.setEncoding("utf8");
                  response.on("data", (chunk) => { body += chunk; });
                  response.on("end", () => {
                    try {
                      const decoded = JSON.parse(body || "{}");
                      if (response.statusCode >= 200 && response.statusCode < 300) {
                        resolve(decoded);
                      } else {
                        const error = new Error(decoded.stderr || decoded.error || body || ("Native Python HTTP " + response.statusCode));
                        error.result = decoded;
                        reject(error);
                      }
                    } catch (error) {
                      reject(error);
                    }
                  });
                });
                request.on("timeout", () => request.destroy(new Error("Native Python bridge timeout")));
                request.on("error", reject);
                request.write(payload);
                request.end();
              });
              const makeProcess = (command, args, options = {}) => {
                const proc = new EventEmitter();
                proc.stdout = new PassThrough();
                proc.stderr = new PassThrough();
                proc.stdin = new Writable({ write(_chunk, _encoding, callback) { callback(); } });
                proc.pid = 0;
                proc.killed = false;
                proc.exitCode = null;
                proc.signalCode = null;
                proc.kill = () => {
                  proc.killed = true;
                  return false;
                };
                setImmediate(async () => {
                  try {
                    const result = await bridgePython(command, args, options);
                    const stdout = result.stdout || "";
                    const stderr = result.stderr || "";
                    if (stdout) proc.stdout.write(stdout);
                    if (stderr) proc.stderr.write(stderr);
                    proc.stdout.end();
                    proc.stderr.end();
                    const code = Number.isFinite(Number(result.exitCode)) ? Number(result.exitCode) : (result.ok === false ? 1 : 0);
                    proc.exitCode = code;
                    proc.emit("exit", code, null);
                    proc.emit("close", code, null);
                  } catch (error) {
                    const stderr = error?.result?.stderr || error?.message || String(error);
                    if (stderr) proc.stderr.write(stderr + "\n");
                    proc.stdout.end();
                    proc.stderr.end();
                    proc.exitCode = 1;
                    proc.emit("error", error);
                    proc.emit("exit", 1, null);
                    proc.emit("close", 1, null);
                  }
                });
                return proc;
              };
              childProcess.spawn = function(command, args, options) {
                if (pythonKind(command)) return makeProcess(command, args, options || {});
                return original.spawn.apply(this, arguments);
              };
              childProcess.execFile = function(file, args, options, callback) {
                let actualArgs = args;
                let actualOptions = options;
                let actualCallback = callback;
                if (typeof actualArgs === "function") {
                  actualCallback = actualArgs;
                  actualArgs = [];
                  actualOptions = {};
                } else if (typeof actualOptions === "function") {
                  actualCallback = actualOptions;
                  actualOptions = {};
                }
                if (!pythonKind(file)) return original.execFile.apply(this, arguments);
                const proc = makeProcess(file, actualArgs || [], actualOptions || {});
                if (actualCallback) {
                  let stdout = "";
                  let stderr = "";
                  proc.stdout.on("data", (chunk) => { stdout += chunk.toString(); });
                  proc.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
                  proc.on("close", (code) => {
                    const error = code === 0 ? null : Object.assign(new Error(stderr || ("Native Python exited " + code)), { code });
                    actualCallback(error, stdout, stderr);
                  });
                }
                return proc;
              };
              childProcess.exec = function(command, options, callback) {
                let actualOptions = options;
                let actualCallback = callback;
                if (typeof actualOptions === "function") {
                  actualCallback = actualOptions;
                  actualOptions = {};
                }
                const tokens = tokenise(command);
                if (!tokens.length || !pythonKind(tokens[0])) {
                  return original.exec.apply(this, arguments);
                }
                return childProcess.execFile(tokens[0], tokens.slice(1), actualOptions || {}, actualCallback);
              };
              const syncBlocked = (command) => {
                const message = "Native Python bridge does not support synchronous child_process calls; use async spawn/execFile/exec.";
                const stderr = Buffer.from(message + "\n");
                if (command === "object") {
                  return { status: 1, signal: null, pid: 0, stdout: Buffer.alloc(0), stderr, output: [null, Buffer.alloc(0), stderr] };
                }
                const error = new Error(message);
                error.status = 1;
                error.stderr = stderr;
                error.stdout = Buffer.alloc(0);
                throw error;
              };
              childProcess.spawnSync = function(command, args, options) {
                if (pythonKind(command)) return syncBlocked("object");
                return original.spawnSync.apply(this, arguments);
              };
              childProcess.execFileSync = function(file, args, options) {
                if (pythonKind(file)) return syncBlocked("buffer");
                return original.execFileSync.apply(this, arguments);
              };
              childProcess.execSync = function(command, options) {
                const tokens = tokenise(command);
                if (tokens.length && pythonKind(tokens[0])) return syncBlocked("buffer");
                return original.execSync.apply(this, arguments);
              };
              console.error("[NATIVE-PYTHON] child_process bridge installed for python/python3/pip");
            };
            installNativePythonBridge();
            try {
              Object.defineProperty(os, "tmpdir", {
                value: () => nativeTmp,
                configurable: true
              });
              Object.defineProperty(os, "homedir", {
                value: () => nativeHome,
                configurable: true
              });
              syncBuiltinESMExports();
            } catch (error) {
              process.stderr.write(
                `[NATIVE-NODE-FULL-GATEWAY] failed to patch os paths: ${'$'}{
                  error?.stack || error?.message || String(error)
                }\n`
              );
            }

            process.chdir(packageDir);
            process.argv = [
              process.argv[0] || "plawie-native-node",
              launcherPath,
              "gateway",
              "run",
              "--port",
              String(port),
              "--bind",
              "loopback",
              "--allow-unconfigured",
              "--verbose"
            ];

            const bootstrapMarker = path.join(nativeStateDir, "native-full-gateway-bootstrap.json");
            const bootstrapStdioLog = path.join(
              nativeStateDir,
              "native-full-gateway-bootstrap-stdio.log"
            );
            const formatError = (error) => error?.stack || error?.message || String(error);
            const appendBootstrapLog = (line) => {
              try {
                fs.appendFileSync(bootstrapStdioLog, `[${'$'}{new Date().toISOString()}] ${'$'}{line}\n`);
              } catch {
                // Keep diagnostics best-effort so logging never breaks startup.
              }
            };
            const writeBootstrapMarker = (stage, extra = {}) => {
              try {
                fs.writeFileSync(bootstrapMarker, JSON.stringify({
                  phase: "full-gateway-bootstrap",
                  openclawStarted: stage,
                  fullSkillRegistryLoaded: "pending",
                  chatRoutingEnabled: "pending",
                  host,
                  port,
                  canaryMode,
                  packageDir,
                  launcherPath,
                  mobileRunMainPath,
                  manifestPath,
                  nativeConfigStatus,
                  nativeManagedPaths: {
                    bin: nativeManagedBin,
                    pythonHome: nativePythonRoot,
                    pythonBin: nativePythonBin,
                    pythonSitePackages: nativePythonSitePackages,
                    path: process.env.PATH,
                    pythonPath: process.env.PYTHONPATH
                  },
                  argv: process.argv.slice(1),
                  node: process.version,
                  platform: process.platform,
                  arch: process.arch,
                  updatedAt: new Date().toISOString(),
                  ...extra
                }, null, 2));
              } catch {
                // Marker updates are diagnostic only.
              }
            };
            const wrapWritableStream = (stream, name) => {
              const originalWrite = stream.write.bind(stream);
              stream.write = (chunk, encoding, callback) => {
                const text = Buffer.isBuffer(chunk) ? chunk.toString("utf8") : String(chunk);
                if (text.includes("[gateway] http server listening")) {
                  writeBootstrapMarker("http-listening", { httpListeningAt: new Date().toISOString() });
                }
                if (text.includes("[gateway] ready")) {
                  writeBootstrapMarker("gateway-ready", { readyAt: new Date().toISOString() });
                }
                appendBootstrapLog(`${'$'}{name}: ${'$'}{text.replace(/\s+${'$'}/, "")}`);
                return originalWrite(chunk, encoding, callback);
              };
            };

            writeBootstrapMarker("launching", { startedAt: new Date().toISOString() });
            fs.writeFileSync(bootstrapStdioLog, "");
            wrapWritableStream(process.stdout, "stdout");
            wrapWritableStream(process.stderr, "stderr");
            process.on("warning", (warning) => {
              appendBootstrapLog(`warning: ${'$'}{formatError(warning)}`);
            });
            process.on("unhandledRejection", (reason) => {
              const message = formatError(reason);
              writeBootstrapMarker("unhandled-rejection", { error: message });
              appendBootstrapLog(`unhandledRejection: ${'$'}{message}`);
            });
            process.on("uncaughtException", (error) => {
              const message = formatError(error);
              writeBootstrapMarker("uncaught-exception", { error: message });
              appendBootstrapLog(`uncaughtException: ${'$'}{message}`);
            });
            const nativeOriginalExit = process.exit.bind(process);
            process.exit = (code = 0) => {
              writeBootstrapMarker("process-exit", { exitCode: code });
              appendBootstrapLog(`process.exit(${'$'}{code})`);
              return nativeOriginalExit(code);
            };

            console.error(`[NATIVE-NODE-FULL-GATEWAY] launching mobile-safe runCli gateway run on ${'$'}{host}:${'$'}{port}`);
            try {
              writeBootstrapMarker("before-run-main-import");
              const { runCli } = await import(pathToFileURL(mobileRunMainPath).href);
              writeBootstrapMarker("before-run-cli");
              await runCli(process.argv);
              writeBootstrapMarker("run-cli-returned");
            } catch (error) {
              const message = formatError(error);
              writeBootstrapMarker("caught-error", { error: message });
              console.error(`[NATIVE-NODE-FULL-GATEWAY] bootstrap failed: ${'$'}{message}`);
              throw error;
            }
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

    private fun appendStartIgnoredLog(message: String) {
        val now = SystemClock.elapsedRealtime()
        val previous = lastStartIgnoredMessage
        if (previous == message && now - lastStartIgnoredAtMs < 10_000L) {
            suppressedStartIgnoredCount += 1
            if (suppressedStartIgnoredCount == 1) {
                appendLog("$message; duplicate start requests suppressed")
            }
            return
        }

        if (suppressedStartIgnoredCount > 0 && previous != null) {
            appendLog(
                "startup duplicate summary; suppressed=$suppressedStartIgnoredCount " +
                    "last=\"$previous\""
            )
        }
        lastStartIgnoredMessage = message
        lastStartIgnoredAtMs = now
        suppressedStartIgnoredCount = 0
        appendLog(message)
    }
}
