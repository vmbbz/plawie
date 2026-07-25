package com.openclaw.plawie

import android.content.Context
import android.os.SystemClock
import android.util.Log
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.Base64
import java.util.UUID
import java.util.zip.GZIPInputStream

/**
 * Installs the OpenClaw core directly from the official upstream release.
 *
 * Plawie deliberately does not mirror or repackage the gateway. GitHub is the
 * release control plane: we resolve the latest stable release from
 * openclaw/openclaw, verify its published evidence files, then install the
 * exact npm tarball that upstream attests. The small npm CLI bootstrap is also
 * downloaded from npmjs and integrity-pinned here; it never ships in the APK.
 */
class OfficialOpenClawProvisioner(
    private val context: Context,
    private val onProgress: ((String, Double) -> Unit)? = null
) {
    data class NativePackageStatus(
        val ready: Boolean,
        val version: String?,
        val receiptVersion: String?,
        val receiptIntegrity: String?
    )

    private data class OfficialRelease(
        val version: String,
        val tag: String,
        val tarballUrl: String,
        val tarballIntegrity: String,
        val evidenceSha256: String,
        val releaseManifestSha256: String
    )

    private data class StagedRelease(
        val requestId: String?,
        val stagedAtEpochMs: Long,
        val release: OfficialRelease
    )

    private val filesDir: File
        get() = context.filesDir

    private val workDir: File
        get() = File(filesDir, NATIVE_WORK_DIR)

    private var lastReportedProgress = 0.0

    @Synchronized
    fun provisionLatest(requestId: String? = null): Map<String, Any> {
        if (NativeNodeBridge.running()) {
            throw IllegalStateException(
                "The native Node runtime is already running. Stop the gateway before provisioning OpenClaw."
            )
        }

        workDir.mkdirs()
        reportProgress("Resolving the latest official OpenClaw release…", 0.02)
        val release = resolveOfficialRelease()
        val existing = nativePackageStatus(context)
        if (
            existing.ready &&
                existing.version == release.version &&
                existing.receiptVersion == release.version &&
                existing.receiptIntegrity == release.tarballIntegrity
        ) {
            reportProgress(
                "Official OpenClaw " + release.version + " is already installed and verified.",
                0.98
            )
            return receiptMap(release, updated = false)
        }

        val staging = File(workDir, ".openclaw-install-" + UUID.randomUUID())
        val cacheDir = File(workDir, "npm-cache")
        try {
            staging.mkdirs()
            cacheDir.mkdirs()
            writeStagedRelease(staging, release, requestId)

            reportProgress(
                "Official release " + release.version +
                    " confirmed. Downloading its exact npm package once…",
                0.12
            )
            val archive = File(staging, "openclaw-" + release.version + ".tgz")
            downloadToFile(
                release.tarballUrl,
                archive,
                maxBytes = MAX_OPENCLAW_TARBALL_BYTES,
                onBytesCopied = { receivedBytes, totalBytes ->
                    val downloadFraction = if (totalBytes != null && totalBytes > 0L) {
                        0.15 + (0.40 * receivedBytes.toDouble() / totalBytes.toDouble())
                    } else {
                        0.16
                    }
                    reportProgress(
                        downloadProgressMessage(
                            "Downloading the official OpenClaw package",
                            receivedBytes,
                            totalBytes
                        ),
                        downloadFraction
                    )
                }
            )
            verifySha512Integrity(archive, release.tarballIntegrity)

            reportProgress("Official package integrity verified. Preparing npm…", 0.56)
            val npmCli = ensureNpmCli()
            val candidate = File(staging, "full-openclaw")
            installOfficialArchive(
                npmCli = npmCli,
                archive = archive,
                prefix = candidate,
                cacheDir = cacheDir
            )
            reportProgress(
                "npm completed. Verifying the installed OpenClaw package…",
                0.92
            )
            return activateVerifiedInstall(candidate, release)
        } finally {
            if (staging.exists()) {
                staging.deleteRecursively()
            }
        }
    }

    private fun activateVerifiedInstall(
        candidate: File,
        release: OfficialRelease
    ): Map<String, Any> {
        verifyInstalledPackage(candidate, release.version)
        writeReceipt(candidate, release)

        val target = File(workDir, FULL_GATEWAY_DIR)
        replaceDirectory(candidate, target)
        reportProgress(
            "Installed and verified official OpenClaw " + release.version +
                " from upstream release metadata.",
            0.99
        )
        return receiptMap(release, updated = true)
    }

    private fun receiptMap(release: OfficialRelease, updated: Boolean): Map<String, Any> {
        val packageDir = File(workDir, PACKAGE_RELATIVE_PATH)
        return mapOf(
            "installed" to true,
            "updated" to updated,
            "version" to release.version,
            "releaseTag" to release.tag,
            "source" to "official-openclaw-github-release",
            "packagePath" to packageDir.absolutePath,
            "integrity" to release.tarballIntegrity,
            "evidenceSha256" to release.evidenceSha256,
            "releaseManifestSha256" to release.releaseManifestSha256
        )
    }

    private fun resolveOfficialRelease(): OfficialRelease {
        val latest = JSONObject(
            downloadUtf8(
                OFFICIAL_LATEST_RELEASE_URL,
                maxBytes = MAX_METADATA_BYTES
            )
        )
        if (latest.optBoolean("draft", true) || latest.optBoolean("prerelease", true)) {
            throw IllegalStateException("OpenClaw latest GitHub release must be a stable published release.")
        }

        val tag = latest.optString("tag_name").trim()
        val version = tag.removePrefix("v")
        if (!VERSION_PATTERN.matches(version) || tag != "v" + version) {
            throw IllegalStateException("Unexpected official OpenClaw release tag: " + tag)
        }

        val assets = latest.optJSONArray("assets") ?: JSONArray()
        val evidenceName = "openclaw-" + version + "-postpublish-evidence.json"
        val evidenceShaName = evidenceName + ".sha256"
        val releaseManifestName = "openclaw-" + version + "-release-manifest.json"
        val releaseManifestShaName = releaseManifestName + ".sha256"
        val assetNames = mutableSetOf<String>()
        for (index in 0 until assets.length()) {
            val asset = assets.optJSONObject(index) ?: continue
            assetNames.add(asset.optString("name"))
        }
        for (required in listOf(
            evidenceName,
            evidenceShaName,
            releaseManifestName,
            releaseManifestShaName
        )) {
            if (!assetNames.contains(required)) {
                throw IllegalStateException(
                    "Official OpenClaw release " + tag + " is missing required asset " + required
                )
            }
        }

        val evidenceBytes = downloadBytes(
            officialReleaseAssetUrl(tag, evidenceName),
            maxBytes = MAX_METADATA_BYTES
        )
        val evidenceSha = parseSha256(
            downloadUtf8(
                officialReleaseAssetUrl(tag, evidenceShaName),
                maxBytes = MAX_METADATA_BYTES
            ),
            evidenceName
        )
        verifySha256(evidenceBytes, evidenceSha, evidenceName)

        val manifestBytes = downloadBytes(
            officialReleaseAssetUrl(tag, releaseManifestName),
            maxBytes = MAX_METADATA_BYTES
        )
        val manifestSha = parseSha256(
            downloadUtf8(
                officialReleaseAssetUrl(tag, releaseManifestShaName),
                maxBytes = MAX_METADATA_BYTES
            ),
            releaseManifestName
        )
        verifySha256(manifestBytes, manifestSha, releaseManifestName)

        val evidence = JSONObject(String(evidenceBytes, StandardCharsets.UTF_8))
        if (evidence.optString("releaseVersion") != version || evidence.optString("releaseTag") != tag) {
            throw IllegalStateException("Official OpenClaw evidence does not match release " + tag)
        }
        if (evidence.optString("npmDistTag") != "latest") {
            throw IllegalStateException("Official OpenClaw evidence is not for the latest npm release.")
        }
        if (!evidence.optBoolean("npmRegistrySignaturesVerified", false) ||
            !evidence.optBoolean("npmProvenanceAttestationMatched", false)
        ) {
            throw IllegalStateException(
                "Official OpenClaw release evidence did not verify npm signatures and provenance."
            )
        }

        val tarballUrl = evidence.optString("openclawNpmTarball").trim()
        val integrity = evidence.optString("openclawNpmIntegrity").trim()
        validateOfficialTarballUrl(tarballUrl, version)
        validateSha512Integrity(integrity)

        return OfficialRelease(
            version = version,
            tag = tag,
            tarballUrl = tarballUrl,
            tarballIntegrity = integrity,
            evidenceSha256 = evidenceSha,
            releaseManifestSha256 = manifestSha
        )
    }

    private fun ensureNpmCli(): File {
        val tooling = File(workDir, TOOLING_DIR)
        val npmDir = File(tooling, NPM_DIR)
        if (isNpmCliReady(npmDir)) {
            reportProgress("Official npm installer is ready.", 0.64)
            return File(npmDir, "bin/npm-cli.js")
        }

        tooling.mkdirs()
        val staging = File(tooling, ".npm-" + UUID.randomUUID())
        try {
            staging.mkdirs()
            val archive = File(staging, "npm.tgz")
            reportProgress("Downloading the pinned official npm installer…", 0.58)
            downloadToFile(
                NPM_CLI_TARBALL_URL,
                archive,
                maxBytes = MAX_NPM_TARBALL_BYTES,
                onBytesCopied = { receivedBytes, totalBytes ->
                    val downloadFraction = if (totalBytes != null && totalBytes > 0L) {
                        0.58 + (0.05 * receivedBytes.toDouble() / totalBytes.toDouble())
                    } else {
                        0.59
                    }
                    reportProgress(
                        downloadProgressMessage(
                            "Downloading the pinned official npm installer",
                            receivedBytes,
                            totalBytes
                        ),
                        downloadFraction
                    )
                }
            )
            verifySha512Integrity(archive, NPM_CLI_INTEGRITY)

            val extracted = File(staging, "extracted")
            extractTgz(archive, extracted, MAX_NPM_UNPACKED_BYTES)
            val packageRoot = File(extracted, "package")
            if (!isNpmCliReady(packageRoot)) {
                throw IllegalStateException("Official npm CLI archive did not contain npm " + NPM_CLI_VERSION)
            }
            replaceDirectory(packageRoot, npmDir)
            reportProgress("Official npm installer verified.", 0.64)
            return File(npmDir, "bin/npm-cli.js")
        } finally {
            if (staging.exists()) {
                staging.deleteRecursively()
            }
        }
    }

    private fun isNpmCliReady(root: File): Boolean {
        val cli = File(root, "bin/npm-cli.js")
        val packageJson = File(root, "package.json")
        if (!cli.isFile || !packageJson.isFile) return false
        return try {
            JSONObject(packageJson.readText()).optString("version") == NPM_CLI_VERSION
        } catch (_: Exception) {
            false
        }
    }

    private fun installOfficialArchive(
        npmCli: File,
        archive: File,
        prefix: File,
        cacheDir: File
    ) {
        prefix.mkdirs()
        val args = arrayOf(
            "plawie-native-node",
            npmCli.absolutePath,
            "install",
            "--global",
            archive.toURI().toString(),
            "--prefix",
            prefix.absolutePath,
            "--cache",
            cacheDir.absolutePath,
            "--registry=https://registry.npmjs.org",
            "--omit=dev",
            "--ignore-scripts",
            "--no-bin-links",
            "--no-audit",
            "--no-fund",
            "--no-update-notifier",
            "--install-strategy=nested",
            "--loglevel=warn"
        )
        reportProgress("Installing the verified official OpenClaw package with npm…", 0.66)
        val installStartedAtMs = System.currentTimeMillis()
        val started = NativeNodeBridge.start(args)
        if (started.code != 0) {
            throw IllegalStateException("Native npm installer could not start: " + started.message)
        }

        val deadline = SystemClock.elapsedRealtime() + NPM_INSTALL_TIMEOUT_MS
        var lastLivenessReportAtMs = 0L
        while (true) {
            // node::Start can retain Android process-global event-loop state
            // after npm has finished. npm's own durable debug record is the
            // authoritative completion signal; package layout is verified by
            // the caller before activation.
            val npmExitCode = npmExitCodeFromLogs(cacheDir, installStartedAtMs)
            if (npmExitCode != null) {
                if (npmExitCode == 0) {
                    reportProgress("npm reported exit 0. Validating installation…", 0.90)
                    return
                }
                throw IllegalStateException(
                    "Native npm installer reported exit code " + npmExitCode +
                        ". See the npm cache under " + cacheDir.absolutePath
                )
            }
            if (!NativeNodeBridge.running()) break
            if (SystemClock.elapsedRealtime() >= deadline) {
                throw IllegalStateException(
                    "Native npm installer timed out after " +
                        (NPM_INSTALL_TIMEOUT_MS / 60000L) + " minutes."
                )
            }
            val now = SystemClock.elapsedRealtime()
            if (now - lastLivenessReportAtMs >= NPM_LIVENESS_REPORT_INTERVAL_MS) {
                val elapsedMs = (System.currentTimeMillis() - installStartedAtMs).coerceAtLeast(0L)
                val boundedFraction = 0.68 +
                    minOf(0.18, 0.18 * elapsedMs.toDouble() / NPM_INSTALL_TIMEOUT_MS.toDouble())
                reportProgress(
                    "Installing the verified official OpenClaw package with npm (" +
                        (elapsedMs / 1000L).toString() +
                        " seconds elapsed)…",
                    boundedFraction
                )
                lastLivenessReportAtMs = now
            }
            Thread.sleep(250)
        }
        val exitCode = NativeNodeBridge.exitCode()
        if (exitCode != 0) {
            throw IllegalStateException(
                "Native npm installer failed with exit code " + exitCode +
                    ". See the npm cache under " + cacheDir.absolutePath
            )
        }
    }

    private fun npmExitCodeFromLogs(cacheDir: File, notBeforeMs: Long): Int? {
        val logsDir = File(cacheDir, "_logs")
        val logs = logsDir.listFiles()
            ?.filter {
                it.isFile &&
                    it.name.endsWith(".log") &&
                    it.lastModified() >= notBeforeMs - LOG_TIMESTAMP_SKEW_MS
            }
            ?.sortedByDescending { it.lastModified() }
            ?: return null

        for (log in logs) {
            val match = NPM_EXIT_CODE_PATTERN.findAll(readFileTail(log, MAX_NPM_LOG_TAIL_BYTES))
                .lastOrNull()
            if (match != null) return match.groupValues[1].toIntOrNull()
        }
        return null
    }

    private fun readFileTail(file: File, maxBytes: Int): String {
        RandomAccessFile(file, "r").use { reader ->
            val start = (reader.length() - maxBytes).coerceAtLeast(0L)
            reader.seek(start)
            val length = (reader.length() - start).toInt()
            val bytes = ByteArray(length)
            reader.readFully(bytes)
            return String(bytes, StandardCharsets.UTF_8)
        }
    }

    private fun reportProgress(message: String, progress: Double) {
        val boundedProgress = progress.coerceIn(0.0, 1.0)
        val monotonicProgress = maxOf(lastReportedProgress, boundedProgress)
        lastReportedProgress = monotonicProgress
        Log.i(TAG, message)
        runCatching { onProgress?.invoke(message, monotonicProgress) }
            .onFailure { error ->
                Log.w(TAG, "Could not report OpenClaw installation progress", error)
            }
    }

    /**
     * npm may call process.exit(0) from inside libnode. That can terminate the
     * dedicated installer process before Kotlin receives the normal native
     * callback. The npm debug log and app-private staging directory are
     * durable, so the Flutter-process waiter can safely finish activation
     * without downloading OpenClaw again.
     */
    @Synchronized
    fun recoverCompletedStagedInstall(requestId: String): Map<String, Any>? {
        val cacheDir = File(workDir, "npm-cache")
        val stagingDirectories = workDir.listFiles()
            ?.filter { file ->
                file.isDirectory && file.name.startsWith(STAGING_DIRECTORY_PREFIX)
            }
            ?.sortedByDescending { it.lastModified() }
            ?: return null

        for (staging in stagingDirectories) {
            val staged = readStagedRelease(staging) ?: continue
            if (staged.requestId != requestId) continue

            val npmExitCode = npmExitCodeFromLogs(cacheDir, staged.stagedAtEpochMs)
                ?: continue
            if (npmExitCode != 0) {
                throw IllegalStateException(
                    "Native npm installer reported exit code " + npmExitCode +
                        " before its isolated process exited."
                )
            }

            val candidate = File(staging, "full-openclaw")
            if (!candidate.isDirectory) {
                throw IllegalStateException(
                    "npm reported success, but the staged OpenClaw package is missing."
                )
            }

            reportProgress(
                "Recovering the verified official OpenClaw installation after npm completed…",
                0.93
            )
            val result = activateVerifiedInstall(candidate, staged.release)
            if (staging.exists()) {
                staging.deleteRecursively()
            }
            return result
        }
        return null
    }

    private fun writeStagedRelease(
        staging: File,
        release: OfficialRelease,
        requestId: String?
    ) {
        val payload = JSONObject()
            .put("schemaVersion", 1)
            .put("requestId", requestId ?: "")
            .put("stagedAtEpochMs", System.currentTimeMillis())
            .put("version", release.version)
            .put("tag", release.tag)
            .put("tarballUrl", release.tarballUrl)
            .put("tarballIntegrity", release.tarballIntegrity)
            .put("evidenceSha256", release.evidenceSha256)
            .put("releaseManifestSha256", release.releaseManifestSha256)
        File(staging, STAGED_RELEASE_FILE).writeText(payload.toString())
    }

    private fun readStagedRelease(staging: File): StagedRelease? {
        val file = File(staging, STAGED_RELEASE_FILE)
        if (!file.isFile) return null
        return try {
            val payload = JSONObject(file.readText())
            val version = payload.optString("version").trim()
            val tag = payload.optString("tag").trim()
            val tarballUrl = payload.optString("tarballUrl").trim()
            val tarballIntegrity = payload.optString("tarballIntegrity").trim()
            val evidenceSha256 = payload.optString("evidenceSha256").trim()
            val releaseManifestSha256 = payload.optString("releaseManifestSha256").trim()
            if (
                version.isEmpty() || tag.isEmpty() || tarballUrl.isEmpty() ||
                    tarballIntegrity.isEmpty() || evidenceSha256.isEmpty() ||
                    releaseManifestSha256.isEmpty()
            ) {
                null
            } else {
                StagedRelease(
                    requestId = payload.optString("requestId").trim().ifBlank { null },
                    stagedAtEpochMs = payload.optLong(
                        "stagedAtEpochMs",
                        staging.lastModified()
                    ),
                    release = OfficialRelease(
                        version = version,
                        tag = tag,
                        tarballUrl = tarballUrl,
                        tarballIntegrity = tarballIntegrity,
                        evidenceSha256 = evidenceSha256,
                        releaseManifestSha256 = releaseManifestSha256
                    )
                )
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun verifyInstalledPackage(prefix: File, expectedVersion: String) {
        val packageDir = File(prefix, PACKAGE_RELATIVE_PATH)
        val packageJson = File(packageDir, "package.json")
        val launcher = File(packageDir, "openclaw.mjs")
        val runMain = File(packageDir, "dist/cli/run-main.js")
        val typebox = File(packageDir, "node_modules/typebox/package.json")
        if (!packageJson.isFile || !launcher.isFile || !runMain.isFile || !typebox.isFile) {
            throw IllegalStateException(
                "Official OpenClaw install is incomplete. Expected package, launcher, CLI, and typebox files."
            )
        }
        val installedVersion = try {
            JSONObject(packageJson.readText()).optString("version")
        } catch (error: Exception) {
            throw IllegalStateException("Installed OpenClaw package.json is unreadable.", error)
        }
        if (installedVersion != expectedVersion) {
            throw IllegalStateException(
                "Official OpenClaw version mismatch: expected " + expectedVersion +
                    ", found " + installedVersion
            )
        }
    }

    private fun writeReceipt(prefix: File, release: OfficialRelease) {
        val receipt = JSONObject()
            .put("schemaVersion", 1)
            .put("source", "official-openclaw-github-release")
            .put("version", release.version)
            .put("releaseTag", release.tag)
            .put("tarballUrl", release.tarballUrl)
            .put("tarballIntegrity", release.tarballIntegrity)
            .put("evidenceSha256", release.evidenceSha256)
            .put("releaseManifestSha256", release.releaseManifestSha256)
            .put("installedAtEpochMs", System.currentTimeMillis())
        val destination = File(prefix, INSTALL_RECEIPT)
        val temporary = File(destination.parentFile, destination.name + ".tmp")
        temporary.writeText(receipt.toString())
        if (!temporary.renameTo(destination)) {
            destination.writeText(receipt.toString())
            temporary.delete()
        }
    }

    private fun replaceDirectory(candidate: File, target: File) {
        if (!candidate.isDirectory) {
            throw IllegalArgumentException("Candidate directory does not exist: " + candidate.absolutePath)
        }
        val backup = File(
            target.parentFile,
            "." + target.name + ".backup-" + UUID.randomUUID()
        )
        var movedOld = false
        try {
            if (target.exists()) {
                if (!target.renameTo(backup)) {
                    throw IllegalStateException("Could not prepare previous native OpenClaw install for replacement.")
                }
                movedOld = true
            }
            if (!candidate.renameTo(target)) {
                throw IllegalStateException("Could not activate verified native OpenClaw install.")
            }
            if (backup.exists()) backup.deleteRecursively()
        } catch (error: Exception) {
            if (!target.exists() && movedOld && backup.exists()) {
                backup.renameTo(target)
            }
            throw error
        }
    }

    private fun extractTgz(archive: File, destination: File, maxUnpackedBytes: Long) {
        destination.mkdirs()
        var totalBytes = 0L
        TarArchiveInputStream(
            GZIPInputStream(BufferedInputStream(FileInputStream(archive)))
        ).use { tar ->
            while (true) {
                val entry = tar.nextTarEntry ?: break
                val name = normalizeTarEntryName(entry.name)
                    ?: throw IllegalStateException("Unsafe archive entry in npm CLI bootstrap.")
                if (entry.isSymbolicLink || entry.isLink) {
                    throw IllegalStateException("Refusing link entry in npm CLI bootstrap: " + name)
                }
                val output = safeArchiveDestination(destination, name)
                when {
                    entry.isDirectory -> output.mkdirs()
                    entry.isFile -> {
                        output.parentFile?.mkdirs()
                        FileOutputStream(output).use { destinationStream ->
                            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                            while (true) {
                                val read = tar.read(buffer)
                                if (read <= 0) break
                                totalBytes += read.toLong()
                                if (totalBytes > maxUnpackedBytes) {
                                    throw IllegalStateException("npm CLI archive exceeds unpacked size limit.")
                                }
                                destinationStream.write(buffer, 0, read)
                            }
                        }
                        output.setExecutable((entry.mode and EXECUTABLE_MODE_MASK) != 0, false)
                    }
                    else -> throw IllegalStateException("Unsupported npm CLI archive entry: " + name)
                }
            }
        }
    }

    private fun downloadBytes(url: String, maxBytes: Long): ByteArray {
        val temporary = File.createTempFile("plawie-download-", ".bin", context.cacheDir)
        return try {
            downloadToFile(url, temporary, maxBytes)
            temporary.readBytes()
        } finally {
            temporary.delete()
        }
    }

    private fun downloadUtf8(url: String, maxBytes: Long): String {
        return String(downloadBytes(url, maxBytes), StandardCharsets.UTF_8)
    }

    private fun downloadToFile(
        url: String,
        destination: File,
        maxBytes: Long,
        onBytesCopied: ((Long, Long?) -> Unit)? = null
    ) {
        destination.parentFile?.mkdirs()
        val connection = openSecureConnection(url)
        try {
            val contentLength = connection.contentLengthLong
            if (contentLength > maxBytes) {
                throw IllegalStateException("Download is larger than the allowed limit.")
            }
            val expectedBytes = contentLength.takeIf { it >= 0L }
            onBytesCopied?.invoke(0L, expectedBytes)
            connection.inputStream.use { input ->
                FileOutputStream(destination).use { output ->
                    copyBounded(
                        input,
                        output,
                        maxBytes,
                        expectedBytes,
                        onBytesCopied
                    )
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun openSecureConnection(url: String): HttpURLConnection {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = true
        connection.connectTimeout = CONNECT_TIMEOUT_MS
        connection.readTimeout = READ_TIMEOUT_MS
        connection.setRequestProperty("User-Agent", USER_AGENT)
        connection.setRequestProperty("Accept", "application/json, application/octet-stream;q=0.9, */*;q=0.1")
        val code = connection.responseCode
        val finalUrl = connection.url
        if (finalUrl.protocol.lowercase() != "https") {
            connection.disconnect()
            throw IllegalStateException("Refusing non-HTTPS upstream download.")
        }
        if (code !in 200..299) {
            val body = try {
                connection.errorStream?.bufferedReader()?.use { it.readText().take(240) }
            } catch (_: Exception) {
                null
            }
            connection.disconnect()
            throw IllegalStateException(
                "Upstream download failed with HTTP " + code +
                    if (body.isNullOrBlank()) "." else ": " + body
            )
        }
        return connection
    }

    private fun copyBounded(
        input: InputStream,
        output: FileOutputStream,
        maxBytes: Long,
        expectedBytes: Long?,
        onBytesCopied: ((Long, Long?) -> Unit)?
    ) {
        var total = 0L
        var lastReportedAtMs = 0L
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val count = input.read(buffer)
            if (count <= 0) break
            total += count.toLong()
            if (total > maxBytes) {
                throw IllegalStateException("Download exceeds allowed size limit.")
            }
            output.write(buffer, 0, count)
            val now = SystemClock.elapsedRealtime()
            if (
                onBytesCopied != null &&
                    (lastReportedAtMs == 0L ||
                        now - lastReportedAtMs >= DOWNLOAD_PROGRESS_REPORT_INTERVAL_MS ||
                        (expectedBytes != null && total >= expectedBytes))
            ) {
                onBytesCopied.invoke(total, expectedBytes)
                lastReportedAtMs = now
            }
        }
    }

    private fun downloadProgressMessage(
        label: String,
        receivedBytes: Long,
        totalBytes: Long?
    ): String {
        if (totalBytes != null && totalBytes > 0L) {
            val percent = ((receivedBytes * 100L) / totalBytes).coerceIn(0L, 100L)
            return label + " " + percent.toString() + "% (" +
                formatByteCount(receivedBytes) + " / " + formatByteCount(totalBytes) + ")…"
        }
        return label + " (" + formatByteCount(receivedBytes) + ")…"
    }

    private fun formatByteCount(bytes: Long): String {
        val megabyte = 1024L * 1024L
        return if (bytes >= megabyte) {
            (bytes / megabyte).toString() + " MB"
        } else {
            (bytes / 1024L).toString() + " KB"
        }
    }

    private fun parseSha256(raw: String, expectedName: String): String {
        val line = raw.lineSequence().firstOrNull {
            val fields = it.trim().split(Regex("\\s+"))
            fields.size >= 2 && fields.last() == expectedName
        } ?: throw IllegalStateException("Checksum for " + expectedName + " was not found.")
        val hash = line.trim().split(Regex("\\s+")).first()
        if (!SHA256_PATTERN.matches(hash)) {
            throw IllegalStateException("Malformed SHA-256 checksum for " + expectedName)
        }
        return hash.lowercase()
    }

    private fun verifySha256(bytes: ByteArray, expectedHex: String, label: String) {
        val actual = MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { byte -> "%02x".format(byte) }
        if (!actual.equals(expectedHex, ignoreCase = true)) {
            throw IllegalStateException("SHA-256 verification failed for " + label)
        }
    }

    private fun validateOfficialTarballUrl(value: String, version: String) {
        val uri = try {
            URI(value)
        } catch (error: Exception) {
            throw IllegalStateException("Official OpenClaw evidence has an invalid npm tarball URL.", error)
        }
        val expectedPath = "/openclaw/-/openclaw-" + version + ".tgz"
        if (
            uri.scheme != "https" ||
                uri.host != "registry.npmjs.org" ||
                uri.path != expectedPath ||
                uri.query != null ||
                uri.fragment != null
        ) {
            throw IllegalStateException("Official OpenClaw evidence points outside the npm registry.")
        }
    }

    private fun validateSha512Integrity(value: String) {
        if (!value.startsWith("sha512-")) {
            throw IllegalStateException("Official OpenClaw evidence has no SHA-512 integrity value.")
        }
        try {
            if (Base64.getDecoder().decode(value.removePrefix("sha512-")).size != 64) {
                throw IllegalStateException("Official OpenClaw evidence has an invalid SHA-512 integrity value.")
            }
        } catch (error: IllegalArgumentException) {
            throw IllegalStateException("Official OpenClaw evidence has an invalid SHA-512 integrity value.", error)
        }
    }

    private fun verifySha512Integrity(file: File, expectedIntegrity: String) {
        validateSha512Integrity(expectedIntegrity)
        val expected = Base64.getDecoder().decode(expectedIntegrity.removePrefix("sha512-"))
        val digest = MessageDigest.getInstance("SHA-512")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count <= 0) break
                digest.update(buffer, 0, count)
            }
        }
        if (!MessageDigest.isEqual(expected, digest.digest())) {
            throw IllegalStateException("SHA-512 integrity verification failed for " + file.name)
        }
    }

    private fun normalizeTarEntryName(value: String): String? {
        val normalized = value.replace('\\', '/').removePrefix("./").trim()
        if (
            normalized.isEmpty() ||
                normalized.startsWith("/") ||
                normalized == ".." ||
                normalized.contains("../") ||
                normalized.contains(":")
        ) {
            return null
        }
        return normalized
    }

    private fun safeArchiveDestination(root: File, relativePath: String): File {
        val rootCanonical = root.canonicalFile
        val child = File(rootCanonical, relativePath).canonicalFile
        val rootPrefix = rootCanonical.path + File.separator
        if (child != rootCanonical && !child.path.startsWith(rootPrefix)) {
            throw IllegalStateException("Archive entry escapes destination: " + relativePath)
        }
        return child
    }

    private fun officialReleaseAssetUrl(tag: String, asset: String): String {
        return "https://github.com/openclaw/openclaw/releases/download/" + tag + "/" + asset
    }

    companion object {
        private const val TAG = "OfficialOpenClaw"
        private const val NATIVE_WORK_DIR = "native-node-embedded"
        private const val FULL_GATEWAY_DIR = "full-openclaw"
        private const val PACKAGE_RELATIVE_PATH = "lib/node_modules/openclaw"
        private const val INSTALL_RECEIPT = "plawie-upstream-install.json"
        private const val TOOLING_DIR = "tooling"
        private const val NPM_DIR = "npm"
        private const val NPM_CLI_VERSION = "10.9.2"
        private const val NPM_CLI_TARBALL_URL =
            "https://registry.npmjs.org/npm/-/npm-10.9.2.tgz"
        private const val NPM_CLI_INTEGRITY =
            "sha512-iriPEPIkoMYUy3F6f3wwSZAU93E0Eg6cHwIR6jzzOXWSy+SD/rOODEs74cVONHKSx2obXtuUoyidVEhISrisgQ=="
        private const val OFFICIAL_LATEST_RELEASE_URL =
            "https://api.github.com/repos/openclaw/openclaw/releases/latest"
        private const val USER_AGENT = "Plawie-Android-Upstream-Installer"
        private const val CONNECT_TIMEOUT_MS = 20_000
        private const val READ_TIMEOUT_MS = 45_000
        private const val NPM_INSTALL_TIMEOUT_MS = 20L * 60L * 1000L
        private const val NPM_LIVENESS_REPORT_INTERVAL_MS = 2_000L
        private const val DOWNLOAD_PROGRESS_REPORT_INTERVAL_MS = 350L
        private const val ISOLATED_PROVISION_WAIT_GRACE_MS = 2L * 60L * 1000L
        private const val MAX_METADATA_BYTES = 2L * 1024L * 1024L
        private const val MAX_NPM_TARBALL_BYTES = 24L * 1024L * 1024L
        private const val MAX_NPM_UNPACKED_BYTES = 160L * 1024L * 1024L
        private const val MAX_OPENCLAW_TARBALL_BYTES = 256L * 1024L * 1024L
        private const val MAX_NPM_LOG_TAIL_BYTES = 128 * 1024
        private const val LOG_TIMESTAMP_SKEW_MS = 5_000L
        private const val EXECUTABLE_MODE_MASK = 0x49
        private val VERSION_PATTERN = Regex("\\d{4}\\.\\d{1,3}\\.\\d{1,3}")
        private val SHA256_PATTERN = Regex("[a-fA-F0-9]{64}")
        private val NPM_EXIT_CODE_PATTERN = Regex("""\bverbose exit (\d+)\b""")
        private const val ISOLATED_PROVISION_STATUS_FILE =
            "official-openclaw-provision-status.json"
        private const val STAGED_RELEASE_FILE = "plawie-staged-upstream-release.json"
        private const val STAGING_DIRECTORY_PREFIX = ".openclaw-install-"
        private const val PROVISION_STATUS_QUEUED = "queued"
        private const val PROVISION_STATUS_RUNNING = "running"
        private const val PROVISION_STATUS_SUCCEEDED = "succeeded"
        private const val PROVISION_STATUS_FAILED = "failed"
        private const val MAX_PROVISION_ERROR_CHARS = 2_000

        /**
         * Creates a durable request that [OfficialOpenClawInstallService] can
         * fulfil from its own process. libnode is intentionally not run in the
         * Flutter UI process: Node owns process-global state and can destabilize
         * an Android renderer when an npm transaction exits.
         */
        fun createIsolatedProvisionRequest(context: Context): String {
            val requestId = UUID.randomUUID().toString()
            writeIsolatedProvisionStatus(
                context = context,
                requestId = requestId,
                state = PROVISION_STATUS_QUEUED,
                message = "Preparing the official OpenClaw installer…",
                progress = 0.0
            )
            return requestId
        }

        fun markIsolatedProvisionRunning(context: Context, requestId: String) {
            writeIsolatedProvisionStatus(
                context = context,
                requestId = requestId,
                state = PROVISION_STATUS_RUNNING,
                message = "Starting the official OpenClaw installer…",
                progress = 0.01
            )
        }

        fun markIsolatedProvisionProgress(
            context: Context,
            requestId: String,
            message: String,
            progress: Double
        ) {
            writeIsolatedProvisionStatus(
                context = context,
                requestId = requestId,
                state = PROVISION_STATUS_RUNNING,
                message = message,
                progress = progress.coerceIn(0.0, 1.0)
            )
        }

        fun markIsolatedProvisionSucceeded(
            context: Context,
            requestId: String,
            result: Map<String, Any>
        ) {
            writeIsolatedProvisionStatus(
                context = context,
                requestId = requestId,
                state = PROVISION_STATUS_SUCCEEDED,
                result = result,
                message = "Official OpenClaw is installed and verified.",
                progress = 1.0
            )
        }

        fun markIsolatedProvisionFailed(
            context: Context,
            requestId: String,
            error: Throwable
        ) {
            val detail = (error.message ?: error.javaClass.simpleName)
                .replace(Regex("[\\r\\n]+"), " ")
                .take(MAX_PROVISION_ERROR_CHARS)
            writeIsolatedProvisionStatus(
                context = context,
                requestId = requestId,
                state = PROVISION_STATUS_FAILED,
                error = detail,
                message = "Official OpenClaw installation failed."
            )
        }

        /**
         * Waits for the isolated installer without blocking the Flutter UI
         * thread. If npm exits its embedded process before Kotlin can persist
         * success, the app-private staging transaction is recovered here
         * without a second OpenClaw download.
         */
        fun awaitIsolatedProvisionResult(
            context: Context,
            requestId: String
        ): Map<String, Any> {
            val deadline = SystemClock.elapsedRealtime() +
                NPM_INSTALL_TIMEOUT_MS + ISOLATED_PROVISION_WAIT_GRACE_MS
            while (SystemClock.elapsedRealtime() < deadline) {
                val status = readIsolatedProvisionStatus(context)
                if (status?.optString("requestId") == requestId) {
                    when (status.optString("state")) {
                        PROVISION_STATUS_SUCCEEDED -> {
                            val result = status.optJSONObject("result")
                                ?: throw IllegalStateException(
                                    "Official OpenClaw installer reported success without a result."
                                )
                            return jsonObjectToMap(result)
                        }
                        PROVISION_STATUS_FAILED -> {
                            val detail = status.optString("error")
                                .ifBlank { "Unknown isolated installer failure." }
                            throw IllegalStateException(detail)
                        }
                        PROVISION_STATUS_RUNNING -> {
                            val recovered = try {
                                OfficialOpenClawProvisioner(context)
                                    .recoverCompletedStagedInstall(requestId)
                            } catch (error: Throwable) {
                                markIsolatedProvisionFailed(context, requestId, error)
                                throw error
                            }
                            if (recovered != null) {
                                markIsolatedProvisionSucceeded(context, requestId, recovered)
                                return recovered
                            }
                        }
                    }
                }
                Thread.sleep(200)
            }
            throw IllegalStateException(
                "Official OpenClaw installer did not finish before its timeout."
            )
        }

        private fun isolatedProvisionStatusFile(context: Context): File =
            File(File(context.filesDir, NATIVE_WORK_DIR), ISOLATED_PROVISION_STATUS_FILE)

        private fun readIsolatedProvisionStatus(context: Context): JSONObject? {
            val file = isolatedProvisionStatusFile(context)
            if (!file.isFile) return null
            return try {
                JSONObject(file.readText())
            } catch (_: Exception) {
                null
            }
        }

        fun isolatedProvisionStatusForChannel(context: Context): Map<String, Any> {
            val status = readIsolatedProvisionStatus(context) ?: return emptyMap()
            val channel = linkedMapOf<String, Any>()
            val state = status.optString("state").trim()
            if (state.isNotEmpty()) channel["state"] = state
            val message = status.optString("message").trim()
            if (message.isNotEmpty()) channel["message"] = message
            if (status.has("progress")) {
                channel["progress"] = status.optDouble("progress", 0.0)
            }
            if (status.has("updatedAtEpochMs")) {
                channel["updatedAtEpochMs"] = status.optLong("updatedAtEpochMs", 0L)
            }
            val error = status.optString("error").trim()
            if (error.isNotEmpty()) channel["error"] = error
            return channel
        }

        private fun writeIsolatedProvisionStatus(
            context: Context,
            requestId: String,
            state: String,
            result: Map<String, Any>? = null,
            error: String? = null,
            message: String? = null,
            progress: Double? = null
        ) {
            val destination = isolatedProvisionStatusFile(context)
            destination.parentFile?.mkdirs()
            val payload = JSONObject()
                .put("schemaVersion", 2)
                .put("requestId", requestId)
                .put("state", state)
                .put("updatedAtEpochMs", System.currentTimeMillis())
            if (result != null) payload.put("result", JSONObject(result))
            if (!error.isNullOrBlank()) payload.put("error", error)
            if (!message.isNullOrBlank()) payload.put("message", message)
            if (progress != null) payload.put("progress", progress.coerceIn(0.0, 1.0))

            val temporary = File(destination.parentFile, destination.name + ".tmp")
            temporary.writeText(payload.toString())
            if (!temporary.renameTo(destination)) {
                destination.writeText(payload.toString())
                temporary.delete()
            }
        }

        private fun jsonObjectToMap(value: JSONObject): Map<String, Any> {
            val result = linkedMapOf<String, Any>()
            val keys = value.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                result[key] = jsonValueForChannel(value.get(key))
            }
            return result
        }

        private fun jsonValueForChannel(value: Any): Any = when (value) {
            is JSONObject -> jsonObjectToMap(value)
            is JSONArray -> buildList {
                for (index in 0 until value.length()) {
                    add(jsonValueForChannel(value.get(index)))
                }
            }
            JSONObject.NULL -> ""
            else -> value
        }

        fun nativePackageStatus(context: Context): NativePackageStatus {
            val workDir = File(context.filesDir, NATIVE_WORK_DIR)
            val packageDir = File(workDir, PACKAGE_RELATIVE_PATH)
            val packageJson = File(packageDir, "package.json")
            val launcher = File(packageDir, "openclaw.mjs")
            val runMain = File(packageDir, "dist/cli/run-main.js")
            val typebox = File(packageDir, "node_modules/typebox/package.json")
            val version = try {
                if (packageJson.isFile) JSONObject(packageJson.readText()).optString("version").ifBlank { null }
                else null
            } catch (_: Exception) {
                null
            }
            val receipt = try {
                val file = File(File(workDir, FULL_GATEWAY_DIR), INSTALL_RECEIPT)
                if (file.isFile) JSONObject(file.readText()) else null
            } catch (_: Exception) {
                null
            }
            return NativePackageStatus(
                ready = version != null && launcher.isFile && runMain.isFile && typebox.isFile,
                version = version,
                receiptVersion = receipt?.optString("version")?.ifBlank { null },
                receiptIntegrity = receipt?.optString("tarballIntegrity")?.ifBlank { null }
            )
        }
    }
}
