# Native Wallet, Bridge, and Wallet-Funded Provider Completion Design

Status: approved architecture; implementation pending

## Goal

Complete the production path from an external source wallet to Base USDC and
then to usable wallet-funded models, while preserving Plawie's native-first
OpenClaw runtime, context, tool loop, and mandatory human approval boundaries.

The completed product flow is:

```text
Phantom / MetaMask / another external source wallet
        -> user reviews and approves an exact LI.FI transaction
        -> Base USDC arrives in Plawie's internal wallet
        -> user approves an exact x402 payment when one is required
        -> Venice or BlockRun models remain inside the OpenClaw agent loop
```

This work does not replace the native OpenClaw gateway, route ordinary chat
around it, or make PRoot primary. PRoot remains an explicitly selected fallback.

## Current Product Truth

| Capability | Current state |
|---|---|
| LI.FI bridge quote | Validates Ethereum, Solana, or Robinhood Chain to Base USDC |
| Bridge execution | Opens the generic Jumper homepage and discards transaction data |
| Venice Base USDC top-up | Implemented with visible approval and Android authentication |
| Venice inference | Not connected to model discovery or the OpenClaw chat transport |
| BlockRun x402 | Catalogued, but not connected to per-request inference |
| OpenRouter crypto top-up | Legacy unused service; not an active product path |
| Phantom / EVM wallet handoff | No direct launch, callback, or connected-wallet session |
| Bridge settlement tracking | No source transaction receipt or LI.FI status polling |
| Base wallet export | Implemented in an authenticated Android-owned dialog |
| Wallet persistence | Designed for app updates, but the observed creation failure is not yet root-caused |

The current quote-only behavior remains safe, but the app must not present it as
an integrated bridge. Venice top-up must not be presented as useful for chat
until Venice inference is routed through the gateway. BlockRun must not appear
ready until the exact per-request payment path is active.

## Non-Negotiable Invariants

### Native OpenClaw remains the orchestration owner

OpenClaw continues to own:

- conversation and session history;
- system prompts and context policy;
- tool definitions and tool-call loops;
- skill execution and node routing;
- model selection and fallback policy.

Wallet-funded providers are exposed to OpenClaw as OpenAI-compatible providers.
The Chat page must not call Venice or BlockRun directly. No provider adapter may
trim, summarize, rebuild, or otherwise alter OpenClaw's messages or tools.

### The internal Base wallet never signs bridge calldata

Bridge transactions originate on Ethereum, Solana, or Robinhood Chain and are
signed by the user's external source wallet. The existing internal Base signer
remains limited to its bounded Base transfer, Venice identity, and x402
interfaces. It must not gain generic `personal_sign`, arbitrary typed-data, or
arbitrary transaction-calldata methods.

### Every blockchain payment has human authorization

- A bridge requires a Plawie review followed by the external wallet's approval.
- A Venice top-up requires an exact Plawie payment review and a fresh Android
  device-authenticated signature.
- Every paid BlockRun inference retry requires approval of the exact 402 amount
  and a fresh Android device-authenticated signature.
- Agent tools may inspect balances, capabilities, quotes, receipts, and status.
  They may not approve, sign, retry a paid request, or broadcast a transaction.
- A chat reply such as `yes` is never payment approval.
- Background activity cannot display an approval surface, so it must pause with
  an actionable `approval_required` result instead of spending.

### No secret bridge or provider credentials ship in the APK

LI.FI public endpoints require no client API key. A LI.FI partner key, if added
later for rate limits, belongs behind a controlled backend and not in Flutter,
Android resources, Dart defines, logs, or release assets.

Reown requires a project ID. It is an application identifier rather than a
wallet private key, but it must be restricted to Plawie's Android application ID
in the Reown dashboard and supplied by release configuration. No placeholder
project ID may silently ship.

## Delivery Boundaries and Order

The implementation is split into four reviewable slices because every later
slice depends on the earlier security contract.

1. Repair and prove wallet creation, loading, recovery, and update persistence.
2. Execute and track external-wallet bridge transactions.
3. Connect Venice and BlockRun to OpenClaw through a payment-aware loopback
   provider proxy.
4. Remove legacy payment paths, align product truth, and complete release proof.

Each slice gets failing tests first, a focused implementation commit, and
verification before the next slice begins.

