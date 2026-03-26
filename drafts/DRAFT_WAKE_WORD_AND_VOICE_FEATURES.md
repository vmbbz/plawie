# DRAFT — Wake Word "Plawie" + Advanced Voice Features
**Status:** ✅ Complete (All Phases 4a–4d) — implemented 2026-03-26 | **Priority:** P2 | **Phase:** 4
**Reference:** yuga-hashimoto/openclaw-assistant — HotwordService.kt, OpenClawSession.kt, SpeechRecognizerManager.kt

---

## Features in Scope

1. **Wake word "Plawie"** — hands-free activation, fully offline (Vosk)
2. **Continuous mode** — auto-restart listening after every response
3. **Silence timeout** — configurable how long to wait before auto-submitting
4. **Dynamic agent fetching** — discover agents from gateway at runtime (no hardcoded list)

---

## 1. Wake Word Detection — "Plawie"

### Competitor Approach
- **Engine:** Vosk (offline Kaldi-based ASR)
- `HotwordService` — Android foreground service, continuous mic loop
- Sensitivity: 0.0–1.0 (default 0.7), configurable
- Modes: Off / Foreground (only when app open) / Always (background)
- Barge-in: can interrupt TTS when wake word detected
- 5-minute watchdog auto-recovery

### Our Approach

**Option A: Vosk (same as competitor) — RECOMMENDED**
- Vosk Android library: `io.github.alphacephei:vosk-android:0.3.47`
- Tiny English model: `vosk-model-small-en-us-0.15` (~40MB)
- Add to `android/app/build.gradle`, download model on first run
- New Kotlin service: `android/app/src/main/kotlin/.../HotwordService.kt`
- Foreground service with microphone, runs independently of the main activity

**Option B: pocketsphinx Flutter — lower quality, simpler**
Not recommended — less accurate than Vosk.

**Option C: Custom keyword in speech_to_text — hacky, not reliable**
Not recommended.

### Implementation (Option A)

**New files:**
- `android/.../HotwordService.kt` — foreground service, Vosk mic loop
- `android/.../WakeWordReceiver.kt` — BroadcastReceiver to bridge native→Flutter
- Add to `AndroidManifest.xml`: service declaration, `FOREGROUND_SERVICE` permission

**Flutter side:**
- New platform channel `com.nxg.openclawproot/hotword`
- `startHotword()` / `stopHotword()` / `setMode(off/foreground/always)`
- Flutter listens for `EventChannel` events: `{event: "wake_word_detected"}`

**Keyword activation flow:**
```
HotwordService → detects "Plawie" → sends broadcast
  → WakeWordReceiver → EventChannel → ChatScreen
  → ChatScreen activates mic (same as tapping mic button)
  → Normal speech → submit → response → TTS
  → If continuous mode: restart listening
```

**Wake words list:** `["plawie", "hey plawie", "ok plawie"]`

---

## 2. Continuous Listening Mode

### What it does
After TTS finishes speaking:
- If `continuousMode = true`: wait 500ms → restart STT automatically
- Creates indefinite conversational loop until user taps stop or says nothing for silence timeout

### Implementation (Pure Dart — no native changes)
In `lib/screens/chat_screen.dart`, after `_piperTts.onComplete` / `TtsService.onComplete`:

```dart
// In _handleSubmit, after TTS fires:
_piperTts.onComplete = () {
  if (mounted) {
    setState(() => _speechIntensity = 0.0);
    if (_continuousMode && !_isGenerating) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isGenerating) _startListening();
      });
    }
  }
};
```

`_continuousMode` bool loaded from `PreferencesService`.

---

## 3. Silence Timeout

### Competitor approach
Injects 3 Android intent extras into the `SpeechRecognizer` intent:
- `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS`
- `EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS`
- `android.speech.extras.SPEECH_INPUT_MINIMUM_LENGTH_MILLIS`

### Our approach
`speech_to_text` v7 passes `listenOptions` to the Android recogniser.
Add to `NativeBridge.kt` or directly in the `SpeechToText.listen()` call:

