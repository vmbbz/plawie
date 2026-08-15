# Crypto Commerce Foundation Status

**Branch:** `codex/crypto-commerce-foundation`
**Date:** 2026-08-15
**Status:** Foundation round; live monetization remains disabled

## Completed in this round

- Replaced the subscription/Stripe strategy with the BYOK and crypto-commission strategy.
- Added the detailed [crypto commerce and AvatarForge implementation plan](CRYPTO_COMMERCE_AND_AVATARFORGE_IMPLEMENTATION_PLAN.md).
- Removed the unused `CryptoCreditsService`, which contained the obsolete OpenRouter/Coinbase/LI.FI prototype flow.
- Updated the dynamic provider/x402 plan so the removed service is not treated as an active architecture surface.

## Existing capabilities preserved

- Venice prepaid top-up remains provider-owned and wallet-approved.
- BlockRun remains per-request x402; it is not represented as a Plawie balance.
- LI.FI remains quote/read-only until external execution and partner fee configuration are independently enabled.
- Android wallet signing remains visible, authenticated, and bounded by the existing payment intent policy.
- AvatarForge remains a local equip experience with a clearly marked future web portal; no mint/rental success is simulated.
- Added `lib/services/commerce_fee_policy.dart` as a pure, integer-safe,
  fail-closed fee calculator. It has no treasury, network, signing, or provider
  integration and therefore cannot collect a fee by itself.
- Added `CommerceReceipt` and `CommerceReceiptStore` as a redacted local
  projection. Existing x402 provider settlements are mirrored into it with a
  zero Plawie fee; local receipts never become proof of platform revenue.
- Added `ProductTelemetryEvent` and `ProductTelemetryRecorder` as a strict,
  consent-aware analytics boundary. It accepts only bounded operational fields
  and rejects prompts, transcripts, wallet data, signatures, credentials, and
  arbitrary payloads.
- Added explicit provider monetization metadata; Venice and BlockRun are both
  currently `none`, so no referral, split, or first-party settlement behavior
  is implied by the catalog.
- Added the non-custodial `AvatarAssetManifest` and `AvatarAssetRecord`
  contracts. Local previews, verified assets, minted assets, rentals, and
  expired rentals are distinct; the preview UI now says minting and rentals
  are planned rather than available.
- Added `CommerceCommissionQuote`, which requires fee schedule timing, asset,
  recipient reference, disclosure, partner cost, expiry, and reconciled net
  received before it can exist. It is not connected to a live payment path.
- Added [the AvatarForge smart-contract stub](AVATARFORGE_SMART_CONTRACT_STUB.md)
  to make the non-live boundary explicit: no chain, contract/program,
  addresses, ABI, minting, renting, or custody code exists yet.

## Deliberately not enabled

- No recurring subscriptions.
- No Stripe integration.
- No hidden provider fee or changed x402 payee.
- No LI.FI integrator fee without a verified partner identity, fee wallet, public schedule, legal review, and reconciliation.
- No AvatarForge mint/rental transaction without a portal, asset/license contract, chain decision, and audited contract/program path.
- No central account requirement for local/BYOK use.
- No telemetry or analytics dependency has been added yet; the next round will
  define a consent-aware, payload-redacted event contract before any provider
  is connected.

## Next implementation gate

The next code round can add disabled-by-default domain models and redacted event contracts. Live commission behavior requires external inputs that cannot be safely invented in source:

- provider referral/split/settlement agreement;
- LI.FI Partner Portal configuration and fee wallet;
- approved fee schedule and destination disclosure;
- South African legal/accounting/compliance review;
- AvatarForge chain, contract/program, metadata, license, creator split, and rental rules;
- production backend and secret configuration.
