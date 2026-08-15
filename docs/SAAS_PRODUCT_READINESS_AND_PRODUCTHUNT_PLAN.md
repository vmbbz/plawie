# Plawie SaaS Product Readiness and Product Hunt Plan

**Status:** Planning baseline — no cloud account, billing, or central analytics backend is enabled yet  
**Date:** 2026-08-15  
**Product:** Plawie, the local-first Android companion and OpenClaw control surface

## Executive decision

Plawie should become a measurable SaaS product in stages, without turning the local-first promise into an account wall.

The recommended foundation is:

| Capability | Recommended first system | Why |
|---|---|---|
| Identity, optional accounts, workspaces, entitlements | Supabase Auth + Postgres + Edge Functions | One durable user/workspace model, SQL reporting, row-level authorization, and a reasonable path from solo users to teams |
| Product analytics and experiments | PostHog | Funnels, retention, feature flags, experiments, surveys, and a Flutter SDK in one product analytics layer |
| Web subscriptions and invoices | Stripe Billing + Checkout + Customer Portal | Mature subscription lifecycle, webhook events, tax/recovery options, and a clean web checkout |
| Android digital subscriptions | Google Play Billing | Required platform lane for digital goods sold through a Play-distributed app; verify purchases on a secure backend |
| Cross-platform entitlement wrapper | RevenueCat, only when needed | Reduces native Play/App Store entitlement plumbing if mobile subscriptions become a core product; do not add it before there are real products to sell |
| Crash and diagnostic triage | Existing bounded logs first; evaluate Sentry separately | Product analytics should not become a dump for sensitive prompts, audio, wallet material, or gateway logs |

