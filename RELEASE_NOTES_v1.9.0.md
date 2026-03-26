# Release v1.9.0 — "Voice-First World"

**Release Date:** March 26, 2026
**Version:** 1.9.0
**Baseline:** v1.7.2 (commit `cfa053f`)
**Flutter analyze:** 0 errors across all `lib/`

---

## Overview

This release delivers four major feature phases that transform Plawie from a text-first AI chat app into a full voice-first, vision-capable, hands-free AI companion — all running locally on your Android device.

---

## New Features

### 🎙️ Phase 2 — Multi-Engine TTS & Voice Control

**4 selectable TTS engines**, accessible from Settings → Voice & Speech:

| Engine | Type | Notes |
|--------|------|-------|
| **Piper** | Offline (default) | sherpa-onnx VITS — best quality, zero internet |
| **Android Native** | Offline | Uses device-installed voices (Google, Samsung, etc.) |
| **ElevenLabs** | Cloud | Ultra-realistic voices; requires API key |
| **OpenAI TTS** | Cloud | 13 voices (alloy, coral, shimmer…); reuses your OpenAI key |

**Additional controls:**
- **Speech Speed** — 0.5×–2.0× slider, default 1.2×
- **Continuous Mode** — auto-restarts mic 500ms after TTS finishes; enables hands-free conversation loops
- **Silence Timeout** — 1s–15s configurable; submitted via `listenMode: confirmation`

**Files created:**
- `lib/services/tts_service.dart` — facade singleton
- `lib/services/engines/tts_engine.dart` — abstract interface
- `lib/services/engines/piper_tts_engine.dart`
- `lib/services/engines/native_tts_engine.dart`
- `lib/services/engines/elevenlabs_tts_engine.dart`
- `lib/services/engines/openai_tts_engine.dart`

**Files modified:** `lib/screens/chat_screen.dart`, `lib/screens/settings_screen.dart`, `lib/services/preferences_service.dart`

---

### 📹 Phase 3 — Video Vision AI (Offline + Cloud)

Your agent can now watch and understand video.

**Offline path (when local vision model is active):**
1. Tap 📹 in the chat input bar; choose clip duration (3s / 5s / 10s / 30s)
2. Camera records clip via `camera` package (`ResolutionPreset.low`)
3. MP4 written to PRoot-mapped path; `ffmpeg -vf fps=1 -frames:v N` extracts JPEG frames
4. Each frame POSTed to `llama-server :8081/v1/chat/completions` with vision payload
5. Summary pass produces coherent scene description — **100% offline**

**Cloud path (when no local vision model is active):**
- MP4 base64 encoded and sent inline to Gemini 1.5/2.0 Pro via OpenClaw gateway
- Routing: `GatewayService.sendCloudVideoMessage()` → `POST /v1/chat/completions` with `data:video/mp4;base64,...` content block

**Files created:**
- `lib/services/video_capture_service.dart`
- `lib/utils/video_frame_extractor.dart`

**Files modified:** `lib/services/local_llm_service.dart` (`analyseVideoFrames()` stream), `lib/services/gateway_service.dart` (`sendCloudVideoMessage()`), `lib/providers/gateway_provider.dart`, `lib/screens/chat_screen.dart`

---

### 🤖 Phase 4a–4c — Continuous Mode, Dynamic Agents, Silence Timeout

**Dynamic Agent Fetching:**
- `GatewayService.fetchAgents()` calls `agents.list` RPC on gateway connect
- Returns `{defaultAgent, agents:[{id,name}]}`
- Agents appear automatically in the model picker dropdown — no hardcoded list
- New model: `lib/models/agent_info.dart`

**Continuous Mode:**
- `TtsService.onComplete` hook: if `PreferencesService.continuousMode == true && !_isGenerating`, restart mic after 500ms
- Creates fully hands-free conversation loop until user taps stop

**Silence Timeout:**
- `_speechToText.listen(pauseFor: Duration(seconds: silenceTimeoutSeconds), listenOptions: SpeechListenOptions(listenMode: ListenMode.confirmation, cancelOnError: true))`
- Default 5s; configurable 1s–15s in Settings

---

### 🗣️ Phase 4d — Wake Word "Plawie" (Vosk, Fully Offline)

Say *"Plawie"*, *"Hey Plawie"*, or *"OK Plawie"* to activate your agent, hands-free, from anywhere.

