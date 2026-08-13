# Release Boundary Architecture And Runbook

Date: 2026-07-25

Status: current release-boundary reference after the fresh-key native default
release gate passed.

## Purpose

This document freezes the current architecture and operator procedure for the
PRoot to embedded native Node migration.

The migration goal is:

```text
Drop PRoot as the production OpenClaw Gateway runtime and replace it with the
embedded Android native Node libnode.so runtime, while preserving chat,
providers, streaming, skills, tools, avatar/device bridges, startup behavior,
and one-action rollback.
```

The current state is not "research only" anymore. Native Node has passed the
native-default release gate with a working provider key:

```text
native default -> 18789 health live -> normal chat accepted
-> provider assistant text visible -> PRoot rollback restored and sticky
```

PRoot is still intentionally retained as an emergency rollback engine.

## Runtime Architecture

The production Gateway contract remains stable:

```text
Flutter UI
  -> GatewayService
  -> selected GatewayRuntime
  -> OpenClaw Gateway on 127.0.0.1:18789
  -> GatewayConnection / WebSocket / chat.send / tools / skills
```

The runtime owner is selected by `PreferencesService.gatewayRuntimeOwner`.
The fallback registry object still exists as `GatewayRuntimeRegistry.current`,
but the selected owner preference decides what starts.

Current owner default:

```text
native-node-full-gateway-production
```

Emergency rollback owner:

```text
proot
```

Important distinction:

- Fresh installs and eligible upgraded installs should select native production
  by default.
- A device that was manually rolled back during testing will keep `proot` as a
  sticky emergency owner until `/native-default-owner-enable` is run again.

## Engines

| Engine | Runtime id | Role |
| --- | --- | --- |
| Embedded native Node full Gateway | `native-node-full-gateway-production` | Intended production owner on `127.0.0.1:18789` |
| PRoot Gateway | `proot` | Emergency rollback owner on `127.0.0.1:18789` |
| Embedded native Node full Gateway sidecar | `native-node-full-gateway-bootstrap` | Diagnostics sidecar on `127.0.0.1:18790` |
| Embedded native Node smoke | `native-node-embedded-smoke` | Historical diagnostics smoke lane |
| Native smoke server | `native-node-smoke` | Historical basic HTTP smoke lane |
| Production-port canary | `native-node-production-port-canary` | Historical guarded bind canary |

Local LLM and voice/TTS engines are separate app capabilities. They do not own
the OpenClaw Gateway port and are not substitutes for the Gateway runtime owner.

Local NDK LLM remains in the product:

- `local-llm/...` bypasses Gateway and runs directly through fllama.
- `plawie_ndk/local-llm` keeps Gateway as tool/session owner and routes model
  generation through the manual Dart bridge on `127.0.0.1:11435`.
- Native `libnode.so` replaces the Gateway owner, not fllama.
- PRoot removal must not remove the Local LLM page, direct GGUF inference, or
  the NDK bridge.

Latest installed-device result:

- Qwen 2.5 1.5B starts from the Local LLM page.
- The NDK bridge reports ready on `127.0.0.1:11435`.
- A direct OpenAI-compatible bridge request returned `OK`.
- Gateway chat to `plawie_ndk/local-llm` reached the bridge, but the Chat UI
  timed out after 90 seconds without assistant text. Treat bridge-chat as
  experimental until this stream/session path is hardened.

## Ports

| Port | Owner | Use |
| --- | --- | --- |
| `127.0.0.1:18789` | exactly one production runtime | Production OpenClaw Gateway HTTP and WebSocket |
| `127.0.0.1:18790` | native diagnostics sidecar only | Native smoke/bootstrap diagnostics, not production |
| `127.0.0.1:8765` | phone-side `AgentSkillServer` | Host inspection may use `adb forward`; do not `adb reverse` it |
| `127.0.0.1:11435` | optional Dart NDK bridge | Manual OpenAI-compatible local model provider for `plawie_ndk/local-llm` |

Host inspection over USB usually maps:

```powershell
adb -s RZCX30KA9AW forward tcp:28789 tcp:18789
adb -s RZCX30KA9AW forward tcp:28790 tcp:18790
```

Do not treat those host ports as app architecture. They are only USB inspection
tunnels.

## Diagnostics And Release Variants

The release boundary has three practical variants:

| Variant | Native owner default | PRoot packaged | Diagnostics commands | Intended use |
| --- | --- | --- | --- | --- |
| Debug/internal diagnostics | Native, unless sticky rollback | Yes | Broad hidden canaries enabled | Engineering and field validation |
| Public rollback build | Native | Yes | Rollback available; broad canaries disabled | First native-default public release |
| No-PRoot branch build | Native | No | Rollback replaced by native repair/reset | Later cleanup branch after rollback is no longer needed |