The detailed executable plans are:

- [Secure wallet reliability](../plans/2026-08-05-secure-wallet-reliability.md)
- [External wallet bridge execution](../plans/2026-08-05-external-wallet-bridge-execution.md)
- [Wallet-funded provider Gateway](../plans/2026-08-05-wallet-funded-provider-gateway.md)
- [Wallet payment release hardening](../plans/2026-08-05-wallet-payment-release-hardening.md)

## 1. Wallet Reliability and Persistence

### Observable wallet states

The Android wallet manager and Dart service must agree on an explicit state
instead of reducing every problem to `exists: false`:

```text
absent
healthy
legacyMigrationRequired
authenticationUnavailable
envelopeCorrupt
keystoreKeyMissing
keystoreKeyInvalidated
orphanedKeystoreAlias
operationBusy
```

Every state has one safe set of actions. In particular, a corrupt envelope or
missing Keystore key must never show the ordinary Create button, because doing
so could overwrite the only recoverable wallet identity.

### Transactional wallet creation

Creation is a transaction:

1. Confirm that no valid envelope, legacy wallet, or unresolved damaged state
   exists.
2. Confirm that a secure lock method supported by the signer is available.
3. Generate the secp256k1 private key in Android memory.
4. Create or obtain the Android Keystore envelope key.
5. Require device authentication.
6. Encrypt the private key and atomically persist the envelope.
7. Read the envelope back, decrypt it through the same auth policy when needed,
   and confirm its derived address.
8. Return success only after the read-back integrity check.

If creation fails before a valid envelope is committed, remove any newly
created orphaned alias and partial atomic-file artifacts. Existing aliases and
envelopes are never deleted by a generic catch block.

### Recovery behavior

- `envelopeCorrupt`: explain that the encrypted record cannot be trusted. Offer
  authenticated removal only behind a destructive recovery warning and require
  the user's backup before replacing the wallet.
- `keystoreKeyMissing` or `keystoreKeyInvalidated`: preserve the envelope for
  diagnostics, explain that decryption is unavailable, and offer restore-from-
  backup or authenticated removal. Never claim that an app update alone can
  repair the key.
- `orphanedKeystoreAlias`: if no committed envelope exists, remove only the
  known Plawie envelope alias and retry creation. This cleanup is safe because
  the alias encrypts no committed wallet record.
- `authenticationUnavailable`: do not create a weaker software credential or
  bypass per-use authentication. Explain the required device-lock change.
- `legacyMigrationRequired`: keep the existing explicit migration and delete
  the historical Flutter secure-storage key only after verified native commit.

### Persistence contract

The wallet envelope remains in app-private `noBackupFilesDir`; its encryption
key remains under the stable Android Keystore alias. A normal signed APK update
with the same application ID and signing identity must preserve both. Clear
data and uninstall intentionally remove the wallet and are never described as
safe update procedures.

The Base page must state:

- app updates preserve the wallet;
- uninstalling or clearing data removes the on-device wallet;
- an exported backup is required for disaster recovery;
- anyone with the exported private key controls the funds.

### Diagnostics

Wallet operations emit redacted structured logs containing operation, state,
security level, envelope presence, and stable error code. They never include a
private key, ciphertext, signature, full signed transaction, auth token, or
secret header.

The observed device failure must be reproduced and its exact state/error code
captured before production wallet code is changed. Candidate failure states in
the source are not treated as a confirmed root cause.

## 2. External-Wallet Bridge Execution

### Separation of planning and execution

`BridgeQuoteService` remains responsible for public discovery and quote
validation. A new execution coordinator owns wallet connection, final quote,
approval, submission, callback handling, status, and receipts.

The chat-accessible `bridge.quote` capability stays read-only. Bridge execution
is initiated only from foreground UI on the Base page. An agent may prepare the
form or explain a quote, but cannot launch a wallet or advance the state machine.

### Bridge state machine

```text
draft
  -> connectingWallet
  -> quoting
  -> awaitingPlawieReview
  -> awaitingExternalWallet
  -> submitted
  -> sourcePending
  -> destinationPending
  -> completed | failed | refunded | partial | expired | cancelled
```

State changes and receipts are persisted so returning from another wallet,
process recreation, or temporary network loss does not lose an in-flight
transfer.

