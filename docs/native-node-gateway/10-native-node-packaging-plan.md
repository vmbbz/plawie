# Native Node Packaging Plan

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## Decision

Do not attempt a direct native launch of the installed PRoot OpenClaw tree.

Use a staged native Android bundle:

```text
Native Node runtime
  -> curated OpenClaw mobile bundle
  -> alternate port 18790
  -> health/RPC shadow tests
  -> eventual canary only after parity
```

PRoot remains production on `127.0.0.1:18789`.

## Why

OpenClaw currently requires Node `>=22.19.0`, and the installed tree contains
Linux/glibc native addons. Android native code uses the Android runtime stack,
not the Ubuntu/glibc userspace available inside PRoot.

Source-backed constraints:

- Node's official build documentation does not treat Android as a normal
  supported distribution target:
  https://github.com/nodejs/node/blob/main/BUILDING.md
- Android NDK native code uses Android's C/C++ runtime model, including
  libc++ support rather than a standard GNU/Linux userspace:
  https://developer.android.com/ndk/guides/cpp-support
- `nodejs-mobile` demonstrates that a Node runtime can be embedded in an
  Android app and serve HTTP from a background thread, but it is a runtime
  integration pattern, not proof that OpenClaw's Linux dependency tree works
  unchanged:
  https://nodejs-mobile.github.io/docs/guide/guide-android/getting-started/

## Candidate Runtime Strategies

| Strategy | Pros | Cons | Current verdict |
| --- | --- | --- | --- |
| Custom Bionic-native Node executable | Closest to existing CLI/server shape; can run as a managed process | We own Node build QA, ABI, patches, and native addon compatibility | Preferred research path |
| Embedded Node shared library | Tight app lifecycle control; proven pattern via nodejs-mobile | Must expose stdout/stderr/stop semantics and confirm Node version support | Viable fallback |
| Full Linux `node_modules` reuse | Fastest to try | Native addons are Linux/glibc; host tools assume Ubuntu | Reject as production path |
| PRoot plus native sidecars | Minimal risk to Gateway | Does not remove PRoot startup/resource cost | Useful fallback and transition path |
| glibc compatibility layer | Could run Linux addons | Fragile, large, unclear Android lifecycle behavior | Avoid unless all native paths fail |

## Phase 3 Work Order

1. Build or source a Node `>=22.19.0` Android arm64 runtime.
2. Replace the Phase 2 NanoHTTPD smoke endpoint with a real Node process on
   `127.0.0.1:18790`.
3. First Node smoke payload must return:

```json
{
  "ok": true,
  "runtime": "native-node",
  "node": "v22.x",
  "platform": "...",
  "arch": "arm64",
  "port": 18790,
  "openclawStarted": false
}
```

4. Add stdout/stderr capture to the existing native smoke logs.
5. Add stop/restart tests that prove no orphan process remains.
6. Create a curated OpenClaw mobile bundle:
   - `openclaw.mjs`
   - required `dist/` chunks for Gateway boot
   - dashboard/static assets needed by Gateway
   - provider extensions used by Plawie install/chat model list
   - node pairing/RPC/device tooling paths
   - mobile skills catalog
7. Gate or remove incompatible modules for first boot:
   - browser automation
   - desktop clipboard
   - Ollama daemon management
   - Bonjour/Avahi discovery
   - host shell/exec unless routed through an Android/PRoot compatibility lane
8. Try `openclaw --version` on native Node.
9. Try `openclaw gateway --port 18790 --bind loopback` only after the version
   command works.
10. Keep all UI and chat traffic on PRoot until shadow parity passes.

## Shim Candidates

| Surface | Mobile-compatible direction |
| --- | --- |
| `openssl` binary use | Prefer Node `crypto` or Android-side certificate/token helper |
| `/bin/sh` exec tools | Route to existing PRoot terminal lane or Android node commands |
| `node-pty` | Keep terminal in existing Android/PRoot service initially |
| `sharp`/canvas | Disable image transforms first; later add Android-compatible builds or app-native media helpers |
| browser/chrome | Disable first; browser tools can route through Android WebView/canvas later |
| Bonjour/Avahi | Disable MDNS in local-loopback mobile mode |
| Ollama daemon management | Keep removed/deprecated; local LLM stays NDK/direct bridge |

## Non-Negotiables

- Do not bind `18789` during Phase 3.
- Do not change `GatewayRuntimeRegistry.current`.
- Do not route chat, dashboard, node pairing, tools, or TTS to native runtime.
- Do not mutate `openclaw.json` for native experiments.
- Do not package Linux/glibc `.node` addons as if they were Android-native.

## Exit Gate For Phase 3

Phase 3 is complete only when:

- real native Node starts on device;
- `/health` responds on `127.0.0.1:18790`;
- start/stop/restart leaves no orphan process;
- a curated OpenClaw bundle can run `openclaw --version`;
- any failed OpenClaw boot logs precise missing dependency/module names;
- PRoot Gateway remains unaffected and still pairs the Android node.
