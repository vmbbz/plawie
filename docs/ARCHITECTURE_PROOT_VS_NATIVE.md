# PRoot vs Native Runtime Architecture

Last updated: 2026-06-02

Status: native `libnode.so` is the intended production Gateway runtime. PRoot
is retained as an emergency rollback runtime.

## Main Goal

Replace the PRoot-hosted OpenClaw Gateway with the embedded Android native Node
`libnode.so` Gateway runtime without breaking chat, providers, streaming,
skills, tools, sessions, device bridges, avatar behavior, startup, or rollback.

The stable production contract remains:

```text
Flutter UI
  -> GatewayService
  -> selected GatewayRuntime
  -> OpenClaw Gateway on 127.0.0.1:18789
  -> GatewayConnection / WebSocket / chat.send / tools / skills
```

## Current Runtime Split

| Layer | Runtime | Responsibility | Release role |
| --- | --- | --- | --- |
| Embedded native Node full Gateway | Android arm64 `libnode.so` + OpenClaw package | Production Gateway on `127.0.0.1:18789` | Intended default |
| PRoot Gateway | Ubuntu userland + Node.js Gateway | Emergency Gateway rollback on `127.0.0.1:18789` | Rollback only |
| Native Android / Flutter | App process + services | UI, lifecycle, runtime selection, pairing, capability bridge | Always required |
| Phone-side node host | `AgentSkillServer` on `127.0.0.1:8765` | Android device capability execution and local tool catalog | Shared by native and PRoot |
| NDK fllama | llama.cpp native library | Private/offline local model inference | Separate model route |
| NDK Gateway bridge | Dart HTTP server on `127.0.0.1:11435` | Optional Gateway-to-local-model bridge | Separate model route |

Native Node and PRoot must not both own production port `18789`. Exactly one
production Gateway runtime should be alive.

## Runtime Owner Selection

The selected runtime is stored in `PreferencesService.gatewayRuntimeOwner`.

Current intended default:

```text
native-node-full-gateway-production
```

Emergency rollback owner:

```text
proot
```

Fresh installs and eligible upgraded installs should land on native production.
There is also a one-time cutover marker:

```text
native_gateway_default_cutover_applied
```

Behavior:

- If setup is complete and the marker is not applied, an unset or `proot`
  owner is migrated once to native production.
- If an operator rolls back to PRoot, the marker remains applied.
- Because the marker remains applied, rollback is sticky across force-stop and
  relaunch.
- A device that currently shows PRoot after testing is not contradicting the
  native default; it is in sticky rollback state.

## Switch And Rollback

Enable native production owner from the hidden operator path:

```text
/native-default-owner-enable
```

Roll back to PRoot:

```text
/native-default-owner-rollback
```

Release safety rule:

- Native enable and wider diagnostics commands can stay gated in debug or
  operator builds.
- Rollback must remain available even when broad diagnostics are disabled.
- Do not ship a build where rollback depends on
  `PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true`.

## Ports

| Port | Owner | Purpose |
| --- | --- | --- |
| `127.0.0.1:18789` | exactly one production runtime | OpenClaw Gateway HTTP and WebSocket |
| `127.0.0.1:18790` | native diagnostics sidecar only | Smoke/bootstrap diagnostics |
| `127.0.0.1:8765` | phone-side `AgentSkillServer` | Android capability bridge and local tool catalog |
| `127.0.0.1:11435` | optional Dart NDK bridge | OpenAI-compatible local model bridge |

USB inspection should use `adb forward`, not Wi-Fi tunnels and not `adb reverse`
for `8765`.

## Plugin And Tool Evidence

Current observed Gateway logs prove both PRoot and native load the same 12
startup plugins:

```text
browser
canvas
device-pair
file-transfer
google
memory-core
microsoft
openai
openrouter
phone-control
talk-voice
xai
```

Registered startup plugin commands observed:

