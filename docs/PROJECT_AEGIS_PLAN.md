# Project Aegis Plan

Last updated: 2026-05-28

## Status

Historical proposal, not current implementation.

The current production architecture still runs OpenClaw Gateway inside the PRoot
Linux userland. The app has not migrated Gateway execution to a glibc-runner.
Do not use this file as an implementation contract for boot, storage, pairing,
or provider routing.

## Current Source Of Truth

- `ARCHITECTURE_REPORT.md`
- `docs/OPENCLAW_BOOT_SEQUENCE.md`
- `docs/PROVIDER_SIMPLIFICATION_OVERHAUL.md`

## What Remains Useful

The original Aegis idea remains a possible future research direction:

- Reduce rootfs size.
- Reduce PRoot syscall overhead.
- Launch Gateway faster.
- Simplify OpenClaw process management.

Any revival needs a fresh design review against the current code, especially:

- `android/app/src/main/kotlin/com/nxg/openclawproot/ProcessManager.kt`
- `android/app/src/main/kotlin/com/nxg/openclawproot/BootstrapManager.kt`
- `lib/services/native_bridge.dart`
- `lib/services/gateway_service.dart`

## Non-Current Claims

The following claims from the old proposal are not production facts today:

- Gateway boot under 10 seconds through glibc-runner.
- Removal of the PRoot rootfs.
- 80 percent storage reduction from Aegis.
- Watchdog changes based on near-instant boot.
