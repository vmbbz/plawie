# Progress Check: PRoot To Embedded Native Node

Current checkpoint: 2026-06-02

## Main Goal

Drop PRoot as the production OpenClaw Gateway runtime and replace it with the
embedded Android native Node `libnode.so` runtime, without breaking chat,
providers, stream parsing, tool calls, skills, avatar/device bridges, startup,
or rollback.

This is not a haptics migration, a gestures migration, or a collection of
endless tiny canaries. Those canaries were evidence-gathering for the one real
goal: make native Node the production Gateway owner and demote PRoot to
rollback.

## Factual State

The migration is past "is native Node possible?" and past "can native Node speak
the Gateway dialect?" The proven work now covers the major runtime contracts:

- Android arm64 Node `22.22.3` `libnode.so` is packaged and launchable.
- Native Node can bind side-by-side on `18790`.
- Native Node can briefly own production port `18789` and roll PRoot back.
- Native Node can parse real `chat.send` shaped frames.
- Native Node can build provider requests, call a provider, parse streams,
  handle errors/timeouts/cancellation, and return chat-visible text.
- Native Node can capture provider tool plans, execute bounded native-to-Dart
  bridge calls, continue the provider conversation with tool results, and emit
  final assistant text.
- Native Node can see the production skill inventory in representative parity
  checks: `60` production skills, `60` native-visible skills, `0` missing.
- Native Node can see the mobile tool surface in representative parity checks:
  `10` mobile tools and `11` native tool hints.
- A promotion policy map exists for production skills, mobile bridge tools, and
  native mobile tool hints.
- Representative bridge lanes were promoted and soaked under rollback discipline:
  `device-node`, protected `avatar.gesture wave right`, and haptic candidate
  selection.

The crucial implication: we do not need to manually re-test every individual
OpenClaw skill one by one. We proved the classes of behavior that matter:
transport, provider envelope, streaming, tool-plan capture, Dart bridge
dispatch, chat-visible evidence, inventory parity, policy coverage, production
port ownership, and rollback.

## Loose End: Local NDK Gateway Route Hardening

Local on-device inference is still in play and remains independent of PRoot.
The latest installed-device run proved the Qwen 2.5 1.5B runtime, the native
HTTP bridge on `11435`, and direct OpenAI-compatible bridge requests.

The remaining loose end is narrower: Gateway-mediated chat using
`plawie_ndk/local-llm` reached the local bridge, but the chat UI timed out after
90 seconds without assistant text. That route is deferred to production
hardening because it is a Gateway-to-bridge stream/session issue, not evidence
that native Node default or direct local-model inference is broken.

Tracked in:
[86-local-ndk-gateway-route-hardening-loose-end.md](native-node-gateway/86-local-ndk-gateway-route-hardening-loose-end.md).

## Why The Plan Looked Inconsistent

The original phase map had the right destination, but the execution drifted
after the production chat-loop proofs. Instead of moving directly to the real
native Gateway bootstrap, we kept promoting individual bridge slices. That was
safe, but it became over-conservative once these facts were already proven:

- Phase 64: live provider-selected tool execution.
- Phase 65: live provider tool-result continuation.
- Phase 66: native-owned chat loop with final chat-visible text.
- Phase 67: production skill/tool inventory parity.
- Phase 68: promotion policy coverage.

After phase 68, the correct next strategic move should have been the real native
OpenClaw bootstrap path, not more bridge-by-bridge repetition. The later bridge
work is still useful evidence, but it is not the remaining blocker.

## Phase Group Audit

1. Foundation and strategy, phases 01-06:
   captured the current PRoot contract, runtime options, migration plan, risks,
   validation matrix, and research log.

2. Binary and Android runtime foundation, phases 07-21:
   established native smoke endpoints, packaging plans, Node 22 Android build
   evidence, `nodejs-mobile` patch understanding, embedded `libnode.so`
   integration, OpenClaw preflight, and Gateway bootstrap probes.

3. Protocol and frame parity, phases 22-30:
   proved skill registry inspection, request-shape parity, WebSocket
   `chat.send` frame parsing, Dart shadow parity, dry-run queues, direct native
   ACKs, native primary canary, stream canary, and routing skeleton.

4. Provider and tool contracts, phases 31-42:
   proved provider adapter shell, request builder, transport shim, live
   provider call, stream parser parity, provider tool-plan capture, tool
   dispatch dry-run, Dart bridge dry-run, bridge ordering/cancellation, and
   representative bridge execution classes.

5. Production-port ownership and rollback, phases 43-61:
   proved runtime selection, production-port bind, bind soak, runtime owner,
   provider envelope/builder/transport/live/stream/tool-plan under owner mode,
   production tool dispatch, Dart bridge dry-runs, read-only/haptic/avatar
   bridge execution, provider-backed chat, and chat-visible native response.

6. Native chat/tool loop, phases 62-66:
   proved route selection, allowlisted provider tool execution, live provider
   tool execution, tool-result continuation, and a native-owned chat loop that
   emits final visible assistant text.

7. Inventory and policy coverage, phases 67-68:
   proved native visibility of the full production skill registry and mobile
   tool surface, then mapped every production skill/tool/hint to a conservative
   promotion policy.

