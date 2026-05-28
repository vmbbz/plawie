# Audit: OpenClaw Bootstrap Process

Last updated: 2026-05-28

## Status

Historical audit note. The current production boot contract is documented in
`docs/OPENCLAW_BOOT_SEQUENCE.md`.

Do not treat the older `BIN_WRAPPER_ERROR` text as the current active issue
without rechecking code and logs.

## Current Bootstrap Expectations

- Gateway boot is independent of local NDK inference.
- Setup writes hardened Gateway config before the first Gateway start.
- Provider defaults come from `ModelProviderCatalog`.
- Context/output budgets come from `ModelExecutionPolicy`.
- Stale Ollama routes migrate away.
- Node pairing waits for Gateway interactive readiness.

## Preserved Lessons

- Wrapper existence is weaker than package integrity.
- Bootstrap checks should verify package files, not just command discovery.
- Repair paths should be incremental when possible.
- User-facing setup must avoid long hidden installs and obscure platform
  exceptions.
