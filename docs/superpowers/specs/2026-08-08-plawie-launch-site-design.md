# Plawie launch site design specification

**Status:** Approved direction for implementation  
**Branch:** `codex/plawie-landing-site`  
**Production origin:** `https://plawie.app`

## Product story

Plawie puts an OpenClaw-powered AI companion and its operational controls into
an Android-first experience. The site must make this understandable in seconds:
the companion can talk, use approved tools and skills, run through a local
mobile Gateway, and let the user choose local or cloud model paths.

The primary launch line is **OpenClaw in your pocket.** Supporting copy should
explain the product rather than rely on generic phrases such as “the future of
AI” or “your ultimate copilot.”

## Experience concept: the living command deck

The visual system is a dark orbital command deck lit by Plawie's neon-mint
status signal. It borrows the app's black surfaces, precise outlines, mono
telemetry, soft glass, and `#00FFA3` accent while improving hierarchy and
legibility for the web.

The hero is not a static phone screenshot. It is a lightweight, semantic
HTML/CSS product simulation inside a dimensional phone frame. Visitors can
switch between Chat, Skills, Gateway, and Wallet states and trigger one safe
scripted interaction. The surrounding page reacts subtly to the active state.
This creates the feeling of using Plawie without shipping the Flutter runtime,
requiring an account, or exposing private application data.

Motion is purposeful and optional:

- a slow atmospheric grid and mint signal bloom;
- a short boot-sequence reveal on first view;
- state transitions within the product demo;
- subtle telemetry movement tied to real controls;
- no scroll-jacking, autoplay audio, strobing, or animation required to read
  the story;
- `prefers-reduced-motion` removes non-essential motion.

## Information architecture

### 1. Navigation

- Compact Plawie mark and wordmark.
- Product, Architecture, Skills, Safety, and FAQ anchors.
- Primary CTA changes from **Join the launch** before Play publication to
  **Get it on Google Play** only when a real store URL exists.
- Mobile menu is keyboard-operable, closes on Escape, and never traps focus.

### 2. Hero: understand it in ten seconds

- Eyebrow: `NATIVE-FIRST • ANDROID`
- Headline: `OpenClaw in your pocket.`
- Subhead: a concise explanation of companion, skills, and local Gateway.
- Primary CTA: join launch updates or view release status.
- Secondary CTA: explore the live product demo.
- Trust strip: native-first, official Gateway, modular downloads, human-approved
  wallet actions. Each item opens or links to a plain-language explanation.
- Interactive phone demo is visible above the fold on desktop and immediately
  after the copy on mobile.

### 3. Product demo: four real mental models

- **Chat:** conversation with clear model path and a visible proposed tool step.
- **Skills:** ready/configure/download states and a dependency receipt.
- **Gateway:** native owner, local endpoint, health signal, and transparent logs.
- **Wallet:** Base default, another-network selector, bridge quote, and an
  unmistakable human approval boundary.

The demo is illustrative, labelled as a preview, and must not suggest that it
is connected to a visitor's device or wallet.

### 4. Architecture: local control, connected intelligence

A scroll-safe architecture rail explains:

`Android UI → native mobile Gateway → approved skills/tools → local or selected cloud model`

It should distinguish runtime ownership from model transport. A compact
fallback note states that PRoot is an explicit rollback path, not the default.

### 5. Capabilities, expressed as outcomes

- Talk naturally and use voice.
- Install and manage mobile-compatible skills.
- See Gateway health, activity, and repair status.
- Choose a local model or connect a supported provider.
- Keep optional runtimes modular and deliver executable modules through the
  approved mechanism for each release channel.
- Review wallet payment details before authenticated signing.

Claims must be backed by the current app or marked **In development**.

### 6. Setup story

A visual, resumable setup timeline explains that a fresh install downloads the
official upstream Gateway and resolves only the required optional runtimes. It
highlights progress, receipts, and retry/resume behavior. Public wording stays
delivery-channel neutral: Google Play builds must obtain executable modules
through Play Feature Delivery, while signed GitHub packs are reserved for
sideload builds. It must not imply that off-store native executable downloads
are permitted in a Play-distributed build.

### 7. Safety and transparency

Show three enforceable boundaries:

- user selects the model/provider path;
- tools and skills expose readiness/configuration state;
- wallet signing and payments require explicit approval and device
  authentication.

Link to privacy, terms, support, security architecture, and open-source notices.

### 8. Launch section

- Product Hunt launch-ready product statement and maker story.
- Google Play CTA remains a waitlist/release-status action until the listing is
  real.
- Optional email capture is not implemented without a named processor, consent
  copy, retention policy, and deletion path. The safe first release can link to
  a GitHub release/watch flow instead.

