# Android Pack Blocker Phase 5I Audit

Date: 2026-06-10

Status: decision record for the next Android GTM ceiling move.

## Current Truth

The current Android default readiness state remains:

```text
release gate: 13/13, PASS
Android-relevant ready floor: 27/51
unresolved pack blockers: 8
```

The eight unresolved pack blockers after the Phase 5H node-family split are:

```text
coding-agent: android-agent-cli-pack
gemini: android-gemini-cli-pack
gifgrep: android-vision-media-runtime
node-inspect-debugger: android-node-executable-pack
openai-whisper: android-whisper-runtime
sherpa-onnx-tts: android-tts-runtime
songsee: android-audio-runtime
spotify-player: android-audio-runtime
```

Phase 5I intentionally does not raise the ready count. It decides the next
payload lane based on current code, current docs, and credible Android artifact
paths.

## Ranking

### 1. songsee: best next payload lane

Decision: make `songsee` the next implementation target.

Why this is the best next move:

- It is a local audio-to-image skill, so it does not need account auth, browser
  cookies, OAuth, or service API keys.
- Its current source is Go with a small dependency surface.
- The smoke can be fully offline: tiny WAV or MP3 fixture -> PNG/JPEG output.
- It fits the existing dependency-pack verifier model: APK-local binary,
  managed `.openclaw/bin` install, no-shell smoke, receipt only after success.
- It moves the ceiling by a real `+1` without pulling in a large ML model or a
  Node/V8 build project.

Risks and required controls:

- Go is not currently on this Windows host PATH. The implementation round must
  install/use a pinned Go toolchain or a reproducible builder before payload
  work.
- The manifest pack ID remains `android-audio-runtime`, but the first resolver
  must advertise only `songsee`; it must not satisfy `spotify-player`.
- Use a tiny checked-in audio fixture or generated fixture. Do not depend on a
  network service or user media file for the release smoke.
- Count movement happens only after installed-device proof through
  `/device/health`.

Expected honest movement after payload and device proof:

```text
Android ready floor: 27/51 -> 28/51
unresolved pack blockers: 8 -> 7
release gate: unchanged at 13/13
```

### 2. gifgrep: technically plausible, product-gate ambiguous

Decision: do not make `gifgrep` the immediate pack-only target unless the
Android promise is narrowed to local GIF processing or config gates are added.

Why it is tempting:

- It is also Go.
- It has local `still` and `sheet` operations that can be smoked against a tiny
  GIF without network.
- It fits the existing `android-vision-media-runtime` lane.

Why it is not first:

- The user-facing skill promise is GIF search/TUI/download.
- Upstream provider search paths need provider credentials such as
  `GIPHY_API_KEY` or `KLIPY_API_KEY`.
- Marking the whole skill ready from only a local GIF still/sheet smoke would
  be a false-ready risk unless the Skills page says exactly which subset is
  ready.

Allowed future paths:

```text
Option A: local GIF tools only
  Keep the release smoke to gifgrep still/sheet and make the UI say local GIF
  processing is ready while provider search needs API-key config.

Option B: full provider search
  Add config gates for provider keys before moving the skill to ready.
```

### 3. sherpa-onnx-tts: credible but heavy

Decision: viable later, not the next small GTM ceiling move.

Why it is credible:

- Sherpa-ONNX has official Android build docs, Android examples, and prebuilt
  Android shared-library release artifacts.
- It can run offline.

Why it is not next:

- It needs native libraries plus a TTS model policy.
- Models can dominate APK size.
- It needs a product decision around bundled voice, downloadable model pack, or
  optional post-install pack.

Expected order:

```text
Do after songsee, unless we deliberately prioritize offline voice as a major
release feature and accept APK/model work.
```

### 4. openai-whisper: credible but overlaps current API adapter

Decision: keep blocked until a local Whisper runtime/model plan is chosen.

Why it is credible:

- Whisper itself is real and widely used.
- whisper.cpp has Android examples with NDK/CMake support.

Why it is not next:

- OpenAI Whisper upstream is Python/PyTorch-first and heavy for APK-local
  Android.
- A local Android implementation means choosing whisper.cpp or another mobile
  runtime, model size, quantization, fixture audio, and performance gates.
