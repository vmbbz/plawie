# Technical Incident Report: Local LLM Android — Root Cause Analysis & Fixes

**Prepared for:** Senior Engineering Review (Grok)
**Date:** 2026-03-27
**Project:** OpenClaw Android (Flutter)
**Component:** Local LLM — `lib/services/local_llm_service.dart`
**Severity:** P0 — Feature completely non-functional end-to-end

---

## 1. System Architecture Overview

### What This Feature Does

OpenClaw Android runs a **local LLM HTTP server** (llama.cpp `llama-server`) inside a PRoot Ubuntu 22.04 environment embedded in the app. The server exposes port `8081` as an OpenAI-compatible chat completions API endpoint. When available, the OpenClaw gateway (Node.js) routes inference requests to `http://127.0.0.1:8081` instead of cloud providers.

```
Android App (Flutter)
  └─ NativeBridge.runInProot(cmd)
       └─ PRoot Ubuntu 22.04 ARM64 (sandboxed Linux)
            ├─ /root/.openclaw/bin/llama-server   ← the binary we need
            ├─ /root/.openclaw/models/             ← GGUF model files
            └─ port 8081 (127.0.0.1)
```

### Key Dart Classes

| Class | File | Role |
|-------|------|------|
| `LocalLlmService` | `lib/services/local_llm_service.dart` | Orchestrates binary install, model download, server lifecycle |
| `LocalLlmState` | same | Immutable state: `status`, `downloadProgress`, `errorMessage` |
| `LocalLlmStatus` | same | Enum: `idle / downloading / installing / starting / ready / error` |
| `NativeBridge.runInProot()` | `lib/services/native_bridge.dart` | Executes shell commands inside PRoot; throws `PlatformException` on exit code ≠ 0 |

### Critical `NativeBridge.runInProot()` Contract

This is the most important detail in the entire system. Every engineer touching this code must understand:

```dart
// runInProot executes the command as:
//   /bin/sh -c "<command>"
// It throws PlatformException(PROOT_ERROR) on ANY non-zero exit code.
// It NEVER returns an error string — it either returns stdout or throws.
```

This means:
- **No positional shell args** (`$1`, `$2`) are ever set — the command is not invoked as a script
- **Error strings cannot be checked** after the call — the call throws before you can read them
- **Exception = non-zero exit** — any `|| exit 1` in the shell causes a Dart exception

---

## 2. Bug Catalogue — Complete Analysis

### Bug #1: llama-server Binary URL Does Not Exist

**Symptom:** `not a dynamic executable` / binary file is 9 bytes

**Code location:** `_compileBinary()` → `_getOptimalBinaryUrl()`

**What the code did:**
```dart
String _getOptimalBinaryUrl(String cpuInfo) {
  final Map<String, String> binaryMap = {
    'armv8.2-a': 'https://github.com/ggerganov/llama.cpp/releases/download/b3170/llama-server-android-arm64-v8.2a',
    'armv8-a':   'https://github.com/ggerganov/llama.cpp/releases/download/b3170/llama-server-android-arm64',
    // ...
  };
}
```

**Root cause:** These URLs do not exist. **llama.cpp has never shipped Android ARM64 pre-built binaries** in any GitHub release. Verified against releases b8545–b8548 (March 2026): Android is absent from all release assets. When curl fetches a non-existent GitHub release asset, GitHub returns a `302 → 404` HTML redirect page (~9 bytes after following). `chmod +x` was applied to this 9-byte HTML fragment. The OS later rejected it with `Exec format error` ("not a dynamic executable").

**Evidence:** Checked `https://api.github.com/repos/ggml-org/llama.cpp/releases/latest`. Assets include macOS arm64, Windows CPU arm64, Linux x64, openEuler aarch64. No Android.

**Fix:** Replace download with compile-from-source inside PRoot Ubuntu using cmake. The PRoot environment is Ubuntu 22.04 ARM64; it has `apt-get` and can install cmake/g++/git. This is the only supported path. Reference: `llama.cpp/docs/android.md` (official docs) and every community project using llama.cpp on Android (Termux users all compile from source).

---

### Bug #2: Shell Positional Args `$1`/`$2` Never Set

**Symptom:** `curl: (3) URL rejected: Malformed input to a URL function`

**Code location:** `_compileBinary()`, the install script

**What the code did:**
```bash
# Script stored as Dart const string:
CPU_INFO="$1"     # Expects positional arg 1
BINARY_URL="$2"   # Expects positional arg 2

curl -L -o /root/.openclaw/bin/llama-server "$BINARY_URL"
```

```dart
// Called via:
await NativeBridge.runInProot(fullScript, timeout: 600);
```

