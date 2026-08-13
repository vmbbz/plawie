# Plawie v2.3.0 — Human-Governed Mobile Agent

Plawie v2.3.0 brings the full OpenClaw Gateway to a native-first Android control surface, adds production-oriented wallet and paid-model workflows, and completes the KeeperHub hackathon proof path.

## Highlights

### Native-first OpenClaw on Android

- Runs the Gateway through the embedded native Android/Node runtime as the primary path.
- Downloads the current official OpenClaw Gateway during first setup instead of freezing a fast-moving Gateway release inside the APK.
- Keeps the Ubuntu PRoot environment isolated as an optional, user-requested rollback path.
- Records setup and dependency-pack receipts so completed downloads are not repeated unnecessarily.

### Dynamic model providers

- Loads cloud provider catalogs dynamically and groups models by provider.
- Supports BYOK providers alongside wallet-funded providers.
- Adds Venice prepaid-credit models and BlockRun pay-per-request models.
- Automatically performs a read-only Venice balance check when its cached status is missing or stale.
- Explains blocked model choices in place and offers the exact recovery action instead of silently ignoring the tap.

### Wallet and payment control surface

- Provides an Android Keystore-backed personal wallet with device-authenticated signing.
- Uses Base Mainnet as the default funding and payment network.
- Supports external-wallet bridge handoffs with route recovery, settlement monitoring, and persistent receipts.
- Requires visible human review and fresh Android authentication before consequential wallet actions.
- Preserves wallet state and receipts across normal APK updates.

### Human-governed KeeperHub Agent Wallet

- Provisions a separate KeeperHub-managed Agent Execution Wallet through signed, headless onboarding.
- Limits agent-facing access to capability discovery, status, receipts, and typed transaction preparation.
- Binds simulation, approval, authentication, idempotent submission, recovery, and verified receipt state into one execution flow.
- Keeps the personal wallet and Agent Execution Wallet visibly separate.

### Skills and mobile operations

- Resolves optional native dependency packs independently of the APK and the upstream Gateway.
- Surfaces ready, configuration-required, dependency-required, and blocked states on skill cards.
- Adds dependency receipts and repair controls without forcing successful packs to download again.
- Retains explicit native command contracts for Android-compatible skills and device tools.

## Installation

1. Download the `arm64-v8a` APK attached to this release.
2. Install it over an existing Plawie build to preserve setup state, wallet material, and receipts.
3. On a fresh install, complete the guided setup while connected to the internet so Plawie can download and verify the official Gateway and required packs.
4. Add provider credentials or fund a supported wallet provider from the in-app model and Wallet surfaces.

## Platform scope

- Android 10 or newer (`minSdk 29`).
- `arm64-v8a` devices only in this release.
- Base Mainnet is the default onchain network.
- Robinhood-chain viewing and bridge planning are available where supported; direct Robinhood sends remain disabled unless the app is built with a reviewed production RPC endpoint.
- PRoot is not started or downloaded by the primary native runtime. It remains an explicit fallback selected by the user.

## Security notes

- No provider API key, wallet private key, signing password, or release keystore is intentionally embedded in the APK.
- BYOK credentials and wallet secrets remain in Android-protected storage.
- Paid requests and Agent Wallet execution remain subject to explicit foreground approval and device authentication.
- Verify the APK checksum published with the release before sideloading.

## Upgrade note

Version `2.3.0` uses Android `versionCode 13`, so it installs normally over `2.2.1` (`versionCode 12`) when signed with the same application certificate. Do not uninstall or clear app data when upgrading if you want to preserve local setup and wallet state.