```dart
await _speechToText.listen(
  onResult: _onSpeechResult,
  listenOptions: SpeechListenOptions(
    listenMode: ListenMode.confirmation, // stops on silence
    cancelOnError: true,
  ),
);
```

For the raw Android extras (finer control), we may need a method channel call.
**Lower priority** — the `listenMode: confirmation` in speech_to_text gives reasonable silence detection.

---

## 4. Dynamic Agent Fetching

### Competitor approach (protocol v3)
- `agents.list` RPC → `{defaultAgent, agents: [{id, name}]}`
- No hardcoded agents — all discovered at runtime from the gateway
- `sessions.list` → parses live sessions

### Current state in our app
- `_selectedModel` in `ChatScreen` is hardcoded to `'google/gemini-3.1-pro-preview'`
- Model list in the model selector dropdown is hardcoded
- No dynamic agent/session discovery

### Our approach
**New method on `GatewayService`:**
```dart
Future<List<AgentInfo>> fetchAgents() async {
  final frame = await invoke('agents.list');
  // Parse agents array from frame
}

Future<List<SessionInfo>> fetchSessions() async {
  final frame = await invoke('sessions.list');
}
```

**In ChatScreen:**
- On gateway connect, call `fetchAgents()` → populate model/agent dropdown dynamically
- Add session switcher button to the chat header
- Default to gateway's `defaultAgent` when no selection exists

**Why this matters:** When new OpenClaw skills (Twilio, MoonPay) are installed, they register as agents. Currently users have to know the agent ID. Dynamic fetch shows them in the UI automatically.

---

## Settings Screen Additions (Voice & Node)

```
Voice & Speech
──────────────────────────────────────────
TTS Engine          [Piper (Offline) ▼]
Speech Speed        [────●──────────]  1.2×
Continuous Mode     [●] ON              ← toggle
Silence Timeout     [────────●──────]  5 s

Wake Word
──────────────────────────────────────────
Wake Word "Plawie"  [●] ON
  Mode              [Foreground ▼]       ← Off / Foreground / Always
  Sensitivity       [────●──────────]  0.7
  Barge-in TTS      [○] OFF
```

---

## Phase Order

| Phase | Feature | Risk | Complexity |
|-------|---------|------|-----------|
| 4a | Continuous mode | LOW | 20 lines Dart |
| 4b | Dynamic agent fetch | LOW | 50 lines Dart |
| 4c | Silence timeout via speech_to_text options | LOW | 5 lines |
| 4d | Wake word "Plawie" (Vosk) | HIGH | New Kotlin service + native integration |

**Recommendation:** Ship 4a–4c first. Wake word (4d) is the most impactful feature but requires the most native work. Do it after TTS engine selection and video vision are stable.

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `android/.../HotwordService.kt` | CREATE (Phase 4d) |
| `android/.../WakeWordReceiver.kt` | CREATE (Phase 4d) |
| `android/app/src/main/AndroidManifest.xml` | MODIFY — service declaration (4d) |
| `android/app/build.gradle` | MODIFY — add Vosk dependency (4d) |
| `lib/services/native_bridge.dart` | MODIFY — hotword channel methods (4d) |
| `lib/services/gateway_service.dart` | MODIFY — fetchAgents(), fetchSessions() (4b) |
| `lib/screens/chat_screen.dart` | MODIFY — continuous mode, dynamic agents (4a+4b) |
| `lib/screens/settings_screen.dart` | MODIFY — Voice & Speech section |
| `lib/services/preferences_service.dart` | MODIFY — add new settings keys |

---

## Dependencies Needed (Phase 4d only)

```gradle
// android/app/build.gradle
implementation 'io.github.alphacephei:vosk-android:0.3.47@aar'
implementation 'net.java.dev.jna:jna:5.13.0@aar'
```

Vosk model (~40MB) downloaded to PRoot `/root/.openclaw/models/vosk/` on first enable.