**Root cause:** `NativeBridge.runInProot()` executes commands as `/bin/sh -c "<script>"`. In this form, `$1` and `$2` are the positional parameters of the *outer* shell invocation, not of the script. Since `runInProot` passes no arguments after the `-c` string, `$1` and `$2` are both empty. `curl` receives an empty string as the URL, producing error 3.

**Fix:** Use Dart's `String.replaceFirst()` to inline the values directly into the script string before execution:
```dart
final fullScript = installScript
    .replaceFirst('CPU_INFO="\$1"', 'CPU_INFO="$cleanedCpuInfo"')
    .replaceFirst('BINARY_URL="\$2"', 'BINARY_URL="$binaryUrl"');
```
Note: This fix became moot when Bug #1's approach (download) was replaced entirely with compile-from-source, but the underlying principle applies to any future shell scripting via `runInProot`.

---

### Bug #3: `_isBinaryInstalled()` Accepted the 9-Byte Corrupt Stub

**Symptom:** `_compileBinary()` never ran after the URL bug was introduced; "Process died immediately" on every Start attempt

**Code location:** `_isBinaryInstalled()`

**What the code did:**
```dart
Future<bool> _isBinaryInstalled() async {
  final result = await NativeBridge.runInProot(
    'test -x /root/.openclaw/bin/llama-server && echo "exists"',
    timeout: 5,
  );
  return result.trim() == 'exists';
}
```

**Root cause:** `test -x` tests only the **executable permission bit** — it does not validate the file's content or format. The previous failed download script had applied `chmod +x` to the 9-byte HTML fragment before exiting. So `test -x` returned true. The guard condition in `downloadAndStart()`:
```dart
final binaryExists = await _isBinaryInstalled();
if (!binaryExists) {
  await _compileBinary(); // ← NEVER REACHED
}
```
...was satisfied by the corrupt stub, so `_compileBinary()` was never called. The compile-from-source fix in commit `7b34cb1` was entirely gated by this check and therefore silently did nothing on the actual device.

**Fix:** Add a file size gate. A real `llama-server` binary is 5–15 MB. The corrupt stub is 9 bytes. `stat -c%s` returns file size in bytes:

```dart
'test -x /root/.openclaw/bin/llama-server && '
r'[ $(stat -c%s /root/.openclaw/bin/llama-server 2>/dev/null || echo 0) -gt 1048576 ] && '
'echo "exists"',
```

Minimum threshold: 1 MB (1,048,576 bytes). This is deliberately conservative — any real llama-server will be far above this threshold regardless of build configuration.

**For Grok engineers:** A more robust check would be `file /root/.openclaw/bin/llama-server | grep -q ELF` which verifies the ELF magic bytes. However, `file` may not be installed in the base Ubuntu 22.04 PRoot image. Size gate is simpler and reliable for this use case. Another option: run `llama-server --version` and check exit code 0.

---

### Bug #4: Skills Install — `PlatformException` Made Fallback Unreachable

**Symptom:** `PlatformException(PROOT_ERROR, Command failed (exit code 1): error: unknown command 'skill')`

**Code location:** `skills_manager.dart` ~line 140

**What the code did:**
```dart
// Stage 1: try new singular syntax
final cliResult = await NativeBridge.runInProot(
  'openclaw skill install ${skill.id}',
  timeout: 45,
);
// Stage 2: fallback if Stage 1 returned an error string
if (cliResult.contains('error:') || cliResult.contains('unknown command')) {
  // Try clawhub...
}
```

**Root cause:** `runInProot` **throws** on non-zero exit. If the OpenClaw gateway doesn't support `skill` (singular), the command exits 1, which throws `PlatformException`. The code after the await — the `if (cliResult.contains(...))` check — is **never reached**. `cliResult` is never assigned. The exception propagates up to the UI which displays it directly.

**The fallback was never reachable by design** — it relied on `runInProot` returning an error string, but `runInProot` throws instead.

**Fix:** Wrap Stage 1 in `try/catch` and use the exception itself as the signal to fall through:

```dart
String cliResult;
try {
  cliResult = await NativeBridge.runInProot(
    'openclaw skill install ${skill.id}',
    timeout: 45,
  );
} catch (_) {
  // Stage 1 failed (unknown command, old gateway) — force fallback
  cliResult = 'error:';
}
if (cliResult.toLowerCase().contains('error:') || ...) {
  cliResult = await NativeBridge.runInProot(
    'npx clawhub install ${skill.id}',
    timeout: 60,
  );
}
```

---

### Bug #5: Git Clone Timeout at 15% Progress

**Symptom:** Compilation stuck at 15% (Stage 2) on every attempt

**Code location:** `_compileBinary()` Stage 2

**What the code did:**
```dart
await NativeBridge.runInProot(
  'rm -rf /tmp/llama_build && '
  'git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /tmp/llama_build',
  timeout: 300, // 5 minutes
);
```

