# Release Configuration

This file records build inputs. The Reown project ID and dapp origin are public
client metadata already present in every configured APK; private RPC credentials,
wallet material, signatures, API keys, callback captures, and receipts remain
secrets and must not be committed, printed in CI logs, or packaged as assets.

## Wallet and bridge inputs

| Define | Required when | Failure behavior |
| --- | --- | --- |
| `REOWN_PROJECT_ID` | Optional rotation override; public default is configured | Connected wallet capability is unavailable only if both are invalid |
| `PLAWIE_DAPP_URL` | Optional rotation override; public default is `https://plawie.app` | Connected wallet capability is unavailable only if both are invalid |
| `ROBINHOOD_RPC_URL` | Production internal Robinhood sends; must be a credential-free public HTTPS origin with no path/query/userinfo | Sends are disabled; rate-limited official public reads remain |
| `ENABLE_LIFI_CONNECTED_BRIDGE` | Connected LI.FI execution is approved | Connected execution stays disabled |
| `ENABLE_RELAY_DEPOSIT_BRIDGE` | Relay strict-deposit execution is approved | One-time address stays disabled |
| `ENABLE_REOWN_EVM_WALLETS` | Reown EVM legal/configuration acceptance is complete | EVM wallet connection stays disabled |
| `ENABLE_SOLANA_MWA_WALLETS` | Android MWA legal/device acceptance is complete | Solana MWA stays disabled |
| `ENABLE_REOWN_SOLANA_FALLBACK` | Reown Solana fallback acceptance is complete | Phantom/Solflare Reown fallback stays disabled |
| `ENABLE_BASE_ACCOUNT_MWP` | A separately reviewed production adapter exists | Base Account remains honestly unavailable |

All gates default to `false`. LI.FI public quote/capability requests do not
require an embedded API key. Any future partner credential belongs behind a
controlled backend. Build-time Dart defines are compiled into the APK and are
never a safe transport for paid RPC credentials or provider secrets.

## Product analytics inputs

Product analytics remains disabled unless the user explicitly opts in **and**
all required build inputs below are valid. The PostHog project token is public
ingest metadata, not an administrative API key, but it should still be supplied
through controlled release configuration so staging and production data cannot
be mixed accidentally.

| Define | Required when | Failure behavior |
| --- | --- | --- |
| `PLAWIE_POSTHOG_HOST` | Consented product analytics is enabled; exact regional ingest origin such as `https://eu.i.posthog.com` | No product analytics are queued or transmitted |
| `PLAWIE_POSTHOG_PROJECT_KEY` | Consented product analytics is enabled; public project token only, never a personal or secret API key | No product analytics are queued or transmitted |
| `PLAWIE_RELEASE_CHANNEL` | Every measured build | Defaults to `android-preview` |
| `PLAWIE_APP_VERSION` | Optional release metadata override | Defaults to `AppConstants.version` |
| `PLAWIE_SITE_RELEASE_CHANNEL` | Measured Netlify landing build | Defaults to `web-production`; must begin with `web-` |

The client appends `/i/v0/e/` to the configured HTTPS host and sets PostHog's
`$process_person_profile` property to `false`, `$geoip_disable` to `true`, and
the stable queued event ID as `$insert_id` for idempotent retries. It does not
enable autocapture, session replay, advertising identifiers, or a general
analytics SDK. Never put a PostHog personal API key, project secret key,
Supabase service-role key, or other backend credential in a Dart define.

The Netlify landing build accepts the same host and public project token plus
`PLAWIE_SITE_RELEASE_CHANNEL`. It generates an ignored runtime configuration in
the publish directory. If host/key are absent, the generated configuration is
disabled and the site creates no analytics identity or prompt. EU production
requires `https://eu.i.posthog.com`, which is narrowly allowed by the site's
`connect-src` policy. See
[the PostHog measurement runbook](POSTHOG_MEASUREMENT_AND_DASHBOARD_RUNBOOK.md)
and [the Data Safety inventory](ANALYTICS_PRIVACY_AND_DATA_SAFETY.md).

Before supplying these defines to a public build:

1. create separate PostHog staging and production projects in the chosen data
   region;
2. update the app/site privacy disclosure and Google Play Data Safety answers;
3. verify opt-in, opt-out, queue retry, and deletion behavior against staging;
4. confirm dashboards use active installations rather than claiming verified
   people;
5. verify captured properties contain no prompts, responses, transcripts,
   audio, wallet data, signatures, credentials, raw URLs, or raw exceptions.

### Create the Reown project

1. Sign in at `https://dashboard.reown.com` and create a Plawie project using
   the AppKit product.
2. The reviewed project ID is stored as public APK metadata. A release may
   override it with `REOWN_PROJECT_ID` during a controlled project rotation.
3. Under **Project Domains**, add the exact origin used by
   `PLAWIE_DAPP_URL`. For example, if Plawie controls `https://plawie.app`, use
   that exact HTTPS origin for both. A controlled GitHub Pages origin is also
   acceptable for testing; a GitHub repository URL is not an app origin.
4. Under **Mobile Application IDs**, add Android package
   `com.openclaw.plawie`.

Plawie's reviewed public client configuration is:

- Project ID: `b20414538d1c91f0697cc92149003107`
- Metadata origin: `https://plawie.app`
- Android application ID: `com.openclaw.plawie`
- Native callback: `plawie://wallet-callback`

Before production publication, `plawie.app` must resolve publicly, serve HTTPS,
and be present in the Reown Project Domains allowlist. The app cannot configure
DNS or the authenticated Reown dashboard from an APK build.

The current Android return callback is already owned by the app as
`plawie://wallet-callback`; do not put that custom-scheme value in
`PLAWIE_DAPP_URL`. Plawie currently uses Reown relay mode and passes only this
native callback. A future Reown Link Mode rollout would require a separately
verified HTTPS universal link, Android App Links intent filter, and hosted
`/.well-known/assetlinks.json`; the app must not claim that configuration
before those pieces exist.

## Production command shape

The release owner must provide the upload-keystore values through protected CI
or local environment storage and must not echo them. `ROBINHOOD_RPC_URL`, if
used, is explicitly public configuration rather than a secret.

```powershell
if ([string]::IsNullOrWhiteSpace($env:ROBINHOOD_RPC_URL)) { throw 'ROBINHOOD_RPC_URL is required' }
if ([string]::IsNullOrWhiteSpace($env:PLAWIE_UPLOAD_STORE_FILE)) { throw 'Upload keystore is required' }

# Supply both only after PostHog staging verification and policy updates.
# $env:PLAWIE_POSTHOG_HOST = 'https://eu.i.posthog.com'
# $env:PLAWIE_POSTHOG_PROJECT_KEY = '<public project token>'
$env:PLAWIE_RELEASE_CHANNEL = 'android-production'

.\scripts\build_plawie_android.ps1 -Mode release -Bundle
```

The build helper fails closed on incomplete release signing and runs the
compiled-artifact secret audit before returning success. See
`ANDROID_CREDENTIAL_SECURITY.md` for the storage and threat model.

Production enablement also requires stable Android application ID/signing,
Reown project restrictions, the shipped legal/attribution bundle described in
`EXTERNAL_WALLET_BRIDGING.md`, and the controlled checklist below. Missing
evidence means the corresponding gate remains off.

## Debug acceptance

Debug builds may use Robinhood's documented public RPC for read-only and
non-spending checks. Enable only the bridge transports whose non-secret
configuration is actually present. A build with missing Reown values must show
an honest unavailable state rather than a partially working wallet chooser.

No automated test or device smoke test may approve, sign, bridge, transfer, or
submit a Mainnet payment.
