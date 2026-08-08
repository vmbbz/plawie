# Plawie launch and wallet handoff — 2026-08-08

This document freezes the application milestone from which the public launch
site was branched. It is the restart point for wallet, bridge, provider-credit,
and Android release work after the first website deploy.

## Source milestone

- Application branch: `codex/hybrid-bridge-funding-design`
- Landing-site branch: `codex/plawie-landing-site`
- Shared source commit: `e8c58dd` (`fix: gate optional rollback terminal setup`)
- Android application ID: `com.openclaw.plawie`
- Public dapp origin: `https://plawie.app`
- Native wallet callback: `plawie://wallet-callback`
- Reown project ID: stored as reviewed public client metadata in the app build

No wallet key, provider key, RPC credential, signature, callback capture, or
payment receipt belongs in this document or the website.

## Confirmed application architecture

Plawie is native-first. Android owns the primary Gateway lifecycle, local
bridges, dependency receipts, and user interface. PRoot is not the normal
runtime and is available only as an explicit user-demand rollback path.

Fresh setup downloads the current official OpenClaw Gateway from its upstream
release source instead of baking a quickly stale Gateway into the APK. Larger
native skill runtimes are downloaded as signed, versioned dependency packs and
recorded so successful packs are not fetched again unnecessarily. This keeps
the Play delivery artifact smaller while preserving explicit setup progress and
repair behavior.

The application can use cloud providers selected by the user and supports a
separate local-model path. Public copy must therefore never claim that all data
always remains on-device or that every use is cloud-free.

## Wallet and bridge milestone

Implemented at the branch point:

- Android-protected internal EVM wallet creation, import, persistence, export,
  and authenticated signing contract.
- Base Mainnet is the default network; Robinhood Chain is available as an
  additional network without renaming the underlying Base-oriented modules.
- Wallet page exposes network switching and a deliberate default-network
  control.
- Visible human approval remains mandatory before signing or sending payments.
- LI.FI quote/capability plumbing and external-wallet bridge architecture exist.
- Reown metadata is configured for `https://plawie.app` and the Android package.
- Solana Mobile Wallet Adapter and Reown transports are feature-gated until
  their production acceptance checks are complete.
- Optional rollback terminal setup is isolated from the primary native path.

Not yet production-approved:

- A real Mainnet bridge acceptance run with the final external-wallet return
  path and settlement monitoring.
- Production `ROBINHOOD_RPC_URL` for internal Robinhood Chain sends.
- Reown dashboard allowlisting of the live HTTPS origin and Android package.
- Connected wallet feature gates in the release build.
- End-to-end provider-credit purchase and immediate model-use acceptance for
  every crypto-funded provider.
- Any future Reown Link Mode rollout. It requires a separately reviewed HTTPS
  universal link, Android App Links intent filter, and hosted
  `/.well-known/assetlinks.json`.

The detailed release gates and wallet behavior remain authoritative in
`docs/RELEASE_CONFIGURATION.md`, `docs/EXTERNAL_WALLET_BRIDGING.md`,
`docs/BASE_WALLET_SECURITY_AND_RECOVERY.md`, and
`docs/WALLET_FUNDED_MODEL_PROVIDERS.md`.

## Website dependency and DNS state

`plawie.app` is registered through Netlify and its authoritative nameservers are
already managed by Netlify. At the branch point the DNS zone has no site records
and the origin does not yet serve HTTPS.

The correct order is:

1. Create/connect a Netlify project to the landing-site branch.
2. Deploy the static site to its generated `*.netlify.app` preview URL.
3. Assign `plawie.app` as the production domain and `www.plawie.app` as an
   alias redirect.
4. Let Netlify DNS provision the site records and managed certificate.
5. Verify both HTTPS names, canonical redirects, security headers, and the
   public `/.well-known/` paths.
6. Add the live `https://plawie.app` origin and `com.openclaw.plawie` to the
   Reown project allowlists.

A fixed origin-server IP is not a prerequisite for this Netlify-managed flow.

## Resume checklist after website deployment

1. Verify the deployed origin and certificate from at least two networks.
2. Finish the privacy, terms, support, and deletion-request URLs required by the
   Play listing and expose them inside the app where policy requires.
3. Complete Reown origin/application allowlisting.
4. Provide the production Robinhood RPC through controlled release
   configuration, never the repository or website bundle.
5. Rebuild the signed release bundle with only reviewed bridge gates enabled.
6. Run the human-approved wallet acceptance matrix: create, restore after app
   update, import, export, network switch, external connect, quote freshness,
   rejection, approval, callback, settlement, balance refresh, and duplicate
   submission prevention.
7. Resume crypto-funded provider model discovery and chat-consumption tests.
8. Run the complete Android release, Play policy, and store-listing checklist.

## Public-claim guardrails

The launch site may say:

- native-first Android OpenClaw companion;
- official Gateway downloaded during fresh setup;
- modular, receipted dependency packs keep the APK lean;
- local and user-selected cloud model paths;
- skills and device integrations are managed from the phone;
- wallet actions require explicit human approval.

The launch site must not say:

- PRoot is the primary runtime;
- no request or data ever leaves the device;
- all skills, providers, bridges, payments, or chains are production-ready;
- a roadmap transport or feature gate is already available;
- the wallet is custodial, insured, audited, or risk-free.

