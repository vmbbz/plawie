# Hybrid External-Wallet to Base Funding Design

Status: approved

Date: 2026-08-07

Wallet interoperability amendment:
`2026-08-07-protocol-wallet-interoperability-design.md`. Where wallet-specific
language in this document names Reown, MetaMask, Phantom, or Solflare as the
architecture, the approved protocol-router amendment takes precedence.

## Decision

Plawie will replace the current quote-only bridge card with one canonical Base
funding panel offering two non-custodial methods:

1. **Connect wallet and bridge** is the default. Plawie connects the source
   wallet, requests and validates a fresh executable LI.FI route, shows an exact
   review, asks the external wallet to approve, and tracks settlement into the
   app-owned Base wallet.
2. **Send to a one-time address** is the alternative. Plawie requests a strict
   Relay deposit order, shows exact transfer and refund instructions, and tracks
   the deposit and destination delivery without requiring a dapp session.

`Open Jumper` remains only a best-effort, explicitly unmonitored fallback. It is
never presented as continuation of a Plawie quote.

This design supersedes the bridge-execution section of
`2026-08-05-native-wallet-bridge-paid-provider-design.md` and requires the
existing `2026-08-05-external-wallet-bridge-execution.md` implementation plan
to be replaced after this specification is approved.

## Verified AI-provider settlement boundary

The provider payment rails were rechecked against official documentation and
live, unsigned `402 Payment Required` challenges on 2026-08-07:

| Provider surface | Live accepted settlement | Robinhood Chain |
|---|---|---|
| Venice `POST /api/v1/x402/top-up` | Base USDC and Solana USDC | Not offered |
| BlockRun `blockrun.ai` | Base USDC per request | Not offered |
| BlockRun `sol.blockrun.ai` | Solana USDC per request | Not offered |
| BlockRun `nano.blockrun.ai` | Polygon, Arbitrum, Optimism, and Unichain USDC through Circle Gateway | Not offered |

The first-release Plawie transport integrates BlockRun's default Base surface;
the additional BlockRun gateways do not expand the app's signing authority.
Therefore, `Base-canonical` describes Plawie's selected app payment rail, not
every rail each provider supports. Plawie continues settling Venice and
BlockRun through its Android-owned Base wallet so wallet authentication,
visible approval, receipts, balances, and provider consumption retain one
security owner. A user funding from Robinhood Chain must first bridge into that
Base wallet; Plawie must never construct a Robinhood payment merely because the
wallet or provider is EVM-compatible.

Direct provider payment from an external Solana wallet is a separate future
feature. It would need a provider-payment-specific Solana challenge parser,
human approval, signature/broadcast policy, provider identity binding, and
receipt model. The bridge MWA path in this design cannot silently double as
that payment rail. If a future live challenge offers Robinhood Chain, it also
remains disabled until its chain, asset, signer, settlement, recovery, and
release policy receive an explicit implementation review.

## Problem Being Corrected

The shipped Base page currently requests a LI.FI quote, displays planning data,
discards `transactionRequest`, and opens the generic Jumper homepage. The
browser, Jumper, and any browser-connected wallet receive no route ID, source
chain, token, amount, destination address, or Plawie wallet session. They cannot
reconstruct the quote or open an approval for it.

That behavior is safe but not an executable bridge. The product must either
complete a transfer through a defined signing/deposit protocol or label the
result as an estimate with no implied continuation.

## Goals

- Fund Plawie's app-owned Base Mainnet wallet with native Base USDC from a
  supported external chain and token.
- Give users the familiar connected-wallet approval flow when their wallet can
  connect.
- Give users a simple exact-transfer flow when connection is unavailable or
  undesirable.
- Preserve non-custody: Plawie never receives an external wallet private key and
  never becomes the refund custodian.
- Persist enough redacted state to resume status tracking without asking the
  wallet to sign or send twice.
- Keep bridge execution exclusively in foreground Base UI. Chat and agents may
  prepare parameters, quote, explain, and report status, but cannot connect,
  reveal a deposit instruction, approve, sign, send, or retry a transfer.
- Keep the existing native OpenClaw Gateway, skills, model context, and internal
  Base signing boundaries unchanged.

## Non-Goals