### Connected source wallet is authoritative

The executable flow obtains the source address from the connected external
wallet session. A manually entered address remains acceptable for a read-only
quote, but it cannot be used as the signer identity. Immediately before signing,
Plawie requests a fresh quote using the connected address and the displayed
internal Base destination address.

The final quote must revalidate:

- source and destination chain IDs;
- source and destination addresses;
- source token and native Base USDC contract;
- exact source amount and minimum destination amount;
- slippage bound;
- route tool identity;
- quote freshness;
- transaction chain, sender, target, value, and bounded response size.

The full raw transaction is held only in the foreground execution coordinator
until handoff. It is never stored in logs, agent-readable receipts, or the Base
wallet signer.

### EVM handoff

Reown AppKit supplies wallet selection and WalletConnect-compatible EVM
sessions for Ethereum and Robinhood Chain. The app supports `eth_chainId`,
chain switching, bounded chain addition from trusted shipped metadata, and
`eth_sendTransaction` only for the reviewed LI.FI transaction.

For ERC-20 source assets, allowance and bridge execution are separate reviewed
transactions. Plawie must not request unlimited allowance. It requests the
minimum exact allowance needed by the fresh route, displays the spender and
amount, waits for the approval receipt, refreshes the route if stale, and then
requests the bridge transaction.

Robinhood Chain is available only when both LI.FI runtime discovery and trusted
Robinhood network metadata agree. If the connected wallet cannot add or switch
to it, the UI reports the limitation and retains the quote-only/manual option.

### Solana handoff

Phantom uses its documented Android universal/deep-link session and return flow.
The callback is registered under a Plawie-owned URI scheme or verified app link
and includes an unpredictable state value tied to one pending request.

The coordinator validates the returned Phantom public key as the quoted source
address. The serialized LI.FI Solana transaction is accepted only from the
fresh validated quote, handed to Phantom for user review/signing, and matched to
the pending state on return. Plawie never asks Phantom to reveal a seed or
private key.

If Phantom is unavailable or the route cannot be represented through its
supported transaction method, the app offers a clearly labelled external
Jumper fallback. It must not claim that the route was prefilled or monitored.

### Callback and replay protection

- Android `singleTop` intent handling forwards only allowlisted wallet callback
  URIs to the bridge coordinator.
- Every request has a cryptographically random state, source chain, creation
  time, and one-shot consumed marker.
- Unknown, expired, duplicate, wrong-chain, or wrong-wallet callbacks are
  rejected.
- Relaunching Plawie without a matching pending request never changes bridge
  state.

### LI.FI status and receipts

After obtaining a source transaction hash, poll LI.FI `/status` with the source
and destination chains and route tool. Back off while pending and stop at a
bounded timeout without declaring failure; the receipt remains resumable.

A bridge receipt stores only non-secret operational data:

- local receipt ID and LI.FI quote/route ID;
- source/destination chain and token identifiers;
- source transaction hash and destination transaction hash when available;
- submitted amount and minimum/actual received amount;
- tool, timestamps, status, substatus, and last checked time;
- connected public source address and internal Base destination address.

Completion means LI.FI reports a terminal successful status and the Base USDC
balance refresh succeeds or is explicitly marked pending. A quote ID or wallet
return alone is never completion.

## 3. Wallet-Funded Providers Inside OpenClaw

### Payment-aware loopback provider proxy

Add a dedicated OpenAI-compatible proxy bound only to Android loopback. It is a
separate component from the NDK local-model bridge because it forwards cloud
provider traffic without changing payloads.

```text
Chat UI
  -> native OpenClaw Gateway (context, tools, skills, retries)
  -> loopback paid-provider proxy (auth and payment policy only)
  -> Venice or BlockRun
  -> loopback proxy
  -> OpenClaw Gateway
  -> Chat UI
```

The proxy supports the exact Gateway contracts required by enabled providers:

- `GET /v1/models` with bounded caching and stale/error metadata;
- `POST /v1/chat/completions` including SSE streaming and tool calls;
- `POST /v1/responses` only after contract tests prove the Gateway uses it;
- health/status endpoints for setup and diagnostics.

It forwards messages, tools, tool-choice fields, generation parameters, and
stream events without context trimming or prompt reconstruction. Model IDs may
be mapped from Plawie's namespaced ID to the upstream provider ID, but message
content is invariant.

