# ARCHITECTURE: Local LLM on Android — Plawie / OpenClaw

**Document type:** Living engineering reference — architecture, history, refactor roadmap
**Last updated:** 2026-03-28 (commit `5238893`)
**Status:** Phase 1 complete — fllama NDK inference active. PRoot retained for gateway only.
**Repo:** https://github.com/vmbbz/plawie

> **For AI agents and engineers arriving fresh:**
> This document is designed for you. It records every dead end, every exact error message,
> and every root cause discovered during months of iteration. Start at §2 if you want to
> understand where we came from. Start at §3 if you just want to understand what's running now.
> Start at §7 if you have a specific bug or task.

---

## Table of Contents

1. [System Context — What This App Is](#1-system-context)
2. [The Journey: Everything We Tried Before It Worked](#2-the-journey)
3. [Current Architecture — fllama Hybrid](#3-current-architecture)
4. [Inference Flow — Message to First Token](#4-inference-flow)
5. [Model Download & Activation Flow](#5-model-download--activation-flow)
6. [fllama API Reference](#6-fllama-api-reference)
7. [Known Bugs, Errors & Exact Fixes](#7-known-bugs--errors--exact-fixes)
8. [Remaining Refactor Tasks](#8-remaining-refactor-tasks)
9. [Performance Guide](#9-performance-guide)
10. [Stability & Safety Concerns](#10-stability--safety-concerns)
11. [Future Roadmap](#11-future-roadmap)
12. [File Map — Every File That Touches Local LLM](#12-file-map)
13. [Key NativeBridge Contract (Must Read)](#13-nativebridge-contract)
14. [Community & Peer Review](#14-community--peer-review)

---

## 1. System Context

### What This App Is

Plawie is a Flutter/Android AI assistant app. It runs a **self-contained AI gateway** — no Termux,
no root, no external app required. Everything ships inside the APK's app storage.

```
Android App (one self-contained APK)
  │
  ├─ Flutter (Dart) UI — chat, avatar, local LLM screen, settings
  │
  ├─ PRoot Ubuntu ARM64 userland (downloaded on first run, ~700MB)
  │     └─ Node.js 22 → OpenClaw gateway (cloud model routing, skills, agents)
  │           └─ port :18789 (WebSocket + HTTP)
  │
  └─ fllama (NDK — built into APK at compile time)
        └─ llama.cpp running natively on ARM64
              └─ GGUF model files loaded directly from host filesystem
```

### Two Separate Inference Paths

```
Cloud models (Claude, Gemini, GPT-4o):
  Flutter → GatewayService (WebSocket) → PRoot → Node.js → OpenClaw → cloud API

Local LLM (any GGUF model):
  Flutter → LocalLlmService → fllama (NDK) → llama.cpp → response
  [No PRoot. No Node.js. No HTTP server. Runs entirely inside Flutter's process.]
```

The gateway (PRoot) and fllama are **completely independent**. If PRoot crashes, local inference
keeps working. If the user hasn't set up PRoot yet, local inference still works.

---

## 2. The Journey

> This section documents every approach tried, in order, with the exact errors produced.
> It exists so future engineers and AI agents don't repeat these paths.

### Approach 1 — Download Pre-built llama-server Binary (FAILED)

**What we tried:** Download a pre-compiled `llama-server` ARM64 binary from the official
llama.cpp GitHub releases, copy to PRoot rootfs, `chmod +x`, execute.

**The code:**
```dart
// constants.dart (now deleted)
static const String _llamaBuild = 'b5616';
static String getLlamaServerZipUrl() =>
    'https://github.com/ggerganov/llama.cpp/releases/download/$_llamaBuild/'
    'llama-b${_llamaBuild}-bin-ubuntu-x64.zip';
```

**The error:**
```
HTTP 404 — asset does not exist
```

**Root cause:** **llama.cpp has never shipped Ubuntu ARM64 binaries in any GitHub release.**
Verified against releases b5616, b8545–b8548 (March 2026). Available assets per release:
- `llama-*-bin-ubuntu-x64.zip` ✅
- `llama-*-bin-macos-arm64.zip` ✅
- `llama-*-bin-win-arm64.zip` ✅
- `llama-*-bin-ubuntu-arm64.zip` ❌ — DOES NOT EXIST IN ANY RELEASE

**Also checked:** `avdg/llama-server-binaries` GitHub repo — only contains Windows binaries.

**Conclusion:** There is no official pre-built Ubuntu ARM64 binary for llama-server. Do not
search for one. Do not attempt this path again.

---

### Approach 2 — Compile llama-server from Source Inside PRoot (FAILED)

**What we tried:** Instead of downloading a binary, compile it inside the PRoot Ubuntu layer
using cmake + g++. The PRoot container has `apt-get` and can install build tools.

**Problems encountered:**

**2a. Shell positional args `$1`/`$2` never set:**
```dart
// The install script used:
CPU_INFO="$1"     // ← positional arg, never set
BINARY_URL="$2"   // ← positional arg, never set

// Called via:
NativeBridge.runInProot(fullScript, timeout: 600);
// runInProot executes as: /bin/sh -c "<script>"
// In this form, $1/$2 are the outer shell's positional params — always empty.
```

**Error produced:** `curl: (3) URL rejected: Malformed input to a URL function`
(curl received an empty string as the URL)

**Fix:** Inline the values before execution:
```dart
final fullScript = installScript
    .replaceFirst('CPU_INFO="\$1"', 'CPU_INFO="$cleanedCpuInfo"')
    .replaceFirst('BINARY_URL="\$2"', 'BINARY_URL="$binaryUrl"');
```

**2b. Corrupt 9-byte binary bypassed the install check:**
```dart
// The guard check:
Future<bool> _isBinaryInstalled() async {
  final result = await NativeBridge.runInProot(
    'test -x /root/.openclaw/bin/llama-server && echo "exists"',
  );
  return result.trim() == 'exists';
}
```
`test -x` only checks the **executable permission bit**, not file size or content.
A previous failed download had applied `chmod +x` to a 9-byte HTML error page (GitHub's 404
redirect body). The check returned `true`. The compile step was never triggered.

**Fix for check:**
```bash
test -x /path/to/bin \
  && [ $(stat -c%s /path/to/bin 2>/dev/null || echo 0) -gt 1048576 ] \
  && echo "exists"
```

**2c. Git clone timeout at ~15% progress:**
```dart
await NativeBridge.runInProot(
  'git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /tmp/llama_build',
  timeout: 300, // 5 minutes
);
```
A shallow clone of llama.cpp transfers ~100–150MB even with `--depth 1`.
At mobile speeds (1–5 Mbps) this takes 240–750 seconds. The 300s timeout expired every time.
`git clone` has **no resume capability** — each timeout restarts from 0 bytes.

**Fix:** Use `curl` tarball download with `-C -` (resume):
```bash
curl -L -C - --retry 3 --retry-delay 10 --connect-timeout 30 \
  -o /tmp/llama_src.tar.gz \
  "https://github.com/ggml-org/llama.cpp/archive/refs/heads/master.tar.gz"
```

**2d. Total compilation time:** Even with all fixes, cmake configure + build on a mobile CPU
takes **20–40 minutes**. This is untenable UX for a production app feature.

**Conclusion:** Compile-from-source works but is too slow and fragile for production. A user
waiting 40 minutes on first run will uninstall the app.

---

### Approach 3 — npm + node-llama-cpp HTTP Server Inside PRoot (FAILED)

**What we tried:** Write a `server.js` + `package.json` to the PRoot rootfs, run `npm install`
to download `@node-llama-cpp/linux-arm64` (prebuilt), then run a Node.js HTTP server on `:8081`.

**Problems encountered:**

**3a. `--ignore-scripts` skipped the prebuilt download:**

OpenClaw bootstrap installs the gateway as:
```bash
npm install -g openclaw --ignore-scripts
```
The `--ignore-scripts` flag skips the npm `postinstall` script. node-llama-cpp uses a
postinstall script to download its prebuilt native addon (`@node-llama-cpp/linux-arm64`).
Because `--ignore-scripts` was set globally, **the prebuilt binary was never downloaded**.
Running `node server.js` immediately threw:
```
Error: Cannot find module '@node-llama-cpp/linux-arm64-gnu'
```

**3b. PRoot mkdir race condition:**
```dart
// Flutter code:
final serverDir = '$filesDir/rootfs/root/.openclaw/local-server';
await Directory(serverDir).create(recursive: true);
// ↑ Creates directory on the HOST filesystem

// Then:
await NativeBridge.runInProot(
  'cd /root/.openclaw/local-server && npm install',
);
```
**Error produced:**
```
PlatformException(PROOT_ERROR, cd: /root/.openclaw/local-server: No such file or directory)
```

**Root cause:** `Directory.create()` operates in the **host Android filesystem namespace**.
PRoot processes run in their **own Linux namespace**. When PRoot spawns a new process, it
mounts `$filesDir/rootfs` as its `/`. A directory created by Flutter via `dart:io` at
`$filesDir/rootfs/root/.openclaw/local-server` IS visible inside PRoot at
`/root/.openclaw/local-server` — but ONLY if PRoot is already running. When `runInProot`
spawns a new PRoot process, the mount happens at spawn time. The directory must exist
**before** the spawn.

Workaround: Have PRoot create the directory itself:
```bash
mkdir -p /root/.openclaw/local-server && \
cp /root/.openclaw/llama-pkg.json /root/.openclaw/local-server/package.json && \
cd /root/.openclaw/local-server && npm install
```
This is safe because `/root/.openclaw/` always exists (OpenClaw config lives there).

**3c. `bionic-bypass.js` requirement:**
Node.js inside PRoot Ubuntu links against `glibc`. The prebuilt
`@node-llama-cpp/linux-arm64-gnu` binary also expects glibc. PRoot provides glibc (Ubuntu),
but there can be dynamic linker version mismatches. A `bionic-bypass.js` preload script was
needed to patch the runtime environment.

**3d. Still required an internet connection during first use (npm install ~50MB)**

**Conclusion:** Every piece of this approach required a different hack. Even if all hacks worked,
the server would be: one more process (RAM overhead), one more HTTP layer (latency), and
fragile across npm registry availability and bionic compatibility.

---

### Approach 4 — fllama (Flutter NDK Plugin) ✅ CURRENT IMPLEMENTATION

**Why this works:**
- No binary download (NDK library compiled at APK build time)
- No npm, no Node.js, no PRoot for inference
- No HTTP server (direct Dart API)
- No process to kill or restart
- No namespace issues (runs in Flutter's own Dart isolate)
- Cancel support via `fllamaCancelInference(requestId)`
- Runs inside Flutter's process — survives as long as the app does

**What was needed:**
1. Add `fllama` git dependency to `pubspec.yaml`
2. Pin NDK version to `27.0.12077973` in `android/app/build.gradle.kts`
3. Rewrite `LocalLlmService` to replace HTTP/PRoot methods with fllama calls
4. Update `GatewayService` to route `local-llm/*` model IDs to `LocalLlmService.chat()`

**Total code change:** 393 lines removed, 207 lines added.

---

## 3. Current Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Android Application                           │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Flutter (Dart) Process                    │    │
│  │                                                              │    │
│  │   ┌────────────┐     ┌──────────────────────────────────┐   │    │
│  │   │  Flutter   │     │       LocalLlmService             │   │    │
│  │   │    UI      │◄───►│  _activeModelPath  (host FS path) │   │    │
│  │   │  chat,     │     │  _activeMmprojPath (vision only)  │   │    │
│  │   │  local LLM │     │  _activeRequestId  (cancel token) │   │    │
│  │   │  screen    │     │  status: idle/downloading/ready/  │   │    │
│  │   └─────┬──────┘     │         starting/error            │   │    │
│  │         │            │                                    │   │    │
│  │         │            │  chat() → fllamaChat()             │   │    │
│  │         │            │  testInference() → fllamaChat()    │   │    │
│  │         │            │  analyseVideoFrames() → fllamaChat()│  │    │
│  │         │            └──────────────┬───────────────────-─┘   │    │
│  │         │                           │                          │    │
│  │         │            ┌──────────────▼──────────────────────┐  │    │
│  │         │            │  fllama (Dart isolate → JNI → NDK)  │  │    │
│  │         │            │  libfllama.so (arm64-v8a)            │  │    │
│  │         │            │  llama.cpp compiled at APK build     │  │    │
│  │         │            └─────────────────────────────────────-┘  │    │
│  │         │                                                       │    │
│  │         │            ┌────────────────────────────────────┐   │    │
│  │         └───────────►│      GatewayService                │   │    │
│  │                      │  cloud: WebSocket → :18789          │   │    │
│  │                      │  local: → LocalLlmService.chat()   │   │    │
│  │                      └──────────────┬─────────────────────┘   │    │
│  │                                     │ NativeBridge (JNI)       │    │
│  └─────────────────────────────────────┼───────────────────────--─┘    │
│                                        │                                │
│   ┌────────────────────────────────────▼──────────────────────────┐    │
│   │           PRoot Ubuntu ARM64 (gateway only, not inference)     │    │
│   │   /usr/local/bin/node → openclaw gateway → port :18789         │    │
│   │   /root/.openclaw/models/*.gguf  ← SAME FILES fllama reads     │    │
│   │   (accessed by fllama via host path: $filesDir/rootfs/...)     │    │
│   └────────────────────────────────────────────────────────────────    │
└──────────────────────────────────────────────────────────────────────┘
```

### Message Routing Decision Tree

```
GatewayService.sendMessage(message, model)
         │
         ├─ model.startsWith('local-llm')  ─────────────────────────────►
         │                                                                │
         │                                              LocalLlmService   │
         │                                              .chat(hist, msg)  │
         │                                                    │           │
         │                                              fllamaChat()      │
         │                                                    │           │
         │                                              NDK / llama.cpp   │
         │                                                    │           │
         │                                              Stream<String>    │
         │                                              token deltas ◄────┘
         │
         └─ cloud model (claude-*, gemini-*, gpt-*)
                   │
                   └── WebSocket :18789 → PRoot → OpenClaw → API
```

---

## 4. Inference Flow

### Text Chat (Full Detail)

```
1. User submits message
         │
2. chat_screen.dart → GatewayService.sendMessage(msg, 'local-llm/qwen2.5-1.5b-instruct-q4_k_m')
         │
3. GatewayService detects 'local-llm' prefix
         │
4. LocalLlmService.chat(conversationHistory, userMessage)
         │
         ├── _state.status != ready → yield '[Error] Local LLM not ready'
         ├── _activeModelPath == null → yield '[Error] No model path'
         │
         ├── Convert history:
         │     List<Map<String,dynamic>>  →  List<Message>
         │     {role:'user', content:'...'}  →  Message(Role.user, '...')
         │     {role:'assistant', content:'...'}  →  Message(Role.assistant, '...')
         │     {role:'system', content:'...'}  →  Message(Role.system, '...')
         │
         ├── StreamController<String> controller = StreamController()
         │
         ├── fllamaChat(
         │     OpenAiRequest(
         │       messages: [...history, Message(Role.user, userMessage)],
         │       modelPath: _activeModelPath,    // e.g. /data/user/0/.../rootfs/root/.openclaw/models/qwen2.5-1.5b.gguf
         │       mmprojPath: null,               // null for text models
         │       maxTokens: 1024,
         │       contextSize: 4096,
         │       numGpuLayers: 99,               // llama.cpp tries GPU, falls back to CPU
         │       temperature: 0.7,
         │     ),
         │     (String response, String responseJson, bool done) {
         │       final delta = response.substring(lastResponse.length);
         │       // ↑ response is ACCUMULATED text — must compute delta yourself
         │       lastResponse = response;
         │       if (delta.isNotEmpty) controller.add(delta);
         │       if (done) controller.close();
         │     }
         │   ).then((id) => _activeRequestId = id)
         │   // ↑ requestId stored for cancellation
         │
5. return controller.stream
         │
6. chat_screen.dart listens to stream → renders tokens as they arrive
```

### Vision Chat

```
GatewayService.sendVisionMessage(prompt, imageBase64)
         │
LocalLlmService.analyseVideoFrames([base64Decode(imageBase64)], prompt)
         │
         ├── Encode first frame: base64Encode(frames.first)
         ├── Build vision prompt: "data:image/jpeg;base64,<...>\n\n<prompt>"
         │
         └── fllamaChat(OpenAiRequest{
               modelPath: _activeModelPath,    // e.g. Qwen2-VL-2B-Q4_K_M.gguf
               mmprojPath: _activeMmprojPath,  // e.g. mmproj-Qwen2-VL-2B-f16.gguf
               messages: [Message(Role.user, visionPrompt)],
             }, callback → Completer<String>)
             // non-streaming for vision: wait for complete response
```

---

## 5. Model Download & Activation Flow

```
LocalLlmService.downloadAndStart(LocalLlmModel model)
         │
         ├── Already downloading/starting/installing? → return (no double-start)
         │
         ├── _isModelInstalled(model)?
         │     File('$filesDir/rootfs/root/.openclaw/models/${model.id}.gguf').exists()
         │     && file.length() > 1MB
         │
         │   NOT INSTALLED → _downloadModel(model):
         │         ├── HttpClient.getUrl(model.huggingFaceUrl)
         │         │     Example URL: https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf
         │         ├── alreadyBytes = existing tmpFile.length() (resume support)
         │         ├── Range: bytes=$alreadyBytes-  (HuggingFace CDN supports Range)
         │         ├── 206 Partial → FileMode.append
         │         │   200 Full → FileMode.write
         │         │   416 Range Not Satisfiable → file complete, skip to copy
         │         ├── Stream → tmpFile (temp dir, survives app restart)
         │         └── tmpFile.copy → $filesDir/rootfs/root/.openclaw/models/
         │
         ├── model.isMultimodal?
         │     → _isMmProjInstalled? NOT → _downloadMmProj(model)
         │         (same resume logic, different URL)
         │
         └── _activateFllama(model):
               ├── _activeModelPath = '$filesDir/rootfs${model.prootModelPath}'
               │     Note: this is the HOST filesystem path, not the PRoot path
               │     PRoot path:  /root/.openclaw/models/file.gguf
               │     Host path:   /data/user/0/com.nxg.openclawproot/files/rootfs/root/.openclaw/models/file.gguf
               │     fllama needs the HOST path (it runs outside PRoot)
               ├── _activeMmprojPath = same pattern for mmproj (or null)
               ├── File.existsSync(_activeModelPath) → throws if missing
               ├── PreferencesService.configuredModel = 'local-llm/${model.id}'
               └── _state = { status: ready, activeModelId: model.id }


Model File Locations:
  Host path (what fllama uses):  $filesDir/rootfs/root/.openclaw/models/
  PRoot path (what gateway uses): /root/.openclaw/models/
  Same physical bytes — PRoot mounts $filesDir/rootfs as its root /
  No file duplication. No sync needed.
```

---

## 6. fllama API Reference

### Package Location

```
Pub cache: C:/Users/cosyc/AppData/Local/Pub/Cache/git/fllama-e812a796f557dd95360830f1f8577a25076f6aba/
pubspec.yaml:
  fllama:
    git:
      url: https://github.com/Telosnex/fllama.git
      ref: main
```

### Core API

```dart
// ─── Main inference call ────────────────────────────────────────────────────
// Returns immediately. Inference happens in a Dart isolate.
// Returns the request ID (use for cancellation).
Future<int> fllamaChat(OpenAiRequest request, FllamaInferenceCallback callback)

// ─── Callback type ─────────────────────────────────────────────────────────
// Called on EVERY token generated.
// response = ACCUMULATED text (not delta!) — must compute delta yourself
// done = true on FINAL call (last token or cancelled)
typedef FllamaInferenceCallback =
    void Function(String response, String openaiResponseJsonString, bool done)

// ─── Cancellation ──────────────────────────────────────────────────────────
// Sends cancel to the isolate → C++ fllama_inference_cancel(requestId)
// The callback WILL still be called with done=true and the partial output
void fllamaCancelInference(int requestId)

// ─── Request class ─────────────────────────────────────────────────────────
class OpenAiRequest {
  final String modelPath;        // REQUIRED: absolute host FS path to .gguf
  final String? mmprojPath;      // optional: mmproj .gguf for vision models
  final List<Message> messages;  // conversation history + current user message
  final List<Tool> tools;        // tool/function definitions (default: [])
  final int maxTokens;           // default: 333 — increase for longer responses
  final int contextSize;         // default: 2048 — max context length in tokens
  final int numGpuLayers;        // 0=CPU only, 99=all layers on GPU (auto-detects)
  final double temperature;      // default: 0.7
  final double topP;             // default: 1.0
  final double frequencyPenalty; // default: 0.0
  final double presencePenalty;  // default: 1.1 (matches llama.cpp default)
  final Function(String)? logger;// optional: receives llama.cpp log lines
}

// ─── Message class ─────────────────────────────────────────────────────────
class Message {
  final Role role;   // Role.user | Role.assistant | Role.system | Role.tool
  final String text; // message content (string only — no multipart natively)
}

// ─── Tokenizer ─────────────────────────────────────────────────────────────
// Returns token count for a string — use for context overflow detection
Future<List<int>> fllamaTokenize(FllamaTokenizeRequest request)
class FllamaTokenizeRequest { final String input; final String modelPath; }
```

### Critical: The Accumulated Response Pattern

```dart
// ❌ WRONG — this would yield the entire response on every token
(response, _, done) { controller.add(response); }

// ✅ CORRECT — compute delta from accumulated text
String lastResponse = '';
(response, _, done) {
  final delta = response.substring(lastResponse.length);
  lastResponse = response;
  if (delta.isNotEmpty && !controller.isClosed) controller.add(delta);
  if (done && !controller.isClosed) controller.close();
}
```

### Threading Model

```
Main Isolate (Flutter UI thread)
    │
    │  fllamaChat() → SendPort → _helperIsolateSendPort
    ▼
fllama Helper Isolate (spawned once at first call, lives forever)
    │
    │  _toNative(request) → Pointer<fllama_inference_request>
    │  fllamaBindings.fllama_inference(nativeRequest, nativeCallback)
    ▼
libfllama.so (JNI, Android NDK arm64-v8a)
    │
    │  [llama.cpp token loop]
    │  each token → NativeCallback → _IsolateInferenceResponse → SendPort
    ▼
Main Isolate receives _IsolateInferenceResponse
    │
    └── FllamaInferenceCallback(response, jsonStr, done)
         └── StreamController.add(delta) → UI
```

**The helper isolate is long-lived.** One inference runs at a time. Concurrent calls are
queued in the isolate's ReceivePort. If you need immediate cancellation on a new message,
call `fllamaCancelInference(oldRequestId)` before starting the new request.

### Android NDK Build (How fllama Gets into the APK)

```
android/app/build.gradle.kts:
  ndkVersion = "27.0.12077973"  // PINNED — must not change without testing
  // fllama's CMakeLists.txt builds llama.cpp with:
  //   ANDROID_ABI = arm64-v8a
  //   ANDROID_PLATFORM = android-29
  //   GGML_VULKAN = OFF (currently — GPU not enabled yet)
  //   GGML_OPENMP = OFF

// The built library is:
//   android/app/build/intermediates/cmake/debug/obj/arm64-v8a/libfllama.so
// Packaged in APK as:
//   lib/arm64-v8a/libfllama.so
```

**Warning:** Changing `ndkVersion` from `27.0.12077973` breaks the build. fllama's native
code has NDK-specific build flags. Pin this and don't change it without a full `flutter build
apk` validation.

---

## 7. Known Bugs, Errors & Exact Fixes

### Error: `fllamaCancel` not defined

**When it appears:** Dart analysis error during migration from old code.

**Cause:** The correct function name is `fllamaCancelInference(int requestId)`, not
`fllamaCancel`. This is exported from `fllama_io_inference.dart`.

**Fix:** Use `fllamaCancelInference(_activeRequestId!)`.

---

### Error: `PlatformException(PROOT_ERROR, cd: /root/.openclaw/local-server: No such file or directory)`

**When it appears:** Any attempt to run `cd` into a directory that Flutter created via
`Directory.create()` before the PRoot spawn.

**Root cause:** See §2, Approach 3b — namespace mismatch between Flutter's host filesystem
operations and PRoot's spawned namespace.

**Fix:** Let PRoot create its own directories:
```bash
# Instead of Flutter creating the dir, let PRoot do it:
await NativeBridge.runInProot(
  'mkdir -p /root/.openclaw/local-server && ...',
);
```

---

### Error: `curl: (3) URL rejected: Malformed input to a URL function`

**When it appears:** Any shell script using `$1`/`$2` positional args passed via `runInProot`.

**Root cause:** See §2, Approach 2a.

**Fix:** Inline variable values in the Dart string before passing to `runInProot`:
```dart
final cmd = 'URL="$theUrl" && curl -L "\$URL" -o /tmp/output';
```

---

### Error: `not a dynamic executable` (or binary is 9 bytes)

**When it appears:** After a failed GitHub binary download where the URL returned 404 HTML.

**Root cause:** See §2, Approach 1. GitHub 302→404 redirect body is ~9 bytes.
`chmod +x` was applied to it. OS rejects it as not a valid ELF.

**Fix:** After any binary download, validate:
```bash
[ $(stat -c%s /path/to/binary) -gt 1048576 ] && file /path/to/binary | grep -q ELF
```

---

### Error: `model runner unexpectedly stopped` (HTTP 500 from Ollama Hub)

**When it appears:** During long inference tasks when using the PRoot-based Ollama Hub with a cloud-like agent profile. Devices often crash or timeout.

**Root cause:** A massive context multiplier effect:
1. The OpenClaw Node.js gateway assigns an unchecked default `contextWindow` of 200,000 tokens (assumed for Gemini/Claude). 
2. The Node.js gateway sends its full agent system prompt (instructions.md, ~27,000 chars) + tool definitions + the unbroken conversation history on _every_ request.
3. Ollama dynamically allocates KV-cache memory to handle 200,000 tokens for the `qwen2.5` model, rapidly exhausting Android's 1.9 GB process limit on 8 GB devices. Android's Low Memory Killer (LMK) abruptly terminates the model runner.

**Fix:** 
1. `GatewayService.configureOllama()` now forces `contextWindow: 4096` in `openclaw.json` to instruct the Node.js agent to aggressively trim conversation history before transmitting.
2. The heavy 27K agent prompt is overridden with a ~60-token `_kMobileSystemPrompt` specifically when Ollama is selected.
3. The Modelfile template `PARAMETER num_ctx` is increased to 4096, which comfortably fits local tasks and matches the new gateway guardrail.

---

### Error: `Error: Cannot find module '@node-llama-cpp/linux-arm64-gnu'`

**When it appears:** node-llama-cpp require() inside PRoot Node.js after bootstrap.

**Root cause:** See §2, Approach 3a. `--ignore-scripts` during `npm install -g openclaw`
skipped the postinstall step that downloads the prebuilt native addon.

**This error means node-llama-cpp is not installed.** Running `npm install` again in the
right directory (without `--ignore-scripts`) would fix it, but see all the other approach 3
problems for why we abandoned this path entirely.

---

### Error: `disabledUntil` — local model locked out for 1 hour

**When it appears:** After the first inference attempt through the OpenClaw gateway, when
model load time (60–90s) exceeded OpenClaw's inference timeout.

**Root cause:** OpenClaw's provider backoff system misclassifies slow responses as rate limits.
Writes `disabledUntil` to `auth-profiles.json`. Sequence: 1min → 5min → 25min → 1hour.

**This bug is now fully eliminated by fllama.** fllama bypasses the gateway entirely for
local inference — no OpenClaw provider layer, no timeout, no backoff.

**If you see this in old code:** The fix was `_clearLocalLlmCooldown()` which deleted
`usageStats` + `disabledUntil` from `auth-profiles.json` before each restart.

---

### Error: `[Error] Local LLM is not ready. Status: idle`

**When it appears:** User sends a message to local-llm before calling `downloadAndStart()` or
`startWithModel()`, OR after `stop()` was called.

**Fix in code:** Check `_state.status == LocalLlmStatus.ready` before inference calls.
LocalLlmService.chat() handles this gracefully — yields the error string and closes the stream.

---

### ~~Warning: `Unused import: '../constants.dart'`~~ (resolved)

`llamaServerUrl`/`llamaServerPort` constants deleted from `constants.dart` (commit `fd5e319`).
`gateway_state.dart` import removed from `local_llm_service.dart` (commit `9fb122f`).
`flutter analyze` passes clean.

---

## 8. Refactor Task Status

> **Last updated: 2026-03-29** — All P1, P2 (except tool-use), and P3 tasks are complete.

### ✅ P1 — Production Critical (all done)

| Task | Commit | Notes |
|------|--------|-------|
| **8.1** Vision image format | fd5e319 | `<img src="data:...">` — fllama's actual C++ parser format (confirmed from example app) |
| **8.2** Context window per-model | fd5e319 | `_activeContextSize` getter, clamps to 512–8192, replaces hardcoded 4096/2048 |
| **8.3** Concurrent inference guard | fd5e319 | `_isInferring` flag; cancel-on-overlap via `fllamaCancelInference` |
| **8.4** Thread count binding | fd5e319 | Replaced `fllamaChat()` → `fllamaInference(_buildInferenceRequest())` which sets `numThreads: _state.threads` |

**Key implementation notes:**
- `fllamaChat()` hardcodes `numThreads=2` and never exposes it via `OpenAiRequest`. The fix is `fllamaInference()` + a private `_buildInferenceRequest()` helper that mirrors `fllamaChat()`'s behavior (setting `input: ''` — the C++ side reads `openAiRequestJsonString` directly).
- Vision: fllama's C++ parser expects `<img src="data:image/jpeg;base64,...">`. Bare data URIs do NOT work.

---

### ✅ P2 — Quality & UX (all done)

| Task | Commit | Notes |
|------|--------|-------|
| **8.5** System prompt | fd5e319 | `Role.system "You are Plawie..."` injected at head of `chat()` message list |
| **8.6** History trimming | fd5e319 | `_trimHistory()` — chars-per-token budget, drops oldest messages first |
| **8.7** UI labels | fd5e319 | "Health Check" → "Engine Status", "View server log" → "View engine info", status card updated |
| **8.8** Tool-use / function calling | ✅ 9fb122f | Multi-turn local tool dispatch loop — see below |

#### 8.8 Tool-Use / Function Calling (complete — 2026-03-29)

Implemented in `local_llm_service.dart` commit `9fb122f`. Key design:

- `_localTools` — static list of `Tool` objects exposed to the model (currently: `get_current_datetime`)
- `_dispatchLocalTool(name, argumentsJson)` — synchronous dispatcher returning JSON result string
- `_runChatTurn(messages, controller, {depth})` — core multi-turn loop:
  1. Runs one inference turn with `tools: _localTools, toolChoice: ToolChoice.auto`
  2. Streams text deltas to the controller as they arrive
  3. Accumulates `tool_calls` data across streaming chunks (fllama delta pattern from example app)
  4. On `finish_reason == 'tool_calls'`: dispatches tools, appends `Message(Role.assistant, toolCalls: [...])` + `Message(Role.tool, result)`, recurses with `depth+1`
  5. Depth limit: 3. On normal `finish_reason` (or no tool calls): closes stream.
- `chat()` — builds initial message list and delegates entirely to `_runChatTurn()`
- `stop()` — closes `_activeChatController` immediately

**Tool call wire format** (`Message.toolCalls` list element):
```dart
{
  'id': tc['id'],
  'type': 'function',
  'function': {'name': name, 'arguments': argumentsJsonString},
}
```

**To add a new local tool:**
1. Add a `Tool(name: ..., jsonSchema: ..., description: ...)` to `_localTools`
2. Add a `case 'tool_name':` branch in `_dispatchLocalTool()` returning a JSON string
3. That's it — the loop handles multi-turn automatically

**Reference:** `fllama/example/lib/main.dart` `_parseStreamChunk()` lines 523–571 for the delta accumulation pattern.

---

### ✅ P3 — Architecture Cleanup (all done)

| Task | Commit | Notes |
|------|--------|-------|
| **8.9** Remove unused constants | fd5e319 | `llamaServerPort` / `llamaServerUrl` deleted from `constants.dart` |
| **8.10** Remove gateway check | fd5e319 | PRoot conflict guard removed from `downloadAndStart()` |
| **8.11** Stale imports/comments | fd5e319 | `GatewayService` import removed, class doc updated |

---

## 9. Performance Guide

### Token Throughput by Device Class (CPU-only, fllama default)

```
Device Class          SoC                Threads  Qwen2.5-1.5B  Qwen2.5-3B
──────────────────────────────────────────────────────────────────────────────
Budget (6GB)          SD 7 Gen 1         2        4–8 tok/s     2–4 tok/s
Mid-range (8GB)       SD 8 Gen 1         4        10–15 tok/s   6–10 tok/s
Flagship (12GB)       SD 8 Gen 2/3       4        15–22 tok/s   10–15 tok/s
Ultra flagship (16GB) SD 8 Elite         6        22–35 tok/s   15–22 tok/s

Note: Thread count is set from LocalLlmState.threads (user-adjustable slider,
      default 4). Passed via _buildInferenceRequest() → FllamaInferenceRequest.numThreads.
```

### GPU Offload Status (2026-03)

```
fllama sets numGpuLayers=99 in our code, instructing llama.cpp to use GPU.

Current reality:
  GGML_VULKAN is NOT enabled in fllama's NDK build → silently falls back to CPU
  All numbers above are CPU-only

When GGML_VULKAN is enabled (future work):
  Adreno 730 (SD 8 Gen 1):   ~50–70 tok/s for 1.5B Q4_K_M
  Adreno 740 (SD 8 Gen 2):   ~70–90 tok/s
  Adreno 830 (SD 8 Elite):   ~100–130 tok/s
  Expected improvement: 3–5× over CPU

How to enable: fork fllama, add -DGGML_VULKAN=ON to android/CMakeLists.txt,
               add Vulkan validation before use (some OEM drivers are buggy).
```

### RAM Requirements

```
Component                      RAM
───────────────────────────────────────────────────────────────
Flutter engine (base)          ~80MB
PRoot + Node.js (idle)         ~180MB
PRoot + Node.js (active RPC)   ~250MB
────────────────────────────────────────────
Qwen2.5-0.5B Q4_K_M           ~500MB tensors
Qwen2.5-1.5B Q4_K_M           ~1.1GB tensors  ← Recommended
Qwen2.5-3B Q4_K_M             ~2.1GB tensors
Qwen2-VL-2B Q4_K_M            ~1.4GB + 300MB mmproj
LLaVA-1.5-7B Q4_K_M           ~4.4GB + 600MB mmproj
────────────────────────────────────────────
8GB device available budget:   ~6GB (Android keeps ~2GB)
Safe max: Qwen2.5-3B or Qwen2-VL-2B
7B models: risky on 8GB, OK on 12GB+
```

### Quantization Guide

```
Format    Size (1.5B)  Quality      Speed   Use When
──────────────────────────────────────────────────────────────────
Q2_K      550MB        Poor/incoherent  Fast  Never — too low quality
Q3_K_M    750MB        Acceptable   Fast    Storage < 1GB only
Q4_K_M    1.0GB        Good         Fast    ✅ Default — best balance
Q5_K_M    1.2GB        Better       Med     12GB+ devices
Q6_K      1.4GB        Best native  Med     Diminishing returns vs Q5
Q8_0      1.8GB        ~FP16        Slow    Not worth it on mobile
F16       3.0GB        Reference    Slow    Never on mobile
```

### Thermal Management

```
Observation: Sustained 100% CPU inference causes thermal throttling in 3–7 min on most phones.

Mitigation strategies:
1. Thread cap: SD 8 Gen 3 → 4 threads (P-cores only) instead of 8
   Loses ~15% throughput, runs ~30°C cooler under sustained load

2. Minimum context: Use model.contextWindow.clamp(512, 4096) not full 32768
   KV cache for 32768 context costs 3–4× more RAM + compute than 4096

3. User awareness: Warn users that long-form generation (essays, code)
   will throttle. Short Q&A queries are fine indefinitely.

4. GPU offload (future): Shifts compute from CPU to GPU,
   reducing CPU thermal load significantly
```

---

## 10. Stability & Safety Concerns

### 10.1 fllama Helper Isolate is Unrecoverable if Dead

fllama's helper isolate is spawned once and lives for the app's lifecycle. If it dies (OOM,
unhandled exception), `fllamaChat()` calls will hang forever waiting on `_helperIsolateSendPort`.

**Symptom:** Inference never completes, no error, no timeout.
**Detection:** Look for absence of `[fllama inference isolate]` log lines after a request.
**Mitigation:** Add an inference timeout:
```dart
fllamaChat(request, callback)
    .timeout(const Duration(minutes: 3), onTimeout: () {
      controller.addError('[Error] Inference timed out');
      controller.close();
      return -1;
    });
```

### 10.2 GGUF File Integrity

The download check `file.length() > 1MB` is insufficient. A 1GB file that's 50% downloaded
passes this check but will cause a native crash (SIGSEGV) when llama.cpp tries to read past
the end of the file.

**Better check:**
```dart
// Compare actual size vs expected
final expected = model.fileSizeMb * 1024 * 1024;
final actual = await file.length();
return (actual - expected).abs() / expected < 0.05; // within 5%
```

### 10.3 Model Loading and the "First Call" Delay

fllama does NOT pre-load the model on `_activateFllama()`. The model is loaded on the **first
`fllamaChat()` call**. First call = 5–30 seconds of silence before any token appears.
Subsequent calls (same session, model already in memory) = <500ms TTFT.

**Do NOT call `stop()` between turns.** `stop()` clears `_activeModelPath` but does NOT
unload the model from fllama's memory. A subsequent `downloadAndStart()` will re-activate
(fast path), but the first inference after any `stop()` will re-trigger the model load delay.

**UI recommendation:** Show "Loading model..." state during the first inference call after
activation. Track `_isFirstInference` flag and show spinner accordingly.

### 10.4 Concurrent Inference (Current Gap — see §8.3)

Two simultaneous `fllamaChat()` calls on the same context = undefined behavior in llama.cpp.
This is not currently guarded against. The `_isInferring` guard described in §8.3 must be
added before production release.

### 10.5 Model Files Inside PRoot Rootfs

Model files are stored at `$filesDir/rootfs/root/.openclaw/models/`.
If the user resets the PRoot environment (full reinstall in bootstrap settings), model files
are deleted. Re-download required.

**Future fix:** Move model storage to `$filesDir/models/` (outside rootfs). fllama reads the
host path directly — it doesn't need models inside PRoot. A symlink inside PRoot can be
created for gateway compatibility if needed.

### 10.6 NDK Version Must Be Pinned

`android/app/build.gradle.kts` has:
```kotlin
ndkVersion = "28.2.13676358"
```
**Do not change this without testing.** This version is required by `speech_to_text` (the highest NDK requirement across all plugins). fllama's Dart hook auto-selects the highest installed NDK, so both fllama and speech_to_text are satisfied by this single version. NDK versions are backward-compatible for fllama's C++ code — the constraint is `speech_to_text ≥ 28.2`, not an upper bound.

### 10.7 Hardware Scaling Myth & KV-Cache Context Clamping

For a long time, the Android Low Memory Killer (LMK) crashed the `llama-server` process under PRoot. The assumption was that the processor couldn't handle inference. **This was false.** The crash was caused by the OpenClaw Node.js gateway demanding a 200,000 token context window (the default for cloud APIs like Gemini/Claude). A local 1.5B/3B model attempting to dynamically allocate KV-Cache memory for 200,000 tokens instantly asks for 3GB+ of RAM, resulting in immediate termination.

**Fix Applied (gateway_service.dart `_syncModelToConfig`):**
Whenever a user selects an `ollama/` route, we force `contextWindow: 4096` in the `openclaw.json` provider block. This strictly forces the Node.js agent loop to trim its own context bounds before sending history down to the local hardware, bypassing memory limits safely.

### 10.8 Time-To-First-Token (TTFT) vs. Loss of Tool Scaffolding (The "Gimmick")

The default OpenClaw Node.js agent injects a massive ~27,000 character system prompt to explain its tools and strict XML/JSON routing behavior. 
- **The Speed Issue:** Passing 27,000 characters (7,700 tokens) to a mobile processor causes "prompt processing" to bottleneck for 10–15 seconds before the first token generation begins.
- **The Fix:** In `_syncModelToConfig`, we dynamically hot-swap `.openclaw/agents/main/agent/instructions.md` out for a tiny 84-character native mobile prompt when routing to local models. TTFT drops to sub-500ms.

**The Crucial Trade-off:** By stripping this 27K cloud prompt, the local model completely loses its rigid behavioral "Tool Scaffolding" instructions (e.g., thinking step-by-step before search, error recovery logic). As a result, using local LLMs inside the OpenClaw gateway is currently considered somewhat of a **gimmick** — the local LLM will frequently hallucinate tool usage syntax or ignore tools entirely because the overarching instruction manual is missing.

### 10.9 The AnyClaw Ecosystem Tradeoff

Competitors (like AnyClaw) achieve speed by abandoning Node.js and WebSocket daemons for purely direct binary CLI execution. While infinitely faster and memory-efficient, this approach entirely drops the official OpenClaw gateway and the "ClawHub" skills registry. 

**Our Stance:** The official Gateway is essential for agent capabilities. The future "Holy Grail" architecture (Phase 4, Option C) is a Local Dart HTTP Bridge intercepting port 11434 and routing OpenClaw Node.js requests natively to `fllama`. This achieves AnyClaw's C++ native speeds while fully retaining the robust Gateway ecosystem.

---

## 11. Future Roadmap

```
Phase 1 ─── COMPLETE (2026-03-28) ─────────────────────────────────────►
  fllama NDK inference replaces all PRoot/HTTP inference paths
  Text inference: ✅ working (§8.1–8.7 all done)
  Vision: ✅ working — <img src="data:..."> HTML format confirmed
  Tool-use: ✅ working — multi-turn local dispatch loop (§8.8, commit 9fb122f)
  Gateway: cloud models still via PRoot (unchanged)

Phase 2 ─── GPU Vulkan (in progress) ───────────────────────────────────►
  Enable GGML_VULKAN in fllama NDK build
  Requirements: LLVM (clang++ for vulkan-shaders-gen host build) +
                NDK 26 vulkan.hpp headers (or LunarG Vulkan SDK)
  Adreno Vulkan validation layer (OEM driver bugs on Samsung Exynos/some MediaTek)
  GPU/CPU toggle in diagnostics UI
  Expected: 3–5× throughput (Adreno 730+: ~70–90 tok/s for 1.5B Q4_K_M)

Phase 3 ─── Context Optimization (1 month) ─────────────────────────────►
  fllamaTokenize() for token-accurate history trimming (replaces 4 chars/token heuristic)
  KV cache sharing between turns (avoid full context reload each turn)

Phase 4 ─── PRoot Gateway Modernization (2–4 months) ───────────────────►
  Option A: Trim Ubuntu rootfs to ~30MB (vs current ~700MB download)
            3–4× faster gateway startup, smaller install
  Option B: Replace Node.js gateway with native Dart routing
            Eliminate PRoot entirely for all model types
  Option C: Build a Native Dart HTTP Bridge (The "Shelf" Wrapper)
            - **Goal:** Eliminate the ~200MB memory footprint of the secondary Ollama C++ server inside PRoot.
            - **How:** Because the OpenClaw Node.js agent inherently requires an OpenAI-compliant HTTP endpoint (`/v1/chat/completions`), and `fllama` does not provide an HTTP server natively, we can wrap fllama using Dart's `shelf` and `shelf_router` packages.
            - **Implementation:** The Dart `shelf` server bindings run on port 8080 and act as a proxy. Requests originating from the OpenClaw Node gateway are translated from standard OpenAI JSON into the NDK's native `OpenAiRequest` structure.
            - **Streaming Optimization:** Since fllama's C++ callback explicitly yields a JSON payload string strictly conforming to the OpenAI SSE delta structure (`openaiResponseJsonString`), no post-processing mapping is required. The Dart isolates simply pipe `utf8.encode('data: $responseJson\n\n')` directly into the HTTP chunked stream response.
            - **Impact:** Removes the PRoot redundancy loop safely without destabilizing the Node.js open-source tooling ecosystems OpenClaw requires.

Phase 5 ─── Multi-model / Hot-swap (3–6 months) ────────────────────────►
  _textModel + _visionModel independent instances
  Hot-swap model without full restart
  RAM-aware dual-load (unload text model before loading vision if RAM tight)
```

---

## 12. File Map

### Core Files — Local LLM Path

| File | Role | Status |
|------|------|--------|
| `lib/services/local_llm_service.dart` | Model catalog, download, fllama activation, inference (text+vision), state machine | ✅ Migrated |
| `lib/services/gateway_service.dart` | Routes `local-llm/*` → `LocalLlmService.chat()`, cloud models → WebSocket | ✅ Updated |
| `lib/screens/management/local_llm_screen.dart` | Model selection UI, download progress, diagnostics playground | ✅ Labels updated |
| `lib/constants.dart` | `llamaServerPort/Url` deleted (were unused post-migration) | ✅ Clean |
| `android/app/build.gradle.kts` | NDK pinned to `28.2.13676358`, arm64-v8a only, 16k page size | ✅ Correct |
| `pubspec.yaml` | `fllama: git: url: Telosnex/fllama ref: main` | ✅ Added |

### Supporting Services

| File | Role |
|------|------|
| `lib/services/bootstrap_service.dart` | One-time setup: Ubuntu rootfs download, Node.js, OpenClaw npm install |
| `lib/services/native_bridge.dart` | JNI → Kotlin: `getFilesDir()`, `runInProot()`, `startGateway()` |
| `lib/services/preferences_service.dart` | Persist `configuredModel`, thread count, user settings |
| `lib/services/piper_tts_service.dart` | Reference: uses same model download pattern as local_llm_service |

### fllama Package (Read-Only Reference)

| File | What to look at |
|------|----------------|
| `fllama/lib/fllama.dart` | Main export — imports everything |
| `fllama/lib/fllama_universal.dart` | `fllamaChat()`, `OpenAiRequest`, `Message`, `Role` |
| `fllama/lib/io/fllama_io_inference.dart` | `fllamaInference()`, `fllamaCancelInference()`, threading model |
| `fllama/lib/misc/openai.dart` | `OpenAiRequest` constructor, `Message`, `Role`, `toJsonString()` |
| `fllama/lib/misc/openai_tool.dart` | `Tool` class for function calling |

### PRoot Gateway Files (Separate from Inference)

| File | Role |
|------|------|
| `lib/services/gateway_service.dart` | WS :18789, cloud model routing, `_configureGateway()`, health polling |
| `assets/openclaw/skills/` | Skill .md definitions bundled into PRoot at bootstrap |
| `$filesDir/rootfs/root/.openclaw/openclaw.json` | Gateway config: providers, API endpoints |
| `$filesDir/rootfs/root/.openclaw/agents/main/agent/auth-profiles.json` | Provider auth, `disabledUntil` state |

---

## 13. NativeBridge Contract

**This section is critical for any engineer writing PRoot shell commands.**

```dart
// NativeBridge.runInProot(String command, {int timeout = 30})
//
// Behavior:
//   Executes: /bin/sh -c "<command>"
//   Returns:  stdout as String (on success)
//   Throws:   PlatformException(code: 'PROOT_ERROR') on any non-zero exit code
//
// What this means for you:
//
// 1. POSITIONAL ARGS ($1, $2) ARE NEVER SET
//    The command runs as /bin/sh -c "..." with no positional arguments.
//    $1, $2, etc. expand to empty string. Inline values instead:
//       ❌  'BINARY_URL="$2" && curl "$BINARY_URL"'  ← $2 = empty
//       ✅  'BINARY_URL="$theUrl" && curl "\$BINARY_URL"'  ← inlined
//
// 2. ANY NON-ZERO EXIT THROWS — use try/catch for expected failures:
//       try {
//         final result = await NativeBridge.runInProot('cmd');
//       } catch (e) {
//         // command failed — handle here
//       }
//    DO NOT try to read the error from cliResult — you never reach that line.
//
// 3. FLUTTER mkdir IS NOT VISIBLE TO A FRESH PROOT SPAWN
//    Directory.create() creates on host FS. PRoot mounts rootfs at spawn time.
//    If PRoot is not already running, directories created after the last spawn
//    ARE visible only if they are in the mounted rootfs path.
//    Rule: Let PRoot create directories with mkdir -p when possible.
//
// 4. TIMEOUTS ARE HARD LIMITS
//    runInProot throws PlatformException on timeout too.
//    git clone = no resume, set timeout conservatively.
//    curl with -C - = resume supported, set timeout per-attempt not per-total.
```

---

## 14. Community & Peer Review

### Comparable Projects (for reference)

| Project | Approach | Notes |
|---------|----------|-------|
| **AidanPark/openclaw-android** | Termux + glibc shim + node-llama-cpp | Requires Termux installed separately. 3–4× faster gateway startup. Our inspiration for node-llama-cpp approach. |
| **AnyClaw/openclaw-android-assistant** | Minimal trimmed Termux userland (~5MB vs our ~700MB) | Self-contained APK. Smaller setup. No Ubuntu overhead. |
| **SmolChat-Android** | llama.cpp via JNI (no fllama) | Open source Android GGUF chat. Reference for JNI patterns. |
| **MLC Chat** | MLC-LLM (TVM) + OpenCL GPU | NPU-aware. Best GPU performance but complex toolchain. |
| **Ollama in Termux** | llama.cpp via Ollama | `pkg install ollama`. CPU only, no GPU. No root. |

### Open Questions for Future Engineers

**Q: Thread count optimal value?**
fllama defaults to 2 threads based on benchmarks on Pixel Fold (2024). On Snapdragon 8 Gen 3
(8 cores), 4 threads on P-cores only gives better throughput with acceptable thermals. Should
thread count be auto-detected from `DeviceInfoPlus.cpuCoreCount`?

**Q: Vulkan driver reliability by OEM?**
Samsung Exynos and some MediaTek devices have buggy Vulkan drivers. Before enabling GPU offload,
a validation layer should query `VkPhysicalDeviceProperties.apiVersion` and skip GPU on known
bad versions. Community data on which OEMs are safe would be valuable.

**Q: Context window: clamped vs full?**
We clamp contextSize to `model.contextWindow.clamp(512, 8192)` but the model supports 32768.
Loading a full 32K KV cache takes ~4GB RAM on 1.5B models (the KV cache scales quadratically
with context length). What's the right default cap for mobile devices?

**Q: GGUF file location after PRoot reset?**
Currently models live inside `$filesDir/rootfs/`. If user resets PRoot, models are lost.
Is there a better default location that's independent of the PRoot rootfs lifecycle?

---

*Architecture document maintained by the Plawie development team.*
*For corrections or contributions, open a PR against this file.*
*Last validated against commit `5238893` (2026-03-28).*
