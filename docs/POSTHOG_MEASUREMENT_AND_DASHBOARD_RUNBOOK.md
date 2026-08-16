# Plawie PostHog Measurement and Dashboard Runbook

**Date:** 2026-08-16
**Status:** Website and Android staging acceptance complete; production activation and dashboards pending
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
context, browser network acceptance test, and Android physical-device consent
test are complete. The received website and Android fields were also reviewed in
PostHog Live events. The accepted property inventory is retained in sections 8
and 9 so the staging gate does not depend on access to an ephemeral event view.

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
| `app_opened` | Measurable app process start; retained for first-open and startup analysis |
| `app_foregrounded` | Visible foreground/PiP activity session after lifecycle-transition deduplication |
| `app_active_heartbeat` | Consented visible-use heartbeat at session start and every five minutes while foreground/PiP remains active |
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

Create each dashboard as a blank dashboard, then add saved insights. PostHog's
current dashboard flow is documented at
<https://posthog.com/docs/product-analytics/dashboards>; trends, funnels, and
retention are documented at
<https://posthog.com/docs/product-analytics/trends/overview>,
<https://posthog.com/docs/product-analytics/funnels>, and
<https://posthog.com/docs/product-analytics/retention>.

### Construction rules

- Use the names below so staging can later be copied to a separate production
  project without ambiguous duplicates.
- Apply the stated `releaseChannel` event-property filter to every insight, not
  a person-property filter. Keep staging and production in separate projects
  even though each insight is filtered.
- `Unique users` means unique consented anonymous installation IDs. Label tiles
  **installations** or **browser installations**, never registered users or
  people.
- Use `Unique users` for acquisition, activation, and retention. Use total event
  count for per-turn reliability ratios so repeated successes and failures are
  represented.
- `app_first_opened` is the first measured open for the current consent-created
  identity. Revoking consent deletes that identity and its once-only state, so a
  later opt-in correctly begins a new anonymous measurement identity. It is not
  a package-manager install counter.
- Do not enable autocapture, replay, heatmaps, person profiles, GeoIP, or broad
  URL/referrer collection to make a dashboard easier to populate.
- Use `app_foregrounded`, not `app_opened`, for active-installation and retention
  reporting. A process can remain alive across multiple visible sessions.
- `app_active_heartbeat` represents visible foreground/PiP use only. Passive
  wake-word listening, an idle foreground service, and a healthy background
  Gateway do not emit it. “Active now” is therefore a ten-minute approximation,
  not an exact presence count.
- Staging is test evidence, so do not turn on **Filter out internal and test
  users** there. Production access and internal-traffic policy are separate
  launch decisions.

### Dashboard A — `Plawie — Acquisition — Staging`

Build this dashboard now because its events are present in staging:

| Insight name | Type | Query | Required filter / setting |
|---|---|---|---|
| Product Hunt campaign browser installations | Trends | `product_hunt_campaign_seen`, unique users | `releaseChannel = web-staging`; last 30 days; daily |
| Product Hunt download browser installations | Trends | `product_hunt_download_clicked`, unique users | `releaseChannel = web-staging`; last 30 days; daily |
| Product Hunt landing to APK click | Funnel | `product_hunt_campaign_seen` → `product_hunt_download_clicked` | ordered; unique users; conversion window 1 day; `releaseChannel = web-staging` |
| All APK download browser installations by surface | Trends | `download_clicked`, unique users | breakdown `surface`; `releaseChannel = web-staging` |
| Release-note browser installations by source | Trends | `release_notes_opened`, unique users | breakdown `source`; `releaseChannel = web-staging` |

The Product Hunt funnel is valid because its two steps share one browser
installation identity. It must not be extended with Android events because the
website and Android identity namespaces are intentionally unrelated.

### Dashboard B — `Plawie — Android Activation — Staging`

Build the first three tiles now. The remaining tiles become meaningful after a
fresh consented setup and successful chat session produce the milestone events.

