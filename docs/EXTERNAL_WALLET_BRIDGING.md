# External Wallet Bridging

Status: reviewed EVM execution foundation; settlement and UI gates disabled

Date reviewed: 2026-08-07

## Reown dependency and license review

Pub resolved `reown_appkit` **1.7.6**. The package archive SHA-256 recorded in
`pubspec.lock` is
`6ea7d0145608d41f38c2286119dfbf1cdabad6644ebe8c8ecb13c0177dae14ee`.
The reviewed license text is the package artifact
`reown_appkit-1.7.6/LICENSE`, SHA-256
`5EB00FF6EA068D9DBAB1AFB20E6D44B5992A6955E7623D1271C5BE98947861E6`.
It identifies itself as the **Reown Community License Agreement**, released
20 August 2025; the package does not declare an SPDX license identifier.

For a distributed application using AppKit, the confirmed legal licensee must
ensure that the following distribution requirements are met:

- include `Portions © 2025 Reown, Inc. All Rights Reserved` in product notices,
  a readme, or an about surface;
- provide a copy of the license with the application;
- satisfy the applicable logo and branding requirements; and
- use the Reown network unless Reown explicitly approves otherwise.

The license also states royalty-free thresholds of 2,500,000 remote processing
calls per month and 500 monthly active users, after which a commercial license
is required. This records the package text, not a conclusion that Plawie's
planned use qualifies for a particular tier or for production release.

## Product and release terminology

`Plawie` is the user-facing product name. `clawa` is the current package
identifier in `pubspec.yaml`; neither name is asserted here to be a legal
entity. `Release owner` means the accountable distributor or release
maintainer. Before production enablement, the release owner must record the
confirmed legal licensee identity in the dated release review described below.

## Service terms requiring release-time confirmation

