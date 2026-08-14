# OpenClaw Official Android Client: Voice Presence, PiP, Persistence, and Avatar Audit

**Audit date:** 2026-08-14<br>
**Upstream scope:** [`openclaw/openclaw/apps/android/app`](https://github.com/openclaw/openclaw/tree/main/apps/android/app)<br>
**Upstream snapshot:** `8a9c7324f83975b0eafe109e7c3360c0b75c177d`<br>
**Local comparison:** Plawie/OpenClaw Flutter Android client in this repository<br>
**Method:** source and documentation audit; no emulator, physical-device, battery-OEM, or Play-policy experiment is claimed here.

## Executive conclusion

The official Android client is more complete in voice than a superficial screen review suggests. It already has:

- a dedicated Voice tab;
- Realtime Talk with continuous capture, streaming input/output levels, transcripts, playback, interruption support, and push-to-talk fallback;
- a native voice orb/waveform with explicit idle, listening, thinking, and speaking phases;
- an on-device Voice Wake manager with Gateway-synchronised trigger words;
- a real `NodeForegroundService` for authenticated node presence and voice-capture visibility;
- Wear OS realtime Talk through the paired phone;
- static per-agent avatar images and an animated 2D OpenClaw mascot.

The most valuable upstream suggestions are therefore not “add continuous talk” or “add avatars” in the broad sense. Those capabilities exist in partial or specific forms. The high-value gaps are:

1. **A first-class compact voice surface, including Android PiP.** The official app has no explicit PiP or external overlay implementation. Voice Talk is a full-screen Compose experience.
2. **A shared lifecycle contract for voice continuity.** The node service persists, but Voice Wake and new PTT capture are deliberately foreground-bound. That policy is defensible, yet it is easy for users to experience it as voice unexpectedly stopping or becoming unavailable.
3. **A persistent visual voice companion.** The official app has a waveform and mascot, but no voice-state avatar that remains meaningful across PiP, notifications, lock-screen transitions, or other Android surfaces.
4. **A precise distinction between realtime conversation and background hands-free operation.** Continuous Talk is implemented; uninterrupted background Talk is a separate product, policy, battery, privacy, and platform problem.
5. **Lifecycle and device-matrix proof.** Logic tests are substantial, but the highest-risk user journeys—PiP entry/exit, Activity stop/start during capture, service recreation, audio focus, process death, and OEM battery restrictions—need explicit end-to-end coverage.

The local Flutter client is already ahead of upstream on PiP, floating overlays, VRM, procedural animation, lip-sync plumbing, wake-word modes, and a multi-engine voice pipeline. Its opportunity is different: consolidate ownership and make those richer capabilities deterministic under Android lifecycle pressure.

## Evidence conventions and boundaries

This article uses the following labels:

- **Implemented:** directly evidenced by code in the audited snapshot.
- **Partial:** a meaningful piece exists, but the requested product behavior is not complete or is constrained by lifecycle/platform policy.
- **Not found:** targeted source searches found no implementation in the official Android app. This is not proof that no behavior can be inherited from Android, Gateway, or another module.
- **Hardening:** an existing capability whose reliability, observability, or contract should be improved.

The upstream snapshot matters. Android behavior, Gateway methods, and policy requirements can change after this audit. Links in the source section use the immutable commit where practical; the user-facing upstream branch remains [`apps/android/app`](https://github.com/openclaw/openclaw/tree/main/apps/android/app).

## Capability scorecard

| Area | Official client today | Local client today | Recommendation |
|---|---|---|---|
| Android PiP | **Not found** in the official app source/manifest | **Implemented** through a native `MethodChannel`, a single mic `RemoteAction`, and `supportsPictureInPicture` | Upstream: add a compact native voice surface. Local: make the existing PiP stateful, testable, and renderer-independent. |
| Voice graphic | **Implemented** as a full-screen orb/waveform with input/output levels and transcript | **Implemented** through VRM, voice orb/chat UI, overlay sync, and speech intensity | Upstream: reuse the voice state machine in PiP/notification. Local: avoid coupling the PiP surface to a WebView renderer. |
| Foreground persistence | **Implemented, policy-bound**: node service persists; Voice Wake and new PTT capture require foreground | **Implemented, but distributed** across several services, wake locks, hotword modes, and Flutter/native bridges | Make desired voice state, actual capture state, and lifecycle state explicit and single-owned. |
| Continuous talk | **Implemented** as Realtime Talk plus native/Push-to-Talk paths | **Partial**: talk relay plus fallback STT; continuous mode restarts turn-based recording after TTS | Do not file “add continuous talk” upstream. File continuity/recovery and clear mode semantics. |
| Avatars | **Partial**: static agent images and animated 2D mascot | **Implemented/richer**: VRM, Three.js, gestures, procedural animation, lip-sync bridge | Upstream: add a lightweight voice-state companion first; local: preserve VRM as an optional full surface, not PiP’s foundation. |
| Wear/ambient surface | **Implemented** for paired-phone Wear OS Talk | No equivalent is the central focus of this audit | Upstream: use Wear as a model for a shared session contract; local: consider it after lifecycle consolidation. |

## 1. Picture-in-picture and compact voice use

### Finding: the official client has no first-class PiP voice surface

Targeted searches of the official Android app found no `PictureInPictureParams`, `enterPictureInPictureMode`, `setPictureInPictureParams`, `supportsPictureInPicture`, `SYSTEM_ALERT_WINDOW`, or `TYPE_APPLICATION_OVERLAY` implementation in the audited app source and manifest.

The official voice experience is instead a full-screen Compose flow. `VoiceScreen` routes between Talk Mode, dictation, and setup. The active Talk screen presents a title, status, waveform, transcript, mute/end controls, and voice selection. This is a strong primary experience, but it does not help a user who wants to keep a conversation visible while reading, navigating, or working in another app.

### What to suggest upstream

Propose a **native compact Voice Companion**, with PiP as its first Android surface:

- enter PiP from Realtime Talk, not from every screen;
- show a small, native-rendered voice orb/waveform rather than embedding the full Compose screen or a WebView;
- show one short status line: `Listening`, `Thinking`, `Speaking`, `Paused`, `Reconnecting`, or `Error`;
- expose only safe, high-value actions: mute/unmute, stop/end session, and expand;
- update `PictureInPictureParams` when voice state changes, but do not depend on a continuously running WebGL renderer;
- return to the full Voice screen without losing session identity, transcript, or user-selected mode;
- make privacy visible: microphone-active state, Android microphone indicator, and a clear stop action;
- respect the user’s explicit background-voice setting and Android restrictions rather than silently turning PiP into an always-on microphone.

PiP should be a **voice control surface**, not a miniature version of the entire OpenClaw client. A 3D avatar, long transcript, camera control, and agent/session management belong in the expanded screen.

### Suggested upstream issue wording

> **Feature: compact Realtime Talk companion with Android PiP**<br>
> Realtime Talk works in the full-screen Voice tab, but the Android client has no first-class compact surface while the user is in another app. Add an opt-in native PiP companion with a live voice-state graphic, short status, mute/stop/expand actions, and session-preserving return to Voice. Keep the PiP renderer lightweight and independent of WebView/3D content. Define explicit behavior for Activity stop/start, gateway loss, microphone permission changes, and process death.

### Acceptance criteria

- PiP is available only while a Talk session exists, with a clear disabled explanation otherwise.
- The voice state and microphone action remain correct after entering PiP, expanding, rotating, and returning from Recents.
- Exiting PiP never leaves a recognizer, audio writer, or foreground-service mode orphaned.
- Gateway loss produces `Reconnecting` or `Disconnected`, not a falsely active animation.
- Process recreation either restores a resumable session or clearly reports that the session ended.
- PiP is usable with Talk playback disabled, microphone muted, accessibility services, large font size, and reduced-motion settings.

## 2. The visual graphic for voice mode

### What the official client already has

The official client has a good foundation for a visual companion:

- `VoiceScreen` derives a `TalkWaveformPhase` from speaking, awaiting-agent, listening, speech-active, input-level, and output-level state;
- `VoiceOrb` renders a circular waveform surface;
- the Talk session shows live transcript entries and status text;
- `OpenClawMascot` is an animated Canvas-based 2D mascot with mood/animation behavior;
- `ClawAgentAvatar` supports bounded raster/SVG/data/remote agent imagery.

This means the missing piece is not “draw something animated.” The missing piece is a **portable visual state contract** that can render consistently in the full screen, PiP, notification, Wear surface, and eventually an ambient avatar.

### Recommended voice visual contract

Use a small state model with explicit precedence:

```text
Idle
  -> Listening(input level, speech detected)
  -> Thinking(transcript submitted, waiting for agent)
  -> Speaking(output level)
  -> Interrupted(user speech or stop)
  -> Reconnecting(network/gateway transition)
  -> Paused(lifecycle/policy/permission)
  -> Error(recoverable or terminal)
```

The graphic should be driven by the same state that drives audio and notifications:

- **Listening:** input amplitude and speech-activity envelope;
- **Thinking:** low-motion pulse, not a fake waveform pretending to hear audio;
- **Speaking:** output amplitude or player envelope;
- **Interrupted:** immediate visual cut and a short transition to Listening;
- **Paused:** frozen/dimmed visual with a reason available to accessibility and the full screen;
- **Reconnecting/Error:** bounded retry animation and readable status.

The design should prefer a native vector/Canvas implementation for compact surfaces. A live WebView/VRM surface can remain a richer optional foreground presentation, but it should not be the only source of truth for whether the microphone is active or whether the agent is speaking.

## 3. Foreground persistence and lifecycle behavior

### Official implementation: strong foundation, explicit boundaries

The official app has a `NodeForegroundService` whose documented purpose is to keep the Android node connection and voice capture visible to the operating system. The service builds an ongoing notification, observes connection and capture state, and starts with foreground service types appropriate to the build flavor.

`MainActivity` reports `onStart` and `onStop` to `MainViewModel`, which forwards foreground state into the runtime. This is a deliberate lifecycle architecture rather than a simple “keep the Activity alive” workaround.

However, two voice policies are important:

1. `VoiceWakeManager` tracks `foreground` separately and resolves `!foreground` to a visible `Paused` status. Its recognizer reconciliation stops or refrains from starting the wake session outside the allowed lifecycle.
2. `TalkModeManager` protects new PTT capture with `NODE_BACKGROUND_UNAVAILABLE: command requires foreground`. Its code also guards asynchronous capture startup against lifecycle/generation changes.

Therefore the precise statement is:

> The official client has foreground-service persistence for node/runtime presence and voice-capture visibility, but it does not promise unrestricted background microphone capture. Voice Wake and new PTT capture are foreground-bound by policy in the audited snapshot.

That distinction should be made visible in product language. Otherwise users reasonably interpret “foreground Voice Wake” or an ongoing notification as meaning “the assistant will always continue listening after I leave the app.”

### Recommendations for upstream

#### A. Separate three states

Expose these independently in the runtime and UI:

```text
desired session: off | talk | wake | ptt
actual session: stopped | starting | listening | speaking | paused | reconnecting | error
execution surface: activity | PiP | foreground service | wear | none
```

Do not infer one from another. A foreground service can be alive while microphone capture is paused; PiP can be visible while the Gateway is disconnected; a Talk session can be logically enabled while audio capture is temporarily unavailable.

#### B. Persist intent, not stale capture

Persist the user’s desired mode and selected session/agent, but never persist a claim that the microphone is currently open. On service or process recreation:

1. restore desired state;
2. verify permission, privacy, foreground-service eligibility, Gateway scope, and audio focus;
3. reconcile to an actual state;
4. publish the reason if the requested state cannot be restored.

#### C. Make transitions observable

The ongoing notification and Voice screen should agree on the same state. Include explicit actions for stop, mute, resume, and open. Report reasons such as microphone permission, another app owning audio focus, Gateway unavailable, user policy, battery restriction, and unsupported background capture.

#### D. Define the background policy as a product choice

Offer clearly named policies rather than one ambiguous “persistent” switch:

- **Foreground only:** default; Talk/Wake is active while the app or an approved compact surface owns the interaction.
- **Background wake:** optional on-device wake word with prominent notification, battery explanation, and permission/policy checks.
- **Background realtime Talk:** separate opt-in, only where technically and policy compliant; requires explicit battery, privacy, audio-focus, and recovery design.

The third mode should not be implied by adding PiP. PiP is a visible surface; it is not a blanket exemption from Android microphone rules.

### Local client finding: capability is richer, ownership is more complex

The local client has multiple native service paths, including `NodeForegroundService`, `PlawieForegroundService`, `NativeNodeEmbeddedService`, `HotwordService`, and capability-specific services. It also has wake-lock bridges and both foreground/always wake-word modes. This gives the fork considerable capability, but creates a higher-risk ownership graph:

- which service owns the Gateway connection;
- which service owns microphone capture;
- which service owns the user-visible notification;
- which component may acquire a wake lock;
- which path wins during boot, Activity recreation, Gateway restart, or native-owner rollback.

The local `GatewayService` contains comments describing a single-owner/canary direction, but the service inventory still warrants a deliberate runtime contract audit. The recommended local fix is consolidation and observability, not adding another service.

## 4. Continuous talk: implemented, but not finished as a product

### Official status

The official app has a dedicated `TalkModeManager`. Its code and tests cover:

- enabling/disabling continuous realtime Talk;
- realtime relay capture and playback;
- live input/output levels;
- transcript and assistant response state;
- audio focus and playback control;
- interruption behavior, configurable because some Android speech-recognizer/audio-session combinations conflict;
- push-to-talk recognition and fallback;
- Gateway-generation changes and relay cleanup;
- explicit foreground errors for new capture.

The official tests include `TalkModeManagerTest`, `TalkAudioPlayerTest`, `RealtimeAgentCoordinatorTest`, `MicCaptureManagerTest`, `PushToTalkRecognitionLadderTest`, `VoiceScreenLogicTest`, and waveform math tests. That is enough evidence to reject a generic “please add continuous talk” suggestion.

### The real upstream opportunity

Suggest **Talk continuity and recovery hardening**:

- preserve a logical Talk session across Activity recreation and compact-surface transitions;
- make gateway disconnect/reconnect behavior explicit and resumable where safe;
- show whether the current mode is realtime full-duplex, native half-duplex, or PTT fallback;
- expose interrupt-on-speech as a clearly described setting with an OEM compatibility fallback;
- pause/resume capture around audio focus, calls, Bluetooth route changes, headphones, and other mic owners;
- make the notification and PiP surface reflect “enabled but paused” versus “fully stopped”;
- test service recreation while listening and while speaking;
- give users a one-tap “resume Talk” action after a policy or lifecycle pause.

### Local status

The local client has a Gateway realtime relay path and a fallback path that records an M4A turn, sends it for transcription, and then restarts listening after TTS. Its persisted `continuousMode` preference is explicitly described as “auto-restart STT after TTS finishes.” That is useful hands-free turn chaining, but it is not equivalent to the official realtime Talk loop or true full-duplex capture.

The local implementation also starts delayed listening retries after TTS and turn completion. These callbacks check `mounted`, which is good, but the delays are not represented as cancellable session jobs. A lifecycle or session-generation token would make it harder for an old turn to restart a new microphone session after a mode change, navigation, Gateway switch, or dispose.

## 5. Avatars and persistent presence

### Official status

The official client has two different avatar concepts:

1. **Agent identity image:** `ClawAgentAvatar` can render bounded local data, remote URLs, raster images, or SVG-style image content for an agent.
2. **Product mascot:** `OpenClawMascot` is a small animated Canvas mascot used in the UI and voice header.

These are valuable and should be acknowledged in any upstream issue. “Add avatars” is too broad and would understate the current implementation.

### What is missing

What is missing is a voice-aware, persistent companion that:

- reacts to the same audio/session state as the waveform;
- remains understandable when the app moves from full screen to PiP, notification, Wear, or paused state;
- indicates listening versus speaking without relying on lip movement alone;
- handles no avatar, broken avatar, remote avatar, and accessibility/reduced-motion cases;
- preserves agent identity without making a remote image an untrusted interactive surface.

### Recommended roadmap

**V1: animated native voice companion**

- extend the existing mascot/waveform with input/output state;
- keep it native and small enough for PiP;
- provide state colors, motion, content descriptions, and reduced-motion behavior;
- add a stable `AvatarVoiceState` contract rather than coupling animation to screen callbacks.

**V2: pluggable agent presence**

- define an avatar capability boundary: static image, native animated mascot, optional rich renderer;
- cache and size-bound remote assets;
- validate URLs and avoid arbitrary script execution for identity images;
- allow an agent to declare supported moods/gestures, while keeping the client’s safety and accessibility defaults.

**V3: rich 3D avatar in the expanded surface**

- consider VRM or another 3D renderer in the full-screen/overlay experience;
- drive mouth movement from actual playback amplitude or viseme events, not only TTS start/complete callbacks;
- keep the renderer optional and recoverable when the GPU, WebView, process, or asset server is unavailable.

Do not make a live VRM/WebView avatar the first PiP implementation. PiP is the wrong place to put a large renderer, remote asset loader, or JavaScript bridge before the voice session contract is reliable.

## 6. Local client comparison and concrete hardening targets

The local repository already implements several requested ideas. The following findings are the highest-value follow-ups for this codebase.

### PiP is present, but the PiP contract is thin

Evidence:

- `android/app/src/main/AndroidManifest.xml` enables `supportsPictureInPicture` and a resizable Activity;
- `android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt` enters PiP with a `3:4` aspect ratio and updates a single mic `RemoteAction`;
- `lib/screens/chat_screen.dart` receives PiP callbacks and forwards the native mic action into Flutter;
- the chat screen hides background/diagnostic content while in PiP and passes `isPip` into the VRM widget.

Hardening:

- replace the “one generic mic action” contract with a typed `PipVoiceState` containing state, enabled actions, label, and session generation;
- keep the mic/stop action owned by the voice session controller, not by a large chat screen;
- provide a native compact visual state for cases where Flutter/WebView is paused or unavailable;
- test PiP from a real Talk/voice state, not only from menu invocation;
- review the disabled `PopupMenuItem` plus nested `ListTile` path around the PiP menu because the interaction/accessibility semantics are easy to make inconsistent;
- ensure entering/leaving PiP does not unconditionally stop a legitimate ongoing session unless the policy explicitly requires it.

### The local VRM renderer can be lifecycle-sensitive in PiP

`VrmAvatarWidget` uses a WebView-backed local avatar asset server and sends `setRenderPaused` for `paused`, `inactive`, `detached`, and `hidden` application states. It also supports a `pip=true` scene mode and suppresses tap interception in PiP.

That is thoughtful integration, but Android may report Activity lifecycle transitions while a PiP window remains visible. A renderer that pauses on every `paused` callback can produce a frozen or blank PiP companion even though the session is still active. The fix is to distinguish:

```text
application hidden with no compact surface -> pause renderer
application hidden but PiP visible -> keep compact renderer or use native fallback
voice session active but renderer unavailable -> preserve audio/session and show native status
```

### Continuous mode should be session-owned

The local chat screen owns `_isListening`, Talk relay IDs, recorder streams, TTS callbacks, delayed restarts, and PiP updates. That is a large amount of lifecycle-sensitive state in one UI state object. A dedicated `VoiceSessionController` would let the full screen, PiP, notification, foreground service, and avatar observe the same authoritative state.

Minimum state shape:

```text
VoiceSessionState {
  desiredMode
  actualMode
  captureOwner
  gatewayConnection
  sessionId
  sessionGeneration
  isMuted
  inputLevel
  outputLevel
  partialTranscript
  finalTranscript
  lastError
  foregroundPolicy
  executionSurface
}
```

Every async callback should carry or validate `sessionGeneration`. On mode change, Gateway change, Activity stop, or dispose, invalidate the old generation before stopping resources.

### Foreground services need a single-owner map

The local Android tree contains several foreground-capable services. That may be intentional because the app includes Gateway, node, terminal, screen capture, installation, hotword, and skill capabilities. The audit recommendation is to publish a small ownership table in code/docs:

| Resource | Sole owner | Consumers |
|---|---|---|
| Gateway connection | one runtime owner | chat, voice, notifications, node tools |
| Microphone capture | voice session owner | full screen, PiP, wake, notification actions |
| Voice notification | one service/notification coordinator | session state and controls |
| Wake lock | runtime policy coordinator | services request/release by reason |
| VRM/WebView renderer | UI surface | voice state only; never session authority |

This will reduce duplicate service starts, stale wake locks, conflicting microphone ownership, and “looks connected but cannot capture” states.

## 7. Features worth suggesting beyond the four initial ideas

These are directly adjacent to the audited gaps and have better product leverage than isolated visual polish:

### A. Voice session notification with real controls

Use the existing foreground notification as a compact control surface with state-aware actions: mute, stop, resume, expand, and open transcript. It should not claim “listening” when capture is paused or only the Gateway session remains alive.

### B. Audio-focus and route continuity

Make phone calls, Bluetooth headset changes, wired headset changes, navigation audio, alarms, and another recorder explicit state transitions. Preserve a logical session while safely releasing the microphone and restoring it only when allowed.

### C. Gateway/provider readiness before Talk starts

The official app already surfaces provider/configuration readiness in Voice UI. Extend that into a preflight summary: microphone permission, realtime provider, Gateway connection, foreground policy, audio route, and battery restriction. This prevents a visually active Talk screen that cannot actually capture.

### D. Session handoff between phone, PiP, and Wear

The Wear companion already establishes a useful architectural direction: the watch uses the phone’s authenticated Gateway session and does not store Gateway credentials. A shared session identity and generation model would let phone full screen, phone PiP, notification, and Wear hand off without duplicating capture or losing transcript state.

### E. User-visible recovery history

For every automatic stop or pause, show a small reason and recovery action. Examples: “Microphone paused because another app took audio focus,” “Talk stopped because the Gateway changed,” and “Wake word paused while the app was not in the foreground.” This is more trustworthy than silently retrying.

### F. Accessibility and reduced-motion parity

Voice state must never be conveyed only through color, pulsing, lip movement, or waveform motion. Provide semantic labels, haptics where appropriate, readable status, high-contrast treatment, and a reduced-motion mode for the orb, mascot, and future avatar.

## 8. Proposed upstream backlog

| Priority | Issue | Why it matters | Scope |
|---|---|---|---|
| P0 | Compact Realtime Talk companion / Android PiP | Keeps voice useful outside the full-screen Voice tab | Native PiP state, controls, lifecycle handoff, tests |
| P0 | Voice session lifecycle/recovery contract | Prevents silent stops, stale capture, and misleading “active” UI | Shared state, service reconciliation, notification parity |
| P1 | Explicit foreground/background voice policy | Makes the current foreground boundary understandable and safe | Settings, status reasons, permission/policy copy |
| P1 | Voice-state visual companion API | Makes waveform, mascot, PiP, notification, and Wear consistent | State schema, level envelope, transcript/status events |
| P1 | Talk lifecycle/device matrix | Proves behavior where users actually encounter failures | Instrumented tests and repeatable manual matrix |
| P1 | Audio focus and route recovery | Prevents broken sessions after calls/Bluetooth/navigation audio | Focus callbacks, pause/resume, state reporting |
| P2 | Rich avatar capability boundary | Allows visual identity without making 3D a session dependency | Static/native/rich renderer contracts |
| P2 | Phone-to-Wear voice session handoff | Builds on existing Wear Talk work | Session identity, ownership, transcript continuity |
| P2 | Media/session controls | Makes speaking state more native to Android | Media/session integration, notification and headset actions |

## 9. Recommended implementation sequence for this repository

1. **Write and test the state contract.** Extract voice lifecycle from `ChatScreen` into a controller/repository with session generation, desired/actual state, and explicit pause reasons.
2. **Make local PiP native-state-first.** The VRM can decorate PiP, but a native orb/status fallback must remain correct when Flutter/WebView rendering pauses.
3. **Map all foreground owners.** Document and instrument which service owns Gateway, microphone, notification, and wake lock resources. Remove or quarantine redundant ownership paths only after observing their current role.
4. **Add lifecycle tests before more animation.** Cover Activity stop/start, PiP, process recreation, Gateway reconnect, audio focus loss, and permission revocation.
5. **Improve visual semantics.** Connect VRM/mascot/waveform to one `VoiceSessionState`; add reduced-motion and accessibility labels.
6. **Only then consider richer persistent avatars.** A 3D avatar should be an optional presentation layer over a reliable voice session, not the component keeping the session alive.

## 10. Test matrix

### PiP and surfaces

- Android 8+ minimum supported PiP behavior;
- enter from idle, listening, thinking, and speaking;
- expand from PiP and return to PiP;
- rotate, resize, split screen, Recents, lock/unlock;
- mic mute/unmute, stop, and expand actions;
- PiP while Gateway disconnects and reconnects;
- PiP while WebView/VRM fails or is recreated;
- process kill and relaunch;
- Talk notification and PiP display the same state.

### Lifecycle and persistence

- Activity `onStart`/`onStop` and configuration recreation;
- home button, another app, screen off, lock screen, and notification shade;
- service killed and sticky restart;
- boot restart and setup-not-complete state;
- battery saver, restricted background mode, and representative OEM task killers;
- microphone permission revoked while active;
- phone call, Bluetooth route change, wired headset, navigation audio, and alarm;
- Gateway restart, network loss, TLS/auth failure, and Gateway scope change.

### Talk behavior

- several consecutive turns;
- user interrupts agent speech;
- silence timeout and no-speech turn;
- realtime provider unavailable;
- fallback recognizer path;
- audio output disabled or playback error;
- duplicate start/stop commands and delayed callback races;
- session handoff between phone full screen, PiP, notification, and Wear.

### Avatar and visual behavior

- static avatar missing, invalid, oversized, remote, SVG, and data image;
- VRM asset server unavailable or slow;
- renderer paused while PiP remains visible;
- TTS playback level versus simple TTS start/complete callbacks;
- reduced motion, TalkBack, large font, high contrast, and color-blind use;
- no visual renderer must not stop audio or Gateway state.

## 11. Bottom line for proposed feature requests

The strongest proposals are:

1. **Add an opt-in native PiP Voice Companion with live state graphics and session-safe controls.**
2. **Define and expose a durable voice lifecycle contract across Activity, foreground service, PiP, notification, and Wear.**
3. **Clarify and harden background voice policy; do not conflate a foreground service with unrestricted background listening.**
4. **Promote the existing waveform/mascot into a shared, voice-aware visual companion contract.**
5. **Treat continuous Talk as an existing feature that needs recovery, audio-focus, lifecycle, and device-matrix hardening—not as a missing checkbox.**
6. **Treat avatars as a presentation layer with a lightweight native first step and optional rich 3D expansion.**

That framing is both more accurate to the official implementation and more useful to maintainers: it recognizes shipped work, identifies user-visible gaps, and points toward changes that improve trust and continuity rather than adding another disconnected surface.

## Sources and audited files

### Official OpenClaw snapshot

- [Official Android app directory](https://github.com/openclaw/openclaw/tree/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/app)
- [Android README](https://github.com/openclaw/openclaw/blob/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/README.md)
- [`TalkModeManager.kt`](https://github.com/openclaw/openclaw/blob/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/app/src/main/java/ai/openclaw/app/voice/TalkModeManager.kt)
- [`VoiceWakeManager.kt`](https://github.com/openclaw/openclaw/blob/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/app/src/main/java/ai/openclaw/app/voice/VoiceWakeManager.kt)
- [`VoiceScreen.kt`](https://github.com/openclaw/openclaw/blob/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/app/src/main/java/ai/openclaw/app/ui/VoiceScreen.kt)
- [`NodeForegroundService.kt`](https://github.com/openclaw/openclaw/blob/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/app/src/main/java/ai/openclaw/app/NodeForegroundService.kt)
- [`MainActivity.kt`](https://github.com/openclaw/openclaw/blob/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/app/src/main/java/ai/openclaw/app/MainActivity.kt)
- [`AgentAvatar.kt`](https://github.com/openclaw/openclaw/blob/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/app/src/main/java/ai/openclaw/app/ui/design/AgentAvatar.kt)
- [`OpenClawMascot.kt`](https://github.com/openclaw/openclaw/blob/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/app/src/main/java/ai/openclaw/app/ui/design/OpenClawMascot.kt)
- [Official Android manifest](https://github.com/openclaw/openclaw/blob/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/app/src/main/AndroidManifest.xml)
- [Official Talk and Voice test inventory](https://github.com/openclaw/openclaw/tree/8a9c7324f83975b0eafe109e7c3360c0b75c177d/apps/android/app/src/test)

### Local comparison files

- [`lib/screens/chat_screen.dart`](../lib/screens/chat_screen.dart)
- [`lib/widgets/vrm_avatar_widget.dart`](../lib/widgets/vrm_avatar_widget.dart)
- [`android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt`](../android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt)
- [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml)
- [`lib/services/preferences_service.dart`](../lib/services/preferences_service.dart)
- [`docs/ANDROID_AVATAR_GRAPHICS_STRATEGY.md`](ANDROID_AVATAR_GRAPHICS_STRATEGY.md)
- [`AVATAR_ARCHITECTURE.md`](../AVATAR_ARCHITECTURE.md)
