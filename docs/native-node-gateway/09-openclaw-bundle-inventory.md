# OpenClaw Bundle Inventory

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

Device inspected: `RZCX30KA9AW`

Package path:

```text
/data/user/0/com.nxg.openclawproot/files/rootfs/ubuntu/usr/local/lib/node_modules/openclaw
```

## Scope

This is a read-only inventory of the OpenClaw package currently installed in
the PRoot rootfs. It exists to decide what a native Android Gateway bundle must
ship, rebuild, disable, or replace.

This inventory did not modify Gateway config, stop/start Gateway, or write into
the rootfs.

## Package Facts

Observed from `package.json`:

| Field | Value |
| --- | --- |
| package | `openclaw` |
| version | `2026.5.20` |
| type | `module` |
| main | `dist/index.js` |
| bin | `openclaw -> openclaw.mjs` |
| Node engine | `>=22.19.0` |
| direct dependencies | `50` |
| optional dependencies | `2` |
| peer dependencies | `1` |

Observed tree size:

| Path | Size |
| --- | --- |
| OpenClaw package | about `668M` |
| OpenClaw `node_modules` | about `551M` |

Observed dependency tree:

- `251` `package.json` files under `node_modules` at depth 2.
- This is too large and Linux-oriented to bundle blindly into the APK.

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

Runtime-sensitive:

- `@lydell/node-pty`
- `tree-sitter-bash`
- `playwright-core`
- `quickjs-wasi`
- `@homebridge/ciao`
- `@earendil-works/pi-coding-agent`
- `@earendil-works/pi-agent-core`

Optional but currently installed:

- `sharp`
- `sqlite-vec`

## Native Addon Findings

Native `.node` files were found in the installed package tree.

| Package area | Observed file or metadata | Native concern |
| --- | --- | --- |
| `@napi-rs/canvas-linux-arm64-gnu` | `skia.linux-arm64-gnu.node`; package declares `os=linux`, `cpu=arm64`, `libc=glibc` | Not Android/Bionic-compatible as-is |
| `@img/sharp-linux-arm64` | `lib/sharp-linux-arm64.node`; package declares `os=linux`, `cpu=arm64`, `libc=glibc` | Not Android/Bionic-compatible as-is |
| `@lydell/node-pty-linux-arm64` | Linux arm64 package | PTY behavior is a core shell/runtime risk on Android |
| `tree-sitter-bash` | prebuilt `tree-sitter-bash.node` for Linux/macOS/Windows | Needs Android build or replacement |
| `koffi` | many platform `.node` builds, including Linux and musl | FFI package must be validated on Android or excluded |
| nested clipboard packages | Linux GNU and musl clipboard `.node` files under `pi-coding-agent` | Desktop clipboard assumptions do not map cleanly to Android |

Conclusion: the installed PRoot `node_modules` tree is a Linux runtime tree.
Native Android must not reuse it directly.

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
