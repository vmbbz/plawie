# Google Play, Wallet Acceptance, and KeeperHub Integration Plan

**Status:** KeeperHub hackathon software slice implemented through bounded chat
proposal controls and remote credential revocation; physical-device acceptance
and independently verifiable proof remain release gates

**Policy and vendor snapshot:** 2026-08-10

**Plawie baseline:** `codex/hybrid-bridge-funding-design` at `e8c58dd`

**Landing-site baseline:** `codex/plawie-landing-site` at `9e69327`

**Supersedes:** `docs/audit/play_store_readiness.md`

**Related controls:** `docs/RELEASE_CONFIGURATION.md` and
`docs/RELEASE_WALLET_PAYMENT_CHECKLIST.md`

This document is the execution roadmap for three connected outcomes:

1. make a Google Play release that does not weaken Plawie's native-first
   architecture or violate Play's code-delivery, billing, financial, privacy,
   permission, or release-signing rules;
2. complete controlled wallet acceptance after `https://plawie.app` is live;
3. integrate KeeperHub where it adds unique onchain automation and execution
   reliability, without replacing Plawie's Android-owned wallet or bypassing
   the rule that every transaction requires fresh human approval.

This is an engineering and policy plan, not legal advice. Google Play policy,
financial regulation, vendor behavior, and supported chains can change. Refresh
all linked sources before production submission.

The attached KeeperHub PDF was treated as a product hypothesis, not as an
authority. Its useful ideas were checked against KeeperHub's current official
documentation, public source, live company material, and Plawie's existing code
before being accepted, narrowed, or rejected below.

---

## 1. Executive decisions

The following decisions are binding unless a later reviewed design explicitly
replaces them.

### 1.1 Distribution must have two policy-distinct lanes

Plawie cannot ship the current GitHub dependency-pack mechanism unchanged in a
Google Play build. Google Play prohibits downloading executable DEX, JAR, or
native `.so` code from outside Play. The existing arm64 packs contain ELF
executables and native libraries. Ed25519 signatures, hashes, receipts, and
smoke tests make those downloads safer, but they do not change the Play policy
classification.

Create two explicit product flavors:

| Lane | Purpose | Executable delivery | Gateway update policy |
| --- | --- | --- | --- |
| `play` | Google Play production and Play testing | Base AAB plus Play Feature Delivery only | Play-delivered, reviewed Gateway revision |
| `direct` | Plawie/GitHub distribution and engineering | Existing signed GitHub packs may remain | Latest official upstream OpenClaw, with existing integrity controls |

The two lanes must have separate manifests, feature flags, update copy,
telemetry labels, and test matrices. Runtime conditionals alone are not enough;
the Play artifact must be provably free of external native-code download paths.

Before the first public release, decide package identity and migration:

- Preferred: reserve `com.openclaw.plawie` for the Play app and move future
  direct builds to `com.openclaw.plawie.direct`.
- Existing beta installs using `com.openclaw.plawie` need an authenticated
  export/import migration flow and an explicit warning that uninstalling or
  clearing data destroys app-private state.
- Do not publish both lanes under the same application ID with incompatible
  signing identities. That creates update failures and an unsafe wallet/data
  migration experience.

### 1.2 Native-first remains the product architecture

`libnode.so` remains the primary Gateway owner. PRoot remains an optional,
user-requested rollback environment and must never start or download because a
wallet, KeeperHub, model provider, skill, or Play feature is unavailable.

The Play refactor changes where optional executable components arrive from; it
does not move normal operation into PRoot and does not turn the app into a
remote-only shell.

### 1.3 The Play Gateway cannot silently fetch arbitrary latest code

The direct build may continue to fetch the latest official OpenClaw package
from upstream GitHub/npm. The Play build needs a stricter release boundary.

Recommended Play policy:

- Pin an upstream OpenClaw version during each Plawie release.
- Deliver its JavaScript package through the base AAB or a Play-delivered
  module, not an external executable pack.
- Preserve upstream version, integrity, license, and provenance in the setup
  receipt.
- Update it through a Plawie Play release or a Play-delivered module update.
- Show honest copy: `Gateway updates are delivered through Google Play`.

Google permits some interpreted code downloads only when that code cannot
enable policy violations. Plawie's general Node runtime, skills, tools, and
filesystem/network capabilities make an unrestricted “always latest” argument
too risky without written policy confirmation. A later policy spike may prove
a constrained signed interpreted-code channel acceptable, but the initial Play
release must not depend on that interpretation.

### 1.4 Wallet transfers and AI-credit purchases are different products

Do not treat all crypto actions as one billing category.

- Wallet creation, backup, receiving, sending, wallet connection, and bridging
  are financial/wallet functionality. They require accurate Financial Features
  declarations and jurisdiction review.
- Model credits, paid AI requests, and paid KeeperHub workflows consumed inside
  Plawie are digital services. In the normal Play policy path, in-app purchase
  enablement must use Google Play Billing unless a documented regional program
  or exception applies.
- Therefore, the first Play release must disable crypto top-up and paid x402
  purchase CTAs unless Play Console enrollment and legal review explicitly
  authorize them for each country. Existing provider credentials/balances may
  remain usable if that use is policy-compliant, but the app must not route the
  user to an unapproved alternative purchase flow.
- The direct build can retain visible, separately approved x402 flows.

This split belongs in build configuration and server/provider policy, not just
UI hiding.

### 1.5 KeeperHub is optional managed execution, not the Plawie wallet

KeeperHub provides workflows, simulation, idempotent direct execution,
status/receipt APIs, marketplace discovery, and x402/MPP payment support. Its
first-party agentic wallet is currently custodial through a KeeperHub-controlled
Turnkey sub-organization, allows configurable auto-approval, and has a different
recovery model from Plawie's Android-owned wallet.

Consequently:

- Do not replace Plawie's Base/Robinhood wallet with KeeperHub's agentic wallet.
- Do not install KeeperHub's wallet npm package into the Gateway as Plawie's
  default payment path.
- Do not enable KeeperHub auto-payment. Plawie requires visible human approval
  for every payment, regardless of amount.