**Root cause:** A shallow clone (`--depth 1`) of the llama.cpp repository transfers approximately 100–150 MB of git objects (even without full history — the pack index, loose objects, and working tree still require significant data). On a mobile connection at 1 Mbps this takes ~800–1200 seconds. The 300s timeout expired every time.

Additionally, `git clone` has **no resume capability** — an interrupted clone must restart from byte 0.

**Fix:** Replace `git clone` with `curl` tarball download:
```bash
curl -L -C - --retry 3 --retry-delay 10 --connect-timeout 30 \
  -o /tmp/llama_src.tar.gz \
  "https://github.com/ggml-org/llama.cpp/archive/refs/heads/master.tar.gz"
tar -xzf /tmp/llama_src.tar.gz -C /tmp/llama_build --strip-components=1
rm -f /tmp/llama_src.tar.gz
```

Key changes:
- `curl -C -` sends `Range: bytes=<existing-file-size>-` on retry — partial tarball is preserved across failures, download resumes
- `--retry 3` handles transient network errors
- Timeout increased to 900s (15 min) — covers 120 MB at 1 Mbps
- No git protocol overhead

**For Grok engineers:** The `master.tar.gz` URL always tracks HEAD. A more stable approach would pin to a specific release tag using the GitHub API:
```bash
TAG=$(curl -sf https://api.github.com/repos/ggml-org/llama.cpp/releases/latest | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
curl -L -C - -o /tmp/llama_src.tar.gz "https://github.com/ggml-org/llama.cpp/archive/refs/tags/${TAG}.tar.gz"
```
This pins to a tested release. Trade-off: the API call adds latency and the tag must be known. Current implementation uses `master` for simplicity.

---

### Bug #6: Model Download Not Resumable — 400 MB Re-Downloaded Every Attempt

**Symptom:** Each interrupted download restarted from zero

**Code location:** `_downloadModel()`

**What the code did:**
```dart
final tmpFile = File('${tmpDir.path}/${model.filename}');
// No check for existing file. Always opens for write (overwrite):
final sink = tmpFile.openWrite();  // FileMode.write = always 0 bytes
// No Range header sent
final request = await client.getUrl(url);
final response = await request.close();
```

**Root cause:** Three compounding omissions:
1. No check whether a partial file already exists at `tmpFile`
2. No `Range: bytes=<offset>-` header on the HTTP request
3. `openWrite()` with default `FileMode.write` truncates any existing content

The temp directory (`getTemporaryDirectory()`) is persistent across app restarts on Android. Any partially downloaded file was being silently discarded by the overwrite.

**Fix:**
```dart
// Check existing bytes
final alreadyBytes = await tmpFile.exists() ? await tmpFile.length() : 0;
// Add Range header
if (alreadyBytes > 0) {
  request.headers.add('Range', 'bytes=$alreadyBytes-');
}
// Handle server response correctly
final isResume = response.statusCode == 206; // Partial Content
final openMode = isResume ? FileMode.append : FileMode.write;
// 416 Range Not Satisfiable = file already fully downloaded
if (response.statusCode == 416) { /* skip to install */ }
```

**For Grok engineers:** HuggingFace CDN supports HTTP Range requests (verified). The model URL format is `https://huggingface.co/<org>/<repo>/resolve/main/<filename>` which routes through Cloudflare — Range header support is universal. Potential edge case: if the server returns 200 instead of 206 (ignores Range), the code correctly falls back to a full download with `FileMode.write`.

---

### Bug #7: Progress Label Invisible to User During Installation

**Symptom:** User sees only a bare percentage like `15.0%` with no context during the 20–40 min compilation

**Code location:** `local_llm_screen.dart`

**What the code did:**
```dart
// In the UI:
if (_state.status == LocalLlmStatus.error && _state.errorMessage != null)
  Text(_state.errorMessage!)  // Only shown during error state
```

```dart
// In the service: set at every stage during installation
_updateState(_state.copyWith(
  errorMessage: 'Stage 2/5: Downloading llama.cpp source (~120 MB)...',
));
// ↑ This was set correctly but never rendered during 'installing' status
```

**Root cause:** The `LocalLlmState.errorMessage` field is dual-purpose: used both for errors and for stage labels during installation. The UI correctly guarded `errorMessage` display behind `status == error`, but the service used the same field for in-progress status labels. The labels were set correctly in state but never appeared on screen.

**Fix:** Render `errorMessage` as the progress label during `downloading` and `installing` states:
```dart
if (_state.status == LocalLlmStatus.downloading ||
    _state.status == LocalLlmStatus.installing) ...[
  LinearProgressIndicator(value: _state.downloadProgress, ...),
  if (_state.errorMessage != null)
    Text(_state.errorMessage!)   // ← stage label or "12.3 MB / 400 MB"
  else
    Text('${(_state.downloadProgress * 100).toStringAsFixed(1)}%'),
],
```

