# OpenClaw Bundle Inventory

Last updated: 2026-05-31

Branch: `native-node-gateway-research`

Device inspected: `RZCX30KA9AW`

Package path:

```text
/data/user/0/com.nxg.openclawproot/files/rootfs/ubuntu/usr/local/lib/node_modules/openclaw
```

## Scope

This is an inventory of the OpenClaw package currently installed in the PRoot
rootfs and mirrored into `assets/openclaw-node-modules.tar.gz`. It exists to
decide what a native Android Gateway bundle must ship, rebuild, disable, or
replace.

On 2026-05-31 the PRoot baseline was refreshed from OpenClaw `2026.5.20` to
`2026.5.28`, then the APK asset bundle was rebuilt from that verified phone
install.

## Package Facts

Observed from `package.json`:

| Field | Value |
| --- | --- |
| package | `openclaw` |
| version | `2026.5.28` |
| type | `module` |
| main | `dist/index.js` |
| bin | `openclaw -> openclaw.mjs` |
| Node engine | `>=22.19.0` |
| direct dependencies | `58` |
| optional dependencies | `1` |
| peer dependencies | `0` |

Observed tree size:

| Path | Size |
| --- | --- |
| `/usr/local/lib/node_modules` | about `362M` |
| OpenClaw package | about `344M` |
| OpenClaw `node_modules` | about `240M` |
| APK asset bundle | `54,295,181` bytes |

Observed dependency tree:

- `254` `package.json` files under `node_modules` at depth 2.
- The refreshed default package is much smaller, but it is still a PRoot/Linux
  runtime tree. Native Android must continue to prove each dependency surface
  before routing production traffic through the embedded runtime.

## Direct Dependencies Of Interest

The direct dependency list includes portable JS packages and runtime-sensitive
packages.

Portable or likely portable:

- `express`
- `ws`
- `undici`
- `zod`
- `yaml`
- `commander`
- `openai`
- `@google/genai`
- `@modelcontextprotocol/sdk`
- `@agentclientprotocol/sdk`
- `qrcode`
- `tar`
- `jszip`
- `rastermill`
- `clawpdf`
- `@silvia-odwyer/photon-node`

Runtime-sensitive:

- `@lydell/node-pty`
- `tree-sitter-bash`
- `playwright-core`
- `quickjs-wasi`
- `@homebridge/ciao`
- `@earendil-works/pi-coding-agent`
- `@earendil-works/pi-agent-core`

Optional but currently installed:

- `sqlite-vec`

## Native Addon Findings

Native `.node` files were found in the installed package tree.

| Package area | Observed file or metadata | Native concern |
| --- | --- | --- |
| `@lydell/node-pty-linux-arm64` | Linux arm64 package | PTY behavior is a core shell/runtime risk on Android |
| `tree-sitter-bash` | prebuilt `tree-sitter-bash.node` for Linux/macOS/Windows | Needs Android build or replacement |
| `@earendil-works/pi-tui` | Darwin and Windows `.node` prebuilds are present | Desktop terminal assumptions do not map cleanly to Android |

Conclusion: the installed PRoot `node_modules` tree is smaller than the
`2026.5.20` baseline, and the previous default canvas/sharp native fanout is no
longer present. It is still a Linux runtime tree. Native Android must not reuse
it directly without the same canary gates used for provider, tool, stream, and
bridge parity.

## Refresh Validation

Live phone checks after the refresh:

| Check | Result |
| --- | --- |
| CLI version | `OpenClaw 2026.5.28 (e932160)` |
| Gateway health | `/health -> {"ok": true, "status": "live"}` |
| Loaded plugins | `12` attempted, `12` loaded |
| UI reconnect | `client=openclaw-control-ui version=2026.5.28` |
| Local tools endpoint | `10` bundled Plawie/mobile tools visible |
| Local skills endpoint | `10` bundled Plawie/mobile skills visible |

## Host Tool And Filesystem Assumptions

Static grep of `dist/*.js` found OpenClaw paths that spawn or inspect host
tools/platforms:

- `openclaw.mjs` respawns through `node:child_process`.
- `dist/entry.js` and `dist/cli/gateway-lifecycle.runtime.js` spawn
  `process.execPath`.
- Gateway certificate generation calls an external `openssl` binary.
- Ollama extension probes `systemctl`.
- Bonjour discovery can use `avahi-browse`.
- Browser/chrome code uses `/bin/sh`, `tar`, `ssh`, Linux display variables,
  and Chromium launch assumptions.
- Exec/bash tooling uses `/bin/sh` and shell process supervision.
- Directory fetch tools use `du` and `tar`.

These are acceptable in PRoot because Ubuntu userspace exists. In Android
native mode they require one of:

- Android-native equivalents;
- app-side bridges;
- feature gating;
- a compatibility sidecar;
- or explicit unsupported-state diagnostics.

## First-Pass Classification

Can probably move early:

- HTTP Gateway core
- provider routing
- chat streaming
- WebSocket/RPC transport
- JSON config parsing
- cloud model providers
- Android node pairing protocol, if port/auth semantics stay identical

Needs shims or disable flags:

- shell/exec host tools
- browser automation
- bonjour/MDNS helpers
- local Ollama daemon management
- directory archive helpers
- certificate generation if it depends on external `openssl`

Needs rebuild/replacement:

- canvas
- sharp
- node-pty
- tree-sitter-bash
- koffi/FFI surfaces
- desktop clipboard helpers

## Migration Implication

The native runtime path should not begin by pointing a native Android Node
binary at the existing installed package directory.

The safer path is:

1. create a curated mobile OpenClaw bundle;
2. include only assets needed for Gateway, dashboard, cloud chat, RPC, node
   pairing, tools, skills catalog, and session persistence;
3. explicitly gate browser/shell/desktop integrations;
4. add Android replacements where the app already owns the capability;
5. boot the curated bundle on `127.0.0.1:18790`;
6. only then compare it against PRoot in shadow mode.