- Do not give the model a KeeperHub organization API key or OAuth token.
- Do not expose KeeperHub's aggregate write-capable MCP catalog directly to the
  model. It includes direct transfers, contract calls, workflow mutations, and
  Tempo hold release paths that OAuth/API-key callers can invoke without the
  interactive browser MFA used by human sessions.

KeeperHub should sit above the wallet as a typed automation/execution provider,
behind Plawie's approval coordinator.

---

## 2. Current architecture baseline

The plan preserves these already-implemented controls:

- native `libnode.so` Gateway ownership, with PRoot isolated as fallback;
- Android Keystore-backed EVM key protection and device-authenticated signing;
- one active payment intent at a time;
- payment intent binding to HTTPS host, method, URL, body hash, chain, asset,
  recipient, amount, nonce, and expiry;
- approval accepted only from the visible Flutter UI;
- one-use approval tickets;
- exact paid-request retry once, redirects disabled;
- fail-closed `uncertain` state after ambiguous submission;
- redacted local x402 and bridge receipts;
- bridge and provider-payment approvals as separate user actions;
- agent-visible payment and bridge tools restricted to read-only status,
  estimates, and redacted receipts;
- Reown metadata for `https://plawie.app`, Android package
  `com.openclaw.plawie`, and callback `plawie://wallet-callback`;
- Base Mainnet as the current default network, with Robinhood and Base Sepolia
  represented as distinct network state;
- targeted package visibility queries rather than `QUERY_ALL_PACKAGES`.

KeeperHub must reuse these boundaries. It must not create an easier second path
to a signature or broadcast.

---

## 3. Google Play gap register

### 3.1 P0 blockers

| ID | Current evidence | Risk | Required release gate |
| --- | --- | --- | --- |
| PLAY-01 | GitHub release packs contain ELF executables and `.so` files | External executable-code delivery is prohibited in a Play app | `play` artifact has no URL, manifest entry, service, or fallback capable of fetching native executable packs |
| PLAY-02 | Release build uses debug signing | Production identity, updates, wallet persistence, and Play App Signing are unsafe | Create protected upload keystore; use Play App Signing; CI fails if release resolves to debug config |
| PLAY-03 | Crypto/x402 top-ups buy digital AI services | Alternative in-app payment may violate Payments policy | Disable in `play` unless Billing/eligible regional program and reporting are complete |
| PLAY-04 | `MANAGE_EXTERNAL_STORAGE` is declared | Plawie is not primarily a file manager/backup/antivirus/document manager | Remove from `play`; use app-private storage, Storage Access Framework, and MediaStore where appropriate |
| PLAY-05 | Broad manifest includes multiple `specialUse` foreground services | Every FGS type needs a valid, user-perceptible core use, declaration, and demo evidence | Consolidate services; declare exact type/subtype; provide stop action and Play Console evidence |
| PLAY-06 | No final privacy/data-safety/account-deletion evidence set | Store submission can be rejected even when data stays mostly local | Publish policy pages, complete data map, SDK audit, deletion determination, and Console forms |
| PLAY-07 | Native library set has not completed 16 KB page-size acceptance | API 35+ native apps must support 16 KB page sizes | CI and physical/emulated 16 KB tests pass for every base and feature module native library |

### 3.2 P1 hardening

