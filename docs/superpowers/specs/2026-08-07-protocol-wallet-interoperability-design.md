# Protocol-Based External Wallet Interoperability Design

Status: approved

Date: 2026-08-07

## Decision

Plawie will not model external-wallet support as a list of privileged wallet
brands. It will select a transport from the source chain and the capabilities
negotiated with the wallet:

1. Reown AppKit is the primary EVM transport for WalletConnect-compatible
   wallets.
2. Solana Mobile Wallet Adapter 2.0 (MWA) is the primary native Android Solana
   transport.
3. Reown AppKit's Phantom and Solflare link integrations are bounded Solana
   fallbacks when MWA is unavailable or the selected wallet does not expose an
   MWA endpoint.
4. Base Account's Mobile Wallet Protocol (MWP) is a separate future transport,
   disabled until an official or independently audited production-safe
   Flutter/Android client is available.

Wallet names such as MetaMask, Trust Wallet, Uniswap Wallet, Phantom, Solflare,
Jupiter, and the Base App are compatibility examples, not support allowlists.
Runtime namespace, chain, account, and method negotiation determine whether a
wallet can execute a particular funding request.

This document amends the connected-wallet sections of
`2026-08-07-hybrid-base-funding-design.md` and Tasks 2, 5, 6, 7, 10, 11, and 12
of `2026-08-07-hybrid-base-funding.md`. Unchanged bridge, Relay deposit,
receipt, agent, Gateway, x402, and internal Base-wallet boundaries remain in
force.

## Why One SDK Is Not Sufficient

Reown AppKit Flutter provides broad EVM wallet discovery through the
WalletConnect network. The resolved `reown_appkit` 1.7.6 package also includes
special Phantom and Solflare services. Those Solana services use each wallet's
link protocol rather than a normal WalletConnect session.

Solana Mobile's MWA 2.0 is the native Android protocol intended to connect one
dapp implementation to any MWA-compliant Solana wallet. Its official Android
Kotlin client is a better native-first default than adding one deep-link
implementation per Solana wallet.

The branded Base App/Base Account is a separate case. Current Base mobile
documentation provides a React Native/TypeScript Mobile Wallet Protocol client,
and current Reown Flutter documentation says the new Base Wallet is not
supported by its legacy Coinbase connector. Plawie will not translate or embed
that JavaScript client, add a hidden WebView signer, or claim Base Account
support without a production-safe native client.

## Terminology

- **EVM-compatible wallet:** A wallet that can negotiate the required `eip155`
  chain, account, and RPC methods. It may hold assets on Ethereum, Base,
  Robinhood Chain, or another supported EVM chain.
- **Base-capable wallet:** Any EVM wallet that can use Base Mainnet. This is not
  limited to the branded Base App.
- **Base App/Base Account:** Coinbase's branded smart-account product using
  Base Account and Mobile Wallet Protocol surfaces.
- **Compatible Solana wallet:** A wallet that responds to MWA 2.0 and supports
  its required sign-and-send operation, optionally including sign-only, or a
  bounded Reown Phantom/Solflare fallback that supports sign-only requests.
- **Installed hint:** Best-effort Android package visibility used to improve
  ordering. It never grants support or hides a wallet from protocol discovery.

## Product Behavior

### Wallet selection

The funding panel asks for source chain, token, and amount before it asks for a
wallet. It then presents transport-appropriate choices:

- EVM opens Reown's live wallet catalog, with search, installed hints, mobile
  links, and WalletConnect QR/copy fallback.
- Solana launches the MWA Android wallet chooser. If no compatible handler is
  available, Plawie may offer Reown's explicit Phantom and Solflare fallbacks.
- Base Account is shown only when its independent release gate is enabled and
  a supported adapter is present. It is not represented by a generic Coinbase
  connector.

The panel never says a brand is supported merely because its package is
installed. A wallet is usable only after the required chain, public account,
and exact methods are approved.

### Base assets already on Base

Wallet brand and source chain are independent. If an external EVM wallet holds
native Base USDC on Base Mainnet, Plawie does not request a bridge route. It
offers a direct exact ERC-20 transfer to the app-owned Base address using the
same Plawie review, external-wallet approval, receipt, and status boundaries.
Assets on Ethereum, Robinhood Chain, Solana, or another supported source use a
validated bridge or strict deposit route.

### Honest unsupported states

- A WalletConnect wallet missing the required chain or method remains visible
  but unavailable for that request, with the missing capability named.
- An Android Solana wallet that does not implement MWA and is not a bounded
  Reown fallback is not launched through guessed deep links.
- Jupiter Mobile is capability-detected. Current public material does not prove
  that it is an MWA signer, so Plawie does not pre-label it compatible. Jupiter
  Extension is a browser Wallet Standard wallet and is not treated as a native
  Android signer.