Rules:

- Public builds must not autostart `18790`.
- Public builds must keep rollback available while PRoot is packaged.
- Debug/internal builds may expose the wide canary command set.
- No-PRoot builds must prove local NDK direct and NDK bridge routes before PRoot
  payload removal.

## Native Node Package Path

The native production runtime in the Android app contains only Plawie-owned
runtime components:

```text
libnode.so
libplawie_node_bridge.so
```

It does not contain an OpenClaw package archive. On fresh setup, the app
resolves the latest stable `openclaw/openclaw` GitHub release, verifies its
published evidence/checksum sidecars, downloads the exact official npm tarball
attested by that evidence, verifies its SHA-512 integrity, and installs it with
an integrity-pinned official npm CLI bootstrap.

The npm transaction runs in an isolated Android process because embedded
`process.exit()` can terminate a libnode host process. Before npm starts, the
app persists the verified upstream release metadata beside an app-private
staging directory. If npm exits the installer process after writing its durable
`exit 0` record, the UI process verifies and atomically activates that same
staged package. Recovery never downloads the OpenClaw tarball a second time.

The isolated installer also persists sanitized progress in the same durable
status record. Flutter and the one shared setup foreground notification show
release validation, byte-level official tarball download, pinned npm bootstrap,
npm installation liveness, and final verification without creating a second
notification.

The verified official package is installed into app-private storage:

```text
$filesDir/native-node-embedded/
$filesDir/native-node-embedded/native-home/
$filesDir/native-node-embedded/native-home/.openclaw/
```

Before launch, the Android runtime adapter applies narrow, idempotent
mobile compatibility changes to the verified installed tree:

- `/tmp/openclaw` is redirected into app-private storage.
- The desktop legacy state-migration preflight and its secondary SQLite
  checkpoint are disabled only on Android. OpenClaw's guarded config snapshot,
  config validation, and normal Gateway SQLite state still run. Direct device
  canaries pass SQLite import/open/write/read/close; the crash is specific to
  the legacy migration preflight. Plawie's native state starts on the current
  schema and is not imported from the separate PRoot rollback home.

Native `attachOrStart` does not await dashboard discovery before entering the
process/health waiter. If the isolated process exits, setup receives the
diagnostic promptly instead of continuing a stale 180-second progress loop.

The isolated Gateway service is non-sticky. Android must not resurrect a
crashed production Gateway with an empty intent, because the default diagnostic
port would otherwise hide the crash behind a healthy `18790` smoke process.
The app watchdog may restart the Gateway only through an explicit production
owner request.

The installed package must satisfy this layout before native Gateway start:

```text
package root: lib/node_modules/openclaw
package version: version named by the verified upstream release evidence
declared binary entry: openclaw.mjs
Android embedded entry used: dist/cli/run-main.js
required Node engine: node >=22.22.3
```

The Android launcher bypasses the desktop CLI wrapper and imports
`dist/cli/run-main.js` directly. It also patches Android-safe temp behavior and
rewrites copied `/root/.openclaw` paths to the native app-owned state directory.

## Native Provider And Optional-Pack Boundary

The embedded native Gateway is configured only with providers that can run from
the official core or through the explicit local NDK bridge. The app removes
stale catalog defaults and refuses an automatic npm/plugin-repair request at
runtime. For example, Groq is an upstream external
`@openclaw/groq-provider` package and cannot be enabled in native setup until a
verified native extension pack exists.

The native config writes an explicit `plugins.allow` containing only
Android-safe bundled official-core plugins and app-owned plugins admitted by
the verified-plugin policy. It drops arbitrary load paths, legacy install
records, unsupported entries, and unsupported slot selections on every policy
pass. A verified plugin is copied from the signed APK into app-private storage,
checked file-by-file against pinned SHA-256 values, bounded to its reviewed
OpenClaw version line, and activated through a staging-directory rename before
the Gateway starts. Config can refer only to the fixed derived path under
`$filesDir/native-node-embedded/full-openclaw/verified-plugins`; it cannot add a
writable or downloaded plugin path.

The first verified extension is `plawie-venice-compat`. It registers hooks only
for provider `venice` and upstream model IDs in the Gemini family. It delegates
replay sanitation and tool-schema normalization to OpenClaw 2026.7.1's official
`passthrough-gemini` and Gemini provider-tool helpers. It does not make network
requests, hold credentials, invent thought signatures, or alter Venice GLM,
Venice Gemma, BlockRun, BYOK, or local-model traffic. Changing its source bytes
or supported Gateway line requires updating the pinned bootstrap receipt and
the model capability-profile version.

