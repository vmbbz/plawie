# Crypto Commerce and AvatarForge Implementation Plan

**Status:** Implementation design; live fees remain disabled
**Date:** 2026-08-15
**Scope:** Plawie Android app, optional account/receipt backend, LI.FI bridge commission, provider top-up attribution, and later AvatarForge commerce

## Current implementation audit

### Payment/provider surfaces

The active product path is already safer than the older prototype:

- `lib/services/ai_payment_provider_catalog.dart` defines Venice prepaid balance and BlockRun per-request x402 semantics.
- `lib/services/x402_payment_transport_service.dart` validates HTTPS hosts, binds the request, requires visible approval, delegates signing to Android, retries once, and stores redacted receipts.
- `lib/services/provider_balance_service.dart` reads provider balance observations; it does not create a universal Plawie balance.
- `lib/services/bridge_quote_service.dart` validates LI.FI chains, token metadata, addresses, amounts, route identity, and minimum destination amount.
- `lib/screens/base_screen.dart` is the canonical visible surface for wallet, provider, quote, approval, and receipt state.
- `lib/services/crypto_credits_service.dart` is a legacy unused OpenRouter/Coinbase/LI.FI prototype and is not a valid foundation for the new commerce model.

### Avatar surfaces

- `lib/screens/avatar_forge_page.dart` currently equips a local `gemini.vrm` asset.
- Its web portal card is marked `SOON`; the button currently shows a snackbar rather than opening a live portal.
- The app has VRM download/equip infrastructure, but does not yet prove token ownership, creator licensing, minting, rental, escrow, or expiry.
- `lib/services/capabilities/avatar_capability.dart` handles avatar behavior/gestures, not NFT commerce.

## Gate model

Every monetization lane has independent gates:

| Lane | Read-only state | User approval | Live revenue gate |
|---|---|---|---|
| LLM provider | catalog, model, balance/402 observation | exact provider payment | provider agreement or referral attribution |
| Bridge | route/fee quote | external wallet transaction | LI.FI partner identity, fee wallet, legal approval, reconciliation |
| Avatar mint | asset preview, manifest, license | creator wallet mint | audited contract/program, metadata, split, support |
| Avatar rental | listing preview, terms, expiry | renter/owner contract action | escrow/delegation design, rights, expiry enforcement, dispute policy |

Read-only states can ship before live gates. A feature flag must not make an unconfigured fee wallet, treasury, contract, or provider agreement look live.

## Phase 1 — remove the legacy credit path

### Objective

Ensure the app cannot accidentally route users toward OpenRouter crypto credits, Coinbase charges, fallback token prices, or an unreviewed direct LI.FI transaction path.

### Work

1. Confirm `CryptoCreditsService` has no imports or runtime construction.
2. Remove it or move it to a clearly quarantined historical directory; do not leave it discoverable as an active service.
3. Add a test/search check that the active payment surface contains no OpenRouter crypto top-up or Coinbase charge call.
4. Keep OpenRouter as a normal BYOK/API-key provider only where the current provider contract supports it.
5. Update docs and UI copy so Venice owns prepaid top-up and BlockRun owns per-request x402.

### Exit criteria

- `rg` finds no active import of `CryptoCreditsService`.
- `flutter analyze` and the payment-focused tests pass.
- No APK asset or UI route contains a Coinbase charge implementation.
- Existing wallet/x402 receipts remain readable.

## Phase 2 — transaction and commission domain

The first local foundation now exists: `commerce_fee_policy.dart` performs
integer-safe, fail-closed fee arithmetic, and `commerce_receipt.dart` projects
redacted provider settlements without treating them as Plawie revenue. The
remaining commission quote, partner settlement, and reconciliation adapters
stay disabled until their external contracts exist.

### Domain types

Create a small domain layer independent of Flutter widgets:

- `CommerceLane`: `providerTopUp`, `bridge`, `avatarMint`, `avatarRental`;
- `CommerceStatus`: `quoted`, `approvalRequired`, `submitted`, `settled`, `failed`, `uncertain`, `refunded`, `reconciled`;
- `FeeSchedule`: version, lane, percentage BPS, flat amount, min/max, token, effective time, recipient reference, disclosure text, enabled flag;
- `CommissionQuote`: gross amount, partner/network costs, Plawie commission, expected destination, expiry, fee schedule version;
- `CommerceReceipt`: stable operation ID, provider/route/token IDs, transaction hashes, amounts, status, timestamps, and redacted error code;
- `AvatarAssetState`: `local`, `unverified`, `verified`, `minted`, `rented`, `expired`.