- Plawie will not import an external wallet seed or private key.
- The internal Base wallet will not sign source-chain bridge calldata.
- The first release will not select a bridge solely by promotional rewards.
- Plawie will not run a custodial refund wallet. Relay one-time-address funding
  is self-custody-only in the first release; CEX withdrawals are not accepted
  because safe CEX recovery requires an integrator-controlled recovery address.
- Plawie will not embed a LI.FI partner secret, Relay secret, wallet session,
  callback payload, signed transaction, or raw calldata in logs or receipts.
- A chat message such as `yes` will never count as blockchain authorization.

## Product Experience

### Entry state

The Base page shows one `Fund from another chain` panel. Destination is fixed to
the currently loaded Plawie Base wallet and displayed in shortened and
copyable/full forms. The panel is disabled when the internal wallet is absent,
recovering, unauthenticated, or not on Base Mainnet.

The user chooses source chain, source token, and exact input amount. Supported
chains and tokens come from live provider capability data; shipped constants
only identify trusted chains and native Base USDC.

The method selector defaults to `Connect wallet`. `One-time address` remains
visible when Relay reports a supported strict-deposit route. Changing method
clears every method-specific quote and review object.

### Connected-wallet flow

```text
Choose source/asset/amount
  -> Connect external wallet
  -> derive source address and chain from the session
  -> request fresh LI.FI executable quote
  -> validate route and transaction
  -> Plawie exact review
  -> optional exact ERC-20 approval in external wallet
  -> refresh quote and review if approval made the quote stale
  -> external wallet bridge approval
  -> persist source hash before polling
  -> LI.FI pending/destination status
  -> terminal receipt and Base USDC refresh
```

The connected session address is authoritative. A manually entered source
address can be used for an estimate but never for executable signing.

On EVM sources, Reown AppKit handles wallet choice, approved account, chain
switch/add, and `eth_sendTransaction`. If an ERC-20 allowance is insufficient,
Plawie requests only the exact source amount for LI.FI's validated approval
target. Unlimited allowance is rejected. Approval and bridge transactions have
separate Plawie reviews and separate external-wallet confirmations.

On Solana, Phantom's universal/deep-link session handles connection and the
current `signTransaction` method. The deprecated `signAndSendTransaction`
method is not used. The callback is bound to one random, expiring state and the
connected case-sensitive public key. The fresh validated serialized transaction
is handed to Phantom unchanged. On return, Plawie verifies that the signed
transaction contains the same reviewed message and expected signer, then sends
those exact signed bytes once through an allowlisted Solana Mainnet RPC. Unknown,
duplicate, expired, wrong-wallet, wrong-chain, or changed-message callbacks
cannot advance the intent.

### One-time-address flow

```text
Choose source/asset/amount
  -> provide a personal source-chain refund address
  -> request Relay strict exact-input deposit quote
  -> validate source route, Base-USDC recipient, amount and refund address
  -> create and persist one active funding instruction
  -> show exact chain/token/amount/deposit address/expiry/refund/output estimate
  -> user sends a normal transfer from the validated self-custody wallet
  -> poll by deposit address and request ID
  -> Relay fill/refund status
  -> terminal receipt and Base USDC refresh
```

The request uses `useDepositAddress: true`, `strict: true`,
`tradeType: EXACT_INPUT`, the app-owned Base address as `recipient`, native Base
USDC as `destinationCurrency`, and the user's personal source-chain address as
`refundTo`. Relay's provider-specific `user` field is populated only according
to the current strict-deposit request schema and verified contract fixtures; it
is not inferred from the differently described generic quote semantics.

The transfer instruction is single-use in Plawie's UI. Inputs freeze once the
address is shown. Revealing an address cannot be undone onchain: after reveal,
`Cancel` becomes `Hide instructions`, and the receipt remains tracked until a
provider terminal observation or explicit expiry/archive. Archiving never
deletes status history or makes the old address safe to reuse. The page presents:

- source network and exact token;
- exact amount in display and smallest units;
- one-time deposit address with copy and QR;
- personal refund address;
- expected/minimum Base USDC where the provider supplies it;
- quote/instruction freshness and `Send immediately` guidance;
- explicit warnings that a wrong token, wrong VM, or unsupported asset can be
  unrecoverable;
- `Open wallet` only when a reviewed chain-specific URI is supported; otherwise
  copy/QR remains the honest path.