| Insight name | Type | Query | Required filter / setting |
|---|---|---|---|
| Daily active Android installations | Trends | `app_foregrounded`, unique users | `releaseChannel = android-staging`; last 30 days; daily |
| Weekly active Android installations | Trends | `app_foregrounded`, unique users | `releaseChannel = android-staging`; last 12 weeks; weekly |
| Active Android installations now (approx.) | Trends | `app_active_heartbeat`, unique users | `releaseChannel = android-staging`; rolling last 10 minutes; show current value |
| Measured first opens | Trends | `app_first_opened`, unique users | `releaseChannel = android-staging`; last 30 days; daily |
| First-open to first value | Funnel | `app_first_opened` → `onboarding_completed` → `gateway_ready` → `first_agent_turn_completed` | ordered; unique users; conversion window 7 days; first occurrence matching filters; `releaseChannel = android-staging` |
| Time to first value | Funnel | same four steps | graph type **Time to convert**; same window and filter |
| Successful turns by runtime lane | Trends | `agent_turn_completed`, total count | breakdown `lane`; `releaseChannel = android-staging` |
| Successful turns by provider | Trends | `agent_turn_completed`, total count | breakdown `providerId`; `releaseChannel = android-staging` |
| Successful turns by input type | Trends | `agent_turn_completed`, total count | breakdown `mode`; `releaseChannel = android-staging` |

The app currently emits `lane` as `local_model` or `gateway_model`; turn `mode`
as `text`, `image`, or `video`; and provider IDs from a bounded catalog with
`local`, `custom`, or `unknown` fallbacks. Do not replace those values with raw
model identifiers.

### Dashboard C — `Plawie — Voice and Gateway — Staging`

| Insight name | Type | Query | Required filter / setting |
|---|---|---|---|
| Voice transcription success rate | Trends formula | A = `voice_turn_completed`; B = `voice_transcription_failed`; formula `100 * A / (A + B)` | total count; `releaseChannel = android-staging`; show percent |
| Voice outcomes by mode | Trends | success and failure series | total count; breakdown `mode`; expected `manual` / `continuous` |
| Voice outcomes by surface | Trends | success and failure series | total count; breakdown `surface`; expected `chat` / `pip` |
| Voice failures by category | Trends | `voice_transcription_failed`, total count | breakdown `errorCode`; `releaseChannel = android-staging` |
| Gateway state transitions | Trends | `gateway_ready` and `gateway_failed`, total count | breakdown `mode`; expected `native_gateway` / `proot_rollback` |
| TTS failures per 100 turns | Trends formula | A = `tts_failed`; B = `agent_turn_completed`; formula `100 * A / B` | total count; `releaseChannel = android-staging` |

Treat a zero denominator as no evidence, not a 0% failure rate. `tts_failed` is
deduplicated once per session and error category, so its tile is a bounded
incident-rate signal rather than a count of every low-level synthesis retry.

### Dashboard D — `Plawie — Retention — Staging`

1. Create a retention insight with start event `app_first_opened`, return event
   `app_foregrounded`, unique users, daily periods, first-ever start occurrence, and
   `releaseChannel = android-staging`. Read D1, D7, and D30 only after each cohort
   period is complete.
2. Create a second retention insight with start event
   `first_agent_turn_completed` and return event `agent_turn_completed` to test
   whether installations that reached first value return for another successful
   turn.
3. Defer voice-user versus non-voice-user and local-versus-Gateway retention
   comparisons until the required events exist and each cohort is large enough
   to avoid identifying or over-interpreting a handful of installations.

### Dashboard completion gate

For each saved insight, confirm the event-property filter, aggregation, window,
and title against this table, add it to the named dashboard, and retain either a
dashboard export or screenshot. Do not mark dashboards complete merely because
empty tiles were created. Acquisition is accepted when its current staging
events render; Android activation/reliability/retention require one deliberately
consented end-to-end staging session and then a property review of each newly
observed event family.

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
10. With consent on, foreground the app, move it into PiP, return to full screen,
    then background it for more than two seconds. Confirm one
    `app_foregrounded` for the uninterrupted foreground/PiP session, heartbeat
    surfaces limited to `foreground` and `pip`, and no heartbeat after true
    backgrounding.

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
- PostHog Live events showed the expected anonymous `plawie-web-*` identity and
  only `campaign`, `medium`, `platform`, `plawieEventId`, `releaseChannel`,
  `schemaVersion`, `source`, and `surface`, plus the required PostHog control
  fields for session ID, timestamp, disabled GeoIP, and disabled person-profile
  processing.
