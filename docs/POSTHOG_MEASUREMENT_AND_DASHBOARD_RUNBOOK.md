# Plawie PostHog Measurement and Dashboard Runbook

**Date:** 2026-08-16
**Status:** EU staging project and Netlify draft verified end to end; Android staging and production activation pending
**Identity model:** Consented anonymous installations, not verified people

## 1. Account setup and project separation

Use PostHog Cloud EU unless a later legal or infrastructure review selects a
different region:

1. Create an account at <https://eu.posthog.com/signup>.
2. Create `Plawie Staging` first.
3. Open **Project settings → Project variables**.
4. Copy the public Project API key/token beginning with `phc_`.
5. Provide only that public token and the selected region to the release
   maintainer.
6. Never provide a Personal API key (`phx_`), project secret key, password,
   recovery code, or service credential to the Android app, website, repository,
   or support channel.
7. After staging is verified, create a separate `Plawie Production` project and
   repeat the public-token step through the production secret manager.

As of 2026-08-16, `Plawie Staging` exists in PostHog EU and its public Capture
API endpoint accepted the repository smoke event. The Netlify deploy-preview
context and browser network acceptance test are complete. Visual confirmation
of the received fields in PostHog Live events and an Android staging-device test
remain release gates.

The public project token identifies the ingestion project; it is not permission
to administer the PostHog account. Dashboard creation can be completed manually
in the PostHog UI and does not require committing an administrative API key.

## 2. Release configuration

### Android staging build

Set these only in the controlled build environment:

```powershell
$env:PLAWIE_POSTHOG_HOST = 'https://eu.i.posthog.com'
$env:PLAWIE_POSTHOG_PROJECT_KEY = '<public phc_ staging token>'
$env:PLAWIE_RELEASE_CHANNEL = 'android-staging'
```

The Android app remains silent until the user explicitly opts in. Invalid,
partial, secret-looking, or non-HTTPS configuration fails closed.

### Netlify staging deploy

Set these in **Netlify → Site configuration → Environment variables**:

```text
PLAWIE_POSTHOG_HOST=https://eu.i.posthog.com
PLAWIE_POSTHOG_PROJECT_KEY=<public phc_ staging token>
PLAWIE_SITE_RELEASE_CHANNEL=web-staging
```

The landing build generates an ignored runtime configuration file. No token is
committed. Without both host and token, the deployed site generates a disabled
configuration, shows no analytics prompt, creates no analytics identifier, and
sends no analytics request.

Production uses the production project token and `web-production` /
`android-production`. Never send staging and production into one project.

## 3. Privacy boundaries implemented in code

- Explicit opt-in; no pre-consent event or analytics identifier.
- Random Plawie installation and session IDs; no advertising ID, Android ID,
  wallet address, account, Gateway identity, email, or hardware identifier.
- Direct PostHog Capture API calls; no analytics SDK, autocapture, replay,
  heatmaps, feature flags, or remote configuration.
- `$process_person_profile=false` and `$geoip_disable=true` on every event.
- No page URL, referrer, search term, arbitrary UTM value, prompt, response,
  transcript, audio, media, filename, wallet data, signature, credential, raw
  provider payload, or raw exception.
- Website UTM values are collapsed into a tiny allowlist. Unknown values become
  `other` or are discarded.
- Opt-out removes the local analytics identity and pending/session state.

## 4. Event inventory

### Website acquisition

| Event | Meaning | Approved dimensions |
|---|---|---|
| `landing_viewed` | One consented landing-page view per browser session | source, medium, campaign, surface, release channel |
| `download_clicked` | Official Plawie GitHub APK link selected | same |
| `release_notes_opened` | Official Plawie GitHub release page selected | same |
| `product_hunt_campaign_seen` | Consented landing session with allowlisted Product Hunt attribution | same |
| `product_hunt_download_clicked` | Download click in an allowlisted Product Hunt-attributed session | same |

Use this launch URL:

```text
https://plawie.app/?utm_source=producthunt&utm_medium=launch&utm_campaign=producthunt_launch_2026
```

Do not add user names, post IDs, search terms, referral URLs, or free-form labels.

### Android activation and reliability

