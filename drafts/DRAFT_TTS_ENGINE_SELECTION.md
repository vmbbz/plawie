# DRAFT — TTS Engine Selection & Voice Settings
**Status:** ✅ Complete — implemented 2026-03-26 | **Priority:** P1 | **Phase:** 2
**Reference:** yuga-hashimoto/openclaw-assistant — TTSManager.kt, SettingsRepository.kt

---

## Problem

Currently Piper (sherpa-onnx VITS) is the only TTS option. Users cannot:
- Adjust speech speed
- Switch to Android's built-in TTS voices (already installed on device)
- Use cloud TTS for higher quality (ElevenLabs, OpenAI)
- Choose between offline and online voice

The competitor exposes 4 engines + speed control as a standard settings screen.

---

## What We Already Have (no new installs needed)

| Package | Already in pubspec? | Purpose |
|---------|-------------------|---------|
| `sherpa_onnx` 1.12.28 | YES | Piper VITS offline TTS |
| `flutter_tts` 4.2.5 | YES | Android/iOS native TTS + engine enumeration |
| `audioplayers` 6.6.0 | YES | WAV playback for Piper |

`flutter_tts` already lets us:
- `getEngines()` — list all TTS engines installed on the device (Google, Samsung, Microsoft, etc.)
- `setEngine(engine)` — switch between them at runtime
- `setSpeechRate(rate)` — 0.0–1.0 (maps to competitor's speed slider)
- Works offline with device voices, no API key needed

---

## Proposed Architecture

```
TtsService (new facade — lib/services/tts_service.dart)
  ├── PiperEngine      → existing PiperTtsService (sherpa VITS, offline, best quality)
  ├── NativeEngine     → flutter_tts (AndroidTTS / iOS AVSpeechSynthesizer)
  ├── ElevenLabsEngine → HTTP to api.elevenlabs.io/v1/text-to-speech (needs API key)
  └── OpenAiEngine     → HTTP to api.openai.com/v1/audio/speech (reuses existing API key)
```

All engines share a common interface:
```dart
abstract class TtsEngine {
  Future<void> speak(String text);
  Future<void> stop();
  bool get isReady;
  String get id;      // 'piper' | 'native' | 'elevenlabs' | 'openai'
  String get label;   // display name
}
```

`TtsService` reads engine preference from `PreferencesService` and delegates. The rest of the app calls `TtsService().speak(text)` — no other file changes needed.

---

## Settings UI (Voice & Node Settings)

Add to `lib/screens/settings_screen.dart`:

```
Voice & Speech
──────────────
TTS Engine:     [Piper (Offline) ▼]   ← dropdown: Piper / Android / OpenAI / ElevenLabs
Speech Speed:   [────●──────────]  1.2×  ← slider 0.5×–2.0×
Continuous Mode [○]                     ← auto-restart listening after response
Silence Timeout [────●──────────]  5 s  ← slider 1s–15s

(if ElevenLabs selected)
  ElevenLabs API Key: [••••••••••••]
  Voice: [Rachel ▼]

(if OpenAI selected)
  Voice: [Coral ▼]   (alloy, echo, shimmer, fable, onyx, nova, coral…)
  Model: [gpt-4o-mini-tts ▼]
```

---

## Implementation Plan

### Step 1 — Speed control on Piper (1 line — already done this session)
`piper_tts_service.dart` now has `double speed = 1.0`. Wire a slider in the settings screen.

### Step 2 — Add `TtsService` facade
New file: `lib/services/tts_service.dart`
- Reads `PreferencesService.ttsEngine` (piper/native/elevenlabs/openai)
- Reads `PreferencesService.ttsSpeed` (default 1.2)
- Delegates `speak()` and `stop()` to the appropriate engine
- Fires `onStart` / `onComplete` so VRM lip-sync still works

### Step 3 — NativeEngine via flutter_tts
Already installed. Wrap `FlutterTts`:
```dart
class NativeTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  Future<void> speak(String text) async {
    await _tts.setSpeechRate(TtsService().speed);
    await _tts.speak(text);
  }
}
```
Engine list from `flutterTts.getEngines()` populates the dropdown automatically.

### Step 4 — ElevenLabsEngine
HTTP POST to `https://api.elevenlabs.io/v1/text-to-speech/{voiceId}`.
Speed: `voice_settings.speed` clamped to 0.7–1.2 (per competitor).
Play MP3 bytes via `audioplayers`.

### Step 5 — OpenAiEngine
HTTP POST to `https://api.openai.com/v1/audio/speech`.
Reuse existing OpenAI API key from `openclaw.json`.
13 voices, 3 model tiers.

### Step 6 — Wire chat_screen.dart
Replace:
```dart
final PiperTtsService _piperTts = PiperTtsService();
```
with:
```dart
final TtsService _tts = TtsService();
```
and update all `_piperTts.*` calls.

---

## Continuous Mode + Silence Timeout
(From competitor — `OpenClawSession.kt`, `SpeechRecognizerManager.kt`)

**Continuous mode:** After TTS `onComplete` fires, if enabled → wait 500ms → restart STT.
Implemented entirely in `ChatScreen._handleSubmit` / `_startListening` — no native changes.

**Silence timeout:** `speech_to_text` already accepts `listenOptions.sampleRate` and related params,
but Android silence timeout must be injected via Android-side intent extras.
→ Add to `ProcessManager.kt` or `NativeBridge` as a platform channel call.
→ Lower priority — default Android behaviour (usually 5s) is acceptable.

---

## Files to Create/Modify
| File | Action |
|------|--------|
| `lib/services/tts_service.dart` | CREATE — engine facade |
| `lib/services/engines/native_tts_engine.dart` | CREATE |
| `lib/services/engines/elevenlabs_tts_engine.dart` | CREATE |
| `lib/services/engines/openai_tts_engine.dart` | CREATE |
| `lib/services/piper_tts_service.dart` | MODIFY — add speed field ✅ done |
| `lib/screens/settings_screen.dart` | MODIFY — add Voice & Speech section |
| `lib/screens/chat_screen.dart` | MODIFY — swap PiperTtsService → TtsService |
| `lib/services/preferences_service.dart` | MODIFY — add ttsEngine, ttsSpeed keys |

---

## Risk: Nothing breaks
- All changes behind the TtsService facade
- Piper is the default — existing behaviour unchanged unless user switches
- `flutter_tts` already in pubspec — no new dependencies for Steps 1–3
- ElevenLabs / OpenAI are HTTP-only — no native modules
