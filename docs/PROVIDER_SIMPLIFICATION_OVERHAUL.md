# Provider Simplification Overhaul

Last updated: 2026-05-23

## Decision

Plawie will no longer present embedded Ollama Local or Ollama Cloud as normal
model routes. The 1.30 GB Ollama daemon path adds too much device pressure,
mobile-data risk, and user confusion for the current Play Store launch target.

The production model contract is now:

| Mode | Route | Runtime | Gateway | User promise |
| --- | --- | --- | --- | --- |
| Cloud Agent Mode | `google/`, `anthropic/`, `openai/`, `xai/`, `openrouter/`, `groq/` | OpenClaw Gateway | Yes | Full tools, skills, dashboard, BYO provider key |
| Private Offline Mode | `local-llm/...` | NDK fllama | No | Offline/private chat and direct app actions |
| Legacy Ollama | `ollama/...` | Embedded daemon | Legacy only | Hidden from UI; stale prefs migrate to safe cloud fallback |

## Stability Baseline

- Live phone check on 2026-05-23 showed `com.nxg.openclawproot`, `libproot.so`,
  and `openclaw` alive.
- No `ollama` process was running.
- Device pairing and node command declaration were healthy in the latest baseline
  logs before NDK-heavy testing.
- One gateway health probe timeout while Flutter detached is not enough evidence
  of gateway regression; the likely stressor is local NDK inference pressure.
- Follow-up ADB check confirmed listeners on `127.0.0.1:18789` and
  `127.0.0.1:8765`, no `ollama` process, and no app crash/ANR pattern. Detached
  FlutterJNI log-forward warnings are expected when the Flutter UI is backgrounded
  while the foreground service keeps streaming logs.

## Implementation Checklist

- [x] Verify gateway/node process stability before changing routing.
- [x] Declare the new provider contract in docs.
- [x] Remove Ollama Local and Ollama Cloud from first-run setup choices.
- [x] Remove Ollama models from chat/settings default model pickers.
- [x] Migrate stale `ollama/...` preferences to the safe cloud fallback.
- [x] Remove low-level Ollama install/start/stop/status methods from Dart and
  Android native code.
- [x] Reframe Local LLM page as NDK Offline Mode only.
- [x] Remove/disable surprise Ollama runtime install/download prompts.
- [x] Add explicit NDK Gateway bridge experiment on `127.0.0.1:11435` without
  making it a production default.
- [x] Fix camera/canvas snapshot UX so captured images attach to chat instead of
  forcing an unclosable full overlay.
- [x] Update README, Help, and architecture docs.
- [x] Run `flutter analyze`.
- [x] Run a debug APK build.

## Verification Results

- `flutter analyze` passes with no issues.
- `flutter build apk --debug` passes and produces
  `build/app/outputs/flutter-apk/app-debug.apk`.
- Gateway health/dashboard code no longer starts or prepares a local Ollama
  runtime.
- NDK fllama analyzer cleanup preserves the native OpenAI-compatible request
  path and removes dead Dart fallback code.
- Targeted grep confirms no `ollama serve`, `11434`, `installOllama`,
  `startOllama`, `stopOllama`, or hidden local API route remains in `lib/` or
  `android/`.

## Non-Goals For This Pass

- Do not enable an HTTP NDK bridge as a Gateway provider by default.
- Do not change the gateway boot/pairing hardening unless required by analysis.

## Verification Matrix

| Scenario | Expected result |
| --- | --- |
| Fresh install, Gemini/Grok/OpenAI/etc. | Setup finishes with gateway ready and no Ollama daemon required |
| Returning user with stale `ollama/kimi...` pref | App silently migrates to safe cloud fallback |
| Chat cloud model with missing key | User is blocked with clear API-key guidance |
| Local LLM page | Shows NDK/offline model downloads only |
| NDK model active | Chat bypasses Gateway and does not call `talk.speak` or Ollama |
| Camera/canvas tool captures | Image appears in chat bubble and does not trap the UI |