If upstream nevertheless requests npm, the launcher blocks it and records
sanitized command arguments and a callsite in
`native-full-gateway-bootstrap-stdio.log`; it never logs credentials.

Native startup skill parity is audit-only. It uses
`repairNativeFromProot: false` and plans missing dependencies without
installing them. Gateway attach, pre-start, readiness, and chat must not copy
from PRoot or download/execute a dependency pack as a side effect.

The OpenClaw core receipt is separate from Plawie optional dependency-pack
receipts:

- core reuse requires the exact verified upstream version and tarball integrity;
- optional-pack reuse requires matching id, version, SHA-256, provisioned
  markers, and a passing smoke receipt.

Do not add a raw ELF command pack to native fresh setup. Stock Android blocks
execution from app-writable storage. Native setup accepts only payloads that
have a verified Android-native loader (APK/JNI), embedded-libnode JavaScript,
or data-only assets. Current remote Linux command packs are excluded from
native first-run setup and stay available only after the user explicitly
chooses PRoot rollback. Optional-pack problems must never invalidate an already
verified native Gateway core installation.

The Dart config mirror also rewrites Linux-only PRoot paths before native reads
them:

```text
/root/... -> $filesDir/native-node-embedded/native-home/...
```

The latest installed-device test confirmed the native `openclaw.json` contains
no `/root` entries after NDK bridge configuration. This prevents embedded Node
from attempting to create `/root` during Gateway-owned local bridge turns.

## Foreground Notification Ownership

Foreground notifications have one owner per active role:

| Role | Owner | Notification |
| --- | --- | --- |
| Setup, including official npm provisioning | `SetupService` and the isolated installer sharing one record | ID 3, `OpenClaw Setup` |
| Native Gateway and paired local phone node after setup | `NativeNodeEmbeddedService` and `NodeForegroundService` sharing one record | ID 7, `OpenClaw Gateway` |
| Explicit PRoot rollback Gateway | `PlawieForegroundService` | ID 4 |
| Optional remote/rollback paired node without the native owner | `NodeForegroundService` | ID 9 |

The native runtime shares the setup record while setup is still active, then
promotes it to the running-Gateway record at completion. Once paired, the local
phone-node service reuses that same package/channel/ID instead of adding a
second persistent notification. Stopping only the phone node detaches it from
the shared record; the native Gateway remains the notification owner.
Unchanged notification text and repeated service-start requests are coalesced
instead of reposting the same Android record. The old Flutter foreground-task
notification is not started. Hotword, screen capture, and terminal
notifications remain separate only while those distinct user-enabled
capabilities are active.

## Gateway Plugins, Skills, And Device Capabilities

Gateway plugin logs are runtime-extension evidence, not a complete list of
every skill or phone action.

The post-ready native skill audit emits one readiness/provisioning summary.
Unchanged missing optional packs stay available in structured management state
but are not repeated line-by-line in every Gateway startup log.

Observed PRoot startup plugins:

```text
browser, canvas, device-pair, file-transfer, google, memory-core, microsoft,
openai, openrouter, phone-control, talk-voice, xai
```

Observed embedded native Node startup plugins:

```text
browser, canvas, device-pair, file-transfer, google, memory-core, microsoft,
openai, openrouter, phone-control, talk-voice, xai
```

Both paths registered these startup plugin commands:

```text
/pair
/dreaming
/phone
/voice
```

Native provider/catalog expansion also loaded 45 provider/catalog plugins and
reported `177` methods and `27` events. That expanded provider/catalog load is
not the same as the 12 startup plugins.

Current phone-side `AgentSkillServer` tool catalog exposes 10 schemas:

```text
avatar-control
tts-voice
device-node
avatar_overlay
base-chain
twilio-voice
agent-card
molt-launch
valeo-sentinel
moonpay
```

Current Android node commands cover avatar, camera, canvas, flashlight/torch,
location, screen recording, sensor, and haptic actions. They do not currently
prove a generic third-party app launcher or a safe WhatsApp send command.