| Area | Current state | Refactor |
| --- | --- | --- |
| Cleartext | `usesCleartextTraffic="true"` globally | Default to false; create the narrowest tested loopback exception needed for the local Gateway; require TLS for non-loopback hosts |
| Legacy storage | `requestLegacyExternalStorage="true"`, read/write storage permissions | Remove from Play manifest; move imports/exports to SAF document/tree grants and media output to MediaStore |
| Overlay | `SYSTEM_ALERT_WINDOW` declared | Remove unless a documented, user-initiated, core overlay feature cannot use in-app UI/PiP/bubbles |
| Battery exemption | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` declared | Prefer normal FGS/WorkManager/user-initiated transfer jobs; retain only if the core local-agent service passes accepted-use review and has prominent opt-in |
| Exact alarms | `SCHEDULE_EXACT_ALARM` declared | Use inexact WorkManager/AlarmManager by default; request special access only for a visible user-created exact automation |
| Boot | exported boot receiver can restart work | Make startup opt-in, persisted, idempotent, and user-perceptible; do not resume spending or wallet sessions |
| Sensors/location/camera/mic | broad optional capability set | Request at point of use; remove unused permissions per flavor; document why each capability is expected by the user |
| FGS setup downloads | several `specialUse` services | Use user-initiated data transfer APIs for explicit downloads where possible; keep one Gateway FGS for genuinely continuous visible operation |
| Release size | arm64 base contains libnode, Python packages, native integrations | Measure AAB download/install size and move optional Play-compliant features on demand |
| Shrinking | release minification/resource shrinking disabled | Enable only after keep rules and full regression tests; record before/after size and startup behavior |
| SDK inventory | Flutter, wallet, analytics/network libraries need one disclosure map | Generate SBOM/Gradle dependency report and map every SDK to Data Safety and privacy policy entries |

### 3.3 Play-compatible dependency delivery

Play Asset Delivery is not a solution for executable code: asset packs cannot
contain executable code. Use Play Feature Delivery for code/native modules.

Proposed modules, aligned with the existing signed-pack boundaries:

| Module | Current examples | Play treatment |
| --- | --- | --- |
| `runtime_gateway` | pinned OpenClaw JS and approved runtime resources | Install-time or on-demand Play feature; immutable version receipt |
| `runtime_media` | ffmpeg/gifgrep/songsee | On-demand; prefer JNI/shared-library wrappers over raw command ELFs |
| `runtime_speech` | whisper/sherpa | On-demand; native libraries and models split so non-code models remain assets |
| `runtime_cli` | blue/eightctl/himalaya/openhue/sonos | Do not assume raw CLI ELFs can simply move unchanged; prototype Play-delivered wrapper/module and disable unsupported cards until proven |
| `runtime_terminal` | tmux and rollback helpers | Direct build first; Play build only after exact policy/technical acceptance |
| `runtime_coding` | coding-agent and large libraries | Defer from initial Play release unless size, code delivery, and behavior review pass |

Implementation rules:

1. Add `play` and `direct` product flavors and flavor-specific manifests.
2. Add Play Feature Delivery through current split-install libraries, not the
   obsolete monolithic Play Core dependency.
3. Build one small native-module spike before converting all packs.
4. Validate install, cancellation, process restart, insufficient storage,
   offline, module update, module removal, and corrupt local state.
5. Load dependent native libraries in deterministic order after split install;
   use the Android-recommended approach for on-demand native libraries and test
   it on Samsung and Pixel devices.
6. Record module name/version, ABI, source revision, install source, integrity,
   smoke result, and timestamp in the existing dependency receipt UI.
7. Never fall back from a missing Play module to a GitHub executable download.
8. Skills whose module is absent show `Available download from Google Play`,
   not `Missing dependency`; skills excluded from the Play lane show an honest
   compatibility explanation.

### 3.4 OpenClaw and skill-code release boundary

Create a release-policy manifest generated at build time:

```text
distribution: play | direct
gateway_source: play_module | official_upstream
gateway_version: exact semver
gateway_integrity: sha256/integrity
native_pack_source: play_feature | signed_github | disabled
paid_workflows: play_billing | approved_regional | disabled
proot: user_requested_only
```

For `play`:

- disallow arbitrary npm lifecycle scripts;
- pin Gateway and first-party skill revisions;
- maintain a signed allowlist of downloadable non-executable content;
- classify skill downloads by capability and data handling;
- prevent a downloaded skill from expanding Android permissions;
- keep command execution inside the current bounded mobile tool/capability
  layer;
- make remote revocation disable a vulnerable skill without downloading
  replacement executable code;
- ask Google Play policy support for written guidance before re-enabling
  externally downloaded interpreted Gateway updates.

For `direct`, retain the existing official-upstream and signed-receipt design,
but preserve all integrity, resume, no-redownload, and exact-version checks.

### 3.5 Signing, bundle, and supply chain

- Create a production upload key outside the repository and back it up in two
  controlled locations.
- Enroll the Play app in Play App Signing.
- Load signing credentials only through CI secret storage or a local untracked
  properties file.
- Add a Gradle assertion that rejects a release using debug signing.
- Build an AAB, then inspect generated split APKs with `bundletool`.
- Run secret scans and inspect packaged assets for API keys, wallet material,
  RPC credentials, logs, receipts, private GitHub URLs, debug certificates, and
  development endpoints.
- Produce SHA-256, versionName/versionCode, Git commit, dependency lock state,
  SBOM, native provenance, and Play policy-manifest records for every candidate.
- Keep APKs, AABs, signing files, reports with secrets, and temporary artifacts
  out of Git.
- Use staged internal, closed, open, then production tracks with crash/ANR and
  startup monitoring gates.

### 3.6 Privacy, account, financial, and store declarations

Publish these HTTPS routes on `plawie.app` before open testing:

- `/privacy`
- `/terms`
- `/support`
- `/account-deletion` if Plawie enables account creation, or a clear page that
  explains that Plawie has no account and links to applicable third-party
  account controls.

Build a field-level data inventory covering:

- prompts, responses, model/provider identifiers, API keys, and provider account
  state;
- Gateway logs and crash diagnostics;
- wallet public addresses, chain selections, balances, quotes, transaction
  hashes, and redacted receipts;
- microphone/audio, camera/images, screen capture, location, sensors, files,
  calendar/contacts if later added, and user-selected skill credentials;
- Reown relay/session metadata, LI.FI/Relay requests, KeeperHub identifiers, and
  every third-party SDK/network endpoint;
- retention, local-vs-transmitted status, encryption, deletion, and user control.

Console work:

- use an organization developer account and complete identity/D-U-N-S setup;
- complete Data Safety for every SDK and server path;
- complete Financial Features declaration, including non-custodial wallet,
  transfers, bridging, and any crypto-related feature that Play asks to classify;
- complete foreground-service declarations and provide trigger/stop videos;
- complete restricted-permission declarations only for permissions that remain;
- complete content rating, target audience, ads declaration, app access/review
  instructions, and demo credentials that expose no real funds;
- prepare wallet/financial licensing evidence for each launch jurisdiction;
- do not target children for the first wallet-enabled release;
- do not describe Plawie as an exchange, custodian, guaranteed investment,
  earning product, or autonomous spender.

### 3.7 Target and device quality

The project already targets/compiles API 36. Maintain that baseline and verify
the applicable Play deadline immediately before submission.

Add release gates for:

- 16 KB page-size compatibility for every `.so` in every split;
- arm64 physical devices from Google and Samsung;
- Android 10 through current Android, with emphasis on Android 14-16 background
  execution and permission behavior;
- cold start, warm start, setup resume, Gateway restart, low storage, low memory,
  network loss, process death, device reboot, and app update;
- ANR, strict-mode, leaked service, notification duplication, and battery use;
- accessibility, font scaling, screen sizes, orientation, keyboard, and TalkBack;
- Play pre-launch report, automated device catalog, and a human closed-track
  acceptance pass.

---

## 4. KeeperHub architecture decision

### 4.0 Winning product amendment

The hackathon implementation is not a generic KeeperHub transfer client. Its
product thesis is:

> Plawie is the human-governed mobile wallet for AI agents: the agent reasons,
> KeeperHub executes reliably, and the human remains the final authority.

The Wallet page will expose two deliberately separate identities:

| Wallet | Custody and purpose | Authority |
| --- | --- | --- |
| **Personal Wallet** | Plawie self-custodial EVM wallet encrypted by Android Keystore | The user; signs only after visible review and device authentication |
| **Agent Execution Wallet** | KeeperHub-managed organization wallet used for bounded automation and execution | KeeperHub/Turnkey custody, with every Plawie-initiated write additionally gated by Plawie's human approval coordinator |

The Agent Execution Wallet must never be presented as the Personal Wallet, use
the same balance card without a custody label, or imply that its key can be
exported/recovered through Plawie's existing wallet backup. Funding, balances,
receipts, and risk copy remain separate.

The hackathon differentiator is the complete mobile execution lifecycle:

```text
chat/agent proposes typed intent
        -> KeeperHub simulates
        -> Plawie binds the simulation to an immutable request
        -> visible review + fresh Android authentication
        -> KeeperHub executes once with persisted idempotency
        -> Plawie survives interruption and reconciles verified proof