```text
/pair
/dreaming
/phone
/voice
```

Native provider/catalog expansion later loaded 45 provider/catalog plugins and
reported `177` Gateway methods and `27` events. Startup plugins are not the
same thing as every provider/catalog plugin, every skill, or every Android
device command.

## Skills, Tools, And Device Capabilities

The app has three separate surfaces that must not be conflated:

| Surface | Where it appears | What it means |
| --- | --- | --- |
| Gateway plugins | Gateway logs and OpenClaw extension loader | Runtime extensions such as providers, browser, phone-control, Talk, memory |
| Skills/tools catalog | Bot Management > Skills > Tools tab and `/api/tools` from `AgentSkillServer` | Tool schemas the mobile node exposes to Gateway |
| Android node capabilities | Node Device Page and `gateway.nodes.allowCommands` | Concrete phone bridge commands allowed through the paired node host |

Current phone-side `/api/tools` catalog exposes 10 tool schemas:

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

Current node command policy includes avatar, camera, canvas, flashlight/torch,
location, screen recording, sensor, and haptic commands. It does not currently
prove a generic Android app launcher or a safe WhatsApp message-sending command.

## Phone-Control And Messaging Edge

The `phone-control` Gateway plugin is loaded, but that alone does not mean the
agent can safely open any Android app and send arbitrary messages.

For a request like:

```text
Open WhatsApp and send Kukness: "Goodnight from OpenClaw buddy"
```

release-safe behavior must be one of these:

- supported compose flow: open WhatsApp or Android share/compose intent with the
  recipient/text prepared, then require explicit user confirmation before send;
- unsupported flow: explain that app-message automation is not enabled;
- future explicit automation flow: require a separate permission/consent model,
  clear audit trail, and rollback-safe command policy.

Silent third-party app messaging should not be claimed as complete just because
`phone-control` is loaded. It requires a concrete Android bridge command,
permission review, UI confirmation policy, and a tested Gateway tool contract.

## Memory And Efficiency

Native `libnode.so` does not make the Gateway free; it still runs OpenClaw,
Node/V8, providers, plugins, sessions, tools, and sidecars. The win is that it
removes the PRoot shim and Ubuntu userland from the active runtime path.

Expected benefits when native owns `18789`:

- no live PRoot process;
- no Ubuntu shell process for the active Gateway;
- fewer translation/bind-mount layers;
- fewer Linux compatibility files touched during steady-state Gateway use;
- lower startup indirection;
- lower risk from PRoot-specific filesystem and process quirks;
- simpler Android app-private state ownership.

PRoot files may remain on disk for rollback. Disk presence is not RAM usage.

When native owns production:

- PRoot should be stopped;
- `pidof openclaw` should not show the PRoot Gateway;
- `libproot.so` should not be active for Gateway service;
- `18790` should not autostart unless a diagnostics build explicitly enables
  the sidecar.

When PRoot owns production:

- native production process should be absent;
- rollback is sticky until native is explicitly re-enabled.

Observed native startup memory in the full Gateway bootstrap log included an
RSS near `452.6 MB` at ready and near `501.7 MB` post-ready. This is full
OpenClaw under native Node, not a tiny smoke process. PRoot's additional cost is
the compatibility/userland layer around a similar Gateway workload.

## Release Edge Cases

Before public release, verify all of these:

- fresh install starts native by default;
- upgrade from old PRoot install applies the one-time native cutover;
- manual rollback remains sticky across force-stop, reboot, and app relaunch;
- native startup failure automatically restores PRoot;
- provider billing/rate-limit errors are surfaced accurately, not replaced by
  generic false messages;
- WebSocket identity handshake still rejects unauthenticated host-only frames;
- node host reconnects after Gateway owner switch;
- `gateway.nodes.allowCommands` is not written into `tools.allow`;
- app permissions match exposed node commands;
- no diagnostics sidecar starts in release unless intentionally enabled;
- USB/Wi-Fi ADB forwards are cleaned after testing;
- PRoot rootfs remains packaged only while rollback is required;
- eventual cleanup release removes PRoot files only after a separate no-rollback
  policy decision.

