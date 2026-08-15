# Android Voice Companion: Local-First Implementation Plan

**Branch:** `codex/android-voice-companion-pip`<br>
**Worktree:** `C:\dev-shared\openclaw-projects\openclaw_android_voice_proposal`<br>
**Remote:** `origin` → `https://github.com/vmbbz/plawie.git`<br>
**Checkpoint:** pushed to the branch above before feature changes

## Why this lane exists

The original `openclaw_final` checkout contains unrelated uncommitted assets and build output. It remains untouched. This external worktree is the isolated local development lane for making the voice companion reliable in the Plawie/OpenClaw client.

The official OpenClaw Android app is a separate contribution target. Its source package, lifecycle architecture, and remote repository are different. We will first make the local product coherent and prove the interaction. Only then should we extract an upstream-compatible proposal.

## First vertical slice

Build a reliable **local PiP Voice Companion** around the existing voice and VRM capabilities.

The first slice is intentionally narrow:

1. one authoritative voice-session state contract;
2. native PiP state and controls that remain correct when Flutter/WebView rendering is paused;
3. explicit lifecycle transitions for PiP, Activity stop/start, Gateway loss, microphone permission, and session disposal;
4. focused tests for stale callbacks, PiP entry/exit, and capture ownership;
5. documentation and a small demo/review checklist.

This is not the first slice:

- a new 3D avatar renderer;
- unrestricted background microphone capture;
- a second foreground service;
- a complete rewrite of `ChatScreen`;
- an upstream OpenClaw PR;
- a large visual redesign without lifecycle proof.

## Current local baseline

The local client already contains:

- Android PiP support in `MainActivity.kt`;
- a PiP mic `RemoteAction` bridged into Flutter;
- VRM/Three.js rendering through `VrmAvatarWidget`;
- Talk relay plus fallback STT paths;
- continuous-mode turn restart after TTS;
- hotword and foreground-service paths;
- avatar gesture and renderer contract tests.

The risk is coordination: voice state is distributed across the chat screen, TTS callbacks, recorder streams, Gateway events, native PiP callbacks, WebView lifecycle, and several Android services. The first slice should reduce that coordination risk before adding more capability.

## Current implementation checkpoint

The first code slice is now implemented on this branch:

- `VoiceSessionController` owns a small voice phase, capture owner, surface,
  and generation contract;
- PiP entry/exit changes the presentation surface without stopping active
  capture;
- the native PiP mic action waits for the asynchronous Flutter toggle before
  refreshing its icon;
- delayed continuous-mode restarts reject stale generations;
- recorder/relay startup and stop paths reject stale async completions;
- disposal invalidates the active generation before resources are released.

Validation completed for this checkpoint:

- targeted Flutter analysis: clean;
- `voice_session_controller_test.dart`: 4 tests passed;
- existing avatar gesture, VRM bootstrap, and Gateway TTS policy tests: passed.

The native compact visual, full Activity/PiP lifecycle matrix, and service
ownership audit remain subsequent phases. The current change deliberately does
not add another Android service or make background microphone capture
unrestricted.

Real-device smoke validation was completed on 2026-08-15 using a Samsung
SM-A556E running Android 14 / API 34:

- the debug APK installed and launched; Gateway reached `LIVE` and the VRM
  chat surface rendered;
- Android confirmed `mode=pinned` and
  `mLastReportedPictureInPictureMode=true`;
- the PiP avatar remained visible after Home, while the app process and
  `NodeForegroundService` stayed alive;
- the system expand control returned the Activity to full screen without a
  crash or ANR;
- microphone permission and device-level AAC capture worked;
- transcript/reply could not be validated because the test device had no
  Gateway token (`STT Exception: No gateway token`);
- Samsung's visible PiP controls did not clearly label a microphone action, so
  native RemoteAction discoverability remains an OEM follow-up rather than a
  claim of completion.

The APK and copied native runtime prerequisites were local build artifacts only
and were not committed or pushed.

## Proposed state boundary

Introduce a small voice-session model without moving every existing behavior at once:

```text
VoiceSessionState
  desiredMode: off | pushToTalk | continuous | wakeWord
  actualState: idle | starting | listening | thinking | speaking |
               paused | reconnecting | stopped | error
  captureOwner: none | chat | pip | wakeWord | service
  sessionId: optional Gateway/realtime session id
  generation: monotonically increasing callback guard
  muted: boolean
  inputLevel: 0..1
  outputLevel: 0..1
  statusReason: optional user-facing reason
  surface: fullScreen | pip | overlay | notification | none
```

The state owner must be independent of the visual renderer. The full-screen chat, PiP action handler, foreground notification, and avatar should observe or submit intents to the same owner.

Every asynchronous recorder, TTS, Gateway, and delayed-restart callback must validate the current generation before mutating state. A callback from an old turn must never restart a new microphone session.

## Implementation phases

### Phase 0 — baseline and branch hygiene

- keep the pushed checkpoint unchanged;
- record the exact branch/worktree in review notes;
- identify the correct PR base before opening a feature PR;
- do not modify the original dirty checkout.

### Phase 1 — state contract and instrumentation

- add the state model and transitions;
- route existing PiP mic updates through the model;
- add diagnostic events for capture start/stop, lifecycle pause, Gateway disconnect, permission failure, and generation rejection;
- preserve existing voice behavior while state becomes observable.

### Phase 2 — PiP reliability

- replace the boolean-only PiP bridge with typed state payloads;
- keep a native fallback status/graphic available when the WebView is paused or unavailable;
- expose only safe actions: mute/resume, stop, and expand;
- define enter/exit behavior for each actual voice state;
- make PiP state updates idempotent.

### Phase 3 — lifecycle and test matrix

- Activity stop/start;
- PiP entry/exit;
- Gateway disconnect/reconnect;
- microphone permission loss;
- TTS completion after navigation/dispose;
- service/native callback after a new session generation;
- renderer failure without audio-session failure.

### Phase 4 — visual polish

- map input/output levels to the existing VRM/voice graphic;
- add `Listening`, `Thinking`, `Speaking`, `Paused`, and `Reconnecting` semantics;
- add reduced-motion and accessibility labels;
- keep 3D rendering optional and never authoritative for capture state.

## Definition of done

- PiP can be entered from an active voice session and returns to the same session.
- Native PiP controls cannot create duplicate capture owners.
- Leaving PiP, navigating away, or disposing the screen cannot cause a delayed old callback to reopen the microphone.
- Gateway loss, permission loss, and lifecycle pause are visible and recoverable.
- Audio/session state remains correct if VRM/WebView rendering is unavailable.
- Focused tests cover the new state transitions and callback-generation guard.
- No new foreground service is introduced without an ownership justification.
- Documentation describes the behavior and known Android policy limits.
- The feature branch has a focused diff suitable for review.

## Branch and PR workflow

### Local product work

1. Work only in this external worktree.
2. Make small commits by vertical slice: state contract, PiP bridge, lifecycle tests, visual polish.
3. Run focused tests and `git diff --check` after each significant round.
4. Push the feature branch to `vmbbz/plawie`.
5. Open a PR against the correct local repository base branch after the diff is focused.

The currently pushed branch is a checkpoint and contains pre-existing commits from the original local branch. It should not automatically be treated as the final feature PR base.

### Official OpenClaw contribution later

An upstream PR must be based on a fork/branch of `openclaw/openclaw`, not this Plawie repository. The upstream contribution should be a portable subset:

- native compact Voice Companion/PiP;
- shared voice-state/lifecycle contract;
- official Talk/Wake integration;
- tests and documentation;
- no Plawie-specific VRM, wallet, Gateway runtime, or overlay implementation.

The sequence is: prove the local interaction, extract the portable design, implement it against the official Android architecture, push to a personal fork, then open a PR to `openclaw/openclaw`. A GitHub issue or discussion can precede that PR if maintainers want design review first.

## Review artifacts to prepare

- state-transition diagram or table;
- short screen recording of full screen → PiP → full screen;
- evidence of Gateway loss/recovery;
- test output for focused voice/PiP tests;
- before/after screenshots of the compact voice graphic;
- PR description with scope, non-goals, Android policy limits, and rollback behavior.