Protected canvas content is served by the Gateway canvas plugin. Android must
load canvas files through the node-scoped `pluginSurfaceUrls.canvas` URL
advertised by the node connect handshake, then append the
`/__openclaw__/canvas/...` file path. Do not construct ad hoc token query
strings for canvas WebView navigation; those can drift from the Gateway's
plugin auth boundary and surface as WebView `Unauthorized` responses.
Scoped URLs are short-lived in current OpenClaw releases. The Android node
refreshes the canvas surface with `node.pluginSurface.refresh` before each
canvas operation, and the WebView treats HTTP 4xx/5xx responses as invocation
failures instead of reporting an error page as successfully presented.

Release rule:

- Do not say "phone-control can send WhatsApp messages" until a concrete
  Android bridge command exists, is in `gateway.nodes.allowCommands`, is backed
  by `AgentSkillServer`, and has a user-confirmation policy.
- Safe first support should compose/open a message with user confirmation, not
  silently send it.

## PRoot Path

PRoot remains present for emergency rollback and for historical management
paths that still read or repair PRoot state:

```text
$filesDir/rootfs/ubuntu/root/.openclaw/
```

Fresh native bootstrap neither starts nor reads PRoot. It builds native
app-private state from the official upstream package; PRoot is entered only
after the user explicitly requests rollback.

## Memory And Efficiency Boundary

Native `libnode.so` still runs the full OpenClaw Gateway, Node/V8, plugins,
providers, sessions, and sidecars. The efficiency gain is removing PRoot's
Ubuntu userland and compatibility process layer from the active production
runtime.

When native owns `18789`:

- PRoot should be stopped.
- The PRoot `openclaw` process should be absent.
- `libproot.so` should not be active for Gateway service.
- `18790` should not autostart unless an explicit diagnostics variant enables
  it.

When PRoot owns `18789`:

- Native production process should be absent.
- Sticky rollback state is intentional.

On-device native logs showed full-Gateway RSS near `452.6 MB` at ready and
near `501.7 MB` post-ready. That is the native full OpenClaw workload, not a
small smoke server. PRoot's extra memory/CPU cost comes from the additional
compatibility/userland layer around a similar Gateway workload.

PRoot files may remain on disk for rollback. Disk presence is not RAM usage.

## Startup And Cutover

`PreferencesService.gatewayRuntimeOwner` now defaults to:

```text
native-node-full-gateway-production
```

There is a one-time cutover marker:

```text
native_gateway_default_cutover_applied
```

Behavior:

- If setup is complete and the marker is not applied, an unset or `proot`
  owner can be migrated once to native production.
- If an operator rolls back to PRoot, the marker remains applied.
- Because the marker remains applied, rollback is sticky across force-stop and
  relaunch.
- If native default startup fails during attach/start, `GatewayService`
  reports the failure and leaves PRoot rollback as an explicit user action.

## Switch To Native

Use this hidden operator command from the real Plawie chat UI:

```text
/native-default-owner-enable
```

Expected result:

- PRoot stops.
- Production port `18789` is released.
- Native full Gateway starts in process
  `com.openclaw.plawie:native_node_smoke`.
- `gateway_runtime_owner` becomes `native-node-full-gateway-production`.
- `http://127.0.0.1:18789/health` returns
  `{"ok":true,"status":"live"}`.
- Normal chat uses the native-owned production Gateway.

## Roll Back To PRoot

Primary rollback command:

```text
/native-default-owner-rollback
```

Release safety rule:

- Rollback must remain available even when broad native diagnostics are disabled.
- Native-default enable and the wider canary commands can stay diagnostic-gated.
- Do not ship a build where rollback requires
  `PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true`.

Known aliases in the command path:

```text
/native-default-owner-off
/native-rollback-proot
/proot-rollback
/restore-proot-owner
```

Expected result:

- Native production runtime is stopped.
- Native process is absent.
- Production port `18789` is released.
- PRoot starts.
- `gateway_runtime_owner` becomes `proot`.
- `http://127.0.0.1:18789/health` returns
  `{"ok":true,"status":"live"}`.
- Force-stop/relaunch keeps PRoot selected because rollback is sticky.

## Verification Commands

USB device check:

```powershell
adb devices
```

Production health:

```powershell
adb -s RZCX30KA9AW forward tcp:28789 tcp:18789
curl.exe --max-time 8 http://127.0.0.1:28789/health
```

Native production owner process:

```powershell
adb -s RZCX30KA9AW shell pidof com.nxg.openclawproot:native_node_smoke
```

PRoot Gateway process:

```powershell
adb -s RZCX30KA9AW shell pidof openclaw
```

Native default pass shape:

```text
health live on 18789
native pid present
PRoot pid absent
normal chat prompt returns provider assistant text or raw provider error
```

Rollback pass shape:

```text
health live on 18789
PRoot pid present
native pid absent
force-stop/relaunch preserves PRoot if rollback was used
```