- Base Account is labeled unavailable while its adapter gate is off; other
  Base-capable EVM wallets continue to work through Reown.
- Relay copy/QR funding and the explicitly unmonitored Jumper fallback remain
  available according to their independent capability gates.

## Architecture

### Provider-neutral session contract

`ExternalWalletSessionService` remains the only interface visible to bridge
execution. It is implemented by a router rather than by one wallet SDK:

```dart
abstract interface class ExternalWalletSessionService {
  Future<WalletConnectionOptions> discover(BridgeChain chain);
  Future<ExternalWalletIdentity> connect(
    BridgeChain chain, {
    String? transportId,
  });
  Future<void> disconnect();
  Future<String> sendEvmTransaction(EvmBridgeExecutionPayload payload);
  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  );
  ExternalWalletIdentity? get identity;
}

enum SolanaWalletSubmissionMode { signOnly, signAndSend }

sealed class SolanaWalletSubmissionResult {}

final class SignedSolanaTransaction extends SolanaWalletSubmissionResult {
  final Uint8List signedTransaction;
}

final class SubmittedSolanaTransaction extends SolanaWalletSubmissionResult {
  final String signature;
}
```

`ExternalWalletTransportRouter` owns independently gated adapters:

- `ReownEvmWalletAdapter`
- `SolanaMwaWalletAdapter`
- `ReownSolanaFallbackAdapter`
- future `BaseAccountMwpAdapter`

The router selects by requested chain type and negotiated capability. It does
not branch on a display name. Each identity records a non-secret transport ID,
wallet-reported label, namespace, chain, public address, and approved methods.
Receipts may record the transport ID for diagnostics but never session topics,
authorization tokens, callback envelopes, or shared secrets.

Every adapter normalizes a sign-only response to raw transaction bytes before
returning it; transport-specific base58/base64 text never crosses into the
controller or verifier. Before any wallet request, the receipt persists a
non-secret SHA-256 digest: the canonical EVM chain/sender/target/value/calldata
tuple (excluding wallet-estimated gas), or the exact serialized Solana message
bytes. A Solana receipt also persists its recent blockhash for bounded expiry
recovery; neither value is exposed to agents or logs.

### EVM through Reown

Reown's Explorer-backed catalog remains dynamic. Plawie requests only the
chains and methods needed for the reviewed funding action. At minimum:

- namespace `eip155`;
- exact source chain;
- account ownership from the approved session;
- `eth_sendTransaction`;
- bounded chain switching only when the selected wallet exposes the current
  standard method.

MetaMask, Trust Wallet, Uniswap Wallet, Rainbow, and other WalletConnect wallets
need no Plawie execution adapter. Android package queries may provide installed
hints for a bounded set of high-use wallets, but absence from those queries
never removes the wallet from Reown search or QR connection.

### Solana through native MWA 2.0

The Android host integrates the current compatible version of Solana Mobile's
official Kotlin MWA client. A dedicated platform bridge exposes only:

- discover/authorize a Mainnet wallet;
- return the wallet-selected case-sensitive public key and supported features;
- submit one exact serialized transaction through MWA 2.0's standard mandatory
  `signAndSendTransactions` operation, even when the wallet also advertises the
  deprecated sign-only extension;
- deauthorize and clear SDK-scoped authorization state.

The Android MWA intent invokes the system-compatible wallet chooser. Plawie does
not query or launch Phantom, Solflare, Jupiter, or another MWA wallet by package
name. SDK authorization material stays in SDK-scoped secure storage or memory
and never enters Dart preferences, receipts, logs, or agent payloads.

Selection is capability-based, never brand-based. Sign-only remains available
only to the explicit bounded compatibility adapters; Plawie compares their
returned transaction with the reviewed message and signer, persists the derived
signature, and broadcasts those exact bytes once through its bounded Solana
broadcaster.

MWA 2.0 requires wallets to expose `signAndSendTransactions`, while sign-only is
deprecated and may be absent. In that case Plawie validates and freezes the
exact serialized unsigned transaction before invoking the wallet. The wallet
signs and broadcasts it, then returns the transaction signature. Plawie validates
the returned signature, binds it to the reviewed message and selected signer
where the transaction format permits local verification, persists it before any
status request, and polls settlement without broadcasting from Plawie.

