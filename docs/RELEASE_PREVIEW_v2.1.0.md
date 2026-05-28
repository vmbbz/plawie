# Release Preview: Plawie v2.1.0 - Project Aegis

Last updated: 2026-05-28

## Status

Historical preview copy, not current product architecture.

The current app still uses the PRoot-hosted OpenClaw Gateway. Project Aegis
claims about replacing PRoot with a glibc-wrapper, reclaiming storage, and
achieving sub-10-second Gateway cold boot are proposal copy only.

For current architecture, read:

- `ARCHITECTURE_REPORT.md`
- `docs/OPENCLAW_BOOT_SEQUENCE.md`
- `docs/PROVIDER_SIMPLIFICATION_OVERHAUL.md`

## Current User-Facing Architecture

- Cloud Agent Mode: OpenClaw Gateway in PRoot with provider keys.
- Private Offline Mode: direct fllama/NDK local models via `local-llm/...`.
- Compact Bridge Mode: manual `plawie_ndk/local-llm` bridge on
  `127.0.0.1:11435`.

Keep this file only as historical release planning context.
