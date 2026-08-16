# Plawie launch-site deployment and release-channel runbook

**Updated:** 2026-08-16

**Integration branch:** `native-node-gateway-research`

**Production origin:** `https://plawie.app`

**Netlify publish directory:** `site`

## Purpose

This runbook takes the standalone Plawie launch site from local validation to a
Netlify deploy preview and then to the production domain. It also records the
Google Play delivery boundary discovered during launch review so the website
does not make a claim the Android release cannot support.

The website is static semantic HTML, CSS, and dependency-free JavaScript. It
does not depend on the Flutter web shell, does not contain wallet or provider
credentials, does not set marketing cookies, and does not collect email. A
direct PostHog Capture API adapter is present but remains disabled unless a
valid build destination and explicit visitor consent both exist.

The dedicated landing branch excluded the app-only `fllama` gitlink because
Netlify attempted to resolve it during repository preparation even though the
site build never runs Flutter. The canonical native application branch must
retain that reviewed local-LLM dependency. Deploy the landing site from the
site-only branch or an exported `site/` artifact; never delete `fllama` from
the combined Android branch to work around a hosting checkout limitation.

## Local preview

From the repository root:

```powershell
npx netlify dev
```

The checked-in `netlify.toml` publishes `site/`. A plain static server is useful
for visual work, but Netlify Dev is the better final local check because it
applies redirects and response headers.

Before every deploy:

1. Validate all HTML documents.
2. Parse `manifest.webmanifest`, `sitemap.xml`, and `security.txt` as applicable.
3. Run `node --check site/assets/js/site.js`,
   `node --check site/assets/js/product-analytics.js`,
   `node scripts/test_landing_analytics.mjs`, and
   `node scripts/test_landing_analytics_browser.mjs`.
4. Test at 320, 393, and 1440 CSS pixels with no horizontal overflow.
5. Exercise the mobile menu, four demo tabs, Gateway preview control, network
   switch, payment-review dialog, Escape close, and keyboard focus.
6. Run an accessibility scan on the landing page and all policy/support pages.
7. Run Lighthouse against the Netlify-served version.
8. Check that no key, token, private log, email address, or device capture was
   introduced into the publish directory.

## Content Security Policy maintenance

The inline JSON-LD block is the only inline script. Its exact SHA-256 hash is
allowlisted in `site/_headers`. Any edit to that block requires a new hash.

The VRM contains embedded textures that Three.js exposes through temporary
same-page `blob:` URLs while decoding the model. Keep `blob:` narrowly allowed
for `connect-src` and `img-src`; it is not required by `script-src`. The Netlify
build validates these sources and continues to reject `unsafe-inline` and
`unsafe-eval` script policies.

`connect-src` also allows only the selected PostHog EU ingest origin. This CSP
permission does not itself transmit data; the analytics module still requires
explicit consent. A region change requires a reviewed CSP change and matching
build configuration. Never add a broad wildcard.

## Optional landing analytics configuration

The owner must create `Plawie Staging` in PostHog EU and supply only its public
`phc_` project token. In Netlify set:

```text
PLAWIE_POSTHOG_HOST=https://eu.i.posthog.com
PLAWIE_POSTHOG_PROJECT_KEY=<public phc_ token>
PLAWIE_SITE_RELEASE_CHANNEL=web-staging
```

The build creates ignored `site/assets/js/product-analytics-config.js`. Do not
force-add it to Git. With no host/key, it contains a disabled configuration and
the site sends nothing. With partial, secret-looking, or unsupported values,
the build fails. Follow
[the measurement runbook](POSTHOG_MEASUREMENT_AND_DASHBOARD_RUNBOOK.md) before
production activation.

PowerShell example:

```powershell
$jsonLd = '<exact inline script text>'
$bytes = [Text.Encoding]::UTF8.GetBytes($jsonLd)
$hash = [Convert]::ToBase64String([Security.Cryptography.SHA256]::HashData($bytes))
$hash
```

After changing the hash, reload through Netlify Dev with the browser console
open. A CSP refusal is a release failure.

## Netlify project and domain sequence

`plawie.app` is registered through Netlify and already uses Netlify DNS. Do not
look for or invent a fixed web-server IP.

1. Create a Netlify site from the GitHub repository.
2. Select `codex/plawie-landing-site` for the first deploy preview. Change the
   production branch only after the landing work is merged into the chosen
   release branch.
3. Keep the repository's `netlify.toml` settings: build command
   `node scripts/build_landing_site.mjs` and publish directory `site`. The build
   materializes the reviewed VRM and limb-animation assets; do not replace it
   with a Flutter build or an npm dependency-install step.
