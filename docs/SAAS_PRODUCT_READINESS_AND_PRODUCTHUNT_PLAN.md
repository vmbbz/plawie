# Plawie Product Readiness, Crypto Commerce, and Product Hunt Plan

**Status:** Guest-first Android and landing-site measurement foundations implemented; production analytics activation and dashboards remain gated
**Date:** 2026-08-16
**Product:** Plawie, the local-first Android companion and OpenClaw control surface

## Executive decision

Plawie is not a subscription SaaS. It is a local-first BYOK and crypto-provider product with optional account services and transaction-based revenue.

Users should be able to run local voice, local Gateway features, and BYOK providers without creating a Plawie account. Plawie earns revenue only when it adds measurable value to a transaction and the user sees the fee before approval.

Product analytics is required for launch learning and defensible product metrics, but product identity is not. Plawie will measure consented anonymous installations and sessions before it introduces optional accounts. The primary first-run action remains local setup, not signup. An account becomes appropriate only when it provides durable value such as cross-device sync, recoverable receipts, creator identity, marketplace participation, or support continuity.

The intended revenue lanes are:

1. Commission or referral revenue on supported crypto-funded LLM credit top-ups, only where the provider contract or referral program explicitly allows it.
2. A transparent bridge/integrator fee on supported LI.FI routes, after partner onboarding, fee-wallet configuration, compliance review, and route-level testing.
3. Later AvatarForge marketplace revenue from 3D companion minting and renting: creator/platform splits, mint fees, rental commissions, and optional asset services.

There is no recurring Pro/Team subscription in this plan. There is no Stripe integration in the product architecture. Any future payment provider would need an explicit decision and would not be assumed by the implementation.

## South Africa payment decision