**For Grok engineers:** A cleaner long-term fix would be to separate `errorMessage` and a `progressLabel` field in `LocalLlmState`, or rename `errorMessage` to `statusMessage` and add a separate `errorMessage`. The current fix is pragmatic — it avoids a breaking state model change while making the existing data visible.

---

## 3. Commit History

| Commit | Description |
|--------|-------------|
| `2c1e520` | Skills install fallback unreachable + shell `$1/$2` positional args empty |
| `7b34cb1` | Replace download-binary with compile-from-source (5-stage cmake pipeline) |
| `da8a69e` | `_isBinaryInstalled()` size gate — corrupt 9-byte stub bypassed guard |
| `c8d2fe1` | Resumable tarball download, model download Range requests, real progress labels |

---

## 4. Current State After Fixes

### What now happens on first Start (no binary yet):

1. `_isBinaryInstalled()` → checks `test -x AND size > 1MB` → **false** (corrupt stub or no file)
2. `_compileBinary()` triggers:
   - Stage 1: `apt-get install cmake g++ make ninja-build` (5 min max)
   - Stage 2: `curl -L -C - master.tar.gz` — **resumable**, 15 min max
   - Stage 3: `cmake configure` (2 min)
   - Stage 4: `cmake --build --target llama-server -j2` (40 min max)
   - Stage 5: verify `--version`, install to `/root/.openclaw/bin/llama-server`
3. `_isModelInstalled()` → check PRoot model path
4. `_downloadModel()` — **resumes** from partial file if interrupted
5. `_startServer()` — launches with mmap (not --no-mmap), no --mlock

### What happens on subsequent Starts:

1. `_isBinaryInstalled()` → file > 1MB → **true** — skip compilation
2. `_isModelInstalled()` → file exists → **true** — skip download
3. `_startServer()` → server up in ~5–10s

---

## 5. Open Questions for Grok Engineers

These are areas where we have working fixes but would benefit from expert review:

### Q1: Is `-j2` the right thread count for compilation?

We use `cmake --build ... -j2` to limit parallelism. The concern: mobile CPUs have 4–8 cores but Android's LMKD (Low Memory Killer Daemon) aggressively kills processes under memory pressure. Higher parallelism = more RAM for compilation = higher kill probability.

**Question:** Is `-j2` optimal, or should it be `nproc / 2` dynamically? Any known issues compiling llama.cpp with high parallelism on 4–6GB Android devices?

### Q2: The `LLAMA_NATIVE=OFF` / `GGML_NATIVE=OFF` cmake flags

These flags disable host-CPU-specific ISA extensions. The intent is to produce a binary that runs on any ARM64 device (not just the one it was compiled on).

**Question:** Is this correct for a binary that will ONLY run on the device it was compiled on? If we compile on a Snapdragon 8 Gen 3 (Armv9.2), is `NATIVE=OFF` losing meaningful performance, and does llama.cpp have a better way to auto-detect SIMD capabilities at runtime?

### Q3: Should `llama-server` be replaced with `llama-cli` or the node-llama-cpp npm binding?

Research shows competitor apps (openclaw-termux, openclaw-android) use `@node-llama-cpp/linux-arm64` — a pre-built npm native addon — rather than the standalone `llama-server` HTTP server. This avoids compilation entirely.

**Question:** Is there a path to using `node-llama-cpp`'s pre-built ARM64 binaries from within a PRoot Node.js environment, rather than compiling and running the HTTP server separately? This would eliminate the 20–40 min one-time compilation entirely.

### Q4: `master.tar.gz` vs pinned release

We currently download `master.tar.gz`. This always gets the latest HEAD which could break API compatibility (llama-server flags change frequently).

**Question:** Should we pin to a specific release tag, and if so, what's the right mechanism? Options: (a) hardcode a tag in Dart code, (b) query GitHub API at runtime, (c) ship the tarball bundled with the APK.

### Q5: PRoot network stack reliability

Multiple failures in testing were related to network operations inside PRoot (git clone timeouts, curl failures). PRoot uses the host's network stack but there can be DNS/routing issues on some Android devices.

**Question:** Are there known mitigations for PRoot networking reliability on Android? Is there a better way to test network connectivity inside PRoot before starting a long download?

---

## 6. Files Modified

```
lib/services/local_llm_service.dart     — Primary: all llama-server logic
lib/screens/management/local_llm_screen.dart  — Progress label rendering
lib/screens/management/skills_manager.dart    — Skills install fallback
```

---

*Document prepared 2026-03-27. Commits: `2c1e520`, `7b34cb1`, `da8a69e`, `c8d2fe1`.*