Do not put a private treasury address or secret in this domain model. The live configuration must arrive only from a verified release/backend configuration path and must be rejected if incomplete.

### Fee arithmetic

Use integer token units and decimal-safe arithmetic. Never calculate a fee through binary floating point when constructing a transaction.

For a percentage fee:

```text
commission_units = floor(gross_units × fee_bps / 10_000)
commission_units = clamp(commission_units, minimum_units, maximum_units)
```

The quote must show:

- gross user amount;
- provider/bridge/network cost;
- Plawie commission;
- expected minimum received or provider credit;
- fee token and recipient semantics;
- fee schedule version and expiry.

The user must approve the exact final transaction that corresponds to the displayed quote.

## Phase 3 — provider top-up commissions

### Why this requires a partner path

Venice’s current top-up flow returns a payment challenge. The challenge contains an exact recipient, amount, resource, and expiry. Changing the recipient or amount locally would invalidate the provider contract and violate the approval binding.

Therefore Plawie may only earn from a provider top-up through:

- provider referral/affiliate attribution;
- provider-supplied platform split;
- an explicitly documented provider merchant endpoint;
- a separate Plawie fee payment that the provider and legal review approve.

The initial implementation should support `monetizationMode: none` and `monetizationMode: referral` without changing payment bytes. `provider_split` and `first_party_settlement` remain disabled until signed agreements and security review exist.

### Work

1. Add provider capability metadata for monetization mode and attribution support.
2. Keep the x402 challenge/payee immutable in the pending intent.
3. Add a redacted attribution field to the provider request only if the provider documents it and the field cannot alter the payment recipient.
4. Capture provider receipt/request/transaction IDs.
5. Reconcile commission from provider reports or a signed partner API, not from the local device receipt.
6. Expose “Provider charge” and “Plawie commission” separately only when the provider integration supplies both.

### Tests

- a local fee setting cannot change x402 `payTo`, amount, asset, resource, nonce, or expiry;
- unknown monetization mode is treated as `none`;
- a provider referral field cannot be sent to a host outside the provider allowlist;
- a provider-confirmed payment remains settled even if local receipt persistence fails;
- duplicate provider callbacks do not duplicate commission records.

## Phase 4 — LI.FI bridge commission

### Partner setup required

Before code enables the fee:

1. Create the LI.FI Partner Portal integration.
2. Obtain the approved integrator string/API configuration.
3. Configure the fee-collection wallet and document its ownership/control.
4. Confirm supported source chains/tokens and fee behavior.
5. Define the public BPS schedule and maximum fee.
6. Complete South African legal/accounting review.