Stripe is removed from the plan. Stripe’s current global page lists South Africa under an “Extended network” category, but eligibility, onboarding, settlement, and product availability are not the same as a guaranteed self-serve account. Stripe also states that opening an account in another country requires a legal entity, tax ID, physical location, phone number, government ID, and physical bank account in that country. See [Stripe global availability](https://stripe.com/global) and [Stripe’s cross-country account requirements](https://support.stripe.com/questions/requirements-to-open-a-stripe-account-in-another-country).

We will not build a business model around that uncertainty. Plawie’s first commercial model is crypto-native and non-recurring. The company still needs South African accounting, tax, financial-crime, consumer-protection, and crypto-asset legal advice before charging commissions or operating a marketplace. This document is an engineering/product plan, not legal advice.

South African launch gates must include a direct review of:

- whether the exact top-up, routing, commission, marketplace, rental, and minting activities make Plawie a Crypto Asset Service Provider or another regulated intermediary;
- whether the business needs an FSCA licence, a licensed partner, or a different operating model;
- FIC/KYC/AML obligations and suspicious-transaction controls;
- VAT/income-tax treatment, crypto-asset reporting, transaction records, and creator payouts;
- consumer disclosures, refunds, disputes, custody, wallet recovery, and cross-border services.

The FSCA says crypto-asset service providers must obtain a licence to conduct business; SARS separately describes reporting obligations for providers facilitating crypto-asset transactions. Review the [FSCA CASP guidance](https://www.fsca.co.za/New-Financial-Service-Provider/), [FSCA authorised-provider resources](https://www.fsca.co.za/Regulated-Entities/), and [SARS Crypto-Asset Reporting Framework](https://www.sars.gov.za/businesses-and-employers/third-party-data/crypto-asset-reporting-framework-carf/) before enabling commercial fees.

## Product boundary

### Free and account-optional

No account is required for:

- local chat and local voice;
- on-device models;
- BYOK model providers;
- local wake word, PiP, foreground voice, and TTS;
- local avatar equip and local VRM assets;
- inspecting local health and bounded logs;
- downloading public Android previews.

An account may be introduced for durable services, but not as a gate in front of local usefulness:

- cross-device avatar/library sync, if explicitly enabled;
- user-submitted support diagnostics;
- creator profiles and AvatarForge listings;
- transaction receipts and commission statements;
- future hosted services, if we ever add them without changing the core promise.

The launch UI must use a guest-first hierarchy:

1. `Continue locally` or the equivalent setup action is primary.
2. Anonymous product analytics is a separate, optional choice with plain-language exclusions.
3. `Create account` is introduced only beside a feature that needs durable identity.
4. Wallet connection is not treated as a Plawie account and is never silently correlated with analytics identity.

### Revenue without subscriptions

The product must distinguish these four financial concepts:

| Concept | Meaning | Counts as Plawie revenue? |
|---|---|---|
| Provider/user spend | USDC or other crypto paid to an LLM provider | No; it is user/provider volume |
| Bridge volume | Assets routed through an external bridge | No; it is gross transaction volume |
| Plawie commission | Contractual/referral/integrator amount attributable to Plawie | Yes, subject to accounting/tax treatment |
| Pass-through/network/partner cost | LI.FI, bridge, gas, facilitator, creator, or settlement share | No; subtract or report separately |

The dashboard must report gross volume, partner share, network cost, refunds/disputes, and net commission separately. We must never present provider spend or bridged principal as Plawie revenue.

## Recommended stack

| Capability | First choice | Boundary |
|---|---|---|
| Optional identity and account recovery | Supabase Auth + Postgres + Edge Functions | Use for accounts, creator profiles, receipts, and consent; never make local mode depend on it |
| Product analytics | First-party bounded adapter to the PostHog Capture API | Person profiles, autocapture, session replay, and broad SDK collection remain disabled; only explicit redacted events are sent |
| Bridge commission | LI.FI Partner Portal/API integrator fee | Requires an approved integrator identity, fee wallet, fee policy, and route reconciliation |
| LLM top-up commission | Provider-specific referral/partner/settlement integration | Do not alter a direct x402 challenge or add a hidden payee |
| Avatar mint/rental commerce | AvatarForge-owned web/API and audited on-chain contracts | External wallet signing first; no app-held marketplace custody |
| Error/incident triage | Existing bounded logs, then evaluate Sentry | Keep product analytics and sensitive diagnostics separate |

Supabase Auth integrates with Postgres RLS; its documentation requires protecting user tables and using server-side authorization. See [Supabase Auth](https://supabase.com/docs/guides/auth), [user data](https://supabase.com/docs/guides/auth/managing-user-data), and [API security](https://supabase.com/docs/guides/api/securing-your-api).

PostHog's public Capture API accepts explicit events and supports anonymous capture with person-profile processing disabled. Plawie's first integration uses that narrow API through the existing HTTP dependency rather than enabling SDK autocapture. See [PostHog Capture API](https://posthog.com/docs/api/capture). A future SDK migration must preserve the same consent and allowlist boundaries.

LI.FI documents an integrator `fee` parameter and configured fee wallet for monetizing supported routes. Fees are taken from the sending asset and collected through LI.FI’s partner flow; this requires LI.FI onboarding and a verified integration. See [LI.FI monetization](https://docs.li.fi/introduction/integrating-lifi/monetizing-integration), [quote parameters](https://docs.li.fi/li.fi-api/requesting-a-quote), and [FeeForwarder](https://docs.li.fi/introduction/integrating-lifi/fee-forwarder).

## Architecture and authority

```text
Landing site ── consented campaign attribution ──┐
Flutter app ── optional account/session ──────────┤
                                                ├── PostHog: redacted product events
Provider/bridge callbacks ── verified API ────────┤
                                                └── Supabase: identity, receipts,
                                                    commission ledger, creator/rental state

User wallet ── explicit external or Android-authenticated approval ── provider/bridge
AvatarForge ── creator wallet + audited contracts + signed asset delivery ── Plawie app
```

### Source-of-truth rules

- Supabase owns Plawie users, creator profiles, optional workspaces, device links, consent state, receipt references, and commission-ledger records.
- The provider owns LLM balance and settlement facts. Plawie records a redacted reference and any contractual commission event; it does not invent a universal provider balance.
- LI.FI owns route/fee/settlement facts for LI.FI integrations. Plawie reconciles the route ID, transaction hashes, fee token, fee amount, and partner payout status.
- AvatarForge contracts and storage own token ownership, mint state, rental state, and creator/platform split facts.
- PostHog owns behavioral analytics, not payment truth, access control, ownership, or balances.
- The client may prepare a quote and show a review. It cannot silently add a fee, choose a new payee, create a provider account, sign, or broadcast.
- No private key, API key, provider credential, x402 signature, or LI.FI secret is placed in the APK or website JavaScript.

## Financial data model

The first ledger is transaction-based, not subscription-based.

| Record | Purpose |
|---|---|
| `users` / `profiles` | Optional account identity and consent |
| `devices` | Random installation ID, platform, release, and last-seen health |
| `provider_connections` | Provider ID, redacted account identity, capability state |
| `provider_payment_receipts` | x402/top-up request ID, provider, asset, amount, payee, status, tx reference |
| `bridge_quotes` | Route ID, source/destination, token, gross amount, fee policy, expiry |
| `bridge_transactions` | Source hash, destination hash, route status, fee token/amount, reconciliation state |
| `commission_intents` | Product lane, quote/receipt reference, fee schedule version, expected commission |
| `commission_settlements` | Actual partner/platform settlement, currency/token, payout reference, status |
| `fee_schedules` | Effective-dated public fee policy, BPS/percentage, minimums, caps, destination wallet reference |
| `avatar_assets` | Canonical VRM/glTF metadata hash, preview, creator, license, chain/network |
| `avatar_mints` | Mint transaction, token/asset ID, creator split, platform commission, status |
| `avatar_rentals` | Listing, renter, owner, terms, duration, escrow/contract reference, platform fee |
| `deletion_requests` | Account/data deletion state and retained legal/financial records |

Every financial record needs a provider/chain event ID, an idempotency key, `created_at`, `observed_at`, `effective_at`, `status`, and a reconciliation state. Keep expected commission and realized commission separate.

### No raw sensitive content

Never send these to PostHog or generic logs:

- audio, transcripts, prompts, model responses, screenshots, attachments, or tool results;
- private keys, recovery phrases, wallet backups, auth headers, provider keys, pairing tokens, or payment signatures;
- full wallet addresses unless a reviewed operational need exists;
- raw Gateway logs or NFT metadata containing personal information.

Use bounded operation codes, release versions, route IDs, public transaction hashes where necessary, and redacted correlation IDs.

## Revenue lane A — crypto LLM credit top-ups

### What is already true

The current app has a provider catalog with explicit semantics:

- Venice is represented as a prepaid wallet-linked provider with a top-up endpoint and balance endpoint.
- BlockRun is represented as a per-request x402 provider and does not use a Plawie top-up balance.
- The active payment transport validates provider hosts, binds the payment to the exact request, requires visible approval, asks Android to authenticate, performs one signed retry, and stores a redacted receipt.
- `lib/services/crypto_credits_service.dart` is a legacy unused OpenRouter/LI.FI/Coinbase path and must remain quarantined or be removed after import/build verification.

### Commission constraint

If a provider returns a direct x402 challenge whose payee is the provider, Plawie cannot secretly insert its own fee. A commission requires one of:

1. a provider referral/affiliate agreement that attributes settled volume to Plawie;
2. a provider API that explicitly supports a platform/partner fee or split;
3. a Plawie-operated merchant/settlement flow that has been legally and operationally approved;
4. a separate, clearly disclosed Plawie service fee paid to an approved recipient.

Until one of these is signed and tested, the app must show the provider’s exact amount and payee and record no fictional Plawie revenue.

### Required implementation

- Add a provider-specific `monetization` capability: `none`, `referral`, `provider_split`, or `first_party_settlement`.
- Show “Provider charge” and “Plawie commission” as separate lines only when the provider contract and signed fee schedule support both.
- Bind the commission schedule version to the payment intent; changing the schedule invalidates the pending intent.
- Record provider request ID, payment intent ID, tx hash, gross amount, partner share, expected commission, and settlement state.
- Reconcile from provider/chain evidence. A local receipt is not proof of revenue.

## Revenue lane B — bridging fee

### Current boundary

The app currently uses LI.FI for read-only quote discovery and hands execution to the user’s external source wallet. This is the correct safety boundary until external wallet execution is fully proven.

### LI.FI monetization path

After LI.FI partner onboarding:

1. Configure the Plawie integrator identity and fee wallet in the LI.FI Partner Portal.
2. Define a public fee schedule with a maximum percentage, minimum/maximum fee, supported chains/tokens, and effective date.
3. Add the integrator and fee parameters to quote requests through a server-owned or signed configuration path.
4. Display gross amount, network/bridge costs, Plawie fee, minimum received, destination, route, expiry, and fee recipient semantics before the user leaves for wallet approval.
5. Preserve `allowDestinationCall=false` unless a separately reviewed destination-call path is required.
6. Record quote ID, integrator, fee schedule version, source hash, destination hash, route status, fee token/amount, and reconciliation status.
7. Test route failures, expiry, partial execution, refunds, duplicate callbacks, and chain/token mismatch.

The app must not embed a LI.FI API key. LI.FI’s docs explicitly warn against exposing API keys in client-side environments.

## Revenue lane C — AvatarForge minting and rental

AvatarForge is a later commerce product, not a current claim that the Android screen already supports minting or rentals.

### Product stages

1. **Local identity stage:** import/download a VRM or glTF asset, validate its manifest/hash, equip it, and keep it usable offline.
2. **Creator stage:** web portal creates an avatar, validates the asset, stores canonical metadata and licensing terms, and lets the creator connect an external wallet.
3. **Mint stage:** creator signs an explicit mint transaction; token ownership and creator/platform fee split are visible before signing.
4. **Marketplace stage:** a user can list an avatar for rental with price, duration, usage rights, asset delivery rules, and revocation/expiry behavior.
5. **App stage:** Plawie resolves a verified token/asset record, downloads a signed or integrity-checked runtime asset, and permits the user to equip only assets whose license and safety checks pass.

### Required decisions before implementation

- Which chain owns the canonical mint: Solana, EVM, or separate lanes?
- What exact contract/program controls minting, rental, escrow, expiry, royalties, and disputes?
- Does “renting” grant a time-bound license, a token transfer, a delegation, or a marketplace listing only?
- Who owns the VRM asset copyright and commercial usage rights?
- How are unsafe files, malicious scripts, oversized assets, and impersonation handled?
- Who receives creator share, protocol share, marketplace share, and network cost?
- What happens when a rental expires while the avatar is equipped or cached offline?

### Proposed fee ledger

For each mint or rental, record:

- gross price and token/chain;
- creator share;
- marketplace/platform commission;
- network/contract fee;
- refunds, cancellations, disputes, and expiry;
- token/asset ID, transaction ID, listing ID, and rental ID;
- metadata and asset hashes;
- license version accepted by creator and renter.

Do not call an avatar “owned” merely because a local file is present. The app should distinguish local asset, verified token, active rental, expired rental, and unverified import.

## Analytics and launch metrics

### Event contract

Every transmitted event has `event_name`, `schema_version`, a random installation ID, an app-session ID, platform, release channel, app version, timestamp, and a locally generated event ID. The installation ID is created only after consent. It is not an Android advertising ID, hardware identifier, wallet address, Gateway device identity, account ID, or cryptographic key.

Until optional accounts exist, dashboards must say **active installations** rather than claiming verified people or registered users. Download counts are acquisition signals, not installs; installation IDs are not people.

Acquisition events:

- `landing_viewed`, `download_clicked`, `release_notes_opened`, `signup_started`, `signup_completed`;
- `product_hunt_campaign_seen`, `product_hunt_download_clicked`.

Activation and retention events:

- `app_first_opened`, `app_opened`, `gateway_ready`, `first_agent_turn_completed`, `agent_turn_completed`, `voice_turn_completed`;
- `wake_word_enabled`, `companion_session_started`, `avatar_equipped`, `onboarding_completed`.

Commerce events:

- `provider_quote_received`, `provider_payment_approved`, `provider_payment_submitted`, `provider_payment_settled`;
- `bridge_quote_received`, `bridge_fee_displayed`, `bridge_approval_started`, `bridge_submitted`, `bridge_settled`;
- `avatar_created`, `avatar_validation_passed`, `avatar_mint_started`, `avatar_minted`;
- `avatar_listing_created`, `avatar_rental_started`, `avatar_rental_expired`, `commission_reconciled`.

Reliability events:

- `gateway_failed`, `voice_transcription_failed`, `tts_failed`, `foreground_service_restarted`, `support_report_submitted`;
- bounded error code and correlation ID only; never raw payloads.

The app analytics boundary rejects prompts, assistant responses, transcripts, audio, media, filenames, raw URLs, wallet addresses, transaction hashes, signatures, balances, API keys, tokens, provider payloads, arbitrary exception strings, and nested objects. Commerce truth remains in signed/provider/chain receipts and the future reconciliation ledger, never in PostHog.

### Business metrics

Do not use MRR, ARR, subscription churn, or subscription LTV. Use:

- landing visitors → APK downloads → activated users;
- 1-day, 7-day, and 30-day retention;
- provider top-up gross volume and successful settlement rate;
- bridge gross volume, route success, average fee, and reconciliation time;
- AvatarForge mints, active listings, rental volume, rental completion, and creator repeat rate;
- Plawie gross commission, partner share, network cost, refunds/disputes, net commission, and contribution margin;
- commission per active user, commission per active creator, and commission per successful transaction;
- product-hunt cohort versus organic/direct cohort;
- support reports and reliability by release/device/channel.

The internal dashboard should show cash/crypto settlement and expected commission separately. Revenue is recognized only after the contractual/chain settlement is evidenced and the accounting treatment is confirmed.

## Product Hunt readiness

Product Hunt is a distribution event, not proof of product-market fit. It does not require Plawie to force product signup. Use one campaign URL with allowlisted UTM attribution, then measure activated installations, retained installations, transaction volume, and commission—not only votes.

Before launch:

- the download link and release checksum work;
- local/BYOK onboarding works with no account;
- voice/PiP/wake-word limitations are honest and tested;
- bridge and provider flows clearly show that the user approves crypto transactions;
- no commercial fee is enabled without its partner/legal gate;
- AvatarForge is labeled “planned” unless the actual portal/contracts are live;
- the support page, privacy page, terms, and data-deletion path match reality;
- analytics events are consented and redacted;
- a founder support/incident plan exists for launch day.

Read the [Product Hunt Launch Guide](https://www.producthunt.com/launch), [preparation guide](https://www.producthunt.com/launch/before-launch), and [sharing guidance](https://www.producthunt.com/launch/sharing-your-launch) immediately before scheduling. Do not incentivize votes or describe planned commerce as shipped capability.

## Implementation sequence

### Phase 0 — truth and quarantine

- Keep local/BYOK operation independent of accounts and commerce.
- Remove or quarantine the unused OpenRouter/Coinbase `CryptoCreditsService`.
- Make the active provider catalog and x402 receipt flow the only payment surface.
- Keep bridge execution and AvatarForge mint/rental disabled until their gates pass.
- Update all user-facing copy to say “provider charge,” “bridge quote,” “planned AvatarForge,” and “no subscriptions.”

### Phase 1 — measurement foundation

- Define event schemas and redaction tests. **Completed.**
- Keep the local `ProductTelemetryEvent` contract as the only feature-code entry point. **Completed.**
- Add a consent-aware, fail-closed PostHog Capture API sender with person profiles and GeoIP enrichment disabled and no autocapture. **Completed in Android and landing-site code; production host/token not configured.**
- Add stable random installation IDs generated only after consent, never hardware or wallet identifiers. **Completed and tested.**
- Add a bounded redacted retry queue that can never block app functionality. **Completed and tested.**
- Instrument app open, onboarding, Gateway readiness/failure, successful agent turns, and voice/TTS success/failure. **Completed for the first Android activation slice.**
- Add consent-aware landing-page acquisition events and allowlisted Product Hunt UTM attribution. **Completed in code with privacy/CSP updates; deployment remains disabled until staging configuration is supplied.**
- Create the activation, reliability, and transaction-volume dashboards. **Dashboard definitions are documented; PostHog project creation is external and pending.**
- Add release/channel/fee-schedule version to every commerce event.
- Configure the production PostHog project token and regional ingest host only through release build configuration; do not commit a fabricated token.

### Phase 2 — optional identity and receipts

- Create Supabase staging with Auth, profiles, personal workspaces, devices, receipts, and RLS.
- Add magic-link/OTP account creation only beside sync, recoverable receipts, creator profiles, marketplace participation, or support continuity.
- Keep `Continue locally` primary. Do not ask for identity merely to count users or unlock local/BYOK chat.
- Keep wallet keys and provider credentials device-owned; the cloud stores references and redacted receipts only.
- Add export/delete flows before broad signup promotion.
- Merge an anonymous analytics identity into an account only after separate analytics consent and explicit signup; never derive identity from a wallet address.

### Phase 3 — commission lanes

- Secure provider commission/referral terms before changing top-up displays.
- Complete LI.FI partner onboarding and fee-wallet setup before adding the fee parameter.
- Implement a server-signed fee schedule, quote display, transaction receipt, and reconciliation job.
- Add a finance export with gross volume, partner share, commission, cost, settlement, and dispute states.

### Phase 4 — AvatarForge

- Publish the asset manifest/license specification.
- Build the portal and wallet-connected creator flow.
- Audit and test mint/rental contracts or use a reviewed partner protocol.
- Implement signed asset resolution, rental expiry, creator/platform split, and app equip checks.
- Only then replace the current “SOON” portal affordance with a real deep link/callback.

### Phase 5 — Product Hunt launch

- Launch the stable local/BYOK product first if commerce gates are not ready.
- If a commission lane is live, disclose it plainly in the launch page and approval UI.
- Publish a dated dashboard snapshot after launch day, day 7, and day 30.
- Use actual activation, retention, transaction success, and net commission to decide what to build next.

## Immediate next commits

1. Confirm the accepted smoke event in PostHog Live events, connect the Netlify staging deploy context, and verify website opt-in and opt-out behavior.
2. Build an analytics-configured Android staging artifact and verify its opt-in, queue, redaction, and opt-out behavior on a physical device.
3. Materialize the documented acquisition, activation, retained-installation, voice, and Gateway dashboards in the PostHog UI.
4. Create the production PostHog project only after staging acceptance and privacy/Data Safety review, then deploy the consent-gated website and use the allowlisted Product Hunt campaign URL.
5. Instrument provider and bridge receipts only after each event can be derived from the redacted receipt contracts without addresses, hashes, signatures, or exact balances.
6. Defer Supabase signup until recoverable receipts, sync, support continuity, or AvatarForge creator features provide a concrete account benefit.
7. Request the external inputs needed for live commission enablement: provider agreements, LI.FI partner identity, fee wallet, legal review, chain/contract choices, and AvatarForge asset/license specification.

## Non-negotiable decisions

- No subscriptions.
- No Stripe dependency.
- No forced account wall for local/BYOK usage.
- No signup merely for analytics, download counting, or Product Hunt participation.
- No analytics transmission before explicit consent or without valid release configuration.
- No prompts, responses, transcripts, wallet data, credentials, raw logs, or arbitrary payloads in product analytics.
- No hidden commission added to a provider challenge.
- No custody or unattended signing introduced to collect revenue.
- No bridge commission enabled without a visible quote and verified fee settlement.
- No AvatarForge mint/rental claim until contracts, metadata, licensing, and asset delivery are real.
- No provider spend or bridged principal counted as Plawie revenue.
- No Product Hunt launch copy that turns a roadmap item into a shipped feature.
