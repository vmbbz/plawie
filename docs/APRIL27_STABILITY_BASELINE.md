# April 27 Stability Baseline

Last updated: 2026-05-24

## Why This Exists

The April 27 build is an important behavioral baseline: it proved that Plawie could run the OpenClaw Gateway, local Ollama inside PRoot, chat, skills, tools, WebView UI, and avatar rendering for long sessions without crashing or hanging. The local model was slow, but the system stayed alive.

That means PRoot overhead alone is not the root explanation for the current instability. Any migration to GLIBC/Aegis or native inference must preserve the runtime contracts that made the April build stable.

## Baseline Commit

- Mainline baseline: `555db1f`
- Duplicate same-era branch commit: `2555bb0`
- Date: 2026-04-27
- Subject: `feat(tts): migrate from Piper amy-low to Kokoro en-v0_19 for near-human voice quality`

The subject mentions TTS, but the important lesson for release readiness is broader: the runtime stayed stable under full-day gateway and local model load.

## Stability Contracts That Worked

### Local Ollama Was First-Class

The April runtime started Ollama inside PRoot directly and treated it as a normal model provider:

- `OLLAMA_HOST=127.0.0.1:11434`
- `OLLAMA_ORIGINS=*`
- `OLLAMA_KEEP_ALIVE=-1`
- `OLLAMA_NUM_PARALLEL=1`
- `OLLAMA_MAX_LOADED_MODELS=1`

This prevented multiple model copies, avoided repeated cold reloads, and kept the gateway path predictable.

### Mobile Model Limits Were Explicit

The gateway configuration and Modelfile path used mobile-safe limits:

- `num_ctx 1024` baseline for lightweight local operation
- `num_gpu 0`
- `num_thread 1`
- `num_batch 512`
- dynamic context/thread handling only when explicitly configured

These limits matter more than raw provider choice. A "local" provider without strict context/thread/session limits can still collapse the device.

### Watchdogs Tolerated Slow Inference

The foreground watchdog used a longer health timeout:

- `HEALTH_TIMEOUT_MS = 20_000`
- `MAX_CONSECUTIVE_FAILURES = 3`

That made sense because a gateway can remain alive while local inference makes health probes slow. Treating every slow health probe as a failing gateway creates false restarts under load.

### Session Bloat Was Managed

The April-era gateway service included stale-session cleanup, local model sync, and direct Ollama fallback behavior. This helped avoid runaway context growth and gave the chat path a recovery lane when the gateway was busy.

## What Changed Since

Later work improved many important areas, especially pairing/security alignment with newer OpenClaw releases, but it also changed the runtime envelope:

- Embedded Ollama daemon paths were removed from normal runtime code.
- Provider routing was simplified toward cloud/OpenRouter and NDK offline mode.
- Gateway speech/talk/session work coupled more UI behavior back through the gateway.
- Health checks became stricter again in some paths.
- Chat/WebView/avatar memory pressure became a stronger trigger during active use.

The current live metrics show gateway health is fine while idle, then degrades when Chat/WebView/avatar load spikes graphics memory. That is a resource-envelope regression, not proof that PRoot was impossible.

Important correction: bundled avatars existed in the April baseline and must not be treated as the root cause by themselves. Android graphics memory is a pressure signal. The root work is preserving the April runtime contract: one model backend owner, bounded local context/thread/tool loops, slow-inference-aware watchdogs, stable provider routing, and no large binary payloads fed back into model context.

## Current Release Hotfix Direction

- Keep Gemini/Boruto avatar quality unchanged while runtime stability is investigated.
- Restore slow-inference tolerance with longer gateway health probe timeouts.
- Cap NDK local inference threads to mobile-safe model recommendations.
- Limit local tool-call repair loops so small models cannot wedge the phone.
- Normalize tool arguments before dispatch so tiny models can still use camera, haptic, sensor, canvas, and avatar actions reliably.
- Strip camera/screen/canvas base64 payloads from local model feedback while still attaching media to the chat UI.
- Treat legacy local Ollama as a controlled compatibility path if we reintroduce it, not as an accidental hidden daemon.

## Implication For GLIBC/Aegis

GLIBC can still be the right strategic direction, but it must not be treated as a magic fix. A GLIBC migration must preserve or improve these contracts:

- One gateway owner.
- One model backend owner.
- One loaded local model unless explicitly changed.
- Mobile-safe context and thread defaults.
- Slow-inference-aware health checks.
- Stable device identity and pairing state.
- Stable tool registration and capability visibility.
- Bounded WebView/avatar graphics memory during chat.
- Returning-user migration from existing PRoot config.

## Release Decision Rule

Before replacing the PRoot runtime, the candidate runtime must pass the same behavioral bar:

- Fresh install reaches dashboard without manual retries.
- Gateway loads default skills.
- Node pairs automatically and stays paired.
- Web Dashboard connects without scope or device drift.
- Chat can send 10 normal prompts without gateway restart.
- Tools are visible and callable.
- Long idle does not break the next chat request.
- Local inference can be slow without watchdog false positives.

If a candidate runtime is faster but fails these stability checks, it is not release-ready.
