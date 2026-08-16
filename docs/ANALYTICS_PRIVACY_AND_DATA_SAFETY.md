# Analytics Privacy and Google Play Data Safety Inventory

**Date:** 2026-08-16
**Status:** Engineering inventory for review; not legal advice or a submitted Play declaration

## Implemented collection boundary

Plawie product analytics is optional for every user and disabled unless both a
valid release destination and explicit consent exist. Local/BYOK use, downloads,
wallet use, and Product Hunt participation do not require analytics or an
account.

The Android implementation sends only allowlisted interaction and reliability
events with a random app installation ID. The website separately sends only
allowlisted acquisition events with a random browser installation ID. These IDs
are not joined to each other or to a wallet, account, email, advertising ID,
Android ID, Gateway identity, or hardware identifier.

PostHog receives requests only after consent. Every event disables person-profile
processing and GeoIP enrichment. Ordinary network infrastructure may still
process connection metadata such as source IP and user-agent to deliver and
protect the service.

## Prohibited analytics content

Do not add any of the following to product analytics:

- prompts, assistant output, transcripts, audio, images, video, or files;
- names, email addresses, phone numbers, account identifiers, or support text;
- wallet addresses, balances, transaction hashes, signatures, private keys, or
  recovery material;
- API keys, auth headers, Gateway tokens, provider payloads, or RPC bodies;
- precise or approximate location, IP-derived location, page URLs, referrers,
  search terms, or free-form UTM values;
- raw logs, stack traces, exception strings, filenames, or nested arbitrary
  payloads.

## Draft Google Play Data Safety mapping

Google Play requires an accurate Data safety form for apps on closed, open, and
production tracks, even when collection is optional. The final answers must
describe every active artifact and every dependency, not only this analytics
module. See Google Play's current guidance:
<https://support.google.com/googleplay/android-developer/answer/10787469>.

For the product-analytics slice, the conservative draft is:

| Play data type | Collected? | Required? | Purpose | Rationale |
|---|---|---|---|---|
| App activity → App interactions | Yes when consented | Optional | Analytics | Feature milestones and successful interactions |
| App info and performance → Diagnostics | Yes when consented | Optional | Analytics | Bounded Gateway, voice, and TTS reliability categories |
| Device or other IDs | Yes when consented | Optional | Analytics | Random Plawie app-installation identifier relates to an app instance |

Engineering intent is **not shared** where PostHog processes the events solely as
Plawie's service provider. The publisher must confirm the executed PostHog terms,
data-processing agreement, configured products, and actual use before selecting
that answer. If PostHog data is used outside service-provider processing, the
declaration must change.

Collection is optional only while every user in every supported region can use
the app without opting in and can turn it off. The current implementation meets
that technical condition; release QA must preserve it.

Do not mark data as ephemeral: product metrics are retained for analysis. Do not
claim that the user can delete previously delivered analytics until a documented
deletion or bounded-retention process exists. Opt-out currently stops new events
and deletes local analytics state.

## Website disclosure inventory

The website uses local storage only for:

- the explicit analytics consent decision;
- a random analytics ID created after consent;
- a random session ID and allowlisted attribution created after consent;
- session-level event deduplication.

It does not use an analytics cookie, advertising pixel, session replay,
autocapture, heatmap, email form, account, or cross-site identifier. Its Content
Security Policy permits only the selected PostHog ingest origin; code still sends
nothing before consent.

## Release gates

Before enabling production analytics:

1. review and accept the PostHog EU terms and data-processing agreement;
2. set an intentional event-retention period;
3. confirm GeoIP enrichment, session replay, autocapture, person profiles, and
   advertising products remain disabled;
4. publish the updated Plawie privacy page before or with the measured build;
5. complete the full dependency and network-endpoint inventory;
6. update the Play Data Safety form for optional app interactions, diagnostics,
   and device/other IDs as applicable;
7. verify encryption in transit and access controls;
8. define who can access production analytics and require MFA;
9. document retention and a support/deletion decision;
10. retain screenshots or exports of the submitted declarations as release
    evidence.

The 2026-08-16 staging acceptance verified the implemented consent boundary on
a physical Android device: no identifier before consent, a random app-only ID
after opt-in, successful queue drain, and identifier/queue removal after
opt-out. PostHog Live events then confirmed that Android transmitted only the
documented lifecycle fields and website acquisition transmitted only the
allowlisted campaign fields. Both surfaces set person-profile processing false
and GeoIP disabled, exposed no prohibited application property, and retained
separate anonymous identity namespaces. This engineering evidence does not
replace the publisher's final Play Data Safety review of the complete production
artifact and all dependencies.