```

This is crucial to Plawie's architecture: OpenClaw supplies reasoning and skill
selection, the app supplies wallet ownership and human governance, and
KeeperHub supplies the execution/reliability layer. Removing any one of the
three makes the demonstration materially weaker.

### 4.1 What KeeperHub adds

KeeperHub is useful where Plawie currently has an intent, wallet, bridge, and
payment layer but not a reusable onchain workflow execution system:

- discoverable typed workflows;
- server-side workflow orchestration and observability;
- dry-run simulation before direct writes;
- stable idempotency keys and execution IDs;
- bounded status polling and verified transaction receipts;
- workflow marketplace calls that may return unsigned calldata;
- paid workflow challenges over x402;
- an auditable transaction link suitable for support and the hackathon.

It is not needed for wallet creation, key custody, Base/Robinhood network
switching, generic bridges, or existing direct x402 AI-provider payments.

### 4.2 What must not be imported

Do not copy or embed the complete KeeperHub backend. The open repository is a
Next.js/server/database/worker product with organization wallets and Turnkey
custody; it is not an Android-native library.

Do not copy these behaviors into Plawie:

- auto-approve below a dollar threshold;
- agent-side transparent payment and retry;
- organization/API-key writes available directly to the model;
- server-custodial wallet presented as the user's Plawie wallet;
- retrying a timed-out broadcast without first reconciling execution/chain
  status;
- mutable workflow writes without a typed allowlist and a visible review;
- unbounded workflow creation, integration mutation, or notification side
  effects from chat.

### 4.3 Headless onboarding and identity binding

KeeperHub documents a supported headless SIWE path. Plawie will use the
Personal Wallet to establish the user's KeeperHub identity without asking the
user to copy an API key from a browser:

1. Request a nonce from `POST /api/auth/siwe/nonce` for the exact Personal
   Wallet address.
2. Construct the fixed KeeperHub EIP-4361 message for
   `https://app.keeperhub.com` and chain-id assertion `1`.
3. Show a Plawie-owned sign-in review and require fresh Android authentication.
4. Sign only after native code validates the exact domain, URI, statement,
   wallet, nonce, issued-at window, and purpose. No generic `personal_sign`
   bridge is exposed to Dart, OpenClaw, or the model.
5. Verify SIWE and retain the returned session cookies in memory only.
6. Request an organization API key. The first request returns the
   `org_api_key_manage` step-up challenge.
7. Show a second visible key-creation review and require a second bounded,
   device-authenticated signature over that exact challenge.
8. Store the returned-once `kh_` credential in Flutter secure storage; store no
   credential in SharedPreferences, Gateway configuration, logs, receipts,
   screenshots, analytics, or model context.
9. Read and display KeeperHub's organization wallet address separately from the
   Personal Wallet address.

The local record stores only the minimum reconnect/revocation metadata: API key
identifier, organization wallet address, Personal Wallet address used for SIWE,
creation time, and last verified KeeperHub request ID. Session cookies are
ephemeral. A reconnect obtains a fresh nonce rather than replaying a signature.

Disconnect must mean revoke, not merely hide:

- reauthenticate with a fresh SIWE session;
- request the API-key deletion step-up challenge;
- visibly approve and sign the exact revocation challenge;
- revoke the remote key;
- clear the local secret only after a terminal remote response, or clearly mark
  `revocationUnknown` and retain recovery instructions.

Because this flow creates a KeeperHub account/organization, the product must
also expose an accurate route to KeeperHub account deactivation and update
Plawie's account-deletion/privacy pages before public release.

### 4.4 Recommended integration modes

#### Mode A: Plawie-signed workflow execution — product default

```text
Agent proposes a typed KeeperHub workflow
        -> Plawie fetches listing/schema
        -> KeeperHub returns read result or unsigned write calldata
        -> Plawie validates chain/to/value/data/expiry
        -> Plawie performs an independent trusted-RPC simulation
        -> visible review sheet
        -> fresh Android device authentication
        -> Plawie wallet or connected external wallet signs
        -> Plawie submits and records a redacted receipt
```

This preserves Plawie's non-custodial wallet and approval model. It is the best
long-term product fit. Confirm whether the selected KeeperHub workflow and API
surface provide sufficient execution proof for any hackathon requirement that
specifically expects KeeperHub to broadcast the transaction.

#### Mode B: KeeperHub-managed direct execution — explicit optional provider

```text
Agent proposes a typed transfer/contract call
        -> app-owned KeeperHub client sends simulate:true
        -> response is canonicalized and bound to an intent
        -> visible review names KeeperHub org wallet and custody boundary
        -> fresh human approval and Android device authentication
        -> app-owned client sends the exact reviewed body once
           with a persisted idempotency key
        -> app polls execution status using server hint
        -> verified receipt and transaction link are stored redacted
```

Mode B is the primary hackathon vertical slice and remains an explicit optional
provider afterward. It uses a KeeperHub organization wallet, not the Plawie
wallet. The UI must show the address, chain, funding source, spending cap,
custody model, recipient, amount, contract/function, reason, simulation result,
idempotency state, and receipt source.

### 4.5 Agent capability boundary

Expose only app-owned capabilities:

```text
keeperhub.capabilities   read-only
keeperhub.search         read-only marketplace search
keeperhub.inspect        read-only listing/schema details
keeperhub.prepare        runs preflight and persists an inert proposal
keeperhub.simulate       preflight only; never signs or broadcasts
keeperhub.status         read-only execution status
keeperhub.receipts       redacted local history
```

The implemented hackathon subset registers only `keeperhub.capabilities`,
`keeperhub.status`, `keeperhub.receipts`, and `keeperhub.prepare` (plus the
standard underscore aliases). Marketplace search/inspect and a separate generic
simulation command remain Phase 6 work and are not advertised prematurely.
`keeperhub.prepare` internally performs only the fixed zero-value proof
simulation described below.