- The reviewed `landing_viewed` event used `platform=web`,
  `releaseChannel=web-staging`, `schemaVersion=1`, `source=producthunt`,
  `medium=launch`, `campaign=producthunt_launch_2026`, and `surface=hero`.
- No page URL, referrer, search term, user account, wallet value, prompt,
  transcript, credential, or other prohibited application property appeared.

## 9. Verified Android staging evidence — 2026-08-16

- Device: Samsung SM-A556E; installed package `com.openclaw.plawie` version
  `2.3.0` / version code `15`, debuggable staging build.
- Local arm64 APK: 230,114,071 bytes, SHA-256
  `3ecf8137e3bdfbc7d2f52efda2eeaee9f1e2a5f9d6e886341d0a79d1854e1baf`.
- The APK was installed with replace-in-place semantics, preserving existing app
  data, and its temporary local build output was removed after installation.
- Before consent, the Settings toggle reported analytics off, no analytics
  installation ID existed, and pending/once-only telemetry lists were empty.
- Granting consent changed the UI to configured/on, created only a valid random
  `plawie-install-*` ID, recorded the measured first-open lifecycle marker, and
  drained the pending queue to zero after staging delivery.
- Denying consent again removed the installation ID and reset both telemetry
  lists to zero. The device was left in this denied/off state.
- PostHog Live events showed the expected anonymous `plawie-install-*` identity
  and only `appVersion`, `platform`, `plawieEventId`, `releaseChannel`,
  `schemaVersion`, and `source`, plus the required PostHog control fields for
  session ID, timestamp, disabled GeoIP, and disabled person-profile processing.
- The reviewed `app_opened` event used `appVersion=2.3.0`, `platform=android`,
  `releaseChannel=android-staging`, `schemaVersion=1`, and
  `source=android_app`. `app_opened` and `app_first_opened` used the same
  installation identity for that consented app installation.
- No device/hardware identifier, account, wallet value, prompt, transcript,
  credential, raw error, or other prohibited application property appeared.
- Website and Android events used different identity namespaces and were not
  joined. The property-level Live events review completes staging acceptance;
  production remains disabled until the production gates are completed.

### Visible-activity measurement follow-up — 2026-08-16

- Added `app_foregrounded` and `app_active_heartbeat` behind the same explicit
  Android analytics consent. No new identifier or permission was introduced.
- The lifecycle implementation emits an immediate heartbeat and then one every
  five minutes only while the app is resumed or PiP remains active. A two-second
  grace prevents Android permission and PiP transitions from splitting a
  session; a real background transition cancels the timer.
- The configured staging APK was version `2.3.0` / version code `15`,
  230,117,647 bytes, SHA-256
  `3fc3b75649e9d3acf5ee2a7404eb17f8d9d91c57644829eb3338883084395314`.
  It was installed over the existing Samsung SM-A556E app without clearing
  application data.
- On-device foreground → Home for more than two seconds → foreground testing
  preserved the existing granted consent and anonymous installation identity,
  returned Plawie to the resumed top activity, produced no matching fatal or
  unhandled lifecycle error, and drained the bounded outbound queue to zero.
- Automated coverage verifies foreground-session deduplication, immediate and
  periodic heartbeats, cancellation after true backgrounding, uninterrupted
  foreground/PiP sessions, PiP surface labeling, opt-in while active, and
  immediate shutdown/identity removal on opt-out.
- PostHog Live events must still be reviewed for the two new event names and
  their bounded `source` and `surface` properties before promoting this exact
  build configuration from staging to production.
