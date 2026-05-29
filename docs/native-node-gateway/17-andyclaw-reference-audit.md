# AndyClaw Reference Audit

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## Decision Summary

AndyClaw is useful research, but not as a PRoot replacement.

The repository is an Android-native assistant and skills architecture. It does
not provide a ready Node `>=22.19.0` OpenClaw Gateway runtime, an AVF launcher,
or an embedded `libnode.so` candidate. Its best value for Plawie is on the
Android capability side: skills, device control, Termux sidecar execution,
gateway WebSocket client behavior, extension discovery, and virtual-display
agent tooling.

The runtime decision remains:

```text
Default production: PRoot
Full-fidelity eligible-device lane: AVF Linux VM
Future broad-device native lane: embedded libnode
Android capability/skills reference: AndyClaw patterns
```

## Primary Sources Checked

| Source | Finding |
| --- | --- |
| `https://github.com/EthereumPhone/AndyClaw` | Public `main` branch exists at commit `55c490890a129ed3e52358caab04ca0e2159941a` |
| `README.md` | Describes an Android APK assistant with open stock-Android mode, privileged ethOS mode, local Qwen 1.5B, cloud providers, skills, heartbeat, Termux integration, extensions, and device tools |
| `app/src/main/java/.../NodeRuntime.kt` | Android/Kotlin runtime wrapper around skills, heartbeat, and agent loop; not a Node.js runtime despite the class name |
| `app/src/main/java/.../NodeForegroundService.kt` | Foreground service keeps the Android assistant heartbeat alive |
| `app/src/main/java/.../skills/builtin/TermuxSkill.kt` | Exposes Termux status and command execution as agent tools |
| `app/src/main/java/.../skills/termux/TermuxCommandRunner.kt` | Uses Termux `RUN_COMMAND` intents plus `PendingIntent` result callbacks |
| `AndyClaw/src/main/java/.../gateway/GatewaySession.kt` | WebSocket client with connect/auth, request/response, reconnect, `node.event`, and `node.invoke` handling |
| `AndyClaw/src/main/java/.../gateway/GatewayDiscovery.kt` | Discovers OpenClaw Gateway services through Android NSD and optional wide-area DNS-SD |
| `AndyClaw/src/main/java/.../skills/*` | Kotlin implementation of SKILL.md loading, frontmatter, registry, and command specs mirroring OpenClaw concepts |
| `ExtensionExample/README.md` | Documents APK extension discovery and IPC bridge options for runtime-discovered functions |
| `AGENT_DISPLAY_API.md` and `AGENT_VIRTUAL_DISPLAY.md` | Document virtual-display, screenshot, input, and accessibility-oriented Android agent control patterns |
| `LICENSE` | GPL-3.0; code reuse requires license review. Use as architecture reference unless legal review approves direct copying |

## What AndyClaw Gives Us

AndyClaw is strong evidence for several Android-side patterns that matter to
Plawie:

- A foreground-service heartbeat can keep agent work alive outside a chat page.
- Skills can be tiered by OS capability, permissions, and privileged device
  status.
- SKILL.md frontmatter and executable skill metadata can be represented
  natively on Android.
- Termux can be used as an optional user-installed Linux sidecar through
  Android intents, with command output returned through callbacks.
- A Gateway WebSocket client can live in Android/Kotlin, hold a device
  identity, reconnect, send node events, and respond to `node.invoke.request`.
- APK extensions can be discovered through manifest metadata and invoked
  through bound services, content providers, broadcasts, or explicit intents.
- Virtual display control benefits from a small, grounded action set:
  screenshot, tap/click, swipe, key/text input, and node/accessibility actions.

These are directly relevant to Plawie's device capabilities and future VM or
remote-Gateway bridge. If AVF runs OpenClaw inside a Debian VM, the Android-side
skills still need a clean bridge back into the Plawie app. AndyClaw is useful
as a reference for that bridge.

## What AndyClaw Does Not Give Us

AndyClaw does not solve the core runtime migration problem:

- It does not ship Node `>=22.19.0` for Android.
- It does not run upstream OpenClaw Gateway locally on stock Android.
- It does not replace PRoot, AVF, or embedded `libnode.so`.
- It does not remove the OpenClaw native module and Playwright compatibility
  questions.
- Its privileged device-control tier depends on ethOS/system privileges that
  normal Plawie installs should not assume.
- Its Termux route depends on a separate app, user setup, matching Termux /
  Termux:API provenance, `allow-external-apps`, and Android permissions.

So the correct classification is "skills/control/sidecar reference," not
"runtime candidate."

## Termux Sidecar Option

AndyClaw's Termux route is worth tracking as an optional support lane, especially
because the current test phone does not appear AVF-ready.

Possible Plawie use:

```text
Plawie app
  -> optional Termux capability probe
  -> user grants Termux RUN_COMMAND permission
  -> Plawie exposes a limited terminal/CLI skill
  -> Gateway tools call back into Plawie
  -> Plawie runs approved commands through Termux
```

This can be useful for user-installed CLI tools, diagnostics, experiments, and
SKILL.md executable sidecars. It should not become the Gateway runtime default:
Termux is external, setup-heavy, and can time out or hang during package
installations. It is a capability lane, not the main OpenClaw process lane.

## Gateway Client Lessons

AndyClaw's Gateway client design validates several choices already important to
Plawie:

- Keep Gateway sessions explicit and observable.
- Maintain device identity and signed connection metadata.
- Separate request/response RPC from async Gateway events.
- Treat `node.invoke.request` as a callback into Android capabilities.
- Use reconnect/backoff loops, but surface state clearly.
- Normalize loopback/canvas host URLs when a Gateway is remote or VM-hosted.

These patterns are especially relevant for the AVF lane, where the Gateway may
run at a VM bridge address instead of `127.0.0.1`.

## Extension And Skill Lessons

The extension model is attractive, but should be staged carefully:

1. Keep Plawie's built-in Android node/tools first.
2. Add richer capability metadata and user-facing permission descriptions.
3. Consider a manifest-based local extension API only after Gateway stability
   and security review.
4. Require explicit user approval for executable or cross-app skills.
5. Treat GPL-licensed implementation code as reference unless legal review
   approves direct reuse.

For Plawie, the most immediate win is not a plugin marketplace. It is a cleaner
capability taxonomy: what is a skill, what is a tool, what requires permission,
what is local-only, and what can be exposed safely to cloud/AVF/local lanes.

## Virtual Display Lessons

The virtual-display material is useful for future screen-control tools:

- use a small, stable action schema instead of many overlapping gestures;
- return visual feedback after actions to avoid blind multi-step loops;
- cap iteration count and detect repeated no-op actions;
- report permission or capability limits precisely;
- keep privileged `app_process` / shell-UID approaches out of normal consumer
  builds unless the device environment explicitly supports them.

This aligns with Plawie's current rule: normal installs should use app-owned
permissions and app-native node capabilities, while privileged bridges remain
developer or special-device research.

## Integration Recommendation

Do not fork AndyClaw into Plawie. Instead:

1. Keep PRoot Gateway production unchanged.
2. Keep AVF as the best full-fidelity OpenClaw lane for eligible devices.
3. Keep embedded `libnode.so` as the broad-device native research lane.
4. Add an "Android capability bridge" research task inspired by AndyClaw.
5. Evaluate a Termux capability probe only as an optional sidecar tool lane.
6. Use the GatewaySession ideas when designing VM-to-app node invocation.
7. Use the extension/skill ideas to improve Plawie's skill documentation and
   permission UX, not to bypass the Gateway.

## Non-Negotiables

- Do not treat AndyClaw as a Node 22 runtime source.
- Do not copy GPL code into Plawie without license/legal review.
- Do not require Termux for core chat, tools, avatar, or Gateway startup.
- Do not require ethOS/system privileges for normal Plawie features.
- Do not route production chat through any new sidecar until persistence,
  timeout, and reconnection behavior match current Gateway expectations.