The agent may propose inputs and explain results. The agent must not approve,
unlock, sign, submit, retry, release a hold, create a deposit instruction,
create/delete workflows, mutate integrations, or access credentials.

Initially deny or omit all KeeperHub `execute_*`, `execute_workflow`, wallet
mutation, integration mutation, workflow CRUD, listing mutation, Tempo hold,
cancel, and release tools. If a per-workflow MCP endpoint is later used, register
only an individually reviewed slug/schema and still intercept writes in the
app-owned coordinator.

For the hackathon proof, chat may prepare only a zero-value Base Sepolia
self-transfer. The capability asks KeeperHub to simulate the fixed transfer,
then persists an inert proposal in Plawie's receipt store. It cannot approve,
authenticate, submit, retry, revoke, or invoke a generic KeeperHub write. Only
the foreground Wallet approval host can review the proposal and invoke the
coordinator after fresh device authentication.

### 4.6 Proposed modules

```text
lib/services/keeperhub/
  keeperhub_api_client.dart
  keeperhub_auth_store.dart
  keeperhub_headless_onboarding_service.dart
  keeperhub_models.dart
  keeperhub_policy.dart
  keeperhub_execution_coordinator.dart
  keeperhub_approval_broker.dart
  keeperhub_receipt_store.dart
  keeperhub_wallet_controller.dart

lib/services/capabilities/
  keeperhub_capability.dart

lib/widgets/
  keeperhub_agent_wallet_card.dart
  keeperhub_execution_review_dialog.dart

lib/services/
  sensitive_approval_surface.dart

android/app/src/main/kotlin/com/openclaw/plawie/
  KeeperHubMessagePolicy.kt

test/services/keeperhub/
  keeperhub_api_client_test.dart
  keeperhub_headless_onboarding_service_test.dart
  keeperhub_policy_test.dart
  keeperhub_execution_coordinator_test.dart
  keeperhub_approval_broker_test.dart
  keeperhub_receipt_store_test.dart
```

Responsibilities:

- API client: fixed HTTPS origin, bounded payload/response sizes, timeouts,
  no redirects, cookie-origin discipline for session calls, rate-limit handling,
  request IDs, strict JSON parsing, and no secret-bearing exception strings.
- Auth store: KeeperHub OAuth/API credential in Flutter secure storage; never
  SharedPreferences, Gateway config, model context, logs, receipts, or crash
  reports. Prefer user OAuth when KeeperHub supports the mobile redirect safely.
- Headless onboarding: fresh SIWE nonce, bounded native signatures, ephemeral
  cookies, organization-key step-up, organization wallet discovery, reconnect,
  key rotation, and fail-closed revocation.
- Policy: live `GET /api/chains`, allowlisted chains/contracts/functions,
  maximum amount, exact decimal handling, recipient validation, no arbitrary
  calldata in the first release.
- Coordinator: one active intent, simulation binding, one-use visible approval,
  fresh Android authentication, and a persisted idempotency key before send.
  Recovery polls an existing execution ID first; if the first response never
  supplied an ID, an explicit recovery may replay only the immutable body with
  the same key. It never rotates the key or starts different work silently.
- Approval attestation: native code reconstructs and validates a canonical
  Plawie approval statement, then uses the Personal Wallet after device
  authentication. Store the approval digest and approver address, never the raw
  signature. This proves what the local user approved but does not falsely imply
  that KeeperHub cryptographically requires that signature.
- Receipt store: execution ID, stable request fingerprint, redacted addresses,
  chain, asset, amount, status, transaction hash/link, request ID, and timestamps;
  no token, signature, raw calldata, prompt, or secret.
- Capability: typed read/propose interface only. The visible Wallet/Automation
  UI owns execution.

Reuse `X402PaymentApprovalService`, `X402PaymentTransportService`, the paid
provider approval host, bridge receipt transition rules, and Android's secure
signer where their invariants match. Do not duplicate approval state machines.

### 4.7 Idempotency and unknown outcomes

- Persist a deterministic work ID and request fingerprint before first submit.
- Keep the exact simulated body immutable through approval and execution.
- Use one persisted KeeperHub `Idempotency-Key` for the work, not a new UUID per
  network attempt.
- A timeout after submission becomes `outcomeUnknown`.
- On resume, query KeeperHub execution status and chain receipt when an
  execution ID exists. If submission failed before an ID was returned, allow
  only an explicit recovery using the exact persisted body and idempotency key.
- Honor KeeperHub's poll interval hint and stop at a bounded deadline.
- Treat a replay response as the original outcome, not new execution.
- Treat idempotency conflict as a security/reconciliation failure.
- Never convert “receipt persistence failed” into a prompt to pay again.

### 4.8 x402 paid workflows

KeeperHub marketplace writes can return x402 challenges. Plawie's existing Base
USDC EIP-3009 path already has the correct high-level shape: allowlisted HTTPS
host, exact request/challenge binding, visible approval, device-authenticated
signature, one paid retry, and receipt.

Integration work:

1. Add KeeperHub hosts and payment contracts only through a reviewed provider
   catalog entry.
2. Parse the KeeperHub challenge into the existing strict x402 model.
3. Show workflow fee separately from any onchain action value/gas.
4. Require a separate visible approval for workflow payment and execution.
5. Never use KeeperHub's transparent agent-wallet auto-pay behavior.
6. Record separate payment and workflow execution receipts.
7. Disable paid KeeperHub workflows in `play` unless the Play billing/legal gate
   for that country is complete.

### 4.9 Chain scope

KeeperHub's documented stable networks currently include Base and Base Sepolia,
but not Robinhood Chain. Always query `GET /api/chains` and treat it as the live
source of truth.

Initial scope:

- Base Sepolia for development and hackathon acceptance;
- Base Mainnet only after controlled testnet evidence and fresh user approval;
- no KeeperHub Robinhood, Solana, bridge, or cross-chain claim until the live API
  reports support and Plawie's policy/transport is reviewed;
- retain LI.FI, Relay, Reown, and Solana MWA for existing funding/bridge roles.

### 4.10 Production cryptographic authority