LI.FI documents the `integrator` and `fee` quote parameters and describes fee forwarding/collection. See [LI.FI monetization](https://docs.li.fi/introduction/integrating-lifi/monetizing-integration) and [requesting a quote](https://docs.li.fi/li.fi-api/requesting-a-quote).

### Client/backend split

- The app can request read-only quotes.
- A server-owned or signed configuration supplies the active fee schedule and integrator identity.
- The app refuses a fee-enabled quote if schedule version, integrator identity, or recipient disclosure is missing.
- The external wallet signs the user’s exact bridge transaction.
- A reconciliation service polls LI.FI status and verifies source/destination hashes and fee records.

Do not expose a LI.FI API key in the APK. If higher-rate API access is required, proxy it through a narrow backend endpoint with rate limits and no arbitrary URL forwarding.

### Quote acceptance contract

Reject a fee-enabled quote unless all of these match:

- source chain and source wallet;
- destination chain and Plawie destination wallet;
- source token and destination token;
- gross amount and minimum received;
- integrator string and fee schedule version;
- expected fee token and fee amount;
- route expiry and quote ID;
- no unexpected destination call or arbitrary calldata.

## Phase 5 — AvatarForge commerce

The local foundation now validates canonical asset manifests and rental expiry
semantics without connecting to a chain, wallet, portal, or marketplace. The
Android preview remains equip-only and does not claim ownership or rental
rights.

### Asset contract

Define a canonical avatar package before minting:

- VRM/glTF model and animation manifest;
- deterministic asset hash;
- thumbnail/preview hash;
- creator identity and license URL;
- supported runtime version;
- safety scan result;
- permitted app actions and external resources;
- chain/network/token metadata when minted;
- rental rights and expiry behavior.

The Android app must validate the manifest and hash before equipping. A token is not sufficient proof that a downloaded file is safe or compatible.

### Minting

The first mint lane should be non-custodial:

1. Creator uploads and validates the asset in the web portal.
2. Portal shows license, creator split, platform commission, network cost, and final mint target.
3. Creator connects an external wallet.
4. Creator signs the exact mint transaction.
5. Backend observes confirmation and records token/asset ID, transaction, hashes, and split.
6. Android resolves a verified asset record and downloads the permitted package.

Do not mint from the Android app until the web flow, asset storage, contract/program, and recovery/support path are reliable.

### Renting

“Renting” needs a precise technical meaning before code:

- time-bound license only;
- escrowed token rental;
- delegated use rights;
- marketplace listing with off-chain license;
- or another reviewed model.

The contract and app must enforce:

- start/end time;
- permitted user/workspace;
- whether the renter can export or only equip;
- whether cached assets remain usable after expiry;
- revocation, refund, dispute, and creator takedown;
- creator/platform/network fee split.

The app state machine must distinguish `rented` from `owned`, and `expired` from `deleted`. An expired rental must not silently remain an active companion entitlement.

### Current UI change boundary

Keep the existing AvatarForge card marked `SOON` until the portal is live. When ready, replace the snackbar-only button with a verified HTTPS deep link and a return/callback flow that revalidates the asset record. Do not fake a mint/rental success state in the Android UI.

## Phase 6 — optional account and analytics foundation

Accounts exist for receipts, creator profiles, optional sync, and support—not for local use.

Minimum backend tables:

- profiles;
- devices;
- provider receipts;
- bridge receipts;
- commission intents and settlements;
- avatar assets, mints, listings, rentals;
- deletion requests.

Every table exposed to a client has RLS policies. Service-role operations run only in Edge Functions or a private service. Analytics identity is merged only after consent and signup; anonymous local use can remain untracked.

## Phase 7 — operational finance and reporting

Daily reconciliation should compare:

- provider settlement reports versus provider receipts;
- LI.FI route/status/fee records versus bridge receipts;
- chain indexer observations versus mint/rental records;
- expected commission versus realized commission;
- refunds/disputes versus ledger status.

The finance export should contain no prompts, transcripts, private keys, or raw signatures. It should be sufficient to calculate:

- gross provider/bridge/avatar volume;
- partner/creator/network share;
- expected commission;
- realized commission;
- refunds/disputes;
- net commission and operating cost;
- release/version/channel attribution.

## External inputs that block live implementation

The following cannot be invented locally:

- provider commission/referral agreement and settlement API;
- LI.FI Partner Portal integrator identity and fee wallet;
- fee BPS/minimum/maximum schedule;
- South African legal/accounting/compliance decision;
- AvatarForge portal ownership and API contract;
- canonical chain(s), contract/program addresses, and audit evidence;
- creator/renter license and dispute policy;
- production backend project and secrets.

Until these exist, implementation should remain in read-only, testnet, sandbox, or disabled-flag form. The code should make missing configuration visible rather than substituting a placeholder treasury or claiming revenue.

## Definition of done

The commission system is ready for a controlled production release only when:

- the user sees every charge and commission before signing;
- the client cannot alter payee, amount, route, contract, or fee schedule after approval;
- local/BYOK use works without signup;
- provider, bridge, mint, and rental states are independently modeled;
- receipts are redacted, idempotent, and recoverable;
- backend reconciliation proves realized settlements;
- account deletion/export behavior is tested;
- RLS and webhook/authentication tests pass;
- South African legal/accounting/compliance gates are recorded;
- support can explain failed, uncertain, refunded, expired, or disputed transactions;
- the release and Product Hunt copy describe only capabilities that are actually live.