### 9. FAQ

Answer the first-launch objections directly:

- Is Plawie native or PRoot?
- Does everything stay on-device?
- Why does setup download components?
- Can I use local models?
- Which skills work on Android?
- Does Plawie control or spend from my wallet automatically?
- When will it be on Google Play?

## Technical architecture

Use a standalone static site under `site/` rather than replacing Flutter's
existing `web/` shell. The first production version uses semantic HTML, modern
CSS, and small dependency-free JavaScript modules.

Reasons:

- immediate content and SEO without client rendering;
- near-zero dependency and supply-chain surface;
- fast Netlify deploys and previews;
- straightforward CSP and cache policy;
- enough capability for the planned app simulation;
- no coupling between website releases and Flutter web support.

Planned structure:

```text
site/
  index.html
  privacy/index.html
  terms/index.html
  support/index.html
  assets/
    css/site.css
    js/site.js
    brand/
    app/
  _headers
  _redirects
netlify.toml
```

No production secret or client-editable wallet/provider credential is allowed
in this bundle. Reown's project ID is public client metadata but the website
does not need it for the first launch.

## Visual tokens

- Canvas: `#020706`
- Raised surface: `#07110E`
- High surface: `#0D1A16`
- Primary text: `#F4FFF9`
- Secondary text: `#A6B8B0`
- Signal mint: `#00FFA3`
- Mint soft: `#6BFFD0`
- Caution amber: `#FFB300`
- Base blue is reserved for Base-specific wallet UI, not general CTA color.
- Display typography: expressive but locally hosted/system-fallback; body copy
  remains highly readable. No remote font dependency in the critical path.
- Mono typography is reserved for status, labels, receipts, and telemetry.

## Accessibility and performance contract

- Target WCAG 2.2 AA.
- Semantic landmarks and heading order.
- Full keyboard and visible-focus support.
- Minimum 24 CSS-pixel targets with generous 44-pixel design targets.
- Text and non-text contrast checked in both static and interactive states.
- Product demo has tabs, names, selected state, and an equivalent text summary.
- Decorative atmosphere is hidden from assistive technology.
- No information conveyed by color alone.
- Responsive from 320 CSS pixels through large desktop widths.
- Core Web Vitals targets at the 75th percentile: LCP <= 2.5 s, INP <= 200 ms,
  CLS <= 0.1.
- JavaScript enhances controls; the full product story and CTAs remain usable
  without it.
- Images declare dimensions, use modern formats where appropriate, and load
  below-fold media lazily.

## Netlify contract

- Publish directory: `site`
- No build command for the first production version.
- `www.plawie.app` permanently redirects to `https://plawie.app`.
- Security headers include a restrictive CSP, nosniff, referrer policy,
  permissions policy, and clickjacking protection.
- Fingerprinted assets receive immutable cache headers; HTML receives a short
  revalidation policy.
- Netlify deploy previews are reviewed before the production domain is assigned.
- HTTPS and canonical redirect checks are required after domain attachment.

## Product Hunt and Google Play launch kit

The site should also become the source for:

- Product Hunt thumbnail, gallery sequence, maker story, tagline, and an
  embeddable interactive demo or short screen recording;
- Google Play icon, feature graphic, phone screenshots, short description,
  privacy URL, support URL, and release-notes link;
- Open Graph/Twitter card and structured `SoftwareApplication` data;
- a press folder containing approved marks and screenshots, not raw debug or
  error captures.

The Play launch is blocked until executable dependency delivery is separated by
release channel. Native `.so`, dex, and JAR payloads for the Play build belong
in Play Feature Delivery modules. Play Asset Delivery can carry data assets but
must not be presented as an executable-code delivery workaround. Runtime-loaded
OpenClaw JavaScript needs a dedicated policy acceptance review because the
VM/interpreter exception does not waive the rest of Google Play policy.

Product Hunt media must show the interface clearly and avoid rapid cuts or
strobing effects. Google Play artwork must be exported from clean release UI,
without debug logs, keys, localhost tokens, private conversations, or incomplete
feature claims.

## Acceptance checklist

- A new visitor can explain Plawie after the hero.
- Every public capability is either currently testable or visibly marked as a
  roadmap item.
- The four-state product demo works by pointer, keyboard, and touch.
- There is no horizontal overflow at 320 px.
- No private app/device data appears in assets.
- HTML validates and metadata previews correctly.
- Sitemap, robots, canonical, Open Graph, and JSON-LD are present.
- Privacy, terms, and support routes return useful content, not placeholders.
- Lighthouse/axe-equivalent checks pass without critical accessibility issues.
- A local smoke test and a Netlify deploy preview both pass before DNS cutover.