The hackathon path uses a locally enforced Plawie approval plus KeeperHub's
managed organization wallet, low testnet value, server-side caps, and a secret
that never reaches the agent. That is appropriate for the testnet vertical
slice, but the local gate alone is not the final production authority: a stolen
KeeperHub bearer credential could call the API outside Plawie.

The production target is a multi-owner Safe or equivalent policy-bound account:

- KeeperHub remains the execution/reliability signer;
- the Plawie Personal Wallet is an additional owner/approver;
- threshold is greater than one for value-moving actions;
- KeeperHub workflows route through audited function/argument allowlists;
- per-token and per-recipient caps are enforced onchain;
- Plawie presents and signs the exact Safe transaction after human approval.

KeeperHub's current Safe wizard uses a one-owner, threshold-one account. Its
documentation correctly states that the owner can bypass Zodiac Roles and that
multi-owner schemas can close that gap. Therefore the app must not market the
initial managed wallet as cryptographically human-co-signed. Coordinate the
multi-owner integration with KeeperHub before meaningful Mainnet balances or
autonomous schedules are allowed.

If multi-owner execution is unavailable, production Agent Wallet mode remains
optional, minimally funded, visibly custodial, capped, and individually
human-approved. The Personal Wallet remains the user's vault.

### 4.11 Open-source code intake

KeeperHub's repository is Apache-2.0. Prefer implementing the API contract from
official docs. If source is adapted rather than merely studied:

- pin the exact upstream commit reviewed, including branch; the current
  implementation-rich snapshot reviewed for this plan was KeeperHub `staging`
  commit `9a707f09ff5c939c411e3881ab11f63514a6da1a`;
- import only the smallest policy-neutral unit;
- preserve copyright/license notices and add `THIRD_PARTY_NOTICES.md`;
- identify original file/commit and document Plawie modifications in the port;
- add unit/property tests in Dart/Kotlin rather than trusting TypeScript tests;
- rerun security review whenever updating the pinned source.

Useful patterns to adapt conceptually:

- stable error envelopes and request IDs;
- strict simulation response classification;
- persisted idempotency and request fingerprints;
- reserved spending caps and terminal receipt reconciliation;
- narrow typed tool catalogs;
- x402 payment fingerprinting.

Do not vendor KeeperHub's backend, database, workers, wallet custody, or generic
broadcast retry loop into the APK.

---

## 5. Post-deployment wallet acceptance plan

No automated test may submit a Mainnet transaction. Mainnet steps require a
fresh explicit instruction at the moment of execution.

### 5.1 Web and Reown preconditions

- [ ] Deploy `codex/plawie-landing-site` to Netlify production.
- [ ] Confirm `https://plawie.app` resolves, has a valid certificate, and loads
      without mixed content or redirect loops.
- [ ] Confirm `www.plawie.app` has the chosen canonical redirect.
- [ ] Confirm `/privacy`, `/terms`, `/support`, and the account-deletion decision
      page are publicly reachable.
- [ ] In Reown Dashboard, allow exact origin `https://plawie.app`.
- [ ] Add mobile application ID `com.openclaw.plawie` and any reviewed flavor ID.
- [ ] Confirm native callback `plawie://wallet-callback` returns to the exact
      pending intent and rejects unrelated/stale callbacks.
- [ ] Do not claim Reown Link Mode/App Links until `assetlinks.json`, HTTPS
      universal links, certificate fingerprints, and intent filters are added
      and verified.

### 5.2 Non-spending device acceptance

- [ ] Record current Plawie wallet address and app first-install timestamp.
- [ ] Install with `adb install -r`; do not clear data or uninstall.
- [ ] Prove the same wallet address and secure state survive app update/relaunch.
- [ ] Confirm Base Mainnet opens first and chain switching does not change the
      EVM address or mix balances between networks.
- [ ] Confirm wallet export, import, remove, and damaged-key recovery require the
      documented Android authentication/destructive warnings.
- [ ] Open Reown wallet chooser and test installed-wallet discovery without
      `QUERY_ALL_PACKAGES`.
- [ ] Cancel and return from MetaMask, Trust, Coinbase Wallet, Phantom, Solflare,
      and any available WalletConnect-compatible wallet without stale sessions.
- [ ] Test wrong account, wrong chain, rejected request, wallet locked, app
      backgrounded, browser fallback, callback timeout, and process death.
- [ ] Confirm an external wallet request shows the exact reviewed amount,
      recipient, chain, route, minimum output, fees, and expiry.
- [ ] Confirm LI.FI/Relay quote expiry forces a fresh quote and never silently
      substitutes new calldata.
- [ ] Confirm one-time deposit address instructions cannot be recreated or
      marked complete by chat.
- [ ] Confirm cancel/reject never advances to provider top-up.
- [ ] Confirm Gateway stays native and no wallet action starts PRoot.

### 5.3 Testnet transaction acceptance

- [ ] Fund a dedicated low-value Base Sepolia test wallet.
- [ ] Run read-only Base Sepolia balance and chain checks.
- [ ] Run KeeperHub `simulate:true` with an intentionally invalid recipient/body
      and prove it fails closed.
- [ ] Simulate a valid tiny transfer and bind the result to a local intent.
- [ ] Cancel at review; prove no KeeperHub execution ID or transaction exists.
- [ ] Approve a new intent, complete device authentication, submit exactly once,
      and poll to a terminal verified receipt.
- [ ] Kill/restart the app after submit and prove recovery uses the same
      idempotency key and does not double-execute.
- [ ] Save transaction link, redacted local receipt, KeeperHub request ID, and
      app logs with secrets removed.
- [ ] Repeat one x402 paid-workflow test only with test/dispensable funds and a
      separate payment approval.

### 5.4 Controlled Mainnet acceptance

After all testnet gates pass and only with fresh authorization:

- [ ] Use a dedicated wallet with a deliberately tiny balance.
- [ ] Test one inbound bridge route into Base USDC; external wallet approval is
      the first independent confirmation.
- [ ] Wait for provider and onchain finality; do not infer completion from app
      return or one optimistic API response.
