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
- the Flutter/native PiP bridge now carries a typed phase, listening flag, and
  user-facing label, and caches that state before PiP entry;
- the native PiP mic action waits for the asynchronous Flutter toggle before
  refreshing its icon;
- delayed continuous-mode restarts reject stale generations;
- recorder/relay startup and stop paths reject stale async completions;
- full-screen voice UI publishes stable Starting, Listening, Transcribing,
  Thinking, Speaking, Sent, No transcript, Paused, and Error phases with a
  recording/privacy indicator;
- relay error, close, and transcript-finalization timeout paths publish a
  terminal state instead of leaving the user waiting on a stale turn;
- native PiP actions refuse to create a second capture while transcription,
  reply generation, TTS, or relay reconnection is still in progress;
- microphone permission and recorder-start failures are visible as recoverable
  voice errors;
- disposal invalidates the active generation before resources are released.

Validation completed for this checkpoint:

- targeted Flutter analysis: clean;
- `voice_session_controller_test.dart`: 6 tests passed;
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
- after the typed-state round, Samsung's visible PiP menu showed a distinct
  microphone action alongside expand/close/settings; the overlay rendered the
  icon but did not expose the RemoteAction title/content description as visible
  text, so accessibility-label and second-OEM validation remain follow-ups.

The APK and copied native runtime prerequisites were local build artifacts only
and were not committed or pushed.

## Voice-send defect reproduced on device

On 2026-08-15 the debug APK was exercised on the connected Samsung Android 14
device using the actual chat flow: `Show menu` → `Voice Input`, several seconds
of capture, then `Stop Listening`.

The microphone path is working. Android opened `AudioRecord`, the recorder
produced an AAC file, and the recorder stopped cleanly. No user message was
created because the fallback STT path logged:

```text
STT Exception: Exception: No gateway token
```

The failure had two independent causes in `GatewayService.transcribeAudio()`:

- it refused to POST to `/talk/stt` when the embedded/native Gateway had no
  HTTP token, even though a local Gateway may intentionally be unauthenticated;
- when a token did exist, the code read only the URL query while OpenClaw's
  dashboard auth URL normally stores it in the `#token=...` fragment.

The current fix makes the Authorization header optional for an intentionally
unauthenticated local Gateway, supports both token URL forms, accepts any
successful 2xx response, and shows a user-visible retry/configuration message
when transcription returns no text. It does not claim that an STT provider is
configured; the rebuilt APK must still prove the complete audio → transcript →
chat-send path against the device's actual Gateway configuration.

### Native recognizer fallback implemented

The next validation pass found that the authentication defect was not the only
problem. With the rebuilt APK installed, the embedded Gateway returned
`404 Not Found` for `/talk/stt`; that optional HTTP route is not present in this
Gateway/runtime. Treating that route as the only fallback would therefore keep
voice input broken even after auth was corrected.

The local client now follows the official Android client's fallback shape:

- realtime `talk.session.*` remains preferred when a configured realtime
  provider is advertised by `talk.catalog`;
- Android's platform `SpeechRecognizer` is used when realtime Talk is not
  configured, and its recognized text enters the existing chat submission
  path;
- the AAC file plus `/talk/stt` route remains only as a compatibility fallback
  for devices where native recognition is unavailable;
- `speech_to_text.stop()` is allowed to deliver its final callback before the
  text is submitted, with a bounded timeout returning the latest partial text;
- platform `done`, `notListening`, and error callbacks finalize the voice
  session idempotently, so Android silence timeouts cannot leave a stale
  `Stop Listening` state or finalize twice;
- the Android manifest declares the recognition-service query required for
  Android 11+ package visibility.

Device evidence after this change, on the same Samsung Android 14/API 34
handset:

- Google online and offline SpeechRecognizer services started and Android
  opened `AudioRecord` for both an automatic-silence run and a manual-stop run;
- the device reported `NO_SPEECH_DETECTED` because it had no network and no
  installed offline `en-ZA` language pack (`Soda ... error 12`);
- after the automatic timeout, reopening the app menu showed `Voice Input`
  rather than `Stop Listening`, proving that the Flutter session was finalized;
- no `/talk/stt` request or `404` appeared during the native-recognition runs;
- a spoken transcript and chat send remain unproven on this handset until a
  recognition provider/network or the required offline language pack is
  available. This is an environment limitation, not evidence that the
  end-to-end send path is complete.

## Official-client parity audit and adoption backlog

The official OpenClaw Android client was audited separately as a reference
implementation. Its useful lessons are behavioral contracts, not code to copy:

- its `TalkModeManager`/Talk session path treats realtime conversation as a
  session with explicit capture ownership, transcript events, TTS state, and
  continuous-turn transitions;
- its full-screen voice surfaces expose voice state separately from the visual
  renderer, and its foreground node runtime/notification owns process presence;
- its background policy deliberately distinguishes a visible active voice
  session from ordinary Activity backgrounding, rather than silently granting
  unrestricted microphone capture;
- it already has voice wake, background presence, Wear Talk, waveform/mascot
  visuals, and focused lifecycle/auth tests;
- it does not currently provide Android PiP, so Plawie's native PiP work remains
  a local product differentiator rather than an upstream feature already proven
  in the official app.

Plawie already has the complementary pieces—VRM rendering, PiP entry, a native
PiP mic action, Gateway Talk relay/fallback STT, continuous-mode restart,
foreground services, and wake-word support—but they need the same explicit
contracts and proof:

1. **Voice transport reliability — current round substantially advanced**
   - optional local-Gateway auth plus correct query/fragment token parsing;
   - platform SpeechRecognizer fallback when realtime Talk/provider setup is
     absent;
   - terminal callback handling and bounded finalization for native capture;
   - honest detection of a missing `/talk/stt` compatibility route;
   - visible `Listening` → `Transcribing` → `Sent`/`No transcript`/`Error`
     states;
   - bounded transcription timeout, retry, and a diagnostic correlation id;
   - tests for unauthenticated local STT, authenticated STT, non-2xx responses,
     empty transcripts, and exactly-once chat submission.

2. **Realtime Talk parity**
   - verify relay `ready`, `transcript`, `error`, and `close` events are matched
     to the active session without relying on a stale or missing session id;
   - expose relay connection and transcript-finalization state in the UI;
   - ensure stopping capture closes/finalizes the current turn and never leaves
     the user waiting indefinitely for an event that will not arrive.

3. **Lifecycle and foreground policy**
   - preserve capture only while the Activity is in PiP or another explicitly
     authorized voice surface;
   - stop/invalidate capture on ordinary backgrounding, permission loss,
     Gateway disconnect, navigation, and disposal;
   - audit `NodeForegroundService`, `PlawieForegroundService`, wake-word, and
     voice ownership so there is one documented owner for each microphone and
     process-presence responsibility;
   - add tests for Activity stop/start, PiP expand/return, process recreation,
     Gateway reconnect, and stale native/TTS callbacks.

4. **PiP companion hardening**
   - **implemented in the current round:** replace boolean-only native updates
     with a typed phase/listening/label payload cached before PiP entry;
   - **implemented in the current round:** keep an explicit native microphone
     icon and Start voice input/Stop listening RemoteAction description when
     Flutter/WebView rendering is paused or unavailable;
   - expose safe, idempotent actions for mute/resume, stop, and expand;
   - validate RemoteAction accessibility/discoverability on Samsung and at
     least one other Android implementation; Samsung currently shows the icon
     but not the action text in its PiP overlay.

5. **Voice visuals and accessibility**
   - map input/output levels and session phase to the existing VRM/orb without
     making the renderer authoritative for audio state;
   - show `Listening`, `Thinking`, `Speaking`, `Transcribing`, `Paused`, and
     `Reconnecting` semantics;
   - add content descriptions, a large unambiguous stop action, reduced-motion
     behavior, and a visible recording/privacy indicator;
   - make the full-screen and PiP surfaces use the same state owner.

6. **Validation and release evidence**
   - focused unit/widget tests for the state machine and STT contract;
   - real-device transcript/send proof with a configured provider;
   - full-screen → PiP → full-screen recording/video evidence;
   - background/lock/unlock/process-recreation evidence;
   - no APKs, screenshots, tokens, or temporary device artifacts committed.

The implementation order is therefore: obtain provider-backed transcript/send
proof, complete the remaining realtime Talk and lifecycle test matrix, then
add a richer compact visual/accessibility graphic and second-OEM PiP
validation. The basic status presentation and duplicate-action guard are now
implemented; Continuous Talk and avatars are not being reimplemented from
scratch, but are brought under the same reliable session contract.

### Realtime session and background ownership slice

The next local slice now applies the official client's session contract to the
existing Plawie relay without replacing its renderer or Gateway architecture:

- `talk.session.create` includes the Gateway's negotiated main `sessionKey` and
  the device language; if an older Gateway rejects the optional language field,
  the client retries once without that field;
- streamed audio includes a timestamp, matching the official relay payload
  shape;
