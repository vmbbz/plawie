# DRAFT — Video Vision AI (Offline + Cloud)
**Status:** ✅ Complete (Phases 3a–3d) — implemented 2026-03-26 | Phase 3e (screen recording) deferred | **Priority:** P1 | **Phase:** 3
**Reference:** yuga-hashimoto/openclaw-assistant — CameraCaptureManager.kt, ScreenRecordManager.kt
**Builds on:** Vision AI photo support (implemented this session)

---

## What the Competitor Does

### camera.clip
- CameraX `VideoCapture`, LOWEST quality
- Duration: 200ms–60,000ms (default 3,000ms)
- Audio: optional (default true)
- Output: PUT to `https://<gateway>/upload/clip.mp4` with Bearer auth, OR base64 in WebSocket
- The AI gateway receives the video URL and calls the upstream multimodal API

### screen.record
- `MediaProjection` + `VirtualDisplay` + `MediaRecorder` (H264/AAC)
- Duration: 250ms–60s, FPS: 1–60, optional audio
- Returns base64 MP4 in response payload
- Requires foreground service + `MEDIA_PROJECTION` type on Android 14+

### No realtime streaming
There is no live camera feed to the AI. All video is triggered on-demand (record N seconds → send → get response).

---

## Our Approach

### Offline Video Vision — Frame Extraction Strategy
*True offline video LLMs (Qwen2-VL Video, LLaVA-Video) are 7B+ — too large for most phones.*

**Strategy: record short clip → extract frames → send key frames to local vision model**

```
User: "What is in front of me?" + 📹 button
    → Record 3s clip (CameraX, our existing camera pkg)
    → Extract 1 frame per second = 3 JPEG frames
    → Send each frame to local llama-server (Qwen2-VL or LLaVA)
    → Combine responses: "Frame 1: desk with laptop. Frame 2: coffee cup..."
    → Summarise: ask model to summarise the 3 descriptions into one
```

**Pros:** Works 100% offline with Qwen2-VL 2B we've already added.
**Cons:** Not realtime; 3 inference passes per clip (~30s on mobile).

### Cloud Video Vision — Gemini Native
Gemini 1.5 / 2.0 Pro natively supports video as inline_data or file_uri:
```json
{
  "parts": [
    { "inline_data": { "mime_type": "video/mp4", "data": "<base64>" } },
    { "text": "Describe what is happening in this video" }
  ]
}
```
This goes through the existing OpenClaw Node.js gateway — the gateway already proxies to Gemini.
The gateway's `/v1/chat/completions` accepts multipart content if we format the message correctly.

**Max inline video size:** 20MB (Gemini). For 3s clips at LOWEST quality ≈ 500KB–2MB. Fits.

### Realtime / Continuous Vision
Not "streaming" — instead a polling loop:
```
User holds "Live Vision" button
  → Every 2 seconds: take photo → send to vision model → stream result to chat
  → Stops when user releases button
```
This gives "near-realtime" awareness without actual video streaming to the model.

---

## Implementation Plan

### Phase 3a — Short Video Clip Capture (Dart side)
**New service:** `lib/services/video_capture_service.dart`

Uses the `camera` package (already installed) with `startVideoRecording()` / `stopVideoRecording()`.
Duration: configurable 2s–30s (default 5s).
Output: MP4 bytes in memory.

```dart
class VideoCaptureService {
  Future<Uint8List> recordClip({int durationMs = 5000, bool frontCamera = false});
}
```

### Phase 3b — Frame Extraction (offline path)
**New utility:** `lib/utils/video_frame_extractor.dart`

Options:
1. **Pure Dart:** Use `video_compress` or `flutter_ffmpeg` to extract frames
2. **Shell in PRoot:** `ffmpeg -i /tmp/clip.mp4 -vf fps=1 /tmp/frame%d.jpg` (ffmpeg binary in PRoot)

PRoot ffmpeg approach is most reliable since we already have a Linux environment.

```dart
// Extract 1 frame per second as JPEG
Future<List<Uint8List>> extractFrames(Uint8List mp4Bytes, {int fps = 1}) async {
  // Write mp4 to PRoot /tmp
  // Run: ffmpeg -i /tmp/clip.mp4 -vf fps={fps} /tmp/frame%03d.jpg -y
  // Read back frame files
  // Return list of JPEG bytes
}
```

### Phase 3c — Multi-frame Vision Analysis
**Add to `LocalLlmService`:**
```dart
Stream<String> analyseVideoFrames(List<Uint8List> frames, String prompt) async* {
  final descriptions = <String>[];
  for (int i = 0; i < frames.length; i++) {
    final base64 = base64Encode(frames[i]);
    // POST to llama-server :8081 with image_url content (reuse sendVisionMessage)
    final desc = await _singleFrameAnalysis(base64, 'Frame ${i+1}: Briefly describe what you see.');
    descriptions.add('Frame ${i+1}: $desc');
    yield 'Analysing frame ${i+1}/${frames.length}...'; // progress update
  }
  // Final summary pass
  final summary = await _singleFrameAnalysis(
    null,
    'Given these frame descriptions, summarise the scene:\n${descriptions.join("\n")}\n\nUser question: $prompt',
  );
  yield summary;
}
```

### Phase 3d — Cloud Video (Gemini inline)
**Add to `GatewayService`:**
```dart
Stream<String> sendVideoMessage(String prompt, Uint8List mp4Bytes) async* {
  // POST to gateway /v1/chat/completions with Gemini multipart format
  // inline_data mime_type: "video/mp4"
}
```

Only activates when local vision model is NOT active (route to cloud as fallback).

### Phase 3e — Screen Recording (Android only)
Requires native Kotlin: `MediaProjection` foreground service.
**Lower priority** — implement after 3a–3d ship.
File: `android/app/src/main/kotlin/com/nxg/openclawproot/ScreenRecordManager.kt`

---

## Chat UI Changes

Add a 📹 video button next to the 📷 camera button in the input bar.
Long-press → shows duration picker (3s / 5s / 10s / 30s).
Tap → records clip, shows thumbnail with "⏱ 5s clip" label.
Send → routes to offline frames or cloud video based on active model.

---

## Files to Create/Modify
| File | Action |
|------|--------|
| `lib/services/video_capture_service.dart` | CREATE |
| `lib/utils/video_frame_extractor.dart` | CREATE |
| `lib/services/local_llm_service.dart` | MODIFY — add `analyseVideoFrames()` |
| `lib/services/gateway_service.dart` | MODIFY — add `sendVideoMessage()` for cloud |
| `lib/screens/chat_screen.dart` | MODIFY — add video button, clip thumbnail, video routing |
| `android/.../ScreenRecordManager.kt` | CREATE (Phase 3e only) |

---

## Dependencies Needed
| Package | Purpose | Already installed? |
|---------|---------|-------------------|
| `camera` | Video recording | YES (0.11.0) |
| `ffmpeg_kit_flutter` | Frame extraction | NO — add to pubspec |

Alternative (no new dep): use PRoot `ffmpeg` binary — avoids adding a large native library.
**Recommendation:** PRoot ffmpeg approach. Install via `apt-get install -y ffmpeg` in setup script.

---

## Risk Assessment
- Phase 3a (capture) — LOW: reuses existing camera package
- Phase 3b (frames via PRoot ffmpeg) — MEDIUM: need ffmpeg in PRoot setup
- Phase 3c (multi-frame analysis) — LOW: reuses existing vision pipeline
- Phase 3d (Gemini cloud) — LOW: HTTP only, no native changes
- Phase 3e (screen record) — HIGH: requires new Kotlin foreground service