The proxy requires a random app-private bearer capability from the Gateway so
unrelated apps cannot use the device's loopback port. It allowlists exact HTTPS
upstream hosts, rejects redirects, caps headers/body sizes, applies timeouts,
and redacts payment/auth headers from logs.

### Venice

Venice is a prepaid wallet-identity provider:

1. Discover and cache its current models through the documented endpoint.
2. Keep model IDs under the `venice/` provider namespace in Plawie/OpenClaw.
3. Generate a fresh, narrowly scoped Venice SIWE identity signature for each
   documented paid request as required by Venice.
4. Permit that signer only for exact Venice inference and wallet-read routes;
   do not expose generic message signing.
5. Forward the request with `X-Sign-In-With-X` and stream the response through
   unchanged.
6. Read remaining-balance headers when present and refresh the wallet-linked
   balance after successful calls.

Venice inference consumes a prepaid provider balance and does not create a new
on-chain transaction for every chat request. The user pressing Send while a
Venice model and its wallet-funded label are visible authorizes that interactive
inference. Background or agent-initiated Venice use requires a separately
approved bounded task budget; it cannot silently consume the balance.

The existing Base-page top-up remains a separate exact x402 transaction. After
settlement, refresh Venice balance and transaction history before reporting the
top-up as usable.

### BlockRun

BlockRun is a per-request x402 provider and has no prepaid top-up account:

1. Forward the unchanged inference request without payment.
2. Accept only an HTTP 402 from the exact allowlisted resource.
3. Parse the current x402 v2 challenge and validate network, native Base USDC
   contract, amount, payee, resource, scheme, expiry, and the existing per-call
   cap.
4. Persist a request fingerprint and pending payment intent.
5. Pause the provider request and show the exact foreground approval UI.
6. On approval, require Android device authentication and sign only the exact
   EIP-3009 authorization.
7. Retry the same method, URL, and body exactly once with `PAYMENT-SIGNATURE`.
8. Validate and persist the payment receipt before forwarding the inference
   response.

No blanket allowance, session key, standing budget, or automatic payment
wrapper is enabled in the first release. An OpenClaw tool loop may cause more
than one paid model call; every distinct BlockRun 402 payment receives its own
approval. Cancellation leaves the agent turn in an actionable payment-cancelled
state and does not retry.

### Provider discovery, setup, and selection

Venice and BlockRun join the same dynamic model catalog used by existing cloud
providers. Their models come from current endpoints with a safe shipped fallback
only for offline explanation; stale fallback records are not treated as live
availability.

First setup keeps two visibly different paths:

- BYOK provider: enter and validate the provider's API key.
- Wallet-funded provider: no API-key field; explain Base Mainnet, ETH gas, USDC,
  wallet creation/funding, and payment approval requirements.

Selecting a wallet-funded provider during first setup records the choice but
does not create a wallet, bridge funds, top up Venice, or approve a BlockRun
payment. Setup completes into a clear Base-page funding action and model
readiness state.

The model picker and Settings use the existing grouped/searchable UI and add:

- wallet-funded/provider-payment badges;
- current or stale catalog state;
- current provider balance where the provider exposes one;
- `Fund wallet`, `Top up`, `Manage`, or `Payment per request` actions;
- honest disabled reasons when the wallet, balance, Reown configuration, or
  payment proxy is unavailable.

### Context and tool compatibility contract

For the same conversation and model capability, changing from a BYOK provider
to Venice or BlockRun may change only:

- provider/model identifier;
- provider endpoint and authentication/payment headers;
- provider-specific generation fields proven necessary by contract tests.

It may not change conversation history, system prompts, tool schemas, tool
results, session IDs, compaction behavior, or native skill routing. Tests compare
the proxy's decoded upstream body against the Gateway request and require
semantic equality aside from the allowlisted model mapping.

## 4. Product Surfaces and Approval Matrix

| Surface/action | Approval and signer |
|---|---|
| Read-only bridge quote | No payment approval; no signer |
| Execute EVM bridge | Plawie final review, then external EVM wallet approval |
| Execute Solana bridge | Plawie final review, then Phantom approval |
| Ordinary Base transfer | Existing Plawie review and Android authentication |
| Venice top-up | Exact Plawie x402 review and Android authentication |
| Interactive Venice inference | User Send action; prepaid balance debit, no new chain transaction |
| Background Venice inference | Explicit bounded task approval or stop |
| BlockRun inference | Exact 402 review and Android authentication for every paid call |
| Agent payment/bridge tools | Read-only capabilities, quote, balance, status, and receipts |

