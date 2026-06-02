# Release Boundary Architecture And Runbook

Date: 2026-06-02

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

## Ports

| Port | Owner | Use |
| --- | --- | --- |
| `127.0.0.1:18789` | exactly one production runtime | Production OpenClaw Gateway HTTP and WebSocket |
| `127.0.0.1:18790` | native diagnostics sidecar only | Native smoke/bootstrap diagnostics, not production |
| `127.0.0.1:8765` | phone-side `AgentSkillServer` | Host inspection may use `adb forward`; do not `adb reverse` it |

Host inspection over USB usually maps:

```powershell
adb -s RZCX30KA9AW forward tcp:28789 tcp:18789
adb -s RZCX30KA9AW forward tcp:28790 tcp:18790
```

Do not treat those host ports as app architecture. They are only USB inspection
tunnels.

## Native Node Package Path

The native production runtime is embedded in the Android app:

```text
libnode.so
libplawie_node_bridge.so
assets/openclaw-node-modules.tar.gz
```

The app extracts the OpenClaw package into app-private storage:

```text
$filesDir/native-node-embedded/
$filesDir/native-node-embedded/native-home/
$filesDir/native-node-embedded/native-home/.openclaw/
```

The bundled package details proven on-device:

```text
package root: lib/node_modules/openclaw
package version: 2026.5.28
declared binary entry: openclaw.mjs
Android embedded entry used: dist/cli/run-main.js
required Node engine: node >=22.19.0
```

The Android launcher bypasses the desktop CLI wrapper and imports
`dist/cli/run-main.js` directly. It also patches Android-safe temp behavior and
rewrites copied `/root/.openclaw` paths to the native app-owned state directory.

## Gateway Plugins, Skills, And Device Capabilities

Gateway plugin logs are runtime-extension evidence, not a complete list of
every skill or phone action.

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

Native bootstrap can hydrate selected OpenClaw state from the PRoot `.openclaw`
tree, then rewrites unsafe Linux paths into native app-private paths.

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
- If native default startup fails during attach/start, `GatewayService` attempts
  automatic PRoot restore before reporting failure.

## Switch To Native

Use this hidden operator command from the real Plawie chat UI:

```text
/native-default-owner-enable
```

Expected result:

- PRoot stops.
- Production port `18789` is released.
- Native full Gateway starts in process
  `com.nxg.openclawproot:native_node_smoke`.
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

Important release rule:

- Broad smoke diagnostics can unlock hidden commands in debug builds.
- `18790` sidecar autostart should stay behind the narrower autostart flag.
- PRoot rollback must not be hidden behind diagnostics.
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
