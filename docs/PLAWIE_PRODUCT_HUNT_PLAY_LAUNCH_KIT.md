# Plawie Product Hunt and Google Play launch kit

**Status:** Draft source of truth; publication assets are not final until the
Android release passes the gates in `PLAWIE_LAUNCH_SITE_RUNBOOK.md`.

## Positioning

Primary line:

> OpenClaw in your pocket.

Product Hunt tagline:

> A native-first OpenClaw companion for Android

Short description:

> Talk, use mobile-ready skills, inspect your local Gateway, choose your model
> path, and approve wallet actions from one Android companion.

Google Play short-description candidate (under 80 characters):

> Your native-first OpenClaw companion, skills and Gateway on Android.

## Maker story draft

Plawie started with a practical question: what would it take for an OpenClaw
companion to feel at home on Android rather than trapped inside a desktop-shaped
container? The answer became a native-first control surface for conversation,
skills, voice, Gateway health, model choice, and carefully bounded wallet
actions.

The app makes operational state visible. Skills say whether they are ready,
need configuration, need an optional runtime, or are genuinely blocked on
Android. Setup shows progress and receipts. The Gateway exposes health and
repair state. Wallet proposals stop at a human-readable approval before device
authentication and signing.

Plawie is still on its release train. The launch should invite technically
curious Android users to test an honest mobile architecture, not pretend every
desktop skill or provider is already production-ready.

## Product Hunt gallery sequence

1. Hero: Plawie mark, **OpenClaw in your pocket**, clean Chat screen.
2. Living product demo: Chat → Skills → Gateway → Wallet in one short capture.
3. Native architecture: Android UI → mobile Gateway → approved tools → model.
4. Skills: ready, configure, optional runtime, and blocked states.
5. Gateway: healthy owner, pairing, logs, and bounded repair path.
6. Human approval: amount, chain, recipient, reason, expiry, authentication.
7. Setup: visible progress, verification, receipts, and resume behavior.
8. Final card: release status, GitHub, privacy, and support URLs.

Use clean release data only. Never show provider keys, pairing tokens, private
wallet material, personal conversations, private email, exact location, or
unfinished error states. Captures must remain understandable without audio and
must avoid rapid flashing.

## Google Play asset checklist

- 512 × 512 high-resolution app icon.
- 1024 × 500 feature graphic.
- At least four clean phone screenshots from supported device sizes.
- Final app name, short description, full description, category, and tags.
- `https://plawie.app/privacy/` privacy URL.
- `https://plawie.app/support/` support URL.
- Publisher identity, email, and website matching the Play Console account.
- Data safety answers derived from actual app/provider behavior.
- Account-deletion URL if a centralized account is introduced later.
- Closed/internal test evidence across the supported Android matrix.
- App Bundle using Play-compliant executable delivery.
- Third-party notices and content ownership review.

Do not submit the current GitHub dependency-pack architecture unchanged when
packs contain `.so`, dex, JAR, or other executable code. The Play flavor needs
Play Feature Delivery modules, and the runtime-downloaded OpenClaw JavaScript
path needs a focused policy acceptance review.

## Website-to-launch asset map

| Launch need | Current source | Final action |
|---|---|---|
| Open Graph/Product Hunt thumbnail | `site/assets/social/plawie-og.png` | Verify deployed social preview |
| Product story | Landing hero and architecture sections | Condense into launch copy |
| Interactive demo | Landing four-state phone | Record pointer-free 15–25 s clip |
| Privacy | `site/privacy/index.html` | Add final publisher contact/legal review |
| Terms | `site/terms/index.html` | Add final publisher identity/legal review |
| Support | `site/support/index.html` | Confirm monitored contact route |
| Play screenshots | Android release build | Capture only after final UI acceptance |
| Release CTA | GitHub Releases | Swap to Play URL only when live |

## Launch-day checklist

1. Verify production domain, HTTPS, canonical redirects, and social card.
2. Publish only after legal/publisher details and Play delivery gates are done.
3. Schedule Product Hunt with the final gallery, maker comment, and working
   Android download destination.
4. Use the single allowlisted campaign URL:
   `https://plawie.app/?utm_source=producthunt&utm_medium=launch&utm_campaign=producthunt_launch_2026`.
5. Verify the optional analytics prompt, opt-out, privacy page, and PostHog
   production project before publishing that URL.
6. Watch support and issue channels during launch.
7. Keep the site CTA honest if Play review is delayed; never point to a fake or
   unpublished listing.
8. Record the shipped app version and site commit in the release notes.

## Launch measurement boundary

Report Product Hunt landing sessions and official download clicks separately
from Android activation and retention. GitHub sideloading does not transfer the
website's random analytics ID into the app, so do not claim a person-level
landing-to-active-install funnel. Use the definitions and dashboard checklist in
`POSTHOG_MEASUREMENT_AND_DASHBOARD_RUNBOOK.md`.

No signup is required to download, activate, or measure the launch. A future
account should be introduced only beside durable sync, recoverable receipts,
support continuity, or AvatarForge creator value.

Official launch preparation references:

- Product Hunt launch guide: <https://www.producthunt.com/launch>
- Product Hunt preparation: <https://www.producthunt.com/launch/preparing-for-launch>
- Google Play app size guidance:
  <https://developer.android.com/topic/performance/reduce-apk-size>
- Google Play privacy policy requirements:
  <https://support.google.com/googleplay/android-developer/answer/10144311>