**Architecture:**
```
HotwordService (Kotlin foreground service)
  └── Vosk RecognizerThread (grammar-constrained)
       ↓ "plawie" detected
  LocalBroadcastManager → ACTION_WAKE_WORD_DETECTED
       ↓
  MainActivity BroadcastReceiver → EventChannel.EventSink
       ↓ "wake_word_detected"
  Flutter ChatScreen._hotwordSub → _startListening()
```

**Key implementation details:**
- **Vosk model:** `vosk-model-small-en-us-0.15` (~40MB) auto-downloaded to `filesDir/vosk_model` on first enable
- **Grammar:** `["plawie", "hey plawie", "ok plawie", "play we", "[unk]"]` — dramatically reduces false positives vs full speech recognition
- **5-minute watchdog:** auto-restarts Vosk thread on silence/crash
- **3 modes:** Off / Foreground only / Always-on (persisted in `PreferencesService.wakeWordMode`)
- **Settings indicator:** live status dot (green running / grey stopped)

**Files created:**
- `android/app/src/main/kotlin/.../HotwordService.kt`

**Files modified:**
- `android/app/src/main/kotlin/.../MainActivity.kt` — hotword EventChannel + MethodChannel + BroadcastReceiver
- `android/app/src/main/AndroidManifest.xml` — `RECORD_AUDIO`, `FOREGROUND_SERVICE_MICROPHONE`, `HotwordService` declaration
- `android/app/build.gradle.kts` — `vosk-android:0.3.47`, `jna:5.13.0`
- `lib/services/native_bridge.dart` — `startHotword()`, `stopHotword()`, `setHotwordMode()`, `isHotwordRunning()`, `hotwordEvents` stream
- `lib/screens/settings_screen.dart` — Wake Word section with mode picker and status indicator

---

## Bug Fixes & Infrastructure

- `TtsService.init()` renamed from `initPiper()` for consistency with the new facade pattern
- `pauseFor` moved to top-level `listen()` parameter (was incorrectly nested in `SpeechListenOptions`)
- `catchError` handlers in `GatewayService` and `VideoFrameExtractor` now return correct typed values
- Unused variable cleanup in `video_frame_extractor.dart` and `video_capture_service.dart`
- `import 'package:flutter/foundation.dart'` added to OpenAI TTS engine for `debugPrint` + `Uint8List`

---

## Architecture Changes

### New Services
| File | Purpose |
|------|---------|
| `lib/services/tts_service.dart` | Multi-engine TTS facade |
| `lib/services/engines/*.dart` | Piper / Native / ElevenLabs / OpenAI engine impls |
| `lib/services/video_capture_service.dart` | CameraX-based clip recording |
| `lib/utils/video_frame_extractor.dart` | PRoot ffmpeg frame extraction |
| `lib/models/agent_info.dart` | Agent model for dynamic discovery |

### New Android Components
| File | Purpose |
|------|---------|
| `android/.../HotwordService.kt` | Vosk foreground service + watchdog |

### New Preferences Keys
| Key | Type | Default |
|-----|------|---------|
| `tts_engine` | String | `'piper'` |
| `tts_speed` | double | `1.2` |
| `continuous_mode` | bool | `false` |
| `silence_timeout_seconds` | int | `5` |
| `elevenlabs_api_key` | String? | `null` |
| `elevenlabs_voice_id` | String | `'EXAVITQu4vr4xnSDxMaL'` |
| `openai_api_key_tts` | String? | `null` |
| `openai_tts_voice` | String | `'coral'` |
| `openai_tts_model` | String | `'gpt-4o-mini-tts'` |
| `wake_word_mode` | String | `'off'` |

---

## Upgrade Path

This release is fully backward-compatible. All new features default to off or the prior Piper-only behaviour. No migration steps required.

---

## Remaining Roadmap (Post-1.9.0)

| Feature | Priority | Status |
|---------|---------|--------|
| Offline Whisper STT | P1 | Pending |
| Context compaction (auto-summarise at 4096 ctx) | P2 | Pending |
| Inference parameter tuning UI (temp, top-p, system prompt) | P3 | Pending |
| Multimodal model catalog (LLaVA-1.5, Qwen2-VL) + `--mmproj` flag | P4 | Pending |
| LAN Ollama/LM Studio discovery | P5 | Pending |
| Screen recording vision (MediaProjection) | P3e | Pending |

---

*Release prepared by AI Architecture Session — Claude Sonnet 4.6*