- [ ] Refresh Base balance and obtain a new provider challenge.
- [ ] Show a second Plawie approval for x402/top-up; require device auth.
- [ ] Confirm no duplicate notifications, payment retries, or receipts.
- [ ] If KeeperHub managed execution is tested, clearly fund and identify the
      separate KeeperHub organization wallet and use the smallest safe value.
- [ ] Reconcile bridge, payment, and KeeperHub execution as three distinct
      receipt types.

### 5.5 Regression matrix

- [ ] Native Gateway startup, health, pairing, model discovery, context,
      streaming, and restart.
- [ ] Skills readiness/receipt refresh and no redundant pack downloads.
- [ ] Chat has no duplicate assistant message.
- [ ] Canvas, gifgrep, voice/TTS, terminal fallback messaging, and notifications.
- [ ] Offline/reconnect, low battery, low storage, process death, and reboot.
- [ ] No API key, OAuth token, HMAC, private key, signature, raw calldata, prompt,
      or full wallet address in logs/crash reports.
- [ ] Flutter tests, analyzer, Android JVM tests, lint, AAB build, secret scan,
      artifact scan, and physical-device smoke.

---

## 6. Implementation phases

### Phase 0 — Lock release architecture and policy evidence

- [ ] Approve `play`/`direct` package IDs and migration UX.
- [ ] Add flavor matrix and policy manifest design.
- [ ] Obtain organization Play developer account/D-U-N-S readiness.
- [ ] Record legal entity and intended launch countries.
- [ ] Open Play policy support questions for interpreted Gateway updates and
      wallet/AI-credit payment classification.
- [ ] Convert this plan into tracked issues with owner, evidence link, and gate.

**Exit:** no unresolved decision can force a package-ID, signing, payment, or
code-delivery redesign after closed testing begins.

### Phase 1 — Play build and manifest hardening

- [ ] Add flavors and flavor-specific source sets/manifests.
- [ ] Remove GitHub native-pack transport from `play` at compile time.
- [ ] Replace debug release signing with protected upload signing.
- [ ] Remove broad storage/legacy flags from Play.
- [ ] Audit and reduce overlay, alarm, battery, boot, sensor, location, camera,
      microphone, Termux, and foreground-service declarations.
- [ ] Replace broad cleartext with a tested local-Gateway network policy.
- [ ] Add build assertions and artifact inspection tests.

**Exit:** a Play AAB cannot fetch external executable code and fails CI if it
contains debug signing, forbidden permissions, secrets, or direct-only URLs.

### Phase 2 — Play-delivered native modules

- [ ] Implement one small dynamic-feature/native-loading spike.
- [ ] Test module install/update/cancel/restart across physical devices.
- [ ] Define module receipts and skills readiness states.
- [ ] Port approved media/speech runtimes progressively.
- [ ] Keep unsupported CLI/coding/terminal skills honestly disabled.
- [ ] Pin and Play-deliver the reviewed OpenClaw Gateway package.

**Exit:** fresh Play install reaches a native Gateway and every enabled skill is
backed only by base/Play-delivered executable code.

### Phase 3 — Billing, privacy, financial, and Console readiness

- [ ] Publish legal/support/deletion pages.
- [ ] Complete field-level data/SDK map.
- [ ] Implement Play Billing or region-gate/disable digital-credit purchases.
- [ ] Complete financial/jurisdiction review.
- [ ] Prepare Data Safety, Financial Features, FGS, permissions, app access,
      content, and audience declarations.
- [ ] Create store listing assets and review instructions.

**Exit:** Console forms match actual binary/network behavior and all purchase
surfaces are correct for the install country/build.

### Phase 4 — Deploy site and accept wallets

- [ ] Deploy `plawie.app` and configure Reown restrictions.
- [ ] Run sections 5.1-5.3 without Mainnet spending.
- [ ] Fix and repeat all failed paths.
- [ ] Run controlled Mainnet section only after fresh approval.

**Exit:** persisted wallet identity, external-wallet handoff, bridge recovery,
separate payment approval, and receipts are proven on a physical device.

### Phase 5 — KeeperHub hackathon vertical slice

The current event material indicates a 2026-08-13 deadline, so the slice must be
narrow and demonstrable rather than a premature platform rewrite.

- [x] Add fixed-origin REST client, strict errors/request IDs, bounded payloads,
      and ephemeral cookie handling.
- [x] Implement bounded native SIWE/key-management signing and the onboarding
      service from the Personal Wallet, including organization-key step-up,
      secure-storage preflight, returned-once key storage, and provisioning
      recovery after restart.
- [x] Expose onboarding through explicit Wallet UI consent; creation never runs
      from startup, setup, chat, or card rendering.
- [ ] Complete one physical-device KeeperHub account/organization acceptance
      run.
- [x] Show Personal Wallet and Agent Execution Wallet as separate cards with
      explicit custody, chain, address, funding, and risk copy.
- [x] Add typed Base Sepolia native transfer intent only; begin with a zero-value
      self-transfer recommended by KeeperHub to prove the sponsored path safely.
- [x] Implement the execution reliability core: simulation, immutable request
      binding, one-use foreground approval broker, device-authenticated local
      attestation, persisted idempotency key, single submission, bounded poll,
      restart recovery, and redacted verified receipt.
- [x] Wire the approval broker to the visible Wallet review sheet and app
      foreground lifecycle host.
- [x] Share one exclusive screen-capture-protected approval surface between
      paid-provider and Agent Wallet reviews so dialogs cannot overlap or clear
      each other's secure state.
- [x] Add automated failure coverage for cancellation, missing foreground UI,
      tampered receipts, deliberate simulation failure, ambiguous submission,
      status-only recovery, and mismatched transaction receipts.
- [ ] Demonstrate reject/cancel and a deliberately failing simulation before any
      successful write.
- [ ] Submit one real zero-value Base Sepolia KeeperHub transaction, interrupt
      the app/network during polling, reopen, and prove recovery reaches the same
      execution without a duplicate transaction.
- [ ] Follow with one tiny non-zero testnet USDC workflow when test funds and the
      exact reviewed contract are available.
- [x] Add chat proposal and status/receipt tools, while keeping approval and
      execution owned by the foreground Wallet UI.