| Event | Meaning |
|---|---|
| `app_first_opened` | First measurable consented open for an installation |
| `app_opened` | Measurable app session |
| `onboarding_completed` | Local setup milestone completed |
| `gateway_ready` | Gateway changed into interactive-ready state |
| `first_agent_turn_completed` | First successful agent turn on an installation |
| `agent_turn_completed` | Successful agent turn with bounded provider/lane/mode dimensions |
| `voice_turn_completed` | Voice input produced a transcript and entered the turn flow |
| `voice_transcription_failed` | Bounded non-silence voice failure |
| `gateway_failed` | Gateway entered a generic error state |
| `tts_failed` | Bounded TTS failure category, at most once per session/category |

`app_first_opened` means first **measured** open after consent, not necessarily the
first historical launch before consent.

## 5. Dashboards to create

### Dashboard A — Product Hunt acquisition

1. Unique `product_hunt_campaign_seen` installations/sessions.
2. Unique `product_hunt_download_clicked` installations/sessions.
3. Funnel: campaign seen → download clicked, within one day.
4. Download click split by `surface`.
5. Release-note opens split by `source`.

### Dashboard B — Android activation

1. Unique active installations by `app_opened`, daily and weekly.
2. Funnel: `app_first_opened` → `onboarding_completed` → `gateway_ready` →
   `first_agent_turn_completed`, within seven days.
3. Median time between each funnel step.
4. Successful agent turns split by `lane`, `mode`, and bounded `providerId`.
5. Activation rate by Android release channel.

### Dashboard C — Voice and Gateway reliability

1. Voice transcription success ratio:
   `voice_turn_completed / (voice_turn_completed + voice_transcription_failed)`.
2. Voice result split by manual/continuous mode and chat/PiP surface.
3. Gateway-ready installations versus gateway-failed installations.
4. TTS failure count per 100 successful agent turns.
5. Release-channel comparison after every Android release.

### Dashboard D — Retention

1. D1, D7, and D30 retention using `app_opened`.
2. D7 retained installations that also completed an agent turn.
3. Voice-user retention versus non-voice-user retention.
4. Local-model versus Gateway-model retention, reported only when cohorts are
   large enough to avoid misleading conclusions.

## 6. Acquisition-to-app limitation

The GitHub APK download and Android installation have different random IDs.
There is no account, Play Install Referrer handoff, fingerprint, wallet match, or
hidden cross-device identifier. Therefore:

- the website can measure Product Hunt landing-to-download conversion;
- Android can measure install-to-activation and retention;
- current code cannot prove that a specific downloader became a specific active
  installation;
- launch reporting must compare aggregate counts and must not present them as a
  person-level end-to-end funnel.

A future production Play build may evaluate Play Install Referrer attribution,
but only after a privacy/policy review and a separate implementation plan.

## 7. Staging acceptance test

1. Set the three staging environment variables and run
   `node scripts/verify_posthog_capture.mjs`; confirm `landing_viewed` appears in
   PostHog Live events with person and GeoIP processing disabled.
2. Deploy with the staging token and verify no request occurs before consent.
3. Decline and verify no PostHog request, installation ID, or event state exists.
4. Grant consent and verify one `landing_viewed` event with no person profile or
   GeoIP enrichment.
5. Open the Product Hunt test URL and verify only allowlisted attribution.
6. Click download and release notes; verify the event names and surfaces.
7. Turn analytics off and verify new requests stop and local identity is removed.
8. Install a staging Android build; repeat opt-in/opt-out and inspect event
   properties for forbidden content.
9. Keep staging data out of production dashboards.

## 8. Verified staging evidence — 2026-08-16

- Netlify draft: <https://analytics-staging--plawie.netlify.app>
- Draft deploy ID: `6a818f1a94af087f0bac97ef`
- Context variables exist only in `deploy-preview`; the production deploy and
  `plawie.app` were not replaced.
- A clean browser produced no PostHog request and no analytics identifier before
  consent.
- Consent produced `landing_viewed`, `product_hunt_campaign_seen`,
  `download_clicked`, and `product_hunt_download_clicked`; all four requests
  received successful responses.
- The payloads kept only allowlisted Product Hunt attribution and excluded the
  test search-term value.
- Opt-out removed the browser installation ID and suppressed a later download
  capture.
- The local generated runtime configuration was reset to disabled after deploy.

Remaining staging evidence: inspect the four events in PostHog Live events and
complete the equivalent Android physical-device acceptance test.