Relay one-time-address funding accepts only a validated self-custody source and
refund address controlled by the user. CEX withdrawal mode is blocked in the
first release: Relay's documented safe recovery path for CEX-originated sends
requires an integrator-controlled recovery address, which would make Plawie a
custodian. The UI explains the limitation and offers the explicitly unmonitored
external fallback instead.

Only tokens reported as Relay solver-depositable currencies for the selected
source chain are offered. Ethereum and Solana support is discovered live.
Robinhood Chain appears in this mode only if Relay's live chain and currency
metadata explicitly support the requested route.

### External fallback

When neither integrated method can execute, Plawie may open current official
Jumper with best-effort prefilled source chain, token, amount, Base chain, native
Base USDC, and destination address. The final screen says:

> Continue externally. Jumper will create a new route. Plawie will not submit or
> monitor this transfer; verify the Base destination before approving.

The app uses the current `jumper.xyz` host, never relies on the historical
redirect as a contract, never sends raw calldata/session material in the URL,
and never records the fallback as submitted or completed. If current Jumper
does not honor a prefill field, the UI remains truthful and shows copyable
transfer parameters beside the button.

## Architecture

### Provider-neutral coordinator

`BridgeFundingCoordinator` is the only state machine allowed to create or
advance a funding intent. It depends on strategy interfaces rather than on UI:

```dart
abstract interface class BridgeFundingStrategy {
  Future<BridgeFundingCapabilities> capabilities();
  Future<BridgeFundingQuote> quote(BridgeFundingRequest request);
  Future<BridgeFundingSubmission> submit(
    ValidatedBridgeFundingIntent intent,
  );
  Future<BridgeFundingObservation> status(BridgeFundingReceipt receipt);
}
```

- `LifiConnectedWalletStrategy` owns executable LI.FI route retrieval,
  transaction validation, external-wallet requests, and LI.FI status mapping.
- `RelayDepositAddressStrategy` owns strict deposit quote creation, deposit
  instruction validation, and Relay request/deposit status mapping.
- `ExternalJumperFallback` builds an unmonitored URL and has no `submit` or
  status capability.

`BridgeQuoteService` remains a public read-only planner for chat and estimate
surfaces. Executable quote parsing moves behind the connected-wallet strategy
so raw transaction material cannot leak into agent-visible models.

### External wallet sessions

`ExternalWalletSessionService` wraps Reown AppKit and Phantom-compatible link
handling behind injectable adapters. It exposes only:

- wallet label, approved public address, namespace and chain;
- connect, disconnect and bounded chain switch/add;
- exact EVM transaction request;
- exact Solana sign-only request; broadcasting belongs to a separate bounded
  Solana Mainnet broadcaster that accepts only the verified returned bytes.

The Reown project ID is release configuration restricted to Plawie's package
and signing identity. Callback routing accepts only the shipped Plawie callback
scheme/verified host and consumes random state once. Raw session topics and
callback envelopes never enter Plawie receipts, preferences, or diagnostics.
Reown may maintain only its SDK-scoped secure session store. A Phantom shared
secret and callback state remain in memory for one foreground funding flow and
are cleared on disconnect or process death; receipt/status recovery never
requires them.

### Validation boundary

`BridgeTransactionValidator` validates fresh LI.FI data before any review or
wallet request:

- trusted HTTPS provider host with redirects disabled;
- bounded JSON and transaction payload sizes;
- exact source/destination chain IDs and tokens;
- connected source and internal Base destination addresses;
- native Base USDC destination contract;
- exact input and minimum output;
- bounded slippage and quote freshness with a safety margin;
- EVM `from`, `to`, `value`, chain, data encoding and approval target;
- Solana source key, serialized encoding and route metadata;
- trusted route/tool identifier returned by current provider metadata.

`RelayDepositInstructionValidator` separately validates live strict-deposit
responses, including provider/request ID, deposit address format for the source
VM, exact input, recipient, destination chain/currency, refund address, expiry,
and solver-depositable currency membership.

### Persistent state and receipts

Only one active non-terminal funding intent may exist at a time. An exposed
deposit instruction that the user archives remains status-trackable but is no
longer active; creating a replacement requires an explicit warning that the old
address can still receive funds and must never be reused. The unified state
machine is:

```text
draft
  -> checkingCapabilities
  -> connectingWallet | collectingRefundAddress
  -> quoting
  -> awaitingPlawieReview | awaitingDeposit
  -> awaitingExternalWallet | depositDetected
  -> submitted
  -> sourcePending
  -> destinationPending
  -> completed | failed | refunded | partial | expired | cancelled
```

Every transition that follows a user approval or external submission is
persisted before the next external action. Resume can only inspect status; it
cannot reopen a wallet, sign, send, copy, or create a new deposit address.
`cancelled` is valid only before a connected transaction is submitted or before
a strict deposit address is revealed. An exposed deposit instruction can be
hidden or later archived, but not revoked or represented as cancelled.

The versioned redacted receipt stores:

- local intent ID, strategy and provider;
- provider route/request/tool IDs;
- source/destination chain and token identifiers;
- shortened/public source, refund, deposit and Base destination addresses;
- exact submitted, estimated/minimum and actual received amounts;
- source and destination transaction hashes when available;
- state, provider status/substatus, timestamps and last poll time;
- whether an EVM approval was separately submitted.

It never stores raw calldata, serialized or signed transactions, signatures,
Reown topics, callback state/envelopes, private keys, seed phrases, QR images, or
HTTP authorization headers.

## Human Approval and Agent Boundary

| Action | Required authority |
|---|---|
| Read capabilities, quote, status or receipt | Read-only; agent permitted |
| Open/pre-fill Base funding panel | Foreground navigation; agent may suggest |
| Connect external wallet | Explicit foreground tap |
| Generate strict one-time instruction | Explicit foreground review tap |
| EVM exact allowance | Plawie review, then external-wallet approval |
| Connected bridge submission | Plawie review, then external-wallet approval |
| Deposit transfer | User performs normal transfer from validated self-custody wallet |
| Resume polling | Automatic read-only operation; no rebroadcast |

An agent cannot call a strategy's `submit`, request a wallet connection, reveal
or copy a deposit address, approve a route, or turn a status retry into a new
transaction. Background status updates may post one terminal bridge
notification; they do not create a second persistent Gateway notification.

## Status, Recovery, and Idempotency

- A quote or generated address is never `submitted`.
- A connected flow becomes `submitted` only after a valid source hash is
  returned and persisted.
- A deposit flow becomes `depositDetected` only from Relay's observed status,
  not from the user pressing `I sent it`.
- LI.FI and Relay polling uses bounded exponential backoff, `Retry-After`, app
  lifecycle pause/resume, and a manual refresh action.
- Polling timeout means `still pending`, not `failed`.
- A terminal provider success remains success if Base balance refresh fails;
  the receipt records `balanceRefreshPending` and offers refresh.
- Ambiguous wallet return or network loss after submission enters status
  recovery. It never resends automatically.
- EVM unknown-return recovery accepts only a user-supplied source hash whose
  shipped-chain RPC transaction exactly reproduces the persisted review
  fingerprint. Direct Base recovery additionally requires the exact USDC
  transfer target, zero native value, recipient, and amount.
- Solana unknown-return recovery accepts a pasted signature or scans at most
  200 source-address signatures since review creation. It attaches only a
  transaction with the persisted first signer and message digest. Expiry
  requires an invalid reviewed blockhash plus a complete, non-truncated,
  error-free no-match scan passed through the evidenced state transition.
- Refund and partial completion are first-class terminal states with explorer
  links and provider recovery guidance.
- Expired unsent instructions remain visible in history but cannot be reused.

## Error Language

Errors identify the boundary and next safe action:

- `This estimate cannot be approved. Connect your wallet for a fresh route.`
- `Wallet account changed. No transaction was sent; request a new quote.`
- `Quote expired before approval. No transaction was sent.`
- `Send exactly 12.34 USDC on Solana to this one-time address.`
- `This deposit instruction expired. Do not send funds to it.`
- `Deposit detected; Base delivery is still pending.`
- `Transaction submitted; status is temporarily unavailable. Plawie will not
  resend it.`
- `Relay refunded the source address. View the refund transaction.`
- `Jumper is an external flow and is not tracked by Plawie.`

Provider exceptions, raw bodies and callbacks are sanitized before display.

## Data and Network Efficiency

- Capability snapshots have provider-defined freshness and ETag support where
  available.