- stopping relay capture arms a bounded transcript-finalization timer. A
  missing `transcript`/assistant completion no longer leaves the UI waiting
  forever; the client cancels and closes the stale relay session;
- terminal relay error/close/final transcript events cancel that timer;
- ordinary Activity backgrounding stops and invalidates capture after a short
  PiP-transition grace period. An active PiP surface remains an authorized
  voice owner; PiP entry/exit itself does not tear down the session.

This slice has passed analysis and focused session/auth tests. It still needs a
configured realtime provider for real `ready` → audio → transcript → assistant
completion evidence; the current handset's provider/network limitation means
that path is not yet claimed as device-proven.

The newly installed debug APK also passed an ordinary-background smoke: native
recognition opened `AudioRecord`, the Activity was sent Home, and after return
the voice menu showed `Voice Input` rather than `Stop Listening`. The device
again reported `NO_SPEECH_DETECTED` because of its recognition environment, but
the microphone was released and the app did not retain a stale capture owner.

### Typed PiP status and action slice

The PiP bridge now carries the minimum state needed by the native surface
without making the renderer authoritative:

- Flutter sends `phase`, `listening`, and `label` through
  `updatePipVoiceState` on voice-state changes and on PiP entry/exit;
- `MainActivity` caches the last state and uses it when entering PiP, closing
  the race where the system enters PiP before Flutter's next frame updates the
  native action;
- the native `RemoteAction` uses different microphone/cancel icons and
  explicit Start voice input/Stop listening titles and content descriptions;
- the old boolean `updatePipMicState` method remains as a compatibility shim
  for an already-installed Flutter shell, but new code uses the typed bridge.

Device evidence on the Samsung Android 14/API 34 handset:

- the rebuilt debug APK entered PiP with Android reporting `mode=pinned`, a
  3:4 surface, and `hasSetActions=true`;
- the Samsung PiP menu visibly rendered the avatar plus expand, close, and a
  microphone action icon;
- tapping the microphone action correlated with a platform
  `VOICE_RECOGNITION` start/stop pair while the app remained pinned, showing
  that the RemoteAction can reach the voice path;
- the handset still produced no transcript because its recognizer had no
  network and no offline `en-ZA` pack; Samsung's overlay did not expose the
  action's text/content description, so label discoverability is not claimed;
- a second Android implementation, action-level stop/mute semantics, and a
  visible compact status graphic remain validation/polish work.

### Voice phase presentation and PiP action-safety slice

This local round closes the most important user-facing gap left by the session
contract: the session could know that capture had stopped while the screen and
native PiP action still presented an ambiguous start/stop state. The Flutter
surface now derives its compact status from `VoiceSessionState`, rather than
from recorder or WebView timing alone:

- `VoiceSessionPhase` includes explicit capture, transcription, response, and
  terminal phases with stable user-facing labels;
- the expanded composer shows a live-region status row, a red recording/privacy
  dot while capture is active, and phase-specific icon/color treatment;
- the collapsed hold-to-talk control exposes an accessible Start/Stop label;
- relay `error`, `close`, and finalization-timeout events update the visible
  state and invalidate stale callbacks;
- a native PiP action is disabled while a turn is transcribing, thinking,
  speaking, or reconnecting, while still exposing the current status as the
  native fallback indicator;
- permission denial and recorder startup failures become visible `Voice error`
  states rather than silent no-ops.

Validation for this round:

- `flutter analyze`: clean;
- focused voice-session and Gateway-auth tests: passed;
- `flutter build apk --debug`: passed;
- Samsung Android 14/API 34 smoke: the Voice Input menu opened the platform
  recognizer and `AudioRecord`; PiP entered with `mode=pinned`, a 3:4 surface,
  and `hasSetActions=true`, with no crash or ANR;
- transcript/send is still not claimed: the handset's recognizer reports no
  offline `en-ZA` language pack and `NO_SPEECH_DETECTED`, so this environment
  cannot provide spoken text for the final chat-send assertion;
- the repository-wide Flutter suite still reports seven unrelated failures in
  `skill_provisioning_service_test.dart` around legacy dependency-pack label
  expectations. No changed voice test failed.

This round intentionally does not claim provider-backed transcript/send proof,
a second-OEM PiP result, or an unrestricted background microphone service. Those
remain explicit gates for the next validation pass.

## Proposed state boundary

Introduce a small voice-session model without moving every existing behavior at once:

```text
VoiceSessionState
  desiredMode: off | pushToTalk | continuous | wakeWord
  actualState: idle | starting | listening | transcribing | thinking |
               speaking | sent | noTranscript | paused | reconnecting |
               stopped | error
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
