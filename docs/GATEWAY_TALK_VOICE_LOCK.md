# Gateway Talk Voice Lock

This document freezes Plawie's production voice contract to avoid future drift.

## Official OpenClaw Contract

- Android native Talk path: local speech recognition + gateway chat + `talk.speak`.
- Android may use local system TTS only when `talk.speak` RPC is unavailable.
- `talk.catalog` is the source of truth for supported speech/realtime/transcription providers and voice capabilities.
- `tts.providers`, `tts.personas`, `tts.setProvider`, and `tts.setPersona` are the runtime control surface for provider/persona preferences.

References:
- https://docs.openclaw.ai/nodes/talk
- https://docs.openclaw.ai/tools/tts

## Plawie Enforcement Rules

1. Cloud/Gateway chat responses must route voice output through `talk.speak`.
2. Native device TTS fallback is allowed only when `talk.speak` is unavailable (`unknown method` / `method unavailable` path).
3. Provider, persona, and voice selection UI must read live gateway capability/state:
   - providers from `tts.providers`
   - personas from `tts.personas`
   - provider voice IDs from `talk.catalog.speech.providers[*].voices`
4. Voice speed and selected voice ID are client preferences applied as `talk.speak` overrides.
5. Local NDK mode remains separate; it can use native TTS because it bypasses gateway chat intentionally.

## Regression Checklist

- Cloud model selected:
  - sending chat text produces gateway speech (not Android system voice),
  - tool-capable gateway lane remains active,
  - voice modal changes provider/persona without gateway restart loops.
- `talk.speak` unavailable simulation:
  - fallback to local TTS occurs,
  - warning is logged once with backoff.
- Local NDK selected:
  - native/offline speech works without requiring gateway talk RPC.