- Editing form fields is debounced; quote calls are cancelled/superseded and
  never run concurrently for stale inputs.
- A connected flow requests one planning quote and one mandatory fresh
  executable quote; it requotes only after expiry, account/chain change, or an
  approval transaction.
- A deposit address is not regenerated on page rebuild or app resume. Once
  revealed, the persisted instruction cannot be cancelled; it is reused until
  terminal and remains status-trackable after expiry/archive. Creating a new
  instruction after expiry requires an explicit warning that the old address
  must never be used.
- Status polling backs off and stops at terminal state.

## Alternatives Considered

### Generic Jumper handoff only — rejected

It loses route context, cannot trigger the connected wallet for Plawie's quote,
cannot provide a reliable receipt, and currently gives the user a false sense
of continuity.

### Connected-wallet execution only — rejected

It provides the best route and approval experience but excludes exchange
withdrawals, unsupported self-custody wallet sessions, and users who prefer a
normal transfer. CEX withdrawals remain intentionally outside the first release
for either integrated method.

### Deposit-address funding only — rejected

It is simple and avoids contract approvals, but sacrifices LI.FI aggregation,
adds sweep overhead, exposes users to exact-token/refund mistakes, and is not
the expected experience when a compatible wallet is already installed.

### Recommended hybrid

Default connected execution satisfies the familiar wallet-prompt expectation.
Strict deposit instructions cover non-connectable sources without custody. Both
share one receipt/status UI and leave Jumper as a truthful escape hatch.

## Implementation Slices

After approval, the implementation plan will break work into independently
committed slices:

1. Shared bridge models, capability matrix, redacted receipt store and state
   transition tests.
2. Preserve and validate executable LI.FI requests without enabling signing.
3. Reown/Phantom session and one-shot callback adapters.
4. Connected EVM exact-allowance and bridge execution.
5. Connected Solana signing, reviewed-message verification and bounded
   single-broadcast execution.
6. Relay strict-deposit quote, instruction and status strategy.
7. Unified Base funding panel, agent read-only status and honest Jumper fallback.
8. Interruption recovery, notification convergence, documentation, full
   regression verification and controlled mainnet acceptance.

Every slice starts with failing tests, ends with focused and regression
verification, and receives its own source-only commit. APKs, project IDs,
callback captures and generated reports are never committed.

## Test Design

### Pure contract tests

- Live capability parsing for LI.FI and Relay, including unsupported Robinhood
  and unsupported deposit currencies.
- LI.FI route validation for wrong chain/account/token/recipient/amount,
  redirect, expiry, malformed transaction, oversized response and slippage.
- Relay strict instruction validation for wrong deposit VM/address, recipient,
  refund address, amount, token, request ID, expiry and solver currency.
- State-machine tests reject skipped/backward states, concurrent intents,
  duplicate wallet requests, duplicate callbacks, duplicate deposits and
  rebroadcast on resume.
- Receipt migration and corrupt-record quarantine.

### Wallet adapter tests

- Reown configuration absence, connection rejection, account/chain changes,
  exact method allowlist and EVM hash validation.
- Exact ERC-20 allowance, unlimited approval rejection, approval confirmation,
  fresh requote and bridge submission.
- Phantom case-sensitive key binding, encrypted callback/state handling,
  sign-only response verification, changed-message rejection, bounded
  single-broadcast behavior, expiry and replay.

### Provider status tests

- LI.FI and Relay pending, destination pending, completed, failed, refunded,
  partial, not found, rate limited, malformed and timeout responses.
- Restart/resume performs polling only.
- Base balance-refresh failure never rewrites terminal settlement.

### Widget and accessibility tests

- Method selector defaults to connected wallet and clears stale method state.
- Long chain/token names, address copy/full view, QR semantics and small-screen
  overflow.
- Exact review, separate EVM approval, wallet rejection and expired quote.
- Deposit warnings, personal refund requirement, explicit CEX disablement,
  expired-address lockout and one active instruction.
- Unmonitored Jumper wording and copyable Base destination.
- Agent execution attempts return `foreground_approval_required` without
  invoking wallet/provider mutation.

### Device and controlled-mainnet acceptance

Automated tests never spend funds. With explicit user approval and a deliberately
small amount:

1. Install with `adb install -r` and prove the internal Base address persists.
2. Confirm native Gateway remains primary and only its one persistent
   notification is active.