The Base page is the canonical funding and payment-management surface. Chat can
open the same approval or funding panel when a selected model requires action,
but it does not implement a second payment flow. Settings links to the canonical
Base/provider panel.

## 5. Persistence and Idempotency

Wallet, bridge, provider-payment, and provider-balance state use separate
records with stable schema versions.

- Wallet envelope: Android `AtomicFile` plus Android Keystore alias.
- Bridge intents/receipts: app-private persistent store, keyed by local receipt
  ID and source transaction hash.
- x402 intents/receipts: existing payment store extended with request body hash,
  upstream resource, challenge fingerprint, and consumed retry marker.
- Dynamic catalogs: bounded cached snapshots with refresh timestamp and stale
  status.
- Provider balances: short-lived cached observations, never an accounting
  ledger invented by Plawie.

Retries are safe:

- wallet creation resumes or reports a specific damaged state;
- a consumed wallet callback cannot submit twice;
- LI.FI status polling never rebroadcasts;
- a settled x402 receipt is returned instead of signing the same intent again;
- network failure after a paid retry enters receipt-recovery, not blind replay.

## 6. Error Handling and User Language

Errors identify the failed boundary and the next safe action:

- `Wallet record damaged — restore or remove it before creating another.`
- `External wallet connection expired — reconnect and request a fresh quote.`
- `Quote expired — no transaction was sent.`
- `Transaction submitted; destination confirmation is still pending.`
- `Provider requires 0.00xxxx USDC — approval was not granted.`
- `Payment may have settled but the model response was interrupted — checking
  the receipt before retrying.`

The app never reports `ready`, `funded`, `paid`, `bridged`, or `completed` based
only on local intent. Every claim is tied to an appropriate status, receipt,
balance observation, or provider response.

## 7. Tests and Proof

### Wallet tests

- JVM tests for absent, healthy, corrupt, missing-key, invalidated-key, orphaned
  alias, busy operation, and transactional rollback states.
- Dart tests for state mapping and Base-page action availability.
- Device proof for create, export, app restart, signed APK update, import,
  transaction approval cancellation, and recovery copy.
- Explicit proof that clear data/uninstall is destructive and never used as an
  update-persistence test.

### Bridge tests

- Quote validation tests remain intact.
- Contract tests for exact transaction chain, sender, recipient, token, amount,
  slippage, expiry, and size validation.
- EVM tests for connection, chain mismatch, exact allowance, rejection,
  submission, and duplicate callback.
- Solana tests for preserved case-sensitive addresses, callback state,
  transaction handoff, rejection, and malformed payloads.
- LI.FI status tests for pending, done, failed, refunded, partial, timeout, and
  process-resume behavior.
- Widget tests for review copy, multiple-transaction ERC-20 flow, cancellation,
  and manual fallback honesty.

### Provider tests

- Dynamic Venice and BlockRun model parsing, cache, stale, and availability.
- Byte/semantic equality tests proving the proxy preserves Gateway messages and
  tools.
- SSE passthrough, tool-call response, cancellation, timeout, and oversized
  response tests.
- Venice SIWE scope, endpoint allowlist, balance refresh, and top-up/inference
  separation.
- BlockRun no-payment request, exact 402 validation, approval cancellation,
  single paid retry, receipt recovery, replay rejection, and cap enforcement.
- Setup, Settings, model-picker, and Base-page widget tests.

### Live acceptance

No automated test spends mainnet funds. A controlled live test uses an amount
chosen and approved by the user:

1. Create or load the Base wallet and record the public address.
2. Prove persistence across an APK update without clearing data.
3. Connect an external wallet and bridge a deliberately small amount.
4. Observe the source hash, LI.FI terminal status, and Base balance refresh.
5. Top up Venice with an explicitly approved small amount and complete a model
   response through OpenClaw tools.
6. Complete one explicitly approved BlockRun call and verify its receipt.
7. Switch back to a BYOK model and prove the same conversation/tool session
   remains intact.