## Model Routes

| Route | Model IDs | Gateway dependency |
| --- | --- | --- |
| Cloud full Gateway | cloud provider IDs | Native or PRoot owner on `18789` |
| Direct local NDK | `local-llm/...` | Bypasses Gateway |
| Compact NDK bridge | `plawie_ndk/local-llm` | Requires Gateway and bridge server |
| Legacy Ollama | `ollama/...` | Deprecated, not a normal route |

## Local NDK LLM Is Still In Play

The PRoot to native Node migration does not remove on-device inference.

Users can still download and run Qwen, Smol, or other supported GGUF models
from the Local LLM page. Those models run through fllama/llama.cpp NDK inside
the app and keep the `local-llm/...` route:

```text
Chat selects local-llm/...
  -> Gateway is bypassed
  -> LocalLlmService.chat()
  -> fllamaInference()
  -> on-device GGUF model
```

That path remains costless/offline after the model is downloaded. It does not
need PRoot and it does not need native `libnode.so`.

The native `libnode.so` migration affects Gateway-owned routes only. It changes
which runtime owns OpenClaw on `18789`; it does not replace fllama.

## Native HTTP Bridge For Local Model Inference

The NDK Gateway bridge also remains useful:

```text
Gateway model: plawie_ndk/local-llm
Gateway owner: native libnode.so or PRoot
Bridge: http://127.0.0.1:11435/v1
Model runtime: LocalLlmService / fllama
```

This bridge is the path for "use the OpenClaw Gateway, but send the model call
to a compact local model." It lets Gateway keep ownership of tools, sessions,
node context, and tool-result continuation while the actual token generation is
done by the local NDK model.

Native `libnode.so` does not make this bridge obsolete. It makes it cleaner:

- PRoot no longer has to host the Gateway before the bridge can be used.
- The bridge remains a Dart/app-side service on `11435`.
- Gateway-to-bridge traffic stays loopback-only.
- Small local models still need compact prompts and bounded tool schemas.

Direct local mode and bridge mode are intentionally different:

| Mode | Uses Gateway? | Tool owner | Best for |
| --- | --- | --- | --- |
| `local-llm/...` | No | Dart local loop | private/offline chat, low overhead |
| `plawie_ndk/local-llm` | Yes | OpenClaw Gateway | local model with Gateway tool transport |

## PRoot Removal Plan For This Branch

This branch should eventually remove PRoot entirely, while `main` can remain
the robust PRoot-based fallback/product line.

Removal must be staged:

1. Native default release:
   native owns fresh installs; PRoot remains packaged as emergency rollback.
2. Native no-rollback internal build:
   remove PRoot autostart paths and prove native startup, provider chat, node
   host pairing, local LLM direct mode, and NDK bridge mode.
3. State migration:
   migrate OpenClaw config, credentials, sessions, skills, and node pairing out
   of `$filesDir/rootfs/ubuntu/root/.openclaw/` into the app-owned native
   `.openclaw` home.
4. Package cleanup:
   remove the Ubuntu rootfs payload, PRoot binary/service wrappers, PRoot repair
   flows, and PRoot-only docs.
5. Public no-PRoot release:
   ship only after native rollback/failure handling no longer depends on PRoot.

Current branch state is stage 1 moving toward stage 2. PRoot files and process
paths are still present because rollback is still intentionally supported.

## Deprecated Paths

The app no longer treats these as production architecture:

- embedded Ollama daemon in PRoot;
- Ollama Cloud via local daemon proxy;
- PRoot `llama-server` on port `8081`;
- Node `node-llama-cpp` HTTP server in PRoot;
- PRoot as the intended default Gateway owner.