3. Connect an EVM wallet, cancel once, then submit a fresh reviewed LI.FI route;
   observe source hash, terminal status and Base balance refresh.
4. Connect Phantom, cancel once, then perform the same bounded Solana proof.
5. Generate a strict Relay instruction, verify every field, send the exact
   amount from a user-controlled wallet, and observe deposit and Base delivery.
6. Force-stop only after a source hash/deposit detection is persisted; relaunch
   and prove status resumes without signing or sending again.
7. Record redacted explorer/request evidence without full addresses, callbacks,
   signatures, calldata or secrets.

## External Configuration

- Reown project ID supplied at release build time and restricted to Plawie's
  Android package/signing identity.
- Plawie callback scheme or verified app link registered in Android and Reown
  metadata.
- Current Phantom-compatible return handling and installed-wallet queries.
- No API or project identifier is silently replaced with a placeholder.
- Provider capability endpoints and official domains remain pinned and tested;
  any future higher-rate partner credential belongs behind a controlled backend.

## Documentation and Migration

Implementation must update:

- the Base wallet help and security documentation;
- the dynamic provider/x402 roadmap's bridge status;
- release configuration and controlled-mainnet checklist;
- chat capability descriptions for quote/status-only agent access;
- the old external-wallet bridge plan, which must be replaced rather than
  partially combined with this two-strategy design.

The shipped quote-only service remains available behind the estimate and agent
paths until each execution strategy passes device acceptance. Feature gates for
LI.FI execution and Relay deposits are independent, so an outage or rollback in
one strategy does not disable the other, ordinary Base wallet management, BYOK
models, or the native Gateway.

## Acceptance Criteria

- [ ] The generic Jumper button is no longer presented as quote continuation.
- [ ] Connected execution uses a fresh quote bound to the connected account and
      internal Base destination.
- [ ] Every EVM approval is exact and every connected transfer receives both a
      Plawie review and external-wallet confirmation.
- [ ] Phantom callback state, account and transaction are bound and replay-safe.
- [ ] Strict deposit instructions require exact input and a personal refund
      address, and expose only live solver-depositable currencies.
- [ ] Relay deposit mode rejects CEX-originated funding and never creates a
      Plawie-controlled recovery address.
- [ ] Only one non-terminal funding intent can exist; resume never rebroadcasts.
- [ ] Provider status, hashes and Base balance observations—not local intent—
      determine completion.
- [ ] Agent and background paths cannot connect, approve, sign, send, reveal a
      deposit instruction, or retry a transfer.
- [ ] Receipts and logs exclude secrets, raw transaction material and callback
      state.
- [ ] Ethereum, Solana and dynamically supported Robinhood routes have explicit
      capability and failure states.
- [ ] Automated tests spend nothing and controlled mainnet acceptance requires
      explicit user approval.

## Primary References

- [LI.FI route execution](https://docs.li.fi/sdk/execute-routes)
- [LI.FI transaction status and recovery](https://docs.li.fi/agents/workflows/status-recovery)
- [LI.FI widget initialization and URL parameters](https://docs.li.fi/widget/configure-widget)
- [Reown AppKit Flutter installation](https://docs.reown.com/appkit/flutter/core/installation)
- [Reown AppKit Flutter actions](https://docs.reown.com/appkit/flutter/core/actions)
- [Phantom Android universal/deep links](https://docs.phantom.com/phantom-deeplinks/deeplinks-ios-and-android)
- [Phantom sign transaction method](https://docs.phantom.com/phantom-deeplinks/provider-methods/signtransaction)
- [Phantom deprecated sign-and-send method](https://docs.phantom.com/phantom-deeplinks/provider-methods/signandsendtransaction)
- [Relay deposit addresses](https://docs.relay.link/features/deposit-addresses)
- [Relay supported tokens and routes](https://docs.relay.link/references/api/api_resources/supported-routes)
- [Relay deposit-address protocol](https://docs.relay.link/references/protocol/components/deposit-addresses)
- [Venice x402 wallet authentication and top-up](https://docs.venice.ai/guides/integrations/x402-venice-api)
- [BlockRun x402 gateway networks](https://blockrun.ai/docs/x402/endpoints)
- [BlockRun x402 payment flow](https://blockrun.ai/docs/x402/payment-flow)