The package license alone does not establish the applicable Reown account,
project, subscription, billing, branding entitlement, acceptable-use rules,
privacy/data-processing terms, geographic restrictions, or how current usage is
measured. Before enabling connected mode, the release owner must review and
accept the then-current [Reown Terms of Service](https://reown.com/terms-of-service),
[pricing and project limits](https://reown.com/pricing), and
[Flutter project configuration guidance](https://docs.reown.com/appkit/flutter/cloud/relay).
The release must use a valid Plawie-specific project ID, restrict it to the
shipped application identity where supported, keep it out of source control,
and confirm that the selected plan and branding treatment cover expected use.

## Planned enablement evidence

Task 11 owns the following release evidence and must complete it before
connected mode can be enabled:

- keep a dated production release review/checklist in
  `docs/EXTERNAL_WALLET_BRIDGING.md`, including the confirmed legal licensee
  identity and the applicable configuration, license, service terms, plan,
  branding, and projected-usage decisions;
- add the shipped Reown license copy under
  `android/app/src/main/assets/licenses/`; and
- provide the required attribution and branding in an in-app About or legal
  surface.

These assets and UI are intentionally not created in Task 1. If any required
evidence or shipped surface is absent, the feature gate must remain disabled.

## Task 1 release decision

This round adds dependencies only. No connected LI.FI execution implementation
exists in the current app. Before such code is added or shipped, Task 2 must
introduce the planned compile-time `ENABLE_LIFI_CONNECTED_BRIDGE` feature gate,
defaulting to disabled. That gate may be enabled only after a valid Reown
project configuration is supplied and the release owner completes and records
the current license, service-terms, attribution, branding, and projected-usage
check. An unresolved check requires the gate to remain disabled; dependency
resolution is not production approval.

Task 11 will expand this document with operational architecture, threat model,
recovery, release gates, and user-flow guidance.

## Mobile Wallet Adapter dependency and attribution

Android now resolves the exact dependency
`com.solanamobile:mobile-wallet-adapter-clientlib-ktx:2.1.0`. Its published
Maven POM identifies the artifact as **Apache License 2.0** and points to the
upstream `solana-mobile/mobile-wallet-adapter` repository. The integration uses
the official Android chooser and `Solana.Mainnet`; it does not select Solana
wallets by package name.

The release decision is to include the Apache 2.0 license text and applicable
third-party notices in the same shipped legal bundle owned by Task 11. Until
that bundle and its in-app legal surface are verified, Solana MWA remains
disabled by its compile-time feature gate. This is separate from the stricter
Reown license and service-terms review above; satisfying one dependency's
notice requirements does not satisfy the other.

MWA's Activity Result API requires an AndroidX `ComponentActivity`. The app's
activity therefore uses Flutter's supported `FlutterFragmentActivity` base.
The existing canvas screenshot and picture-in-picture integrations were kept
on Android activity APIs and compile-verified after that migration.
MWA's AndroidX graph also requires a modern compile SDK. The root Gradle policy
uses Android Components `finalizeDsl` to raise Android library subprojects to
compile SDK 36 after each plugin's own DSL runs. This specifically prevents
older Flutter plugins from restoring an incompatible compile SDK; it does not
change their minimum SDK, target SDK, or runtime opt-in behavior.

## Task 5 session architecture

Task 5 adds session transports only. It does not submit LI.FI routes, transfer
USDC, expose a bridge execution button, or enable any wallet gate by default.

- Android owns exactly one callback route, `plawie://wallet-callback`. Flutter's
  automatic deep-link handling is disabled for this route. One native owner
  retains the initial link and streams later links without logging URI data.
- EVM sessions use Reown AppKit's protocol and dynamic Explorer catalog. The
  selected chain, public account, and `eth_sendTransaction` approval must match
  exactly; display names never choose EVM execution code.
- Solana uses native MWA first. If sign-only is advertised, Dart receives the
  signed bytes. Otherwise MWA's mandatory sign-and-send path returns one
  signature. Native authorization state never crosses the platform channel.
- Phantom and Solflare are bounded sign-only compatibility fallbacks. They are
  shown only after MWA is proven unavailable and must be selected explicitly.
  Their base58 response is decoded once into raw bytes before leaving the
  adapter.
- Base Account remains an honest unavailable option while its independent gate
  has no production adapter.
- Connect, sign, and send operations are serialized by an in-memory 128-bit
  operation identifier, reviewed-payload fingerprint, and ten-minute expiry.
  Disconnect invalidates the operation. Operation IDs, callback envelopes,
  session topics, authorization tokens, and shared secrets are not persisted,
  logged, exported to receipts, or exposed to agents.

The release build must provide non-empty `REOWN_PROJECT_ID` and an HTTPS
`PLAWIE_DAPP_URL`, then independently enable only the reviewed feature gates:
`ENABLE_REOWN_EVM_WALLETS`, `ENABLE_SOLANA_MWA_WALLETS`, and, if approved,
`ENABLE_REOWN_SOLANA_FALLBACK`. A missing define or disabled gate produces an
unavailable capability instead of a partially working connector.

## Task 6 reviewed EVM execution

Task 6 adds the foreground EVM controller and bounded JSON-RPC client. It still
does not expose an execution button or enable a wallet/bridge gate by default.

- Only the shipped Ethereum, Base, and Robinhood Chain mainnet RPC URLs are
  accepted. RPC redirects are rejected, response bodies are capped at 64 KiB,
  IDs are random non-secret integers, and receipt reads never resubmit.
- ERC-20 allowances use a strict 32-byte `eth_call`. An insufficient allowance
  creates a separate human review for the exact amount; unlimited approval is
  rejected. A confirmed approval is followed by a fresh validated LI.FI quote
  and a new bridge review.
- Every wallet request is preceded by a durable
  `awaitingExternalWallet` receipt containing the canonical SHA-256 payload
  fingerprint. The returned 32-byte source hash is persisted before any RPC
  receipt read. Known user rejection returns to review; ambiguous transport or
  malformed post-request outcomes stay active and blocked from automatic
  resend.
- Base USDC sent from Base Mainnet uses provider `direct_base` and route tool
  `direct_transfer`. It skips LI.FI and allowance calls, estimates bounded gas,
  transfers the exact amount to the current internal Base address, and reaches
  `completed` only after a successful Base receipt and balance refresh.
- Process restoration is read-only. An `awaitingExternalWallet` receipt without
  a trustworthy hash becomes outcome-unknown and never invokes a wallet method.
  Task 8 owns evidence-bound hash recovery and LI.FI settlement monitoring.

Tasks 7 through 10 still own verified Solana submission, full settlement and
recovery, Relay deposits, and the explicit human-approval UI. The EVM execution
foundation must not be presented as a completed bridge until those tasks and
Task 11's release evidence are complete.