- [x] Implement device-authenticated remote API-key revocation through
      `DELETE /api/keys/{keyId}`. Clear local credentials only after confirmed
      revocation or an already-unavailable response; otherwise retain the
      encrypted credential in an honest `revocationUnknown` recovery state.
- [ ] Treat paid x402 marketplace workflow execution as a stretch goal after the
      core reliability demo passes.
- [ ] Capture Git source link, demo video, onboarding sequence, simulated failure,
      interruption recovery, KeeperHub execution ID, and verified transaction
      link required by the event.

**Exit:** a judge can create a real Agent Execution Wallet inside Plawie, ask the
OpenClaw agent for an action, inspect a real KeeperHub simulation, authorize it
on the phone, watch KeeperHub execute it, interrupt and resume the app without a
duplicate, and inspect independently verifiable proof—without autonomous spend,
manual API-key copying, or exposed credentials.

### Phase 6 — KeeperHub production integration

- [ ] Add OAuth if its mobile security/redirect model passes review.
- [ ] Add marketplace search/inspect and selected per-workflow schemas.
- [ ] Add Plawie-signed unsigned-calldata mode.
- [ ] Add paid-workflow x402 through the existing approval transport.
- [ ] Add allowlisted contract/function policies and spending caps.
- [ ] Add support diagnostics, revocation, token rotation, receipt export, and
      account disconnect/deletion handling.
- [ ] Reassess Play billing and financial declarations before enabling any paid
      KeeperHub function in `play`.

**Exit:** KeeperHub is optional, revocable, observable, narrowly permissioned,
and cannot move funds without a fresh Plawie review and human approval.

---

## 7. Inputs still required from the release owner

- Netlify production deployment confirmation for `plawie.app`.
- Reown Dashboard domain/application-ID allowlist confirmation.
- Google Play organization account status and D-U-N-S/legal entity details.
- Intended first-release countries.
- Production upload-key ownership and backup decision.
- Decision on canonical Play/direct application IDs.
- Permission to create a test KeeperHub account/organization through the
  documented SIWE flow. No pasted API key is required; the app creates and
  stores its own organization key after two visible device-authenticated
  signatures.
- A dedicated low-value Base Sepolia/KeeperHub test wallet.
- Production `ROBINHOOD_RPC_URL` if internal Robinhood sends remain in scope.
- Fresh explicit authorization before any Mainnet bridge, transfer, x402 payment,
  or KeeperHub broadcast.

---

## 8. Acceptance definition

This program is complete only when:

1. the Play AAB contains no external native executable download path;
2. release signing, AAB, 16 KB native compatibility, SDK/privacy evidence, and
   Play declarations pass;
3. native Gateway remains primary and PRoot remains user-demand fallback;
4. every enabled Play skill has a Play-delivered or non-executable dependency;
5. wallet state survives normal app updates and every spend requires fresh
   visible approval;
6. bridge, provider payment, and KeeperHub execution cannot silently chain into
   one approval;
7. KeeperHub credentials never enter the Gateway/model context and its raw write
   tools are not exposed;
8. testnet restart/idempotency acceptance proves no duplicate execution;
9. production wallet/payment gates remain off until controlled Mainnet evidence
   and legal/Play gates are complete;
10. the published privacy, support, store, and financial claims match the binary
    users actually install.

---

## 9. Primary sources

### Google Play and Android

- Device and Network Abuse, including external executable code and foreground
  services: <https://support.google.com/googleplay/android-developer/answer/16559646?hl=en>
- Payments policy: <https://support.google.com/googleplay/android-developer/answer/9858738?hl=en>
- Cryptocurrency exchanges and software wallets:
  <https://support.google.com/googleplay/android-developer/answer/16329703?hl=en>
- Blockchain-based content:
  <https://support.google.com/googleplay/android-developer/answer/13607354?hl=en>
- Financial Features declaration:
  <https://support.google.com/googleplay/android-developer/answer/13849271?hl=en>
- Organization accounts and D-U-N-S:
  <https://support.google.com/googleplay/android-developer/answer/13634885?hl=en>
- All Files Access:
  <https://support.google.com/googleplay/android-developer/answer/10467955?hl=en>
- Foreground-service declarations:
  <https://support.google.com/googleplay/android-developer/answer/13392821?hl=en>
- Data Safety:
  <https://support.google.com/googleplay/android-developer/answer/10787469?hl=en>
- Account deletion:
  <https://support.google.com/googleplay/android-developer/answer/13327111?hl=en>
- Privacy policy requirements:
  <https://support.google.com/googleplay/android-developer/answer/17190352?hl=en>
- Package visibility:
  <https://support.google.com/googleplay/android-developer/answer/10158779?hl=en>
- Target API requirements:
  <https://developer.android.com/google/play/requirements/target-sdk>
- 16 KB page sizes:
  <https://developer.android.com/guide/practices/page-sizes>
- Play Feature Delivery:
  <https://developer.android.com/guide/playcore/feature-delivery/on-demand>
- Play Asset Delivery limitations:
  <https://developer.android.com/guide/playcore/asset-delivery>

### KeeperHub

- API overview: <https://docs.keeperhub.com/api>
- Authentication: <https://docs.keeperhub.com/api/authentication>
- Direct execution and idempotency:
  <https://docs.keeperhub.com/api/direct-execution>
- MCP server and per-workflow tools:
  <https://docs.keeperhub.com/ai-tools/mcp-server>
- Agentic wallet custody and safety model:
  <https://docs.keeperhub.com/ai-tools/agentic-wallet>
- Hackathon quickstart and live chain source:
  <https://docs.keeperhub.com/quickstart>
- Headless SIWE onboarding, organization wallet discovery, gas sponsorship, and
  zero-value proof transaction:
  <https://docs.keeperhub.com/api/headless-onboarding>
- Safe signer modes, Zodiac policies, owner-bypass limitation, and multi-owner
  boundary: <https://docs.keeperhub.com/wallet-management/safe>
- Apache-2.0 source: <https://github.com/KeeperHub/keeperhub>
- Official company/event material, including the 2026-07-27 to 2026-08-13 build
  window and real-transaction requirement:
  <https://www.linkedin.com/company/keeperhub>