- OpenClaw already has `openai-whisper-api` as a config-gated app-native
  adapter, so the urgent user-facing gap is smaller than it looks.

### 5. node-inspect-debugger: real but low ROI

Decision: keep parked.

Why:

- A true standalone Node executable would move only `node-inspect-debugger`.
- Node's Android support is experimental from the Node side, and Termux's
  nodejs package shows the build is large and patch-heavy.
- This is a high-effort `+1`, and it does not unlock `gemini` or
  `coding-agent`.

### 6. gemini: blocked behind Node plus auth

Decision: do not pursue before standalone Node is solved.

Why:

- Gemini CLI is a Node package and declares Node >= 20.
- It requires Google sign-in, API key, or Vertex AI config.
- A package-only install would not satisfy the Android runtime without a real
  Node executable and auth/config truth.

### 7. coding-agent: blocked behind agent CLI plus auth/sandbox

Decision: do not pursue as a generic pack.

Why:

- The skill needs one real Android-safe CLI from `claude`, `codex`,
  `opencode`, or `pi`.
- A robust implementation needs executable provenance, auth/config, sandbox
  policy, workspace limits, and command-safety gates.
- This is a product/security lane, not a simple binary payload.

### 8. spotify-player: mixed pack/config/auth risk

Decision: do not ship next.

Why:

- `spogo` is Go and technically plausible, but it uses browser cookies.
- `spotify_player` requires Spotify Premium and has audio/system dependencies.
- The current static classification is pack-gated, but the real product needs
  account/auth setup before the user can use it.
- Adding a binary before a mixed pack-plus-config gate risks false readiness.

Required future fix:

```text
Before moving spotify-player, add explicit user setup/config truth for either
spogo cookies or spotify_player auth, and only then package a binary.
```

## Phase 5J Recommendation

Implement `songsee` as the next payload lane:

```text
Phase 5J target: android-audio-runtime, songsee only
expected score movement after device proof: 27/51 -> 28/51
do not move spotify-player
do not add placeholder audio binaries
do not count host-only build success as release proof
```

Minimum implementation requirements:

```text
1. Establish a pinned Go build path for Android arm64.
2. Build a real songsee Android arm64 executable.
3. Add APK-local audio asset lane if current provisioning roots are not enough.
4. Advertise android-audio-runtime only when songsee exists.
5. Install to managed .openclaw/bin through SkillProvisioningService.
6. Smoke with a tiny local audio fixture and output file existence/header check.
7. Prove /device/health reports songsee ready and spotify-player still blocked.
8. Update provenance, third-party notice, GTM plan, and tests.
```

## Source Notes

Primary sources checked during this audit:

- gifgrep repository and install docs:
  https://github.com/steipete/gifgrep and https://gifgrep.com/install.html
- gifgrep Go module and README:
  https://raw.githubusercontent.com/steipete/gifgrep/main/go.mod and
  https://raw.githubusercontent.com/steipete/gifgrep/main/README.md
- songsee repository, release page, Go module, and README:
  https://github.com/openclaw/songsee,
  https://github.com/steipete/songsee/releases,
  https://raw.githubusercontent.com/steipete/songsee/main/go.mod, and
  https://raw.githubusercontent.com/steipete/songsee/main/README.md
- Node.js build/support docs:
  https://raw.githubusercontent.com/nodejs/node/main/BUILDING.md and
  https://nodejs.org/api/process.html
- Termux nodejs build script:
  https://raw.githubusercontent.com/termux/termux-packages/master/packages/nodejs/build.sh
- Gemini CLI README and package metadata:
  https://raw.githubusercontent.com/google-gemini/gemini-cli/main/README.md and
  https://raw.githubusercontent.com/google-gemini/gemini-cli/main/package.json
- OpenAI Whisper README and whisper.cpp Android example:
  https://raw.githubusercontent.com/openai/whisper/main/README.md and
  https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/examples/whisper.android/lib/build.gradle
- Sherpa-ONNX Android docs and release page:
  https://k2-fsa.github.io/sherpa/onnx/android/build-sherpa-onnx.html and
  https://github.com/k2-fsa/sherpa-onnx/releases
- spogo and spotify-player repositories:
  https://github.com/openclaw/spogo and
  https://github.com/aome510/spotify-player