8. Representative promotions, phases 69-81:
   promoted and soaked selected mobile lanes with PRoot fallback still armed.
   This added confidence, but it does not change the main blocker.

## Actual Current State

The real OpenClaw Gateway now boots under embedded Android native Node on
`127.0.0.1:18790` for diagnostics and on `127.0.0.1:18789` as the selected
production owner.

This is no longer the small probe harness. The implemented native path now:

- extracts `assets/openclaw-node-modules.tar.gz`;
- launches the real OpenClaw package from `lib/node_modules/openclaw`;
- bypasses the desktop launcher wrapper and imports `dist/cli/run-main.js`
  directly to avoid an Android embedded-Node crash;
- patches Android-safe temp behavior for OpenClaw and Node `os.tmpdir()`;
- starts the real HTTP Gateway;
- loads the same 12 startup Gateway plugins observed under PRoot;
- exposes 177 Gateway methods;
- starts sidecars and heartbeat;
- answers `/health` with `{"ok":true,"status":"live"}`;
- serves the OpenClaw Control UI at `/`;
- stays alive in the isolated native Node process.

The real package details confirmed on-device:

- package root: `lib/node_modules/openclaw`
- package version: `2026.5.28`
- binary entry: `openclaw.mjs`
- real entry used on Android: `dist/cli/run-main.js`
- engine: `node >=22.19.0`

Observed startup plugins in both PRoot and native:

- `browser`
- `canvas`
- `device-pair`
- `file-transfer`
- `google`
- `memory-core`
- `microsoft`
- `openai`
- `openrouter`
- `phone-control`
- `talk-voice`
- `xai`

Native provider/catalog expansion later loaded 45 provider/catalog plugins.
That expansion is provider/catalog discovery, not the startup plugin list.

The concrete blockers fixed during real bootstrap were:

- desktop `openclaw.mjs` import crash under embedded Android Node;
- stale or partial extraction cache missing `typebox`;
- concurrent extraction/start race from repeated Flutter startup calls;
- hardcoded `/tmp/openclaw` fallback path;
- Node `os.tmpdir()` returning `/tmp` on Android.

The remaining work is not proving native Node can run OpenClaw. It can. The
remaining work is wiring this full native Gateway into production runtime
selection and then doing controlled cutover/rollback.

## 2026-06-02 Release Boundary Status

Native production ownership is implemented as the intended default owner:

- `PreferencesService.gatewayRuntimeOwner` defaults to
  `native-node-full-gateway-production`.
- A one-time cutover marker migrates eligible existing `proot` or unset owners
  to native once setup is complete.
- `/native-default-owner-enable` persists native production ownership.
- `/native-default-owner-rollback` restores PRoot and remains available outside
  the broad diagnostics gate.
- Sticky rollback is intentional: after rollback, that installed device remains
  on PRoot until native is explicitly re-enabled.

Current attached test device state after the latest release-boundary install:

- Native owns production port `18789`.
- `/health` returns `{"ok":true,"status":"live"}`.
- The app process and `:native_node_smoke` process are present.
- PRoot `openclaw` and `libproot.so` are absent during native ownership.
- `/native-default-owner-rollback` was invoked and proved sticky PRoot
  rollback.
- `/native-default-owner-enable` was invoked afterward and restored native as
  the persisted production owner.
- Force-stop/relaunch cold-started native as the selected default; native took
  longer than 35 seconds to become health-live, then returned green.

Release implication:

- For fresh installs, native is the intended default.
- PRoot is active only after an explicit rollback and remains sticky until
  native is re-enabled.

## 2026-06-02 Install/Test Run Addendum

The current debug APK was rebuilt, installed over USB, and tested on the
attached phone.

Passed:

- `flutter analyze lib/services/gateway_service.dart`.
- `flutter build apk --debug`.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk`.
- Native default production owner on `18789`.
- Native config mirror rewrites PRoot-only `/root/...` paths into
  app-private native paths.
- Native `openclaw.json` contains no `/root` entries after NDK bridge config.
- Normal native health on production port.
- Local Qwen 2.5 1.5B NDK model starts from the Local LLM page.
- NDK bridge on `11435` reports ready.
- Direct OpenAI-compatible bridge request returns `OK`.
- Rollback command restores PRoot, releases native, and reports PRoot health
  live.
- Re-enable command restores native as the persisted owner.
- Cold-start after force-stop selects native and reaches health-live.

Known edge:

- Gateway chat routed to `plawie_ndk/local-llm` reached the bridge
  (`requestCount` advanced) but the Chat UI timed out after 90 seconds with no
  assistant text. Direct bridge inference returned `OK`, so this is a
  Gateway-to-bridge request/stream/session edge, not a broken local model and
  not a PRoot-drop blocker for cloud/tool Gateway release.

Release decision from this run:

- Native `libnode.so` remains the intended Gateway default.
- PRoot remains packaged only as emergency rollback for the first public native
  default release.
- `local-llm/...` direct NDK inference remains supported and independent.
- `plawie_ndk/local-llm` should be documented as experimental until its
  Gateway chat stream behavior is hardened.

## What Is Left

Only these stages matter for the PRoot drop now:

1. App-signed native primary chat canary: complete.
   The installed app routed a real chat turn through the full native Gateway on
   `18789` using the normal Dart `GatewayConnection` device-identity handshake,
   then stopped native and verified PRoot rollback.

2. Native production runtime selector: complete.
   The installed app can select `native-node-full-gateway-production` for one
   guarded real chat turn, let native own `18789`, then restore `proot`.

3. Native primary soak and failure pressure: complete for cutover gating.
   The installed-app soak ran repeated native-owned real chat turns with
   rollback after every cycle. The pressure gate then ran a real native-owned
   chat turn through a provider-failure path and a forced owner rollback probe.
   Both returned PRoot to healthy production service.

4. Native default with rollback: complete for cutover gating.
   Default native ownership is proven on clean app cold-start, and the explicit
   operator rollback command is proven from that default-native state.

5. Remove PRoot from the default startup path: complete for debug cutover.
   The app now has a one-time native-default cutover marker, migrates eligible
   existing `proot` owners to `native-node-full-gateway-production`, and keeps
   `/native-default-owner-rollback` as a sticky emergency rollback path.

## Immediate Next Work

Next work is release hardening and package cleanup, not more
proof-of-possibility:

- Keep diagnostics-only commands available in debug builds, but keep `18790`
  smoke sidecar autostart behind the narrower
  `PLAWIE_NATIVE_GATEWAY_SMOKE_AUTOSTART_DIAGNOSTICS=true` toggle.
- Prepare the release/commit boundary with PRoot retained as emergency
  rollback only.
- Keep `/native-default-owner-rollback` documented as the one-action rollback.
- Harden or explicitly defer the Gateway-to-NDK bridge chat timeout before
  claiming `plawie_ndk/local-llm` as production-ready.

## 2026-06-01 Bootstrap Implementation Status

The real bootstrap path is now implemented locally and compiled:

- `NativeNodeEmbeddedService` has a `full-gateway-bootstrap` mode.
- That mode extracts `assets/openclaw-node-modules.tar.gz` into app storage.
- It locates `lib/node_modules/openclaw/openclaw.mjs`.
- It generates an Android-safe launcher with writable `HOME`, OpenClaw state,
  cache, temp directories, and a patched Node `os.tmpdir()`.
- It starts OpenClaw through embedded `libnode.so` on loopback port `18790`.
- `NativeNodeSmokeProcess`, `MainActivity`, `NativeBridge`,
  `GatewayRuntimeRegistry`, `NativeGatewaySmokeService`, and
  `GatewayService` expose the mode through the existing diagnostics path.
- A debug-only explicit `MainActivity` intent can start the full bootstrap from
  ADB even when PRoot is stuck booting and the chat UI is disabled.
- `:app:compileDebugKotlin` passes.
- `flutter build apk --debug` passes.
- APK install over USB passes.
- The full native Gateway reaches `[gateway] ready` on `18790`.
- `/health` returns `{"ok":true,"status":"live"}`.
- A debug-only production-owner action starts the same real native Gateway on
  `18789`.
- Production-port native ownership was confirmed on-device:
  `DEBUG_NATIVE_FULL_GATEWAY_PRODUCTION` started real OpenClaw under embedded
  Node on `18789`, the marker reached `gateway-ready`, and `/health` returned
  `{"ok":true,"status":"live"}`.
- PRoot rollback/default path was restored by force-stopping the debug owner and
  starting the app normally; production `/health` returned green again.

## 2026-06-01 Native Chat-Turn Gate Status

The next cutover gate is implemented locally and ready for the app-signed test:

- Native bootstrap now hydrates its app-owned OpenClaw home from the existing
  PRoot `.openclaw` config.
- It copies `.env` into the native OpenClaw state directory.
- It guarantees `gateway.auth.mode = token` and persists a token in the native
  config, so the real Gateway does not rely on an invisible runtime-only token.
- Hidden command `/native-full-chat-turn` now runs the real cutover shape:
  stop PRoot, start native on `18789`, connect over WebSocket, send
  `chat.send`, collect visible text or raw provider error, stop native, restore
  PRoot, and report every gate.
- `flutter analyze lib/services/native_gateway_smoke_service.dart
  lib/services/gateway_service.dart` passes.
- `:app:compileDebugKotlin` passes.
- `flutter build apk --debug` passes.
- APK install over USB passes.

Host-only WebSocket validation was attempted over ADB port-forward as a
no-UI check. Native correctly rejected token-only operator connect frames with
`CONTROL_UI_DEVICE_IDENTITY_REQUIRED`. That is expected and desirable: the real
app path must use Dart `GatewayConnection`, because it supplies the signed
device identity. Therefore the remaining proof for this gate is not "can the
host talk to native"; it is "can the installed app send `/native-full-chat-turn`
from Plawie chat and complete rollback."

The app-signed proof is now complete.

Latest app-signed `/native-full-chat-turn` result:

- `ok: true`
- `productionStopped: true`
- `productionPortReleased: true`
- `nativeStarted: true`
- `nativeHealthOk: true`
- `wsConnected: true`
- `wsConnectAttempts: 2`
- `chatSendAckSeen: true`
- `chatSendAccepted: true`
- `rawProviderErrorForwarded: true`
- `nativeStopped: true`
- PRoot rollback restored production `/health` on `18789`.

Two important fixes landed during this gate:

- WebSocket handshake failures now preserve the real gateway rejection reason
  instead of collapsing all failures into `handshake-timeout`.
- Gateway auto-start/auto-heal is paused while a native production owner swap
  canary is in progress, so PRoot does not respawn during deliberate native
  ownership. The logs confirmed the only `Starting gateway` line occurred after
  rollback began.

Current rollback state after host validation:

- Native debug owner was force-stopped.
- Normal app startup was restored.
- Production `/health` on `18789` returned `{"ok":true,"status":"live"}`.

Latest confirmed USB test sequence:

```powershell
adb -s RZCX30KA9AW install -r build\app\outputs\flutter-apk\app-debug.apk
adb -s RZCX30KA9AW forward --remove-all
adb -s RZCX30KA9AW forward tcp:28789 tcp:18789
adb -s RZCX30KA9AW forward tcp:28790 tcp:18790
adb -s RZCX30KA9AW forward tcp:8765 tcp:8765
adb -s RZCX30KA9AW reverse --remove-all
adb -s RZCX30KA9AW reverse tcp:28789 tcp:18789
adb -s RZCX30KA9AW reverse tcp:28790 tcp:18790
adb -s RZCX30KA9AW shell am start -n com.nxg.openclawproot/.MainActivity -a com.nxg.openclawproot.DEBUG_NATIVE_FULL_GATEWAY_BOOTSTRAP
curl.exe --max-time 8 http://127.0.0.1:28790/health
```

Latest key results:

- PID stayed alive: `com.nxg.openclawproot:native_node_smoke`.
- Listener confirmed: `127.0.0.1:18790`.
- HTTP root serves the OpenClaw Control UI.
- `/health` returns `{"ok":true,"status":"live"}`.
- Startup logs show 7 plugins loaded and 177 Gateway methods registered.
- Production owner listener confirmed: `127.0.0.1:18789`.
- Production owner marker: `openclawStarted: "gateway-ready"`, `port: 18789`.
- Rollback/default PRoot path verified after debug owner shutdown.

Next action:

- Run the native primary selector soak with PRoot rollback still armed.

## 2026-06-01 Native Runtime Selector Gate Status

The native production runtime selector is now app-signed and verified on-device.

Hidden command tested from the real Plawie chat UI:

```text
/native-full-selector-owner
```

Latest selector result:

- `phase: native-full-gateway-runtime-selector`
- `ownerBefore: proot`
- `ownerDuring: native-node-full-gateway-production`
- `ownerAfter: proot`
- `selectorSetOk: true`
- `selectorRestoredOk: true`
- `innerPhase: native-full-gateway-production-chat-turn`
- `innerOk: true`
- `productionStopped: true`
- `productionPortReleased: true`
- `nativeStarted: true`
- `nativeHealthOk: true`
- `wsConnected: true`
- `chatSendAckSeen: true`
- `chatSendAccepted: true`
- `visibleTextOk: true`
- `rawProviderErrorForwarded: false`
- `nativeStopped: true`
- `nativePortReleasedAfterStop: true`
- `rollbackStarted: true`
- `rollbackRunning: true`
- `rollbackHealthOk: true`
- `rollbackVerified: true`

The visible chat response confirmed:

```text
Native runtime selector can now select full native for a guarded real chat turn
and restore PRoot afterward.
nextGate: native primary soak with selector enabled and rollback still armed
```

Two additional native config fixes landed during this selector gate:

- Native copied OpenClaw config now rewrites `/root` and `/root/.openclaw/*`
  paths into the app-owned native OpenClaw home/state directories.
- Native copied OpenClaw config now clamps oversized `maxTokens`/`max_tokens`
  output caps to `1024` so OpenRouter/free-budget canaries do not request a
  giant default `16384` output budget.

Verification after the selector run:

- `flutter analyze` passed for the touched Gateway/native smoke files.
- `flutter build apk --debug` passed.
- APK install over USB passed.
- Native config no longer showed `/root` or `16384` in the app-owned native
  OpenClaw config; output caps are now `1024` or lower.
- Production `/health` after rollback returned `{"ok":true,"status":"live"}`.

## 2026-06-01 Native Primary Selector Soak Status

The first repeated native-primary selector soak is now implemented and verified
from the real Plawie chat UI.

Hidden command tested:

```text
/native-full-selector-soak-owner cycles=2
```

Latest soak result:

- `phase: native-full-gateway-runtime-selector-soak`
- `mode: repeated-native-owner-real-chat-turns-with-proot-rollback`
- `cyclesRequested: 2`
- `cyclesCompleted: 2`
- `failedCycle: 0`
- `allCyclesOk: true`
- cycle 1: `ok=true`, `chatSendAccepted=true`, `rollbackVerified=true`
- cycle 2: `ok=true`, `chatSendAccepted=true`, `rollbackVerified=true`
- both cycles returned raw provider errors instead of visible assistant text,
  which still validates native chat outcome handling and rollback under provider
  failure
- final log line: `NATIVE-FULL-SOAK OK Native selector survived repeated real
  chat turns with PRoot rollback.`
- production `/health` after the soak returned `{"ok":true,"status":"live"}`

This proves the selector is no longer just a single-turn trick. Native can be
selected repeatedly as production owner and PRoot returns after each cycle.

Next gate:

- Native default-owner switch with PRoot fallback still compiled and
  operator-accessible.

## 2026-06-01 Native Primary Pressure Soak Status

The bounded failure-pressure gate is now implemented and verified from the real
Plawie chat UI.

Hidden command tested:

```text
/native-full-selector-pressure-owner
```

Latest pressure result:

- `phase: native-full-gateway-runtime-selector-pressure-soak`
- `mode: native-chat-provider-failure-plus-forced-owner-rollback`
- `chatCyclesRequested: 1`
- `failedCycle: 0`
- `chatCyclesOk: true`
- `forcedRollbackOk: true`
- `allPressureOk: true`
- chat cycle 1: `ok=true`, `chatSendAccepted=true`,
  `rollbackVerified=true`, `rawProviderErrorForwarded=true`
- forced rollback: `ok=true`, `nativeHealthOk=true`, `nativeStopped=true`,
  `rollbackVerified=true`
- final log line: `NATIVE-FULL-PRESSURE OK Native selector survived chat
  failure pressure and forced owner rollback.`
- production `/health` after the pressure run returned
  `{"ok":true,"status":"live"}`

This is the important cutover implication: native survived a real provider
failure path and an explicit owner rollback path. The next gate is no longer a
new tool canary. It is the operator-controlled default-owner switch with an
explicit PRoot rollback command.

## 2026-06-02 Native Default Owner Status

The operator-controlled default-owner switch is now app-signed and verified.

Hidden command tested from the real Plawie chat UI:

```text
/native-default-owner-enable
```

Latest default-owner switch result:

- `phase: native-default-owner-switch`
- `mode: persistent-native-production-owner-with-explicit-proot-rollback`
- `ownerBefore: proot`
- `ownerAfter: native-node-full-gateway-production`
- `selectedOwnerId: native-node-full-gateway-production`
- `rollbackOwnerId: proot`
- `nativePreStartStopped: true`
- `prootStopped: true`
- `productionPortReleased: true`
- `selectorSetOk: true`
- `nativeStarted: true`
- `nativeHealthOk: true`
- `nativeHealthStatus: live`
- `wsConnected: true`
- `rollbackAttempted: false`

The first cold-start retest exposed a real cutover blocker: stale/native retry
cleanup was stopping the active production native runtime before the full
Gateway settled. The fix narrowed production pre-start cleanup so it clears the
old `18790` smoke lane only when the smoke port is actually listening and
production `18789` is not already listening.

Clean force-stop/relaunch proof after the fix:

- app launched from a force-stopped state;
- PRoot process stayed absent for the full poll;
- native isolated process stayed up as
  `com.nxg.openclawproot:native_node_smoke`;
- native `/health` on production port `18789` reached
  `{"ok":true,"status":"live"}` at about 65 seconds;
- `/health` remained live through the 3-minute poll;
- final process check: PRoot pid absent, native pid present;
- final host check: `curl http://127.0.0.1:28789/health` returned
  `{"ok":true,"status":"live"}`.

This is the first clean proof that the app can cold-start with native Node as
the persisted production Gateway owner while PRoot remains out of the default
startup path.

The explicit rollback command then passed from this default-native state:

- command submitted through chat as `native-default-owner-rollback`;
- `ownerBefore: native-node-full-gateway-production`;
- `ownerAfter: proot`;
- `selectorRestoredOk: true`;
- `nativeStopRequested: true`;
- `nativeStopped: true`;
- `nativeStopVerified: true`;
- `nativePortReleased: true`;
- `prootStarted: true`;
- `prootRunning: true`;
- `prootHealthOk: true`;
- `prootHealthStatus: live`;
- final host check: `curl http://127.0.0.1:28789/health` returned
  `{"ok":true,"status":"live"}`;
- final persisted owner check: `flutter.gateway_runtime_owner` is `proot`.

Next gate:

- Final startup cutover patch: demote PRoot from default startup to emergency
  rollback.

The short default-native release-window soak then passed the production decision
points:

- persisted owner set to `native-node-full-gateway-production`;
- app force-stopped and relaunched cleanly;
- PRoot stayed absent during native cold-start;
- native production `/health` on `18789` reached
  `{"ok":true,"status":"live"}`;
- normal chat prompt submitted through default-native production Gateway;
- provider path returned a chat-visible OpenRouter billing error instead of
  hanging or losing the turn;
- `/native-default-owner-rollback` restored the selected owner to `proot`;
- PRoot production `/health` on `18789` returned
  `{"ok":true,"status":"live"}`;
- a native diagnostic smoke process remained on `18790` in `embedded-smoke`
  mode, which is not production ownership.

Cutover note: the OpenRouter billing error blocks a successful assistant-text
soak, but it does not block the PRoot drop mechanics. It proves the
default-native runtime reached provider routing and surfaced the provider error
through chat. A paid/working provider key should be used for the final
assistant-text confirmation after the startup cutover patch.

The final startup cutover patch is now implemented and tested:

- `PreferencesService.gatewayRuntimeOwner` now defaults to
  `native-node-full-gateway-production`.
- A one-time `native_gateway_default_cutover_applied` marker migrates an
  existing `proot` owner to native after setup is complete.
- If native default startup fails, `GatewayService.attachOrStart()` attempts
  `_restoreProotDefaultOwner()` automatically and reports the rollback.
- Installed debug APK passed `flutter analyze` and `flutter build apk`.
- Pre-launch state was `gateway_runtime_owner=proot` and no cutover marker.
- First launch after install migrated owner to
  `native-node-full-gateway-production` and set
  `native_gateway_default_cutover_applied=true`.
- PRoot pid stayed absent during cutover cold-start.
- Native production `/health` on `18789` reached
  `{"ok":true,"status":"live"}` at about 42 seconds.
- `/native-default-owner-rollback` restored `gateway_runtime_owner=proot`.
- PRoot production `/health` on `18789` returned
  `{"ok":true,"status":"live"}` after rollback.
- A force-stop/relaunch after rollback preserved `gateway_runtime_owner=proot`
  because the cutover marker remained true; PRoot came live again on `18789`.

This means the PRoot drop is now wired in the app startup path, with sticky
rollback preserved. The remaining release risk is provider-account success
confirmation and release-mode diagnostics tightening, not native Gateway
viability.

Release diagnostics tightening is now implemented and device-checked:

- `PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true` still unlocks hidden native
  diagnostics commands for this debug branch.
- Startup sidecar checks now require the narrower
  `PLAWIE_NATIVE_GATEWAY_SMOKE_AUTOSTART_DIAGNOSTICS=true` define.
- `runStartupSelfTestIfEnabled()` and `runCanaryComparisonIfEnabled()` no
  longer auto-start the `18790` native smoke sidecar from broad diagnostics.
- Installed debug APK passed `flutter analyze`, `flutter build apk`, install,
  force-stop, and relaunch.
- After rollback, the installed app stayed on the sticky PRoot owner state.
- Production `/health` on `18789` returned `{"ok":true,"status":"live"}`.
- Process check showed only the Plawie app process and the PRoot `openclaw`
  process; `com.nxg.openclawproot:native_node_smoke` was absent.
- Host check against forwarded `18790` refused connection, proving the
  diagnostics sidecar did not auto-start.

This closes the release-mode diagnostics tightening item. The next real gate is
assistant-text confirmation with a working provider key on the native default
path, then the release/commit boundary with PRoot documented as emergency
rollback.

## 2026-06-02 Native Default Chat/Provider Gate Status

The next production-path gate was run after diagnostics tightening:

1. The app was switched from sticky PRoot rollback back to native default using
   the hidden operator command:

   ```text
   /native-default-owner-enable
   ```

2. Native became the selected production owner and started the real embedded
   OpenClaw Gateway on production port `18789`.

3. PRoot was stopped and stayed absent during the native-owned production
   window.

4. A normal non-slash chat prompt was sent through the real Plawie chat UI:

   ```text
   reply_with_native_release_gate_ok
   ```

5. The native production Gateway accepted the chat turn, routed it to
   `openrouter/auto`, and surfaced the provider result back into chat.

The provider result was not assistant text because OpenRouter returned a billing
error:

```text
openrouter (openrouter/auto) returned a billing error -- your API key has run
out of credits or has an insufficient balance.
```

This is a provider-account blocker, not a native Gateway blocker. The important
migration signal is that the default-native production path:

- owned `18789`;
- accepted a normal chat prompt;
- reached provider routing;
- surfaced the raw provider failure in the chat UI;
- did not hang;
- did not require PRoot to process the turn.

After the provider-failure test, rollback was run from the same chat UI:

```text
/native-default-owner-rollback
```

Rollback result:

- `ownerBefore: native-node-full-gateway-production`;
- `ownerAfter: proot`;
- `selectorRestoredOk: true`;
- `nativeStopped: true`;
- `nativeStopVerified: true`;
- `nativePortReleased: true`;
- `prootStarted: true`;
- `prootRunning: true`;
- `prootHealthOk: true`;
- `prootHealthStatus: live`;
- production `/health` on `18789` returned
  `{"ok":true,"status":"live"}`;
- `18790` did not return native health, confirming the diagnostics smoke
  sidecar was not live.

Final safe state after this gate:

- selected owner: `proot`;
- production Gateway: PRoot live on `18789`;
- native smoke sidecar: absent;
- smoke port `18790`: no native health response.

The remaining release blocker is one clean assistant-text confirmation with a
working provider key on the default-native path. Once that passes, the migration
can move to the release/commit boundary with PRoot retained as documented
emergency rollback.

## Release Decision Rule

Native should be treated as the intended default runtime now, with one hard
release gate still open:

- If native default owns `18789`, accepts a normal chat prompt, reaches the
  configured provider, and returns assistant text, the PRoot migration can move
  to the release/commit boundary.
- If native default owns `18789`, accepts a normal chat prompt, reaches the
  configured provider, and returns a raw provider/account error, the Node/PRoot
  migration mechanics are still passing, but release remains blocked on provider
  account configuration.
- If native cannot own `18789`, cannot pass `/health`, cannot accept normal
  chat, hangs without an error, or fails rollback, release is blocked on native
  runtime wiring.

Previous classification before the fresh-key retry: provider/account blocked,
not native-runtime blocked.

The next test at that point was not another bridge/tool micro-canary. It was a
single normal chat prompt on native default with a working provider key. Expected
pass line, now satisfied by the fresh-key gate below:

```text
native default -> 18789 health live -> normal chat accepted -> provider assistant text visible -> rollback command restores PRoot
```

## 2026-06-02 Fresh-Key Native Default Release Gate

The fresh-provider-key release gate passed from the real Plawie chat UI.

Preconditions:

- installed debug APK was already built and installed over USB;
- `flutter analyze` passed for the touched Dart gateway/native files;
- `flutter build apk --debug` passed;
- `:app:compileDebugKotlin` passed with Android Studio JBR as `JAVA_HOME`;
- baseline production `/health` on `18789` returned
  `{"ok":true,"status":"live"}`;
- baseline owner was PRoot, with PRoot pid present and native smoke process
  absent;
- the fresh provider key had already produced a normal visible chat response on
  the PRoot baseline path.

Native default ownership gate:

- command sent from the real chat UI:

  ```text
  /native-default-owner-enable
  ```

- native production process became live as
  `com.nxg.openclawproot:native_node_smoke`;
- PRoot process became absent;
- production `/health` on `18789` reached
  `{"ok":true,"status":"live"}`;
- pass poll: native pid `31610`, PRoot absent, health live.

Native default assistant-text gate:

- normal non-command chat prompt sent through the real chat UI:

  ```text
  Reply_with_exactly_native_release_validation_ok
  ```

- logs showed `[CHAT]` first token received and `[CHAT]` complete;
- visible chat response returned:

  ```text
  native-release-validation-ok
  ```

- native production `/health` stayed live throughout the provider turn;
- no provider billing error appeared on this fresh-key run.

Rollback and sticky recovery:

- command sent from the same chat UI:

  ```text
  /native-default-owner-rollback
  ```

- native process stopped;
- PRoot pid `1829` came back;
- production `/health` on `18789` returned
  `{"ok":true,"status":"live"}`;
- app was force-stopped and relaunched;
- PRoot pid `2285` came back after relaunch;
- native smoke process stayed absent after relaunch;
- production `/health` on `18789` again returned
  `{"ok":true,"status":"live"}`.

Current classification: native default release gate passed, with PRoot rollback
and sticky rollback recovery proven after the pass.

Remaining work is now release-boundary work:

- keep PRoot documented as emergency rollback;
- commit the migration state cleanly;
- decide debug/release diagnostics exposure;
- prepare the final operator runbook for native default and rollback.

## 2026-06-02 Release Boundary Documentation

The current architecture and operator path are now documented in:

```text
docs/native-node-gateway/82-release-boundary-architecture-runbook.md
```

That runbook is the current source of truth for:

- active runtime engines and runtime ids;
- production and diagnostics ports;
- native and PRoot state paths;
- the native-default switch command;
- the PRoot rollback command and aliases;
- health/process verification commands;
- diagnostics build flags;
- USB forwarding and cleanup;
- the final release decision rule.

The older `docs/native-node-gateway` phase files remain historical evidence.
They should not be read as the current production owner rule if they say PRoot
is still the default. The current owner rule is:

```text
native-node-full-gateway-production is the intended default;
proot is the sticky emergency rollback owner.
```

Immediate release-boundary tasks after this documentation pass:

- decide which diagnostics flags ship in debug, internal release, and public
  release variants;
- commit the migration state cleanly;
- keep `/native-default-owner-rollback` documented and available until a later
  cleanup release intentionally removes PRoot.

Rollback exposure fix:

- `/native-default-owner-rollback` is no longer grouped with diagnostics-only
  canary command detection.
- Native-default enable remains diagnostic/operator gated.
- This keeps the emergency PRoot recovery path available even when broad native
  diagnostics are disabled for release.

## 2026-06-02 Public Rollback-Shaped APK Gate

The public native-default rollback package boundary was built, installed, and
tested on the USB-connected device.

Build shape:

```powershell
flutter build apk --release `
  --dart-define=PLAWIE_NATIVE_GATEWAY_RELEASE_VARIANT=public-rollback `
  --dart-define=PLAWIE_NATIVE_GATEWAY_OWNER_SWITCH_COMMANDS=true
```

Observed results:

- release APK built successfully and installed with `adb install -r`;
- cold launch selected native Node as production owner;
- `127.0.0.1:18789 /health` returned `{"ok":true,"status":"live"}`;
- process state while native owned production was app process plus
  `com.nxg.openclawproot:native_node_smoke`;
- PRoot `libproot.so` and PRoot `openclaw` were absent while native owned
  production;
- device netstat showed `18789` and Android node host `8765`, with no `18790`
  diagnostics sidecar listener;
- real chat UI provider smoke on `OpenRouter Free Router` returned visible
  assistant text `OK`;
- production health stayed live after the provider-backed chat;
- `/native-default-owner-rollback` from chat restored PRoot, stopped native,
  released native ownership, and returned health-live;
- `/native-default-owner-enable` from chat restored native default, removed live
  PRoot processes, and returned health-live.
- the final rebuilt public rollback RC pass corrected and reverified the owner
  switch report so `nativeRunning: true` is shown with `nativeHealthOk: true`
  after `/native-default-owner-enable`; see
  [88-public-rollback-rc-package-pass.md](native-node-gateway/88-public-rollback-rc-package-pass.md).

Current classification: the first public rollback-shaped release package gate
passed. PRoot is still packaged and proven as rollback, but native Node is the
intended default owner.

## 2026-06-02 Runtime Package Scope Polish

The release UI now distinguishes native Gateway requirements from old
Linux/PRoot package assumptions:

- Native `libnode.so` Gateway does not require Go, Homebrew, Twilio, or Calls
  packages to boot or serve chat.
- Go and Homebrew are labeled as PRoot rollback shell extras.
- Twilio and Calls are labeled as partner skills managed from Bot Management >
  Skills, not native runtime packages.
- Packages, setup, settings, dashboard, skills, and Calls UI copy were updated
  to avoid presenting PRoot-only packages as native Gateway prerequisites.
- The internal no-PRoot package proof now has an explicit Gradle property:

  ```powershell
  .\gradlew :app:assembleRelease `
    -PplawieInternalNoProotProof=true
  ```

  That property excludes PRoot native libraries only for the internal proof
  artifact. Public rollback builds still package PRoot as emergency rollback.

## 2026-06-02 Release Reset After PRoot/Native Log Confusion

The current factual state is:

- native default plus PRoot rollback mechanics are proven by the public
  rollback-shaped APK gate;
- the currently attached device may still show PRoot if it was explicitly
  rolled back, because rollback is sticky by design;
- PRoot chat was observed recovering from a busy/no-first-token window and then
  returning visible assistant responses after the Gateway settled;
- that PRoot recovery should not be classified as "PRoot broken";
- native runtime logs looked weaker than PRoot logs because the Dart
  `GatewayRuntime` implementations for native runtimes returned an empty
  `logStream`;
- native ownership must therefore be judged from app-scoped owner/health/process
  evidence plus native runtime logs, not from whole-phone WebSocket/noise logs.

Release-polish correction:

- native runtimes now poll their native log source and feed redacted lines into
  the same GatewayService log subscription path used by PRoot;
- this makes native startup/plugin/health logs visible in the app activity log
  instead of making healthy native ownership look silent;
- PRoot's streamed logs and native's polled logs are not identical plumbing, but
  they now share the same UI/service observability path.

Remaining release blockers are not more tiny bridge canaries. They are:

- one clean public rollback release build after the native log-stream patch:
  complete;
- install on USB-connected device: complete;
- verify PRoot sticky rollback baseline health/chat after readiness: complete;
- verify re-enable returns to native with no live PRoot process: complete;
- verify native owner health and in-app startup/log evidence: complete;
- verify rollback to PRoot releases native, waits for Gateway settle, and then
  chat responds: complete;
- keep local NDK Gateway bridge-chat hardening documented as a deferred loose
  end, while direct local NDK inference remains supported;
- commit only the release-boundary code/docs, excluding generated build reports
  and APK artifacts.

Final rebuilt public rollback RC evidence:

- build command:
  `flutter build apk --release --dart-define=PLAWIE_NATIVE_GATEWAY_RELEASE_VARIANT=public-rollback --dart-define=PLAWIE_NATIVE_GATEWAY_OWNER_SWITCH_COMMANDS=true`;
- release APK built and installed over USB on `RZCX30KA9AW`;
- attached device initially came up on sticky PRoot rollback, which is expected
  after explicit rollback because `native_gateway_default_cutover_applied`
  remains set;
- PRoot baseline process state showed the app process, `libproot.so`, and
  PRoot `openclaw`, with native absent;
- PRoot reached `Gateway RPC discovery complete` and then served a real chat
  turn with `Gateway accepted`, `First token received`, and `Complete`;
- `/native-default-owner-enable` switched to native, showed
  `nativeRunning: true` with `nativeHealthOk: true`, and removed live PRoot
  processes;
- `/native-default-owner-rollback` restored selector `proot`, stopped native,
  waited for native port release, started PRoot, and returned production health
  live;
- a too-early post-rollback send before RPC readiness hit the 90s no-first-token
  recovery guard; this was not counted as PRoot failure because RPC discovery
  completed only after that first turn had already timed out;
- the held retry after Gateway settle sent at `10:51:01`, received first token
  at `10:51:18`, and completed at `10:51:18`.

Current release classification: public rollback RC mechanics are passing. The
remaining work before push is documentation cleanup, focused analyzer checks,
excluding generated build artifacts, and committing the release-boundary patch.

Known polish/loose ends that do not block this RC boundary:

- post-recovery wait UI can feel opaque after a too-early send;
- transition-time TTS may log `talk.speak failed: Bad state: No element`;
- native log polling and PRoot log streaming are now both visible, but they are
  not identical transports;
- `OpenRouter Free Router` catalog metadata is conservative, but normal Gateway
  chat still attached `Mobile node tool context (OpenClaw Mobile)` in the real
  logs;
- direct local NDK inference remains supported, while Gateway-to-NDK chat bridge
  hardening remains deferred.
