package com.nxg.openclawproot

import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.File
import android.util.Log
import java.util.concurrent.TimeUnit

/**
 * Manages proot process execution, matching Termux proot-distro as closely
 * as possible. Two command modes:
 *   - Install mode (buildInstallCommand): matches proot-distro's run_proot_cmd()
 *   - Gateway mode (buildGatewayCommand): matches proot-distro's command_login()
 */
class ProcessManager(
    private val filesDir: String,
    private val nativeLibDir: String
) {
    private val rootfsDir get() = "$filesDir/rootfs/ubuntu"
    private val tmpDir get() = "$filesDir/tmp"
    private val homeDir get() = "$filesDir/home"
    private val configDir get() = "$filesDir/config"
    private val libDir get() = "$filesDir/lib"
    private val logFile get() = File("$rootfsDir/root/.openclaw/gateway.log")

    private var logSink: io.flutter.plugin.common.EventChannel.EventSink? = null
    private var logThread: Thread? = null
    private val logRingBuffer = java.util.concurrent.ConcurrentLinkedDeque<String>()
    private val MAX_LOG_LINES = 1000

    companion object {
        // Match proot-distro v4.37.0 defaults
        const val FAKE_KERNEL_RELEASE = "6.17.0-PRoot-Distro"
        const val FAKE_KERNEL_VERSION =
            "#1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000"
    }

    fun getProotPath(): String = "$nativeLibDir/libproot.so"

    // ================================================================
    // Host-side environment for proot binary itself.
    // ONLY proot-specific vars — guest env is set via `env -i` inside
    // the command line, matching proot-distro's approach.
    // ================================================================
    private fun prootEnv(): Map<String, String> = mapOf(
        // proot temp directory for its internal use
        "PROOT_TMP_DIR" to tmpDir,
        // Loader executables for proot's execve interception
        "PROOT_LOADER" to "$nativeLibDir/libprootloader.so",
        "PROOT_LOADER_32" to "$nativeLibDir/libprootloader32.so",
        // LD_LIBRARY_PATH: proot itself needs libtalloc.so.2
        // This does NOT leak into the guest (env -i cleans it)
        "LD_LIBRARY_PATH" to "$libDir:$nativeLibDir",
        // NOTE: Do NOT set PROOT_NO_SECCOMP. proot-distro does NOT set it.
        // Seccomp BPF filter provides efficient syscall interception AND
        // proper fork/clone child process tracking.
        //
        // NOTE: Do NOT set PROOT_L2S_DIR. We extract with Java, not
        // `proot --link2symlink tar`, so no L2S metadata exists.
    )

    // ================================================================
    // Common proot flags shared by both install and gateway modes.
    // Matches proot-distro's bind mounts exactly.
    // ================================================================
    private fun commonProotFlags(): List<String> {
        val prootPath = getProotPath()
        val procFakes = "$configDir/proc_fakes"
        val sysFakes = "$configDir/sys_fakes"

        val flags = mutableListOf(
            prootPath,
            "--link2symlink",
            "-L",
            "--kill-on-exit",
            "--rootfs=$rootfsDir",
            "--cwd=/root",
            // Core device binds (matching proot-distro)
            "--bind=/dev",
            "--bind=/dev/urandom:/dev/random",
            "--bind=/proc",
            "--bind=/proc/self/fd:/dev/fd",
            "--bind=/proc/self/fd/0:/dev/stdin",
            "--bind=/proc/self/fd/1:/dev/stdout",
            "--bind=/proc/self/fd/2:/dev/stderr",
            "--bind=/sys",
            // Fake /proc entries — Android restricts most /proc access.
            // proot-distro's run_proot_cmd() binds these unconditionally.
            "--bind=$procFakes/loadavg:/proc/loadavg",
            "--bind=$procFakes/stat:/proc/stat",
            "--bind=$procFakes/uptime:/proc/uptime",
            "--bind=$procFakes/version:/proc/version",
            "--bind=$procFakes/vmstat:/proc/vmstat",
            "--bind=$procFakes/cap_last_cap:/proc/sys/kernel/cap_last_cap",
            "--bind=$procFakes/max_user_watches:/proc/sys/fs/inotify/max_user_watches",
            // Extra: libgcrypt reads this; missing causes apt SIGABRT
            "--bind=$procFakes/fips_enabled:/proc/sys/crypto/fips_enabled",
            // Shared memory — proot-distro binds rootfs/tmp to /dev/shm
            "--bind=$rootfsDir/tmp:/dev/shm",
            // SELinux override — empty dir disables SELinux checks
            "--bind=$sysFakes/empty:/sys/fs/selinux",
            // App-specific binds
            "--bind=$configDir/resolv.conf:/etc/resolv.conf",
            "--bind=$homeDir:/root/home",
            "--bind=$rootfsDir:$rootfsDir",
        )

        // Model directory bind: models are stored at $filesDir/rootfs/root/.openclaw/models
        // (outside the ubuntu rootfs at $filesDir/rootfs/ubuntu/) so they need an explicit
        // bind mount to be visible at /root/.openclaw/models inside PRoot. Without this,
        // Ollama's HTTP create API returns "invalid model name" (misleading error for file not found).
        val modelsHostDir = java.io.File("$filesDir/rootfs/root/.openclaw/models")
        modelsHostDir.mkdirs() // ensure host dir exists before binding
        flags.add("--bind=${modelsHostDir.absolutePath}:/root/.openclaw/models")

        // GPU and Hardware Acceleration bindings (conditional — only bind if device exists)
        for (path in listOf("/dev/kgsl-3d0", "/dev/mali0", "/dev/dri")) {
            if (java.io.File(path).exists()) flags.add("--bind=$path:$path")
        }
        if (java.io.File("/vendor").exists()) flags.add("--bind=/vendor:/vendor")
        if (java.io.File("/system/lib64").exists()) flags.add("--bind=/system/lib64:/system/lib64")

        return flags
    }

    // ================================================================
    // INSTALL MODE — matches proot-distro's run_proot_cmd()
    // Used for: apt-get, dpkg, npm install, chmod, etc.
    // Simpler: no --sysvipc, simple kernel-release, minimal guest env.
    // ================================================================
    fun buildInstallCommand(command: String): List<String> {
        val flags = commonProotFlags().toMutableList()

        // --root-id: fake root identity (same as proot-distro run_proot_cmd)
        flags.add(1, "--root-id")
        // Simple kernel-release (proot-distro run_proot_cmd uses plain string)
        flags.add(2, "--kernel-release=$FAKE_KERNEL_RELEASE")
        // NOTE: --sysvipc is NOT used during install (matches proot-distro).
        // It causes SIGABRT when dpkg forks child processes.

        // Guest environment via env -i (matching proot-distro's run_proot_cmd)
        flags.addAll(listOf(
            "/usr/bin/env", "-i",
            "HOME=/root",
            "LANG=C.UTF-8",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "TERM=xterm-256color",
            "TMPDIR=/tmp",
            "DEBIAN_FRONTEND=noninteractive",
            // npm cache location (mkdir broken in proot, pre-created by Java)
            "npm_config_cache=/tmp/npm-cache",
            "/bin/bash", "-c",
            command,
        ))

        return flags
    }

    // ================================================================
    // GATEWAY MODE — matches proot-distro's command_login()
    // Used for: running openclaw gateway (long-lived Node.js process).
    // Full featured: --sysvipc, full uname struct, more guest env vars.
    // ================================================================
    fun buildGatewayCommand(command: String): List<String> {
        val flags = commonProotFlags().toMutableList()
        val arch = ArchUtils.getArch()
        // Map to uname -m format
        val machine = when (arch) {
            "arm" -> "armv7l"
            else -> arch // aarch64, x86_64, x86
        }

        // --change-id=0:0 (proot-distro command_login uses this for root)
        flags.add(1, "--change-id=0:0")
        // --sysvipc: enable SysV IPC (proot-distro enables for login sessions)
        flags.add(2, "--sysvipc")
        // Full uname struct format (matching proot-distro command_login)
        // Format: \sysname\nodename\release\version\machine\domainname\personality\
        val kernelRelease = "\\Linux\\localhost\\$FAKE_KERNEL_RELEASE" +
            "\\$FAKE_KERNEL_VERSION\\$machine\\localdomain\\-1\\"
        flags.add(3, "--kernel-release=$kernelRelease")

        val nodeOptions = "--require /root/.openclaw/bionic-bypass.js"

        // Guest environment via env -i (matching proot-distro command_login)
        flags.addAll(listOf(
            "/usr/bin/env", "-i",
            "HOME=/root",
            "USER=root",
            "LANG=C.UTF-8",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "TERM=xterm-256color",
            "TMPDIR=/tmp",
            "NODE_OPTIONS=$nodeOptions",
            "CHOKIDAR_USEPOLLING=true",
            "NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt",
            "UV_USE_IO_URING=0",
            "/bin/bash", "-c",
            command,
        ))

        return flags
    }

    // Backward compatibility alias
    fun buildProotCommand(command: String): List<String> = buildInstallCommand(command)

    // ================================================================
    // Execute a command in proot (install mode) and return output.
    // Used during bootstrap for apt, npm, chmod, etc.
    // ================================================================
    fun runInProotSync(command: String, timeoutSeconds: Long = 900): String {
        val cmd = buildInstallCommand(command)
        val env = prootEnv()

        val pb = ProcessBuilder(cmd)
        // CRITICAL: Clear inherited Android JVM environment.
        // Without this, LD_PRELOAD, CLASSPATH, DEX2OAT vars leak into
        // proot and break fork+exec. proot-distro uses `env -i` on the
        // guest side AND runs from a clean Termux shell on the host side.
        // We must explicitly clear() since Android's ProcessBuilder
        // inherits the full JVM environment.
        pb.environment().clear()
        pb.environment().putAll(env)
        pb.redirectErrorStream(true)

        val process = pb.start()
        val output = StringBuilder()
        val errorLines = StringBuilder()
        val reader = BufferedReader(InputStreamReader(process.inputStream))

        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val l = line ?: continue
            if (l.contains("proot warning") || l.contains("can't sanitize")) {
                continue
            }
            output.appendLine(l)
            // Collect error-relevant lines (skip apt download noise)
            if (!l.startsWith("Get:") && !l.startsWith("Fetched ") &&
                !l.startsWith("Hit:") && !l.startsWith("Ign:") &&
                !l.contains(" kB]") && !l.contains(" MB]") &&
                !l.startsWith("Reading package") && !l.startsWith("Building dependency") &&
                !l.startsWith("Reading state") && !l.startsWith("The following") &&
                !l.startsWith("Need to get") && !l.startsWith("After this") &&
                l.trim().isNotEmpty()) {
                errorLines.appendLine(l)
            }
        }

        val exited = process.waitFor(timeoutSeconds, java.util.concurrent.TimeUnit.SECONDS)
        if (!exited) {
            process.destroyForcibly()
            throw RuntimeException("Command timed out after ${timeoutSeconds}s")
        }

        val exitCode = process.exitValue()
        if (exitCode != 0) {
            val errorOutput = errorLines.toString().takeLast(3000).ifEmpty {
                output.toString().takeLast(3000)
            }
            throw RuntimeException(
                "Command failed (exit code $exitCode): $errorOutput"
            )
        }

        return output.toString()
    }

    // ================================================================
    // Start a long-lived gateway process (gateway mode).
    // Uses full proot-distro command_login() style configuration.
    // ================================================================
    fun startProotProcess(command: String): Process {
        val cmd = buildGatewayCommand(command)
        val env = prootEnv()

        val pb = ProcessBuilder(cmd)
        pb.environment().clear()
        pb.environment().putAll(env)
        pb.redirectErrorStream(false)

        return pb.start()
    }

    // ================================================================
    // High-level Gateway Management (direct execution like openclaw-termux)
    // matches original upstream implementation for maximum compatibility.
    // ================================================================

    fun startGateway(): Boolean {
        // Direct execution matching openclaw-termux upstream.
        // NODE_OPTIONS is already injected by buildGatewayCommand() env vars,
        // so we don't need to export it again in the shell command.
        // Redirect stdout/stderr to gateway.log so the log streaming thread
        // can pick up output (including the dashboard token URL).
        val gatewayCmd = "mkdir -p /root/.openclaw && openclaw gateway --verbose > /root/.openclaw/gateway.log 2>&1"
        
        return try {
            android.util.Log.i("ProcessManager", "Starting gateway (output → gateway.log)")
            val fullCmd = buildGatewayCommand(gatewayCmd)
            val pb = ProcessBuilder(fullCmd)
            pb.environment().clear()
            pb.environment().putAll(prootEnv())
            pb.start()
            // Process is backgrounded (&) so bash exits immediately.
            // The health check in GatewayService will verify the gateway is up.
            startLogStreaming(null)
            true
        } catch (e: Exception) {
            android.util.Log.e("ProcessManager", "Failed to start gateway", e)
            false
        }
    }

    fun stopGateway(): Boolean {
        // Original approach: Kill openclaw gateway process directly
        return try {
            val stopCmd = "pkill -f 'openclaw gateway' || true"
            val fullCmd = buildGatewayCommand(stopCmd)
            val pb = ProcessBuilder(fullCmd)
            pb.environment().clear()
            pb.environment().putAll(prootEnv())
            pb.start().waitFor()
            stopLogStreaming()
            true
        } catch (e: Exception) {
            android.util.Log.e("ProcessManager", "Failed to stop gateway", e)
            false
        }
    }

    fun isGatewayRunning(): Boolean {
        // Original approach: Check if openclaw gateway process is running
        return try {
            val checkCmd = "pgrep -f 'openclaw gateway' > /dev/null 2>&1"
            val fullCmd = buildGatewayCommand(checkCmd)
            val pb = ProcessBuilder(fullCmd)
            pb.environment().clear()
            pb.environment().putAll(prootEnv())
            val process = pb.start()
            process.waitFor()
            process.exitValue() == 0
        } catch (e: Exception) {
            false
        }
    }

    fun getRecentLogs(): String {
        return if (logRingBuffer.isNotEmpty()) {
            logRingBuffer.joinToString("\n")
        } else {
            try {
                if (logFile.exists()) {
                    logFile.readLines().takeLast(200).joinToString("\n")
                } else {
                    "Logs not found at ${logFile.absolutePath}"
                }
            } catch (e: Exception) {
                "Error reading logs: ${e.message}"
            }
        }
    }

    fun startLogStreaming(sink: io.flutter.plugin.common.EventChannel.EventSink?) {
        if (sink != null) logSink = sink
        
        if (logThread?.isAlive == true) return
        
        logThread = Thread {
            var lastPosition = 0L
            try {
                while (!Thread.currentThread().isInterrupted) {
                    if (logFile.exists()) {
                        val currentLength = logFile.length()
                        if (currentLength > lastPosition) {
                            logFile.inputStream().use { input ->
                                input.skip(lastPosition)
                                val newBytes = input.readBytes()
                                if (newBytes.isNotEmpty()) {
                                    val newContent = String(newBytes)
                                    newContent.split("\n").forEach { line ->
                                        if (line.isNotEmpty()) {
                                            logRingBuffer.addLast(line)
                                            while (logRingBuffer.size > MAX_LOG_LINES) {
                                                logRingBuffer.pollFirst()
                                            }
                                            logSink?.let { s ->
                                                // We need to return to UI thread for Flutter
                                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                                    try { s.success(line) } catch (_: Exception) {}
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            lastPosition = currentLength
                        }
                    } else {
                        // Reset if file was deleted
                        lastPosition = 0L
                    }
                    Thread.sleep(1000)
                }
            } catch (e: Exception) {
                android.util.Log.e("ProcessManager", "Log streaming error", e)
            }
        }.apply { start() }
    }

    fun stopLogStreaming() {
        logThread?.interrupt()
        logThread = null
        logSink = null
    }

    fun startOllama(): Boolean {
        return try {
            android.util.Log.i("ProcessManager", "Starting internal Ollama server")
            // Ensure any existing instances are cleared first to avoid port collision
            stopOllama()
            
            // Start ollama as a separate process inside PRoot.
            // - OLLAMA_HOST=127.0.0.1:11434 ensures accessibility across PRoot namespaces securely.
            // - OLLAMA_ORIGINS=* ensures the Flutter client can connect across the bridge.
            // - OLLAMA_KEEP_ALIVE=-1 keeps the model in memory indefinitely (no eviction after 5 min idle).
            //   Without this, every request after the eviction window triggers a 10–30s reload, pushing
            //   total request time past the 240s chat timeout on thermally throttled devices.
            // - OLLAMA_NUM_PARALLEL=1 prevents Ollama from loading multiple copies of the model for
            //   parallel requests — saves ~1.5 GB RAM on mobile (only one request at a time anyway).
            val ollamaCmd = "env OLLAMA_HOST=127.0.0.1:11434 OLLAMA_ORIGINS=\"*\" OLLAMA_KEEP_ALIVE=-1 OLLAMA_NUM_PARALLEL=1 OLLAMA_MAX_LOADED_MODELS=1 /usr/local/bin/ollama serve > /root/.openclaw/ollama.log 2>&1"
            val fullCmd = buildGatewayCommand(ollamaCmd)
            val pb = ProcessBuilder(fullCmd)
            pb.environment().clear()
            pb.environment().putAll(prootEnv())
            pb.start()
            true
        } catch (e: Exception) {
            android.util.Log.e("ProcessManager", "Failed to start Ollama", e)
            false
        }
    }

    fun stopOllama(): Boolean {
        return try {
            // Forcefully kill ollama and any related inference subprocesses
            val stopCmd = "pkill -9 -f '[o]llama' || true"
            val fullCmd = buildGatewayCommand(stopCmd)
            val pb = ProcessBuilder(fullCmd)
            pb.environment().clear()
            pb.environment().putAll(prootEnv())
            pb.start().waitFor()
            true
        } catch (e: Exception) {
            android.util.Log.e("ProcessManager", "Failed to stop Ollama", e)
            false
        }
    }

    fun isOllamaRunning(): Boolean {
        return try {
            // Check for any process with 'ollama' in the command line
            val checkCmd = "pgrep -f '[o]llama serve' > /dev/null 2>&1"
            val fullCmd = buildGatewayCommand(checkCmd)
            val pb = ProcessBuilder(fullCmd)
            pb.environment().clear()
            pb.environment().putAll(prootEnv())
            val process = pb.start()
            process.waitFor()
            process.exitValue() == 0
        } catch (e: Exception) {
            false
        }
    }
}