If wallet return or transport status is ambiguous and no trustworthy signature
is available, the operation becomes `submissionOutcomeUnknown`. Plawie does not
automatically retry, resubmit, or claim that the transaction was not sent. The
receipt remains active and cannot be cancelled or archived. Recovery must first
obtain evidence: an exact EVM transaction fetched by a user-supplied wallet
history hash, or a Solana transaction fetched by a supplied signature or bounded
account-history scan whose message digest and first signer match the review.
Status polling is not offered without a trustworthy identifier. A new reviewed
operation is allowed only after reconciliation, or for Solana after the source
blockhash is invalid and a complete bounded history scan proves no exact match;
the ten-minute callback-operation expiry alone is never settlement evidence.

### Reown Solana fallback

The resolved Reown package's Phantom and Solflare link services may be enabled
as an independent fallback after contract tests verify their current APIs. They
must use sign-only operations. Callback URLs are accepted only through the
single Plawie wallet callback bridge, bound to one random expiring pending
operation, consumed once, and never logged.

Fallback display names identify the selected transport but do not create a
general per-wallet adapter framework. Adding another branded deep-link adapter
requires a new reviewed design and cannot bypass MWA capability discovery.

### Base Account gate

`BaseAccountMwpAdapter` is an interface reservation, not an implementation
claim. Its feature gate defaults to false and may be enabled only after all of
the following exist:

- a maintained native Android or Flutter client, or an independently audited
  protocol implementation;
- exact EIP-1193 transaction semantics required by the funding flow;
- app-return, replay, account, and chain binding tests;
- license, service-term, privacy, and production configuration review;
- controlled device acceptance against the current Base App.

No JavaScript bridge, hidden browser, embedded wallet page, or imported Base
Account session is permitted as a shortcut.

## Feature Gates

The global connected-bridge kill switch and transport gates are independent:

```text
ENABLE_LIFI_CONNECTED_BRIDGE=false
ENABLE_REOWN_EVM_WALLETS=false
ENABLE_SOLANA_MWA_WALLETS=false
ENABLE_REOWN_SOLANA_FALLBACK=false
ENABLE_BASE_ACCOUNT_MWP=false
```

Direct Base transfer shares the Reown EVM gate but does not call LI.FI. Relay
deposit funding retains its separate existing gate. A disabled or unavailable
transport cannot disable internal Base wallet management, x402, BYOK/cloud
models, setup, the native Gateway, or skills.

## Android Integration

The one `WalletLinkBridge` callback owner remains responsible for initial and
`onNewIntent` callback delivery. It validates the Plawie callback scheme/host,
never logs URI data, and forwards the opaque envelope to the currently pending
adapter only.

Android package visibility is not an execution allowlist:

- Reown may use an HTTPS VIEW query and a bounded package-hint list solely for
  installed-wallet ordering.
- MWA uses its protocol intent and Android chooser with no wallet packages.
- Phantom/Solflare package visibility exists only when their Reown fallback is
  compiled and enabled.
- Unknown compatible WalletConnect wallets remain available through Reown
  search, QR, or copy-link connection.

## Human Approval and Security

Every transport preserves the existing two-boundary approval model:

1. Plawie displays exact chain, account, token, amount, destination, minimum
   output, fees, expiry, and transaction purpose.
2. The selected external wallet displays and approves the resulting request.

The following rules are invariant:

- agents may discover capabilities, quote, and read redacted status only;
- wallet discovery does not authorize a connection;
- connection does not authorize a transaction;
- account or chain changes invalidate the quote and review;
- only the foreground funding controller can create a pending wallet operation;
- one random 128-bit operation is active, expires after ten minutes, and is
  consumed once;
- no transport may transform an estimate into executable calldata;
- no callback or wallet response may trigger an automatic retry or rebroadcast;
- automated tests never spend funds.

## Failure and Fallback Behavior

Transport failures use stable categories rather than wallet-specific guesses:

- `wallet_transport_unavailable`
- `wallet_not_installed`
- `wallet_connection_rejected`
- `wallet_chain_unsupported`
- `wallet_method_unsupported`
- `wallet_account_changed`
- `wallet_callback_invalid`
- `wallet_operation_expired`
- `wallet_signature_mismatch`
- `wallet_submission_outcome_unknown`

The UI names the safe next action: choose another compatible wallet, switch
funding method, request a fresh quote, copy a Relay instruction, or continue in
unmonitored Jumper. It never instructs the user to import a seed or private key.

## Testing

### Pure Dart tests

- Router selects Reown for EVM and MWA for Solana without inspecting a wallet
  display name.
- Disabled transport gates return explicit availability reasons.
- Namespace, chain, account, and approved-method mismatches reject execution.
- Reown Solana fallback is selected only after MWA unavailability and explicit
  fallback enablement.
- Base Account remains unavailable while its independent gate is false.
- Exported identity and receipt JSON contain no session or callback material.

### Android contract tests

- MWA dependency and intent contract use Mainnet and the Android chooser.
- No Solana wallet package is required by the MWA path.
- The single callback owner handles initial and `onNewIntent` delivery without
  logging URI/query data.