## Diagnostics Flags

Broad native diagnostics:

```text
PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true
```

Native sidecar autostart diagnostics:

```text
PLAWIE_NATIVE_GATEWAY_SMOKE_AUTOSTART_DIAGNOSTICS=true
```

Primary canary diagnostics:

```text
PLAWIE_NATIVE_GATEWAY_PRIMARY_CANARY_DIAGNOSTICS=true
```

Owner switch command availability:

```text
PLAWIE_NATIVE_GATEWAY_OWNER_SWITCH_COMMANDS=true
```

Default: `true`.

This allows `/native-default-owner-enable` without enabling the broad native
canary commands. Public native-default rollback builds should keep this enabled
so sticky PRoot rollback can return to native without shipping diagnostics.

Important release rule:

- Broad smoke diagnostics can unlock hidden commands in debug builds.
- `18790` sidecar autostart should stay behind the narrower autostart flag.
- PRoot rollback must not be hidden behind diagnostics.
- Native re-enable should be controlled by
  `PLAWIE_NATIVE_GATEWAY_OWNER_SWITCH_COMMANDS`, not by broad canary flags.
- Release builds should not auto-start `18790` unless that is explicitly chosen
  for a release diagnostic variant.

## Cleanup

After a test session:

```powershell
adb -s RZCX30KA9AW forward --remove-all
adb -s RZCX30KA9AW reverse --remove-all
```

If native owns production and the test is over, roll back from chat first:

```text
/native-default-owner-rollback
```

Then verify:

```powershell
adb -s RZCX30KA9AW forward tcp:28789 tcp:18789
curl.exe --max-time 8 http://127.0.0.1:28789/health
adb -s RZCX30KA9AW shell pidof openclaw
adb -s RZCX30KA9AW shell pidof com.nxg.openclawproot:native_node_smoke
```

Do not delete OpenClaw state directories as routine cleanup. Those directories
contain user config, provider keys, pairing data, skills, and rollback state.

## Current Release Evidence

The fresh-key release gate proved:

- PRoot baseline was healthy.
- Native default switch succeeded.
- Native owned `18789`.
- PRoot stayed absent during native ownership.
- A normal chat prompt returned visible assistant text:

  ```text
  native-release-validation-ok
  ```

- Rollback restored PRoot.
- Force-stop/relaunch after rollback preserved PRoot as sticky emergency owner.

This means the remaining work is release boundary work:

- keep this runbook current;
- choose which diagnostics flags belong in debug and release variants;
- commit the migration state cleanly;
- keep PRoot packaged only as documented emergency rollback until a later
  cleanup release removes it entirely.

Additional current evidence from logs:

- PRoot startup: 12 startup plugins, 177 methods, 27 events.
- Native startup: same 12 startup plugins, 177 methods, 27 events.
- Native provider/catalog expansion: 45 provider/catalog plugins loaded.
- Native provider chat proof: OpenRouter transport returned HTTP 200 and the
  chat UI received `native-release-validation-ok`.
- Current attached test device is in sticky PRoot rollback state because the
  last gate intentionally exercised rollback.

## Release Decision

Native Node is the intended default runtime when all of these are true:

- `18789` health is live under native;
- normal chat returns assistant text or a raw provider/account error;
- provider errors are surfaced instead of hidden behind generic messages;
- rollback command restores PRoot;
- relaunch after rollback preserves PRoot;
- `18790` diagnostics sidecar does not autostart accidentally.

If any production native startup, health, WebSocket, chat, or rollback check
fails, the release action is:

```text
/native-default-owner-rollback
```

Then ship or continue testing from the PRoot emergency owner until the native
failure is fixed.

## Release Edge Cases To Keep Watching

- Existing installs with old `proot` owner must apply the native cutover once,
  unless they are already in sticky rollback state.
- Provider errors must surface raw/account-specific detail instead of generic
  misleading messages.
- Chat sends during Gateway hot reload must queue or be rejected clearly; they
  must not hang silently.
- The node host must reconnect after owner switches.
- `gateway.nodes.allowCommands` must remain separate from `tools.allow`.
- App permissions must match exposed Android commands.
- Third-party app control must require explicit policy and user confirmation.
- Diagnostics sidecars must not create hidden background memory use in release.
- PRoot rootfs cleanup should be a later release decision after rollback is no
  longer required.
- Local `local-llm/...` must keep working without Gateway or PRoot.
- Manual `plawie_ndk/local-llm` must work under native Gateway ownership when
  the Dart bridge on `11435` is running.
