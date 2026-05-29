# Native Node Gateway Risk Register

Last updated: 2026-05-29

| ID | Risk | Severity | Likelihood | Mitigation | Exit Gate |
| --- | --- | --- | --- | --- | --- |
| R1 | Native runtime breaks current Gateway startup | Critical | Medium | Runtime abstraction must preserve PRoot default; no native code in Phase 1 | PRoot boot parity test passes |
| R2 | Android Node build is unstable because Android is not an official Node release target | High | Medium | Pin Node version; test ABI/device matrix; keep PRoot fallback | Native smoke runtime survives restart loop |
| R3 | OpenClaw dependency assumes GNU/Linux tools or paths | High | High | Dependency audit before production port binding | All Linux-only assumptions listed and mitigated |
| R4 | Native npm modules fail on Android/Bionic | High | Medium | Prefer pure JS; rebuild/replace modules; avoid dynamic install at runtime | Bundle boots without runtime npm install |
| R5 | Native Gateway crash takes down Flutter | Critical | Medium | Prefer isolated process; if embedded, strict crash containment | Forced crash test leaves app alive |
| R6 | Port collision between PRoot and native runtime | Critical | Medium | Shadow runtime uses alternate port until canary phase | Production port owned by exactly one runtime |
| R7 | Config corruption from two runtimes writing same files | Critical | Medium | Single config writer in Flutter; runtime reads only during early phases | No repeated reload/config churn in logs |
| R8 | Node pairing/capability snapshot changes | Critical | Medium | Do not alter NodeProvider/NodeService in runtime phases | Full command declaration verified |
| R9 | Tool/skills behavior regresses | Critical | Medium | Keep Gateway tool policy unchanged; run tool matrix | Tool chips/results pass on cloud route |
| R10 | TTS/Talk provider flow changes | High | Medium | Do not change Talk config; run TTS smoke tests | Talk catalog/status and playback pass |
| R11 | App size grows beyond acceptable limits | Medium | High | ABI splits; prune JS bundle; measure APK/AAB delta | Size budget documented before beta |
| R12 | Performance gains are not worth risk | Medium | Medium | Capture boot time, memory, CPU, first-token, and restart data | Native materially improves target metrics |
| R13 | Foreground/background lifecycle remains unreliable | High | Medium | Add process supervision after runtime parity, not before | Runtime survives app route changes and lock/unlock tests |
| R14 | Security surface grows from bundled Node/runtime assets | High | Medium | Keep loopback binding; retain auth; document asset provenance | Threat review before user-facing beta |
| R15 | Embedded Node crashes the Flutter process | Critical | Medium | Keep embedded runtime smoke-only at first; move to a separate Android process before canary | Forced crash test leaves UI and PRoot Gateway alive |
| R16 | Executable Node and embedded libnode artifacts are confused | High | Medium | Keep separate scripts, docs, diagnostics, and packaging helpers | Wrong artifact type is rejected before APK packaging |
| R17 | Mobile fork lags OpenClaw's Node engine requirement | High | High | Rebase mobile Android patches to Node `>=22.19.0` or wait for matching branch | Native runtime reports a compliant Node version |

## Critical Risk Principle

The current PRoot path is slow but understood. Native Node should reduce
latency and operational weirdness only if it keeps the exact same Gateway
contract. A faster runtime that destabilizes tools, pairing, or config is a
regression.