- Reown installed hints do not function as a wallet allowlist.

### Adapter tests

- Reown EVM supports any fake wallet exposing the requested namespace, chain,
  account, and method, regardless of brand label.
- MWA authorizes, rejects, and deauthorizes; native submission always chooses
  the standard `signAndSendTransactions` operation.
- The bounded fallback sign-only path rejects changed account/message bytes,
  persists the signature, and invokes the Plawie broadcaster exactly once.
- The sign-and-send path validates the reviewed bytes before invocation,
  validates and persists the returned signature, never invokes the Plawie
  broadcaster, and converts ambiguous completion into
  `submissionOutcomeUnknown` without automatic resubmission.
- Outcome-unknown receipts reject cancel/archive/new submission; EVM recovery
  validates fetched transaction fields and calldata, while Solana recovery
  validates fetched signed bytes against the persisted reviewed-message digest.
- Phantom and Solflare fallback callbacks reject replay, expiry, wrong state,
  wrong account, wrong chain, and changed transaction bytes.
- One active pending operation prevents either Solana submission path from being
  invoked twice.

### Device acceptance

Release acceptance uses at least:

- two WalletConnect EVM wallets from different vendors;
- Phantom and Solflare through MWA where their installed versions support it;
- one Reown Phantom or Solflare fallback cancellation and one sign-only proof;
- Base Account unavailable-state verification until its gate is production
  eligible;
- WalletConnect QR/copy fallback from a second device where practical.

Wallet brands used in acceptance are test fixtures, not a permanent allowlist.
Every mainnet submission remains a separately announced, deliberately small,
user-approved action.

## Documentation and Plan Changes

The master implementation plan must be amended before Task 2 starts:

- Task 2 adds transport identifiers and the independent feature gates to the
  typed domain without adding SDK session material.
- Task 5 becomes protocol-routed external wallet sessions and includes native
  MWA dependency/license review, Android bridge, Reown EVM, and bounded Reown
  Solana fallback.
- Task 6 covers generic EVM WalletConnect execution and direct Base USDC
  transfer in addition to LI.FI EVM execution.
- Task 7 covers reviewed native MWA sign-and-send plus signature persistence and
  status polling. Verified sign-only plus one Plawie RPC broadcast remains
  exclusive to the bounded Reown fallback.
- Task 10 presents protocol-based wallet choice and capability errors.
- Task 11 documents the compatibility matrix as capability-based and read-only
  to agents.
- Task 12 expands device acceptance beyond MetaMask and Phantom.

## Acceptance Criteria

- [ ] No wallet display name controls execution routing.
- [ ] Reown wallet search/QR can expose compatible EVM wallets not named in the
      Android manifest.
- [ ] MWA invokes a compatible Solana wallet chooser without package-specific
      execution code.
- [ ] Phantom and Solflare links are fallbacks, not the primary Solana
      architecture.
- [ ] Jupiter is reported according to observed protocol capabilities, not a
      static support claim.
- [ ] Base Account has a separate default-off gate and honest unavailable state.
- [ ] Base USDC already on Base uses a direct reviewed transfer, not a bridge.
- [ ] Namespace, chain, account, method, review, callback, and returned signed
      bytes or transaction signature are bound before state advances.
- [ ] Native MWA sign-and-send never triggers a Plawie broadcast or automatic
      resubmission; bounded fallback sign-only broadcasts at most once.
- [ ] Agent, Gateway, receipts, and logs receive no wallet session material.
- [ ] Internal Base wallet, x402, setup, models, native Gateway, and skills are
      unchanged by wallet transport availability.

## Primary References

- [Reown AppKit Flutter installation](https://docs.reown.com/appkit/flutter/core/installation)
- [Reown AppKit Flutter custom networks](https://docs.reown.com/appkit/flutter/core/custom-chains)
- [Reown AppKit platform feature matrix](https://docs.reown.com/appkit/features/index)
- [Solana Mobile Wallet Adapter](https://docs.solanamobile.com/developers/mobile-wallet-adapter)
- [Solana Mobile native MWA client](https://docs.solanamobile.com/android-native/using_mobile_wallet_adapter)
- [MWA 2.0 wallet migration and mandatory sign-and-send](https://docs.solanamobile.com/mwa/migration/wallets/walletlib)
- [Base Account mobile integration](https://docs.base.org/base-account/quickstart/mobile-integration)
- [Base Account and Reown integration](https://docs.base.org/base-account/framework-integrations/reown)
- [Uniswap Wallet WalletConnect support](https://support.uniswap.org/hc/en-us/articles/11306127816845-How-to-connect-my-wallet-to-a-site-dapp-using-WalletConnect)