4. Review the generated `*.netlify.app` URL before assigning the custom domain.
5. In **Domain management**, assign `plawie.app` as the primary domain and add
   `www.plawie.app` as a domain alias.
6. Allow Netlify DNS to create the required apex/alias records and provision its
   managed TLS certificate.
7. Verify that `https://plawie.app/` returns 200 and
   `https://www.plawie.app/anything` redirects permanently to the canonical
   host and preserves the path.
8. Verify `/privacy/`, `/terms/`, `/support/`, `/robots.txt`, `/sitemap.xml`,
   `/.well-known/security.txt`, `/latest`, and a genuine 404.
9. Check the production response for CSP, HSTS, nosniff, referrer,
   permissions-policy, and frame-ancestors headers.
10. Only after the HTTPS origin works, allowlist `https://plawie.app` and Android
    package `com.openclaw.plawie` in the Reown project dashboard.

Official references:

- Netlify domains: <https://docs.netlify.com/manage/domains/get-started-with-domains/>
- Netlify DNS: <https://docs.netlify.com/manage/domains/set-up-netlify-dns/>
- Managed HTTPS: <https://docs.netlify.com/manage/domains/secure-domains-with-https/https-ssl/>
- Custom headers: <https://docs.netlify.com/manage/routing/headers/>

## Google Play executable-code delivery gate

Google Play policy says a Play-distributed app may not download executable code
such as dex, JAR, or `.so` files from outside Google Play. That means the
current GitHub dependency-pack mechanism is valid only for sideload/GitHub
builds when a pack contains executable Android code. Signing and checksums are
important security controls, but they do not change this distribution rule.

The planned release split is:

| Component | Google Play build | GitHub/sideload build |
|---|---|---|
| Base APK/app bundle | Play App Bundle | Signed APK |
| Native executables and libraries | Play Feature Delivery module, install-time or on-demand | Signed GitHub dependency pack |
| Data-only models/media/assets | Bundled or Play Asset Delivery where appropriate | Signed GitHub pack or normal download |
| Official OpenClaw JavaScript Gateway | Policy-reviewed interpreted-code path | Verified upstream download |
| Receipts and resume state | Shared app contract | Shared app contract |

Play Feature Delivery supports on-demand feature modules and explicitly covers
loading native code after a module is installed. Play Asset Delivery provides
asset directories for app/game data; it must not be used as an off-book native
executable updater.

The policy has an exception for code running in a VM or interpreter with
indirect Android API access. The OpenClaw JavaScript Gateway may fall within
that wording, but runtime-loaded interpreted code must still be unable to
violate Play policies. Before submission, review the Gateway download,
verification, tool allowlists, Android bridge surface, self-update behavior,
and skill-install path as one policy acceptance test. Do not describe the Play
build as compliant until that review and Play internal testing pass.

Official references:

- Device and Network Abuse policy:
  <https://support.google.com/googleplay/android-developer/answer/16559646>
- Play Feature Delivery overview:
  <https://developer.android.com/guide/playcore/feature-delivery>
- On-demand modules and native libraries:
  <https://developer.android.com/guide/playcore/feature-delivery/on-demand>
- Play Asset Delivery for native apps:
  <https://developer.android.com/guide/playcore/asset-delivery/integrate-native>

This architecture migration is intentionally not implemented on the landing
site branch. Resume it on the Android release branch after the website deploy.

## Policy and listing blockers before production launch

- Replace the temporary GitHub-only privacy contact path with the publisher
  identity and contact channel that will appear in Play Console.
- Have the final privacy policy and terms reviewed for the actual legal entity,
  countries, age gate, wallets, bridges, provider data flow, and deletion path.
- Complete the Play Data safety form from verified runtime behavior, not the
  marketing site.
- Finish Play-compliant executable module delivery and interpreted-code review.
- Complete Reown origin/package allowlisting and production bridge acceptance.
- Replace **Release status** with a Google Play badge only after the live store
  URL exists.
- Replace provisional copy and screenshots if any feature gate changes before
  release.

## Production acceptance

- Canonical apex and `www` redirect work over HTTPS.
- Lighthouse targets: Performance, Accessibility, Best Practices, and SEO at
  least 95; LCP at most 2.5 s; CLS at most 0.1.
- No serious or critical accessibility violations.
- Product demo works with pointer, touch, keyboard, and reduced motion.
- Social card renders at 1200 × 630 and contains no debug/private data.
- Privacy, terms, support, deletion instructions, and publisher contact agree
  with the app and Play Console.
- No public wording implies that every skill is Android compatible, every
  request is local, wallet spending is autonomous, or GitHub executable packs
  are part of the Play build.