Supabase is a good fit because its Auth sessions integrate with Postgres Row Level Security (RLS), while its documentation explicitly requires protecting user tables with RLS and using stable `auth.users` references. See [Supabase Auth](https://supabase.com/docs/guides/auth), [managing user data](https://supabase.com/docs/guides/auth/managing-user-data), and [securing the Data API](https://supabase.com/docs/guides/api/securing-your-api).

PostHog should receive deliberately designed events rather than raw conversations. The Flutter SDK supports Android, iOS, macOS, and web, and product analytics supports funnels, retention, lifecycle, and feature adoption analysis. See [PostHog Flutter](https://pub.dev/packages/posthog_flutter) and [PostHog product analytics](https://www.mintlify.com/PostHog/posthog/products/product-analytics).

Stripe should be authoritative for web billing state through signed webhooks; the app must never decide that a subscription is paid based only on a client-side callback. See [Stripe subscription lifecycle](https://docs.stripe.com/billing/subscriptions/overview) and [Stripe subscriptions](https://docs.stripe.com/subscriptions).

For Play-distributed digital features, Google documents a backend purchase-verification and entitlement architecture, including real-time developer notifications. See [Google Play Billing](https://developer.android.com/google/play/billing) and [purchase lifecycle and RTDNs](https://developer.android.com/google/play/billing/lifecycle). RevenueCat is an optional abstraction over Play Billing, App Store billing, and web entitlements; see its [Flutter installation and cross-platform notes](https://www.revenuecat.com/docs/getting-started/installation/flutter).

## The product boundary we should protect

Plawie currently has a valuable distinction:

- local Android runtime and voice interaction can work without a Plawie cloud account;
- users can bring their own model provider keys;
- the app can expose sensitive tools, wallets, conversations, audio, and device actions;
- cloud services are selected by the user rather than assumed.

The SaaS layer should add durable value rather than silently changing that contract.

### Account optionality

An account is required only for features that genuinely need server state:

- cross-device settings and conversation sync, if the user explicitly enables it;
- hosted Gateway or hosted model services operated by Plawie;
- team workspaces, shared skills, roles, and billing;
- paid entitlements, invoices, receipts, and account recovery;
- support diagnostics that the user explicitly submits.

An account is not required for:

- local-only chat and voice;
- on-device models;
- BYOK providers;
- local wake-word and foreground voice operation;
- inspecting local health and logs;
- downloading the public Android preview.

This gives us a conversion path without making privacy-sensitive users abandon the product before they understand its value.

### Monetizable value, not artificial limits

The first paid offer should be attached to an operating cost or durable convenience that users understand:

1. **Free local/BYOK:** local Gateway, local voice, BYOK model providers, basic device tools, and a bounded local history.
2. **Pro:** encrypted sync, multi-device continuity, managed backups, premium voice/companion capabilities, hosted convenience, and higher support priority—only where those services exist and have a real cost/value.
3. **Team or builder:** shared workspace, member roles, skill/configuration sharing, audit history, usage controls, and a team billing owner.
4. **Usage-based add-ons:** only for Plawie-provided hosted inference, hosted Gateway capacity, or other metered infrastructure. Provider pass-through and Plawie margin must be separate ledger lines.

Do not charge for “AI messages” that are actually paid directly by a user’s BYOK provider. Do not describe wallet-funded provider spend as Plawie revenue. Revenue, pass-through volume, provider cost, infrastructure cost, refunds, and gross margin need distinct accounting dimensions.

## Target architecture

```text
Landing site ── consented attribution ──┐
                                        ├── PostHog: product events, funnels, cohorts, flags
Flutter app ── optional auth/session ───┤
                                        │
Stripe webhooks ── signed Edge Function ─┤
Google Play RTDN ── verified backend ────┤
                                        └── Supabase Postgres: users, workspaces, devices,
                                            entitlements, billing ledger, deletion state
```

### System-of-record rules

- Supabase owns Plawie identity, workspace membership, device links, feature grants, and deletion requests.
- Stripe owns Stripe customer, subscription, invoice, payment, refund, and tax facts for web purchases.
- Google Play owns Play purchase facts for Play purchases; the backend stores verified entitlement state and the original purchase token reference according to the applicable data-retention policy.
- PostHog owns behavioral analytics and experiment exposure data, not access control or billing truth.
- The app consumes a short-lived, server-issued entitlement view. It never embeds a Stripe secret, Supabase service-role key, Play private credential, or provider master key.
- Webhooks are idempotent and append-only at the event boundary. Replaying a webhook must not duplicate a subscription, invoice, credit, or entitlement.

### Suggested core tables

| Table | Purpose | Important rules |
|---|---|---|
| `profiles` | Minimal user profile and consent state | References `auth.users(id)`; no prompt/audio content |
| `workspaces` | Future-proof solo and team ownership | Every user starts with a personal workspace; team support uses the same model |
| `workspace_members` | Roles and membership lifecycle | RLS by membership; never trust client-provided role metadata |
| `devices` | Random installation ID, platform, app version, last-seen health | No hardware serial, IMEI, contacts, or unnecessary fingerprinting |
| `attribution_touchpoints` | UTM/referrer/Product Hunt source history | Store coarse campaign metadata, not a hidden identity graph |
| `entitlements` | Server-computed feature access | Derived from verified billing or explicit grants; expires and can be revoked |
| `billing_customers` | Provider customer mapping | Separate provider IDs from internal user/workspace IDs |
| `billing_events` | Immutable provider event ledger | Unique provider event ID; raw payload retention must be bounded and redacted |
| `usage_periods` | Metered usage and cost summaries | Aggregate by workspace/period; never use raw prompt text as a meter key |
| `deletion_requests` | Auditable deletion/export workflow | Track requested, processing, completed, and blocked-by-provider states |

Do not expose billing tables directly to the mobile client. Use Edge Functions or a narrow server API for checkout, entitlement refresh, account deletion, and support exports.

## Identity and attribution design

### Identity lifecycle

1. On first launch, create a random local installation ID. It is not a hardware identifier.
2. Before signup, PostHog may use an anonymous ID only after the user has the required analytics consent. Local-only use can remain untracked.
3. When the user signs up, create the Supabase user and personal workspace.
4. Alias/merge the anonymous analytics identity into the stable internal user UUID only after signup and consent.
5. Link one or more device installation IDs to the user through a short-lived pairing flow.
6. On logout, clear account-scoped local caches and stop sending authenticated events. Do not silently upload local conversations during logout or login.
7. On account deletion, revoke sessions, unlink devices, cancel or explain billing implications, delete Plawie-held data, and retain only legally required financial records.

### Attribution fields

Capture these fields on the landing site and carry them into signup where possible:

- `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`;
- first-touch timestamp and most recent-touch timestamp;
- referrer host, landing path, and release channel;
- `product_hunt_post_id` or a normalized `product_hunt` source marker;
- APK release tag and app version at activation.

Use a campaign URL such as:

```text
https://plawie.app/?utm_source=producthunt&utm_medium=launch&utm_campaign=2026-08-preview
```

Do not place emails, wallet addresses, provider keys, or conversation fragments in UTM parameters.

## Event contract

Create one shared event vocabulary for the landing site, Flutter app, and backend. Every event should have:

- `event_name`;
- `schema_version`;
- anonymous or authenticated actor ID;
- `session_id` where useful;
- `platform`, `app_version`, `release_channel`;
- `workspace_id` only when the event is workspace-scoped;
- `occurred_at` and server-ingested timestamp;
- a small, documented property set;
- a deduplication key for retries.

### Acquisition and signup

| Event | Activation question answered |
|---|---|
| `landing_viewed` | Which sources bring qualified visitors? |
| `download_clicked` | Which CTA and campaign produce APK demand? |
| `release_notes_opened` | Are visitors validating trust before installing? |
| `signup_started` | Where does account intent begin? |
| `signup_completed` | Which source produces actual accounts? |
| `email_verified` | Are signup emails deliverable and trusted? |

### Product activation

| Event | Activation question answered |
|---|---|
| `app_first_opened` | Did the installed artifact launch? |
| `device_linked` | Did the user connect the app to a durable account? |
| `gateway_ready` | Did the core runtime reach a usable state? |
| `first_agent_turn_completed` | Did the user experience the product’s core promise? |
| `voice_turn_completed` | Did voice work end-to-end? |
| `wake_word_enabled` | Is proactive voice useful enough to enable? |
| `companion_session_started` | Is the visual/voice surface being used? |
| `onboarding_completed` | Did the user reach a stable first-session state? |

Recommended activation definition for the first dashboard:

> A new user is activated when, within 24 hours of signup or first app open, the app reaches `gateway_ready` and completes at least one successful agent turn. Voice activation is a separate cohort, not a hidden requirement for everyone.

### Engagement and reliability

- `session_started`, `session_ended`;
- `agent_turn_started`, `agent_turn_completed`, `agent_turn_failed`;
- `voice_listening_started`, `voice_transcription_received`, `voice_turn_completed`, `voice_turn_failed`;
- `tts_started`, `tts_completed`, `tts_failed`, `tts_duplicate_suppressed`;
- `wake_word_detected`, `wake_word_false_triggered`;
- `gateway_restarted`, `gateway_ready`, `gateway_failed`;
- `crash_reported` as a coarse diagnostic reference, never a raw stack/log payload in PostHog;
- `support_report_started`, `support_report_submitted`.

### Monetization

- `pricing_viewed`;
- `checkout_started`;
- `checkout_completed`;
- `subscription_started`;
- `invoice_paid`;
- `payment_failed`;
- `subscription_paused`;
- `subscription_canceled`;
- `refund_issued`;
- `entitlement_granted`, `entitlement_revoked`;
- `usage_limit_reached`;
- `upgrade_started`, `upgrade_completed`, `downgrade_completed`.

Billing events should carry normalized numeric fields such as currency, gross amount, tax, discount, provider fee, refund amount, and net recognized revenue. Never calculate MRR from a client-side `checkout_completed` event.

### Sensitive-data exclusions

Never send these to PostHog or a generic analytics event:

- audio bytes, transcripts, prompts, model responses, screenshots, attachments, or tool results;
- API keys, auth headers, pairing tokens, cookies, session secrets, private keys, recovery phrases, or raw signatures;
- full wallet addresses unless there is a separately reviewed product need;
- precise location, contacts, message contents, or personal files;
- raw Gateway logs or exception payloads that may contain user data.

For failure analysis, send a bounded error code, screen, operation, release, and correlation ID. Keep detailed diagnostics in an explicit user-submitted support flow with redaction.

## Metrics that make the business sellable

Product Hunt votes and page views are launch signals, not the business model. The internal weekly dashboard should show:

### Acquisition

- unique landing visitors by source/campaign;
- download click-through rate;
- signup start and completion rate;
- cost per qualified signup once paid acquisition exists;
- Product Hunt visitors, signups, activated users, and paid conversions separately.

### Activation and product value

- activation rate within 24 hours;
- median time from install/signup to first successful agent turn;
- gateway-ready rate;
- voice completion rate and voice failure rate;
- crash-free sessions and foreground-service restart failures;
- 1-day, 7-day, and 30-day retention cohorts;
- weekly active users / monthly active users;
- feature adoption: voice, wake word, PiP, sync, hosted features, and team sharing.

### Revenue and unit economics

- active paid workspaces and paid seats;
- new MRR, expansion MRR, contraction MRR, churned MRR, and ending MRR;
- ARR run rate (`ending MRR × 12`), clearly labeled as a run rate;
- ARPU and average revenue per paid workspace;
- gross logo churn and revenue churn;
- trial-to-paid and checkout conversion;
- refunds, failed payments, involuntary churn, and recovery rate;
- provider pass-through volume versus Plawie revenue;
- infrastructure and support cost per active workspace;
- gross margin by plan and by hosted feature;
- CAC, payback period, and LTV only after there are enough cohorts to make those estimates meaningful.

For early-stage reporting, show both cash collected and normalized recurring revenue. Do not call a one-time model-credit purchase MRR. Do not call gross provider spend Plawie revenue. Keep the ledger auditable down to provider event IDs and release version.

## Product Hunt launch sequence

Product Hunt’s current launch guidance supports preparing a draft/scheduled launch, building the maker/community response plan, and publishing launch assets before launch day. Read the [official Launch Guide](https://www.producthunt.com/launch), [preparation guide](https://www.producthunt.com/launch/before-launch), and [sharing guidance](https://www.producthunt.com/launch/sharing-your-launch) immediately before scheduling because platform details can change.

### Do not launch before these gates

- A new user can understand the product in one sentence and reach the first successful agent turn without founder intervention.
- Signup, email verification, logout, account deletion, and recovery work on a clean install.
- Local/BYOK mode remains usable if the user declines cloud signup.
- The latest release has a stable install/update path and an honest release page.
- Voice, wake word, PiP, background behavior, and TTS have an explicit tested support matrix; known device limitations are visible.
- Analytics can distinguish anonymous acquisition, signup, activation, retention, and paid conversion without storing sensitive content.
- Stripe webhooks or Play entitlement verification are tested in sandbox, including failed payment, cancellation, refund, and replay.
- Privacy policy, terms, data deletion instructions, support route, and vendor disclosures match the actual implementation.
- A founder can answer support questions during the launch window and publish a short incident/update note if the release fails.

### Suggested timeline

**T-6 to T-4 weeks — instrumentation and private beta**

- create staging Supabase/PostHog/Stripe projects;
- implement event schema and dashboard;
- invite 20–50 testers across device classes;
- measure activation and voice reliability before optimizing the launch page;
- conduct willingness-to-pay interviews rather than guessing the final plan structure.

**T-3 to T-2 weeks — commercial alpha**

- ship optional account creation and workspace identity;
- implement one narrow paid value proposition;
- run checkout and entitlement recovery tests;
- publish privacy/terms/support updates;
- create Product Hunt draft, demo video/GIF, screenshots, founder story, and FAQ.

**T-1 week — release candidate**

- freeze event names and pricing identifiers;
- test clean install, upgrade, logout/login, deletion, and offline/local paths;
- rehearse the launch dashboard and support escalation;
- validate every campaign link and release checksum;
- schedule only when the page, artifact, billing, and support paths are ready.

**Launch day**

- use one canonical Product Hunt campaign URL;
- monitor traffic, signup, activation, checkout, crashes, and support—not only votes;
- respond to comments with useful product detail and honest limitations;
- do not offer rewards for upvotes or ask users to misrepresent their experience;
- record timestamps for any incident, rollback, or pricing change.

**T+1, T+7, T+30 days**

- publish a concise results review;
- compare Product Hunt cohorts with organic and direct cohorts;
- review activation and retention before changing pricing;
- interview activated users and churned users;
- fix the largest activation or reliability bottleneck before adding more features.

## Security, privacy, and operational readiness

### Minimum controls before real accounts

- Separate development, staging, and production projects and credentials.
- Store secrets only in deployment secret stores; no service keys in Flutter assets, APKs, website JavaScript, or Git history.
- Enable RLS on every client-reachable Supabase table and test both positive and negative access cases.
- Use server-side authorization for workspace roles and entitlements; never trust `user_metadata` for authorization.
- Verify Stripe signatures and Google Play purchase tokens on the backend.
- Make webhook handlers idempotent and observable with a correlation ID.
- Rate-limit signup, pairing, checkout creation, support upload, and entitlement refresh endpoints.
- Add a deletion/export path and a written retention schedule before collecting personal data.
- Use explicit analytics consent where required and provide an in-app/site opt-out path.
- Treat prompts, audio, wallet data, provider keys, and device logs as sensitive by default.

### Operational controls

- uptime/health check for the account and entitlement API;
- error budget for signup, login, gateway-ready, voice completion, and checkout;
- release channel labels: debug preview, beta, production;
- incident runbook for auth outage, billing mismatch, data deletion failure, and Android voice regression;
- daily launch dashboard snapshots retained with the release tag;
- support inbox with severity labels and a public status/update path.

## Immediate implementation order

This is the next sequence I recommend, in separate small commits:

1. **Measurement contract:** add a versioned event catalog and redaction tests without sending production data yet.
2. **Staging foundation:** create Supabase staging, Auth, minimal schema, RLS policies, and environment configuration.
3. **Optional account flow:** magic-link/email OTP first; create a personal workspace; preserve local mode for anonymous users.
4. **PostHog integration:** consent-aware landing events and Flutter events; identify/alias only after signup; build the activation and retention dashboard.
5. **Device linking:** link an installation to a user/workspace through a short-lived pairing code; never use a hardware ID.
6. **Commercial wedge:** choose one paid feature with a clear cost/value explanation; do not ship a broad “Pro” label with no entitlement semantics.
7. **Billing adapter:** Stripe Checkout/Portal for web; backend webhook ledger; add Play Billing or RevenueCat only when the Android entitlement is ready for sale.
8. **Readiness rehearsal:** clean install, signup, activation, subscription, refund, revoke, deletion, and offline/local regression tests.
9. **Product Hunt preparation:** campaign attribution, draft page, demo assets, launch support plan, and a no-incentivized-voting policy.
10. **Launch decision:** proceed only when activation, reliability, privacy, support, and billing gates pass together.

## Decisions we should not make yet

- Do not force account creation into the current local-first preview.
- Do not upload every conversation/audio turn to “understand usage.”
- Do not build a custom payment processor or store card data.
- Do not treat PostHog as the billing ledger or Stripe as the product database.
- Do not add RevenueCat merely because it is convenient before there are mobile products and entitlements to manage.
- Do not promise team collaboration, hosted Gateway, encrypted sync, or premium voice until each has a backend security and cost model.
- Do not declare Product Hunt success from votes alone; the durable result is activated, retained, paying users with measurable support and margin.

## First dashboard definition

The initial internal dashboard should have these cards and filters:

- date range, release channel, app version, platform, campaign source, and plan;
- landing visitors → download clicks → signups → activated users → retained users → paid workspaces;
- activation rate, median time to value, 7-day retention, 30-day retention;
- gateway-ready rate, voice completion rate, crash/force-stop rate, and support reports per 100 active users;
- active paid workspaces, MRR, net new MRR, churn, refunds, failed payments, and gross margin;
- Product Hunt cohort versus non-Product Hunt cohort;
- event schema errors, webhook failures, entitlement mismatches, and deletion backlog.

The dashboard should be exportable as a dated CSV/JSON snapshot attached to each release review. That gives a future buyer evidence of acquisition quality, activation, retention, revenue, cost, and operational discipline rather than a collection of screenshots.