## 8. Rollout and Rollback

Independent feature switches control:

- executable external-wallet bridge handoff;
- Venice wallet-authenticated inference;
- BlockRun per-request x402 inference;
- live mainnet signing.

Disabling one switch leaves read-only quotes, wallet management, BYOK providers,
and the native Gateway available. A provider outage cannot disable the wallet or
ordinary chat. A bridge outage falls back to an honestly labelled external
manual flow.

The legacy `CryptoCreditsService` is removed only after repository-wide usage
checks, replacement tests, and documentation migration prove that no live UI,
setup, capability, or receipt reader depends on it.

## 9. Required External Configuration

Production EVM wallet selection requires:

- a Reown project ID supplied through the release build environment;
- the Android package/application ID allowlisted in Reown Cloud;
- Plawie's callback scheme or verified link registered in Android and in Reown
  metadata;
- release signing identity and application ID kept stable across updates.

LI.FI public API integration needs no key. Phantom direct handoff needs no Plawie
custody credential. Venice and BlockRun wallet-funded modes need no user API key.

## 10. Documentation Changes

Implementation updates:

- `DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md` to supersede the
  quote-only Phase 10 execution boundary and record completed phases;
- `MODEL_PROVIDER_AND_HELP_ROADMAP.md` to include Venice and BlockRun only when
  their live Gateway transports pass;
- first-setup, Base-page, payment-security, wallet-backup, and recovery help;
- release notes stating wallet persistence requirements and controlled mainnet
  payment behavior.

## Acceptance Checklist

- [ ] The observed wallet creation failure has a reproduced root cause.
- [ ] Wallet create/import/load/export/recovery states are explicit and tested.
- [ ] Wallet survives a normal APK update with the same package/signing identity.
- [ ] The Base page clearly warns about clear-data/uninstall destruction.
- [ ] Ethereum bridge execution launches a connected EVM wallet with a fresh,
      exact, validated LI.FI transaction.
- [ ] Robinhood execution is gated by both trusted metadata and live LI.FI
      support.
- [ ] Solana execution launches Phantom with a state-bound callback.
- [ ] ERC-20 bridge allowance is exact rather than unlimited.
- [ ] Callback replay, wrong-wallet, wrong-chain, and expired-route cases fail
      without broadcast.
- [ ] LI.FI status and resumable receipts distinguish pending, done, failed,
      refunded, and partial outcomes.
- [ ] Base USDC refresh follows successful bridge settlement.
- [ ] Venice models load dynamically and are selectable in setup, Settings, and
      Chat without an API-key field.
- [ ] Venice chat runs through OpenClaw with wallet SIWE and preserves tools and
      context.
- [ ] Venice top-up refreshes balance and transaction history after settlement.
- [ ] BlockRun models load dynamically and are selectable without an API key.
- [ ] Every BlockRun paid request validates a live 402, asks exact approval,
      authenticates, signs, retries once, and stores a receipt.
- [ ] Background/agent paths cannot approve or spend.
- [ ] Provider balances and readiness are refreshed after settlement.
- [ ] OpenClaw context, tools, skills, and native runtime behavior are invariant.
- [ ] The unused OpenRouter/Coinbase crypto-credit service is removed or
      quarantined with no active references.
- [ ] No LI.FI secret or placeholder Reown project ID is embedded in the APK.
- [ ] Unit, widget, Android, integration, and controlled live acceptance evidence
      is recorded before production release.

## References

- [LI.FI API overview](https://docs.li.fi/api-reference/introduction)
- [LI.FI endpoint specifications](https://docs.li.fi/agents/reference/endpoint-specs)
- [LI.FI transaction execution](https://docs.li.fi/agents/workflows/execution)
- [Reown AppKit Flutter installation](https://docs.reown.com/appkit/flutter/core/installation)
- [Phantom Android deeplinks](https://docs.phantom.com/phantom-deeplinks/deeplinks-ios-and-android)
- [Venice x402 integration](https://docs.venice.ai/guides/integrations/x402-venice-api)
- [Venice chat completions](https://docs.venice.ai/api-reference/endpoint/chat/completions)
- [BlockRun x402 endpoints](https://blockrun.ai/docs/x402/endpoints)
- [BlockRun chat completions](https://blockrun.ai/docs/api-reference/chat-completions)
