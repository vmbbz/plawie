# External Wallet Bridging

Status: implementation complete behind independent release gates; legal bundle
and controlled Mainnet acceptance remain pending

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

## Pending production enablement evidence

The release owner must complete the following evidence before connected mode
can be enabled in a production bundle:

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

## Release decision

The execution implementation now exists, but every release gate defaults to
disabled. `ENABLE_LIFI_CONNECTED_BRIDGE` may be enabled only after a valid
Reown project configuration is supplied and the release owner completes and
records the current license, service-terms, attribution, branding, projected
usage, and controlled Mainnet acceptance checks. An unresolved check requires
the affected gate to remain disabled; implementation and dependency resolution
are not production approval.

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

`PLAWIE_DAPP_URL` is Reown pairing metadata and must match a Project Domains
entry in the Reown dashboard. It is not the Android callback. Android returns
through the manifest-owned `plawie://wallet-callback` custom scheme. Link Mode
and an HTTPS universal callback remain disabled until Plawie controls a domain,
hosts Android Digital Asset Links, and separately reviews that transport.

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

## Production funding contract

The Wallet page owns one `Fund Base from another chain` flow. Its destination
is the displayed Android-owned Base address and native Base USDC. External
wallet keys never enter Plawie, the OpenClaw Gateway, receipts, logs, or agent
tools. The internal Base signer never receives source-chain bridge calldata.

Runtime support is protocol- and capability-based:

- compatible EVM wallets are discovered through Reown's live catalog and are
  selected by approved namespace, chain, account, and method—not display name;
- Solana uses the Android Mobile Wallet Adapter chooser first, without a wallet
  package allowlist; Phantom and Solflare Reown fallbacks are bounded sign-only
  compatibility paths shown only after MWA is unavailable;
- Base Account remains unavailable until its independent production adapter
  and default-off gate are reviewed; and
- LI.FI/Relay chain and exact-token capability data is refreshed before wallet
  discovery or deposit instruction creation. Cached data is display-only.

Robinhood Chain is chain ID `4663`. Its eligible source assets are native ETH
and the official USDG contract
`0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168`, but either appears only when the
action-time LI.FI/Relay intersection confirms a route to native Base USDC.
USDG is a source asset, not Base USDC and not a provider-payment asset. The UI
preselects USDG for a stable-to-stable route when available, keeps ETH visible,
and warns that both ETH bridges and USDG sends must retain source-chain ETH for
gas. No full-balance ETH shortcut is provided.

When a provider top-up needs funding, the same canonical panel opens in a
safe-area, scroll-controlled modal. Only a bridge intent created in that
foreground session can return success, and only from a persisted `completed`
receipt after Base delivery. The first insufficient provider challenge is
destroyed before the modal opens; a new challenge and a separate x402 approval
are required after Base USDC is freshly verified.

### Connected EVM flow

The connected account and chain are authoritative. Plawie requests a fresh
executable LI.FI route and validates source/destination chains, exact contracts,
amounts, recipient, calldata shape, route tool, minimum output, quote age, and
slippage before displaying it. An insufficient ERC-20 allowance receives its
own Plawie review and wallet confirmation for the exact amount; unlimited
allowances are rejected. A confirmed allowance forces a fresh quote and a new
bridge review. The source hash is persisted before status polling. A direct
Base-USDC source skips LI.FI and allowance calls but still receives exact
Plawie review and wallet confirmation.

### Solana submission

MWA sign-only returns signed bytes that must contain the exact reviewed message,
blockhash, and signer; Plawie broadcasts those verified bytes at most once.
MWA sign-and-send returns a signature that is verified and persisted; Plawie
does not broadcast again. Unknown, stale, changed-account, changed-message, or
ambiguous outcomes remain blocked from resubmission and require evidence-bound
signature/history reconciliation.

### Relay self-custody deposit

Relay uses strict exact-input, a one-time deposit address, the app Base address
as recipient, and a personal source-chain refund address controlled by the
user. CEX withdrawal mode is excluded because safe recovery would require a
Plawie-controlled recovery address. The UI shows exact chain, token, amount,
expiry, refund address, minimum Base USDC, warnings, address-only QR, and copy
action. There is no local `I sent it` state. Hiding archives but continues
tracking; after local expiry the full address, QR, and copy action are removed
to prevent reuse while the redacted receipt remains auditable.

### Recovery, agents, and fallback

Only one non-archived intent may be active. Restart recovery polls persisted
hash/signature/request evidence and never reconnects a wallet, signs, broadcasts,
or resends. Outcome-unknown receipts cannot be cancelled or archived. Agent
commands are limited to `bridge.capabilities`, `bridge.quote`, `bridge.status`,
and `bridge.receipts`; status/history are local redacted reads and cannot mint a
UI approval. Execute-like chat language directs the user to the foreground
Wallet page.

Jumper remains an explicitly unmonitored fallback. It receives best-effort
source/destination prefill fields but creates a new external route; Plawie does
not claim to submit, resume, or monitor it.

### Release configuration and rollback

Release builds require non-empty `REOWN_PROJECT_ID` and HTTPS
`PLAWIE_DAPP_URL`. Internal Robinhood transactions additionally require an
HTTPS `ROBINHOOD_RPC_URL`; debug builds may use the official rate-limited public
RPC for non-production checks. Enable independently only after the matching
acceptance:

- `ENABLE_LIFI_CONNECTED_BRIDGE`;
- `ENABLE_RELAY_DEPOSIT_BRIDGE`;
- `ENABLE_REOWN_EVM_WALLETS`;
- `ENABLE_SOLANA_MWA_WALLETS`;
- `ENABLE_REOWN_SOLANA_FALLBACK`; and
- default-off `ENABLE_BASE_ACCOUNT_MWP`.

Named wallets are acceptance fixtures, not permanent compatibility claims.
Production acceptance must prove reject/cancel paths, restart without replay,
redacted logs, exact allowance, one-call Solana behavior, terminal provider
status, Base balance refresh, and no Gateway/context regression. Incidents are
contained by disabling the affected transport/provider gate independently;
the internal wallet, native Gateway, read-only quote/status surfaces, and honest
Jumper fallback remain available.
