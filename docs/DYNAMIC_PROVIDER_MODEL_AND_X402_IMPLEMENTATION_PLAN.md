# Dynamic Providers, Models, Accounts, and Human-Approved x402

Status: approved plan; Phases 1-3 implementation in progress

Date: 2026-08-04

Owner: Plawie native app and OpenClaw Gateway integration

## 1. Purpose

This document is the implementation contract for replacing Plawie's mostly
static cloud-provider and model catalog with a dynamic, provider-aware catalog
while preserving the current native-first Gateway architecture. It also defines
the later x402 payment path, including use of the app's internal Base wallet
without allowing an AI agent, model response, or chat command to spend funds
without explicit human approval.

The work is intentionally staged. Dynamic discovery, account connection, model
selection, and payments are separate concerns. A provider being visible in the
catalog must not imply that it is authenticated, agent-compatible, or permitted
to charge a wallet.

This plan supersedes the earlier idea of adopting OmniRoute as an app-wide
gateway. OmniRoute is not part of the implementation target. Plawie continues to
use the official OpenClaw Gateway downloaded from its official distribution path,
with the native Node runtime as primary and PRoot as an opt-in fallback only.

## 2. Decisions that are already made

### 2.1 Native-first runtime remains unchanged

- Cloud Agent Mode continues to run through the native OpenClaw Gateway.
- Private Offline Mode continues to use the existing fllama/NDK path directly.
- The compact NDK bridge remains a special, deliberately constrained lane.
- PRoot remains a fallback selected by the user or by an explicit recovery path;
  it is not a silent replacement for native setup.
- Dynamic provider/model discovery must not move cloud inference into a new
  direct-HTTP chat runtime.

### 2.2 The official provider owns its gateway and account semantics

Plawie will discover the latest model metadata from each supported provider's
documented endpoint when the provider supports discovery. Plawie will not wrap,
re-publish, or silently replace the official OpenClaw gateway release. The app
may cache provider metadata and selected configuration locally, but it will not
pretend that a cached model list is the provider's live service.

### 2.3 The first UI will stay intentionally small

The model picker needs to solve provider grouping and model discovery, not become
a trading terminal. The initial filters are:

- provider/vendor grouping and expand/collapse;
- search within the currently expanded provider or across all loaded providers;
- an optional `Agent-ready`/tool-capability filter once capability data is
  trustworthy;
- modality only when it is needed by an actual current tool path, such as text
  versus vision.

The first release will not add `Fast`, price-range, context-size, or
`last-refreshed` filters. Price and context can be shown as secondary details if
they are useful, but they are not selection filters. Those filters can be added
later only after usage evidence shows that they reduce friction rather than
increase UI complexity.

### 2.4 Context behavior is a compatibility boundary

Changing the selected cloud model is allowed to change the provider/model
configuration and the provider request's safe output budget. It must not change:

- the stored chat history or session identity;
- the Gateway system prompt and mobile tool policy;
- the set of registered native tools or skill capability context;
- the tool schemas sent to the model, except for an explicit existing tool-policy
  decision;
- the native/PRoot runtime owner;
- the direct local NDK context compaction rules;
- the existing Gateway-versus-direct-local execution lane.

Remote `contextWindow` and `maxTokens` values are untrusted metadata for policy
input. They are never copied directly into a request as an unlimited output
budget. A missing or suspicious value must make the model less permissive, not
more permissive.

### 2.5 Internal Base wallet is a signer, never an unattended allowance

The existing app-controlled Base wallet may become the signing surface for x402,
but only through a pending payment intent and an explicit human approval event.
The following are prohibited:

- an agent deciding that a payment is approved;
- a model response containing a transaction that the app signs automatically;
- a chat command such as “yes” being treated as wallet approval;
- a retry loop that signs the same or a changed payment without another policy
  check;
- exposing the raw private key to Gateway, skills, tools, prompts, logs, or
  provider adapters.

The first payment implementation must use x402 v2, Base Sepolia, the `exact`
scheme, USDC through EIP-3009, small limits, and one test provider. Mainnet,
`upto`, Permit2, ERC-7710, recurring permissions, and additional assets are
separate release decisions.

### 2.6 Research verdict: sound flow, wallet hardening required

The human-approval flow is logical and aligns with x402, but human approval is a
Plawie safety policy rather than a protocol guarantee. Official x402 client
wrappers are designed to parse, sign, and retry automatically. Plawie must put a
deliberate approval gate between parsing the `PAYMENT-REQUIRED` response and
creating the `PAYMENT-SIGNATURE` payload; it must not use an automatic wrapper
unchanged.

The current wallet implementation is suitable for ordinary test transfers but
is not sufficient for production x402 mainnet signing:

- `BaseService` stores the secp256k1 private key as exportable hex through
  `FlutterSecureStorage`;
- `initialize()` loads a long-lived `EthPrivateKey` into the Dart process;
- `sendEth` and `sendUsdc` can sign without per-operation user authentication;
- `exportPrivateKey()` returns the raw key;
- the wallet defaults to Base mainnet;
- there is no approval-bound typed-data signer or intent/receipt ledger.

Android Keystore does not provide portable hardware-backed secp256k1 signing;
its broadly supported hardware EC curve is NIST P-256. For the existing EOA,
the practical Android hardening is envelope encryption: protect the Ethereum
private key with an AES-256-GCM key generated in Android Keystore, require strong
biometric or device credential authorization for each unwrap/sign operation,
prefer StrongBox when available, keep the unwrapped key in memory only for the
single signature, and zeroize temporary buffers. This materially improves the
current design, but it is not equivalent to a private key that never enters the
app process.

A Base Account/passkey smart wallet is the more modern optional destination for
truly user-mediated wallet interactions. The current x402 v2 specification also
describes ERC-7710 for compatible smart accounts. However, adopting a smart
account changes wallet identity, SDK/runtime integration, recovery, and
facilitator compatibility, so it is a later migration rather than a prerequisite
for the first EIP-3009 testnet implementation.

Base Spend Permissions and automatic Sub Account funding are explicitly out of
scope. They are designed to permit later spending without a prompt, which
conflicts with Plawie's requirement that a human approve every transaction.

Research references:

- [`x402 v2 migration guide`](https://docs.cdp.coinbase.com/x402/migration-guide)
- [`x402 exact EVM specification`](https://github.com/x402-foundation/x402/blob/main/specs/schemes/exact/scheme_exact_evm.md)
- [`x402 network and EIP-3009 support`](https://docs.cdp.coinbase.com/x402/network-support)
- [`x402 wallet integration`](https://docs.cdp.coinbase.com/wallets/using-wallets/x402-payments)
- [`Android Keystore`](https://developer.android.com/privacy-and-security/keystore)
- [`Android auth-per-use biometric keys`](https://developer.android.com/identity/sign-in/biometric-auth)
- [`Android tapjacking mitigations`](https://developer.android.com/privacy-and-security/risks/tapjacking)
- [`Android Protected Confirmation`](https://developer.android.com/privacy-and-security/security-android-protected-confirmation)
- [`Base Account overview`](https://docs.base.org/base-account/overview/what-is-base-account)
- [`Base Spend Permissions`](https://docs.base.org/base-account/improve-ux/spend-permissions)
- [`Base Sub Accounts`](https://docs.base.org/base-account/improve-ux/sub-accounts)

### 2.7 Implementation status

Phase 1 is now underway. The first implementation round adds:

- `ProviderSetupService`, which stores the temporary API key only in the
  platform secure store behind an opaque setup-scoped reference;
- one-time migration of the legacy `pending_api_key` preference;
- shared, receipt-based provider setup consumption for native-first setup and
  the explicit PRoot rollback path;
- cleanup when the user changes provider, skips setup, completes setup, or an
  older plaintext handoff is discovered;
- focused lifecycle tests and bootstrap release-contract coverage.

Dynamic model discovery, account connections, and x402 signing remain gated by
the later phases below; this round does not claim those features are complete.

The initial discovery adapter slice is also implemented without changing
Gateway configuration. It supports the documented OpenAI-compatible model-list
shape, Google's paginated `models.list` shape, provider-specific authentication,
ETag revalidation, bounded timeouts, per-provider request deduplication, and
conservative filtering of obvious embedding/moderation/speech-only records.
The adapter keeps the API key in the request boundary and never writes it into
the catalog snapshot.

Endpoint references used for this slice:

- [`OpenAI list models`](https://platform.openai.com/docs/api-reference/models)
- [`OpenRouter list models`](https://openrouter.ai/docs/api/api-reference/models/get-models)
- [`Gemini list models`](https://ai.google.dev/api/models)

## 3. Current-state evidence and preserved responsibilities

The current implementation already has useful boundaries. The migration must
extend them rather than duplicate them.

| Area | Current source | Responsibility to preserve |
| --- | --- | --- |
| Provider/model metadata | `lib/services/model_provider_catalog.dart` | Central model/provider definitions, aliases, credential lookup, config healing |
| Execution lanes | `lib/services/model_execution_policy.dart` | Cloud Gateway, direct local NDK, compact bridge, safe output caps, context policy |
| Chat model selection | `lib/screens/chat_screen.dart` | Persist the selected model, check credentials, keep cloud models on Gateway |
| Settings provider/key UI | `lib/screens/settings_screen.dart` | Provider credential management and model selection entry points |
| First-run provider/key UI | `lib/screens/setup_flow_screen.dart` | Provider selection, temporary API-key collection, agent name, setup handoff |
| Gateway configuration | `lib/services/gateway_service.dart` | Provider config, auth profiles, native policy, reload/restart, Gateway ownership |
| Base wallet | `lib/services/base_service.dart` | Managed EVM wallet, Base network selection, balance/history, ordinary transfers |
| Legacy credit flow | `lib/services/crypto_credits_service.dart` | Legacy OpenRouter/LI.FI flow to quarantine; do not extend as the x402 design |
| Existing provider contract | `docs/MODEL_PROVIDER_AND_HELP_ROADMAP.md` | Current static catalog and three-lane product contract until migration is complete |
| Previous simplification | `docs/PROVIDER_SIMPLIFICATION_OVERHAUL.md` | Static metadata, safe output caps, and cloud Gateway defaults |

The current catalog contains fixed provider defaults and model IDs. The current
execution policy contains explicit context windows and safe output caps. The
current chat screen trusts a persisted cloud model rather than silently
discarding a user choice. That behavior is valuable and must remain during
offline/stale catalog states.

The current Base wallet can create/import a key and send a normal ERC-20 USDC
transfer. A normal `transfer` is not automatically an x402 payment: x402 may
require a typed authorization such as EIP-3009 or another provider-specific
payment payload. The x402 implementation therefore needs a signer adapter and
approval boundary rather than calling the existing generic `sendUsdc` method.

The current first-run screen also has two issues that must be fixed as part of
this migration:

- it stores `pendingApiKey` in `SharedPreferences` until bootstrap consumes it;
  provider keys are secrets and must not pass through ordinary preferences;
- its copy says the key is “never sent anywhere,” although the key must be sent
  by the Gateway to the selected provider when making authorized API requests.

Non-secret setup state such as provider ID, selected model ID, and progress may
remain in preferences. The API key must move to an Android Keystore-backed
secret store and be referenced by an opaque one-time setup ID. The bootstrap
paths must consume that reference idempotently and clear it on success, cancel,
provider change, failure cleanup, or expiry.

## 4. Goals and non-goals

### Goals

1. Load current provider model metadata from documented provider endpoints.
2. Keep models grouped, searchable, and understandable in the existing mobile
   settings/chat surfaces.
3. Preserve model IDs and selected-model preferences across refreshes and
   temporary provider outages.
4. Distinguish discovery, authentication, capability validation, and billing.
5. Keep the native OpenClaw Gateway as the cloud execution owner.
6. Keep the existing native tools and skills available according to the current
   mobile tool policy.
7. Add tests proving dynamic selection does not mutate context or tool payloads.
8. Support provider-specific account/login handoffs without collecting provider
   passwords in Plawie.
9. Add an x402 payment intent and approval flow that is safe by construction.
10. Provide receipts, idempotency, and clear recovery for successful and failed
    dependency/model/payment operations.
11. Preserve first-run provider/API-key setup while removing plaintext pending
    secrets and keeping model discovery non-blocking.
12. Require a separate human approval and device-authenticated signature for
    every x402 payment; no standing spend permission is accepted.

### Non-goals for the first implementation

- replacing OpenClaw with OmniRoute or a new universal proxy;
- creating a universal Plawie credit ledger before provider semantics are proven;
- silently creating provider accounts on a user's behalf;
- supporting every provider at once;
- making all discovered models full-tool models;
- allowing dynamic provider metadata to increase context or output budgets
  without local policy validation;
- adding broad performance/price/context filters before the basic picker works;
- routing cloud chat directly from Dart around Gateway;
- automatically spending from the Base wallet;
- using Base Spend Permissions, Auto Spend Permissions, or any reusable agent
  allowance in the human-approval release;
- supporting Base mainnet payments before testnet and audit acceptance;
- implementing `upto`, Permit2, or smart-account delegation in the first x402
  release;
- changing native tool wildcard/allowlist behavior as part of model discovery.

## 5. Phase 0: context and tool compatibility baseline

This phase must be completed before changing the production model picker.

### 5.1 Context audit result

The current cloud selection path changes the selected model and provider config;
it does not intentionally change chat history or the NDK bridge compaction path.
The risk is indirect: a dynamic model record with a bad context window or output
limit can cause the Gateway to reject a request, truncate useful content, or
leave insufficient room for system instructions and tool schemas.

The implementation must therefore preserve this accounting model:

```text
input tokens + system/tool tokens + requested output tokens <= usable context
```

The selected model's advertised context is not the same as the app's safe
usable context. The policy layer continues to reserve room for the system
prompt, native tool schemas, tool results, reasoning, and the assistant answer.

### 5.2 Context invariance contract

Add a testable snapshot around model switching. For a fixed session and fixed
message, switching from a known static cloud model to a compatible dynamic cloud
model may change only:

- provider ID;
- model ID;
- provider request metadata;
- locally chosen safe output cap.

The snapshot must prove that these do not change:

- message history and message ordering;
- session ID and agent ID;
- system prompt;
- tool names and tool schemas;
- app-native skill capability context;
- tool result normalization;
- Gateway/NDK/PRoot lane;
- NDK bridge history-turn and tool-result limits.

### 5.3 Context metadata policy

Every dynamic model record receives a metadata quality state:

- `verified`: required context/capability fields passed local validation;
- `partial`: model is discoverable but one or more fields are absent;
- `stale`: values are cached past their freshness window;
- `invalid`: provider response is malformed or contradictory;
- `unknown`: no trustworthy capability metadata is available.

Rules:

- `verified` models use the existing model execution policy with a conservative
  output cap.
- `partial`, `stale`, and `unknown` models may be used for ordinary chat only if
  the provider route is known safe; they are not labeled full Agent-ready until a
  tool canary succeeds.
- `invalid` models are displayed with an explanation but cannot be selected.
- No provider response may set an unlimited output token value.
- A provider context value below the system/tool reservation is rejected.
- A provider context value above a local ceiling is clamped for policy purposes;
  the advertised value can remain visible as provider metadata.
- Existing NDK bridge values remain fixed and are not supplied by cloud catalog
  records.

### 5.4 Tool compatibility baseline

Dynamic models must not modify the existing native tool set. Capability metadata
is used to choose the route and label the model, not to rewrite app tool policy.

The current native tool surface is broader than ordinary function calling. The
baseline must account for these classes:

| Tool class | Examples of current behavior | Capability implication |
| --- | --- | --- |
| Device actions | haptics/vibration, flash, device state, sensors | Requires reliable function calls and short structured arguments |
| Media capture/input | camera and image input | Requires vision/image-input support and correct media handoff |
| Canvas/presentation | canvas rendering, generated images, close/resize interactions | Requires structured tool payloads, result continuation, and UI-safe output handling |
| Search/media skills | GIF search, weather, web or provider-backed lookup | Requires tool calls, network error handling, and honest configuration/dependency state |
| Installed skills | ClawHub/skill execution, dependency-aware skills, local executables | Requires skill registration, dependency receipts, tool continuation, and capability discovery |
| Voice/TTS | Talk, speech recognition, TTS playback | Requires media/stream handling; not every text model needs to advertise this capability |
| Structured agent control | schema payloads, tool results, multi-step continuation | Requires stable schemas and a model/provider route that does not rewrite arguments |

This is why a generic provider flag such as `supportsTools=true` is insufficient.
The app should retain the existing mobile tool policy and assess the specific
tool classes through canaries. The first UI does not need a filter for every
class; it needs an honest capability badge and an actionable reason when a
selected model cannot handle a class required by the current request.

The baseline canary matrix is:

| Canary | What it proves |
| --- | --- |
| READY/health | Provider route and Gateway session are usable |
| List phone tools | Tool discovery and schema registration survive selection |
| Vibrate/haptic | A simple native action completes and returns a result |
| Canvas | Structured payload and rendered result survive the tool loop |
| Camera/image or GIF path | Media input/output capability is not falsely advertised |
| One installed skill | Skill resolution, dependency state, and tool continuation work |
| Structured payload | Schema validation and error normalization are compatible |
| Tool-result continuation | Model can continue after a tool result without duplicate replies |
| No-tool chat | Ordinary chat still works when no tool is selected |

The capability label should use a small state machine rather than a boolean:

- `reliable`: provider metadata and local canary support tools;
- `variable`: provider advertises tools but behavior depends on model/router;
- `chatOnly`: no dependable tool call contract;
- `unknown`: not yet tested;
- `blocked`: incompatible schema, route, credential, or safety policy.

The app must not call a model `Agent-ready` only because a remote `/models`
response contains a tools-related field.

## 6. Target data model

The following names are logical contracts. They can be implemented as Dart
classes, JSON records, or a small persistence layer, but their meanings must
remain stable.

### 6.1 `ProviderDefinition`

Describes a supported integration, not a user's credential.

Required fields:

- stable `providerId` (for example `venice`, `blockrun`, `llm402`);
- display name and short description;
- official models endpoint and documentation URL;
- authentication modes (`apiKey`, `oauthBrowser`, `walletIdentity`, `none`);
- supported networks/assets/payment modes;
- whether the provider supports tools, vision, streaming, and structured
  output, expressed as capability claims rather than guarantees;
- whether account creation, login, balance, top-up, or per-request payment is
  supported;
- adapter version and minimum app version;
- host allowlist used by payment validation.

### 6.2 `ProviderConnection`

Represents a user's connection state without storing provider passwords.

Fields:

- `providerId`;
- connection mode;
- redacted account identity/display name if supplied by the provider;
- credential reference, never the raw secret in the model catalog;
- scopes/permissions;
- last validation result and timestamp;
- last error category;
- whether the connection can use normal chat, tools, paid routes, or x402;
- explicit disconnect/revoke state.

### 6.3 `DynamicModel`

Fields:

- namespaced stable ID: `providerId:modelId`;
- provider-native model ID kept separately from the display label;
- display name and optional family/description;
- input/output modalities;
- tool/function calling claim;
- structured output claim;
- streaming/reasoning claims where useful;
- advertised context window, nullable;
- advertised output limit, nullable;
- local safe output cap, never nullable;
- capability state and metadata quality state;
- source endpoint, fetched time, expiry/stale time, and adapter version;
- whether it is currently selected;
- optional user-facing warning, such as “provider/router capability varies”.

Never use a display label as a model ID. Never identify a model only by its
unqualified native ID when two providers can expose the same string.

### 6.4 `ModelCatalogSnapshot`

The cache envelope contains:

- schema version;
- provider ID;
- models and provider metadata;
- fetch time and freshness deadline;
- response ETag or equivalent validator when available;
- redacted error state;
- source/auth mode;
- checksum or canonical hash for diagnostics;
- migration version.

The snapshot is a cache, not a credential store and not an OpenClaw config
replacement.

### 6.5 `PendingProviderSetup`

This is the crash-recoverable, non-secret setup record.

Fields:

- random setup ID;
- provider ID and connection mode;
- selected safe default model ID;
- opaque secret reference when an API key was entered;
- secret creation/expiry time, never the secret value;
- connection validation state (`notTested`, `valid`, `invalid`, `unavailable`);
- bootstrap consumption state and receipt ID;
- last failure category without provider response bodies.

There must be only one active pending setup. Replacing, skipping, or cancelling
it deletes its secret reference before a new record is accepted.

### 6.6 `PendingPaymentIntent` and `PaymentReceipt`

`PendingPaymentIntent` is generated from a validated 402 challenge and is the
only object that the wallet signer accepts. It contains:

- random intent ID and approval nonce;
- provider adapter ID and verified HTTPS origin;
- HTTP method, canonical resource URL, and request-body hash;
- x402 version, scheme, network, asset transfer method, and facilitator identity
  when supplied;
- exact token, amount, recipient, valid-after, valid-before, and payment nonce;
- hash of the canonical payment requirement shown to the user;
- per-request/session/day policy result;
- state, created time, expiry, and one-attempt flag.

`PaymentReceipt` contains the intent ID, provider payment identifier, settlement
response, transaction hash when available, paid amount/asset/network, timestamps,
and final status. It never stores a reusable signature, private key, API key, or
full sensitive request body.

## 7. Provider adapter contract

Create a provider adapter boundary so provider quirks stay out of widgets,
`GatewayService`, and the generic payment flow.

Logical interface:

```text
fetchModels(connection) -> Result<ModelCatalogSnapshot>
validateConnection(connection) -> Result<ProviderConnectionStatus>
buildGatewayProviderConfig(selectedModel, connection) -> GatewayProviderConfig
capabilityFor(model) -> CapabilityAssessment
beginAccountConnection() -> AccountConnectionIntent        [optional]
openAccountManagement(connection) -> Uri                    [optional]
fetchBalance(connection) -> ProviderBalance                 [optional]
preparePayment(402Response, requestContext) -> PaymentIntent [optional]
signPaymentAfterApproval(PaymentIntent, signer) -> Proof    [optional]
```

Adapters must:

- use documented provider hosts and paths;
- normalize errors into stable categories;
- redact credentials, authorization headers, and payment signatures;
- never sign or submit a payment from `fetchModels`, validation, or a model
  selection callback;
- reject payment challenges that do not match the provider's configured host,
  expected chain, token, and request context;
- bind an approved payment to the original HTTP method, canonical URL, body hash,
  provider adapter, and exact challenge hash;
- reject cross-origin redirects before or after a payment challenge and never
  forward a payment signature to a redirected host;
- allow only one signed retry for a payment intent;
- expose only the provider capability facts that were actually observed or
  documented.

## 8. Initial provider semantics

Provider support is added one adapter at a time. These are the first semantics
to model, not a promise to launch all of them in one release.

### 8.1 Providers with model discovery

Venice documents an authenticated models endpoint that returns current model
metadata and capability information. It also documents an x402 top-up path and
a separate wallet-based autonomous API-key flow. Plawie should initially treat
Venice wallet identity and Venice API-key creation as separate capabilities; it
must not create or mint a key merely because a wallet exists.

- Models: [`Venice models endpoint`](https://docs.venice.ai/api-reference/endpoint/models/list)
- x402: [`Venice x402 integration`](https://docs.venice.ai/guides/integrations/x402-venice-api)
- wallet key creation: [`Venice autonomous key creation`](https://docs.venice.ai/guides/integrations/generating-api-key-agent)

BlockRun documents a live models endpoint and x402 per-request access on Base.
It should be represented as a wallet-payment provider rather than forced into an
API-key account model.

- [`BlockRun endpoints`](https://blockrun.ai/docs/x402/endpoints)
- [`BlockRun models API`](https://blockrun.ai/docs/api-reference/models)

llm402 documents model discovery and payment/balance flows with x402/L402,
Cashu, and prepaid options. Its adapter must keep those payment modes explicit
instead of assuming every provider has an account key or a Base top-up.

- [`llm402 documentation`](https://llm402.ai/docs)

The generic x402 protocol is an HTTP 402 challenge/retry flow. Coinbase's
documentation identifies Base as `eip155:8453` and describes ERC-20 payment
schemes such as EIP-3009 and Permit2. Plawie should implement only the schemes
required by a selected provider and should reject an unsupported scheme.

- [`Coinbase x402 documentation`](https://docs.cdp.coinbase.com/x402/welcome)

### 8.2 Provider accounts and login

There is no safe universal “create account” operation. The provider adapter must
declare one of:

- `apiKey`: user pastes/creates a key in provider's official account UI;
- `oauthBrowser`: Plawie opens the provider's official login/consent page and
  receives a callback or user-completed connection;
- `walletIdentity`: provider identifies a wallet or verifies a wallet signature;
- `none`: provider relies on x402 or another anonymous/prepaid mechanism.

If a provider supports account creation, the app may show an official “Create or
manage account” handoff. It must not ask Plawie to store the provider password.
Account access and wallet payment remain different permissions.

## 9. Catalog refresh and caching behavior

### 9.1 When to fetch

Do not fetch every provider's model list during Gateway startup or first-run
setup. Discovery is not required to boot the Gateway and must not delay the
native runtime.

Fetch a provider when:

- the user opens its model group in Settings or the model picker;
- the user connects or revalidates that provider;
- the user explicitly taps Refresh;
- a selected model is no longer available and a controlled refresh is needed.

### 9.2 Cache behavior

- Show a fresh cached snapshot immediately.
- Refresh in the background when it is stale.
- Keep the last valid snapshot if refresh fails.
- Preserve a selected model even if the provider is temporarily unreachable;
  show a stale/unverified warning and offer retry.
- Never replace a valid snapshot with an empty response because of a transient
  network or auth error.
- Store only redacted diagnostics; never persist full provider responses if they
  contain account or billing data not needed by the UI.
- Use request cancellation and one in-flight refresh per provider to prevent
  duplicate requests and duplicate notifications.

### 9.3 OpenClaw configuration boundary

The entire provider model catalog must not be written into OpenClaw config. The
selected provider/model and the minimum required provider configuration are what
the Gateway receives. The catalog remains a Plawie-side discovery/cache concern.

This keeps Gateway startup fast, avoids giant configuration payloads, and
prevents stale or unsupported models from becoming runtime defaults.

## 10. First-run provider and API-key setup

First setup remains available before OpenClaw installation. It must use a small,
bundled set of trusted provider definitions because provider hosts, auth modes,
and payment allowlists are security policy and cannot be downloaded from an
arbitrary remote catalog. Model lists are dynamic; trusted provider adapters are
shipped and reviewed with the app.

### 10.1 Setup goals

The setup page must let a new user:

1. choose Cloud provider, Wallet/x402 provider when supported, Private Offline,
   or Configure later;
2. understand whether the provider uses an API key, official account handoff,
   wallet identity, or per-request x402;
3. save an API key securely when that mode is selected;
4. optionally test the connection without purchasing anything;
5. accept a bundled safe default model so installation is not blocked by a
   models-endpoint outage;
6. review provider, connection method, default model, and payment policy before
   starting installation.

The existing agent-name and quick-settings steps remain after provider
connection. The provider step title should say `Choose your AI provider`, not
`Choose your AI model`, because the current cards select a provider. Dynamic
model selection can be offered after installation or as an optional non-blocking
preview when a catalog is already available.

### 10.2 Recommended first-run flow

```text
Choose mode/provider
  -> explain connection method
  -> API key: open official key page / paste key
     OR x402: create or open internal Base wallet (no payment yet)
     OR offline/configure later: no credential
  -> optional Test connection
  -> save non-secret setup record + opaque secret reference
  -> name agent and quick settings
  -> review: provider, default model, connection, Ask every payment
  -> install official Gateway/dependencies
  -> consume credential exactly once before first Gateway start
  -> clear pending secret and store setup receipt
  -> start native Gateway
  -> refresh dynamic models after setup, never on the critical boot path
```

Wallet creation during setup creates a payment identity only. It must not fund,
top up, sign, or grant spending permission. The review screen must say that every
x402 charge will stop for explicit approval and device authentication.

### 10.3 Provider connection modes in setup

| Mode | Setup UI | Bootstrap result |
| --- | --- | --- |
| API key | Official Create/manage key link, obscured input, optional Test connection | Credential available to selected Gateway provider |
| Official browser/OAuth | Open official account/login page and resume callback/status | Credential/reference stored only after provider confirmation |
| Wallet identity/x402 | Create/open wallet, show address/network, explain funding and approval | Provider marked wallet-capable; no payment and no fake API key |
| Private Offline | Explain that local model download happens later | No cloud credential; direct NDK lane preserved |
| Configure later | Skip safely | Gateway can install/start without cloud inference credential |

Provider cards must come from the same trusted `ProviderDefinition` registry used
by Settings. A provider cannot appear during setup merely because a remote models
endpoint returned its name.

### 10.4 API-key secret lifecycle

Replace `PreferencesService.pendingApiKey` with a dedicated `ProviderSecretStore`
backed by Android Keystore protection. The UI writes the key once and receives an
opaque secret reference. Only this reference enters `PendingProviderSetup`.

Rules:

- never persist the API key in ordinary `SharedPreferences`/DataStore;
- never log the key, prefix beyond a safe redacted suffix, clipboard contents,
  provider response authorization header, or secret reference lookup result;
- clear the text controller and clipboard suggestion state after save;
- changing provider, pressing Skip, going back and replacing a connection,
  cancelling setup, or expiry deletes the old pending secret;
- bootstrap consumes the secret through one common idempotent method used by
  native and PRoot fallback paths;
- consumption produces a non-secret receipt before the pending record is cleared
  so crash recovery cannot duplicate configuration;
- final credential storage has one canonical secret. If OpenClaw requires
  generated config or environment material, it is app-private, minimally scoped,
  never duplicated unnecessarily, and deleted on disconnect;
- native launch should prefer injecting the credential into the embedded Gateway
  process from the secret store rather than keeping duplicate plaintext copies;
- PRoot fallback must pass credentials through a non-logged environment/IPC path,
  never a command-line argument.

The user-facing copy should be accurate:

> Stored securely on this device. Plawie's Gateway sends this key only to the
> selected provider when you make an authorized request.

Do not claim the key is “never sent anywhere.”

### 10.5 Connection validation

Prefix and length checks are hints, not credential validation. `Test connection`
is an explicit user action and should call a documented non-billable endpoint,
preferably the provider's models or identity endpoint. It must:

- use a short timeout and cancellation;
- never invoke a paid model completion;
- distinguish invalid credential, unavailable network, rate limit, malformed
  response, and unsupported provider;
- save only the validation state and timestamp;
- allow installation to continue when validation is unavailable, while clearly
  showing `Not verified`;
- never start/restart Gateway just to validate a setup key.

### 10.6 Setup idempotency and recovery

The two existing bootstrap branches that consume `pendingProvider` and
`pendingApiKey` must converge on one idempotent setup-consumption service. A
stable setup ID and receipt prevent double configuration if Android kills the app
mid-install. On restart:

- `configured` receipt: continue without reading/signing/configuring again;
- valid pending secret: resume from the recorded step;
- expired/missing secret: return to connection input without discarding already
  downloaded Gateway/dependency receipts;
- provider changed: invalidate the old setup and delete its secret;
- setup skipped: remove all pending provider secrets and continue installation.

Provider/key setup must not cause duplicate Gateway downloads, duplicate provider
onboarding, duplicate restarts, or duplicate notifications.

## 11. Model picker and settings UX

### 11.1 Recommended layout

Use the current model picker/settings entry points, but replace the flat static
list gradually:

1. Provider group header with connection status.
2. Expand/collapse control.
3. Search field scoped to the expanded provider or all loaded providers.
4. Model rows with name, short native ID, capability badge, and connection
   requirement.
5. A clear action for Connect, Manage account, Configure key, or Approve wallet
   access depending on provider mode.
6. A compact warning for stale, unverified, chat-only, or blocked models.

Avoid long overflow-prone rows. Model names, provider names, and warnings must
wrap or elide within bounded layouts; no card may depend on a single-line model
name.

### 11.2 Capability language

Use plain labels:

- `Agent tools verified`;
- `Tools may vary by route`;
- `Chat only`;
- `Vision available`;
- `Connect provider`;
- `Payment approval required`;
- `Needs verification`.

Do not claim that a model is installed locally when it is only remotely
discoverable. Do not claim that a provider is configured because its model list
loaded anonymously.

### 11.3 Minimal filters

The first catalog should not expose a filter for every metadata field. Search and
provider grouping solve the primary navigation problem. Add an Agent-ready/tools
filter only after the capability state is backed by a successful local canary.
Add modality only when the current camera/image/GIF flows require it. Defer
speed, price, context, and freshness filters to a measured follow-up.

## 12. Gateway integration and context preservation

### 12.1 Selection flow

1. User selects a namespaced dynamic model.
2. App checks the provider connection and model metadata quality.
3. App asks `ModelExecutionPolicy` for the safe local output cap and lane.
4. App writes only the selected model/provider config through
   `GatewayService`.
5. Gateway reload/restart behavior follows the existing policy; no unconditional
   app restart is introduced.
6. App reconnects the existing Gateway WebSocket/session as it does today.
7. A health/capability check confirms the selected route before labeling it
   Agent-ready.

### 12.2 Required preservation rules

- Keep all cloud models on the Gateway lane.
- Keep direct local models out of Gateway unless the existing compact bridge is
  explicitly selected.
- Do not change `ChatRuntimeService` history or compaction in this project.
- Do not change native skill/tool registration because a model was selected.
- Do not use provider capability metadata to expand mobile wildcard/allowlist
  policy.
- Do not attach every discovered provider/model record to the system prompt.
- Do not silently change a user's selected cloud model because a refresh failed.
- Do not let a provider's claimed context size increase the safe output cap
  beyond local policy.
- If a model cannot support the current tool schema, offer Chat-only mode or
  block the Agent route with an actionable explanation.

### 12.3 Dynamic model configuration

`ModelProviderCatalog` should become the compatibility facade while the dynamic
catalog is introduced. Existing static defaults remain as fallback records until
each provider adapter is proven. `ModelExecutionPolicy` remains the authority for
lane selection, context reservation, and output caps.

The implementation must not spread provider-specific parsing across
`chat_screen.dart`, `settings_screen.dart`, or `gateway_service.dart`.

## 13. x402 payment architecture

### 13.1 Protocol baseline

Implement x402 v2 only. The required wire contract is:

- server challenge: `PAYMENT-REQUIRED`;
- client proof: `PAYMENT-SIGNATURE`;
- server settlement result: `PAYMENT-RESPONSE`;
- Base mainnet: `eip155:8453`;
- Base Sepolia: `eip155:84532`.

Do not mix v1 packages, legacy `X-PAYMENT` headers, or legacy network names with
v2. The first release supports only `(scheme=exact, network=eip155:84532,
assetTransferMethod=eip3009, asset=Base Sepolia USDC)`. EIP-3009 is the best fit
for the current EOA because the user signs a one-time typed authorization with
exact recipient, amount, validity window, and nonce, while the facilitator
settles it. It avoids the standing token allowance required by Permit2.

The `upto` scheme is deferred. Although it is useful for token-based LLM billing,
it authorizes a maximum rather than presenting the final settled amount at
approval time. It needs separate UI language, settlement reconciliation, and
receipt testing before it can satisfy the human-approval contract.

### 13.2 Gateway and provider transport ownership

Cloud inference must remain Gateway-owned, so x402 cannot be implemented as a
separate direct-Dart chat route. The recommended boundary is an app-controlled
x402 provider transport adapter:

```text
OpenClaw Gateway provider request
  -> loopback provider transport / reviewed OpenClaw provider adapter
  -> official provider HTTPS endpoint
  -> 402 challenge
  -> native bridge emits pending intent to Flutter
  -> Flutter approval + Android signer
  -> transport retries the exact original HTTPS request once
  -> provider response returns to OpenClaw Gateway
```

Use the official x402 v2 parsing and EVM scheme implementation where it can be
integrated with the embedded native Node runtime. Replace or wrap the automatic
signer callback with an approval-bound callback to the native wallet service.
Do not fork or wrap the official OpenClaw release merely to add payments. Prefer
a supported provider adapter/plugin or a narrowly scoped loopback transport.

The transport must be disabled for ordinary providers and ordinary HTTP calls.
Only a shipped provider adapter and allowlisted HTTPS origin may invoke it. A
skill that needs paid x402 access must declare that host/payment capability in a
reviewed manifest and use the same payment-intent boundary; arbitrary agent URLs
cannot reach the signer.

If the app is backgrounded, a notification may open the pending-payment screen,
but notification actions cannot approve. Only one payment approval may be active
at a time; additional intents queue or fail with `approvalBusy`.

### 13.3 Payment state machine

The payment path is a user-mediated state machine:

```text
original HTTPS request
  -> provider returns HTTP 402 + PAYMENT-REQUIRED
  -> parse and validate challenge against original request
  -> create PendingPaymentIntent
  -> display human approval UI
  -> user approves or rejects
  -> strong biometric/device credential unlocks one signing operation
  -> revalidate intent and sign exact EIP-712 authorization
  -> retry same request once with PAYMENT-SIGNATURE
  -> parse PAYMENT-RESPONSE and persist redacted receipt
```

States:

- `notRequired`;
- `challengeReceived`;
- `rejected`;
- `expired`;
- `blockedByPolicy`;
- `approvalBusy`;
- `awaitingHumanApproval`;
- `awaitingWalletUnlock`;
- `signing`;
- `submitted`;
- `settled`;
- `uncertain`;
- `failed`.

An `uncertain` result must first query the provider/chain receipt before any
retry. It must never blindly sign again.

### 13.4 Payment intent contents

The app creates the intent from the verified provider challenge, not from model
text. It must show:

- provider and verified host;
- original HTTPS method, canonical URL, and redacted operation;
- request-body hash, never a sensitive body dump;
- selected provider/model/route;
- x402 version, `exact` scheme, EIP-3009 transfer method, and CAIP-2 network;
- token symbol and contract address;
- exact amount in token units and a human-readable amount;
- recipient/pay-to address;
- canonical challenge hash and resource identifier;
- validity window, payment nonce, approval nonce, and payment identifier when
  supported;
- per-request and session spend limits;
- whether this is a top-up or per-request payment;
- a warning if fiat value is unavailable or only estimated;
- link to provider/payment documentation where appropriate.

The approval screen must not look like an ordinary “Continue” dialog. It must
make the spend, recipient, chain, and expiry visible and require a deliberate
Approve action distinct from chat input.

### 13.5 Hard approval rules

- Only a UI approval event tied to the exact intent ID can authorize signing.
- Approval expires with the intent and cannot be reused for another request.
- Chat text, model output, skill output, deep-link parameters, and tool calls
  cannot approve a payment.
- Approval and signing are separate gates: the user first confirms the visible
  intent, then strong biometric or device credential authorizes exactly one
  cryptographic operation.
- Enforce an allowlist of provider hosts, networks, token contracts, and payment
  schemes.
- Enforce per-request, session, and daily limits even though every payment asks.
- Require exact recipient, amount, chain, asset, nonce, and resource match at
  signing time.
- Recompute the canonical challenge and request hash immediately before signing.
- Reject HTTP, TLS errors, cross-origin redirects, changed methods/bodies, stale
  challenges, unsupported facilitators, and unrecognized transfer methods.
- Do not send `PAYMENT-SIGNATURE` across any redirect.
- Treat the payment screen as a sensitive Android activity: use `FLAG_SECURE`,
  hide overlay windows where supported, reject fully or partially obscured touch
  events on approval controls, and mark transaction controls accessibility-data
  sensitive on supported Android versions.
- Keep biometric confirmation enabled for passive face/iris modalities; this is
  a purchase authorization, not low-risk re-authentication.
- Evaluate Android Protected Confirmation as an additional signed record that the
  user approved the short payment statement on supported devices. It supplements
  but does not replace the EIP-3009 signature or the normal approval screen.
- Redact signatures and key material from all logs and diagnostic exports.
- Do not allow a skill to call a generic wallet-send method for x402.
- Do not create Base Spend Permissions, token allowances, session keys, or
  reusable delegations in the human-approval release.
- Retry the original request once only. A second 402 creates no automatic second
  signature and surfaces a recoverable payment error.
- A user can cancel at any state before final submission; cancellation must
  prevent the pending intent from being reused.

### 13.6 Internal Base wallet design

The wallet UI can be the user's visible management surface, but the signing
implementation needs two conceptual identities:

- `userWallet`: ordinary wallet actions explicitly initiated by the user;
- `agentPaymentWallet`: a constrained wallet identity used for approved provider
  payments.

The recommended first release can use a dedicated payment account derived from
the existing internal-wallet architecture, but it should not silently spend the
ordinary user-wallet balance. The Base page must show which address is the x402
payment wallet, its network, USDC balance, security level, and payment receipts.
Funding is always user initiated.

The wallet identities may share a UI and storage foundation, but they must not
share authorization semantics. Before any mainnet payment work:

- Gateway and skills receive a wallet capability handle, never a private key;
- the agent cannot export or inspect the private key;
- replace the long-lived `_credentials` field with address-only idle state;
- encrypt the secp256k1 private key using AES-256-GCM with an Android
  Keystore-generated wrapping key;
- require per-use (`authenticationValidityDurationSeconds=0` or modern
  equivalent) strong biometric/device credential authorization to unwrap;
- prefer StrongBox, fall back to TEE, and report the effective security level;
- unwrap only after an approved, unexpired intent is revalidated;
- sign only the canonical EIP-712 EIP-3009 payload, then zeroize all mutable key
  and message buffers;
- separate wallet creation/import/export from payment signing interfaces;
- gate `BaseService.exportPrivateKey` behind explicit wallet-management UI,
  device re-authentication, warnings, and a separate audit; it is never available
  to the agent-payment service;
- payment signing is exposed only through an approval-bound service;
- ordinary `sendEth`/`sendUsdc` remain user-facing transfers and cannot be
  repurposed by an agent as x402.

Because Android Keystore hardware commonly supports P-256 rather than Ethereum's
secp256k1, this design hardware-protects the wrapping/unlock key rather than
claiming that the Ethereum signature itself is produced inside secure hardware.
The security disclosure and diagnostics must state that distinction honestly.

The first adapter supports Base Sepolia USDC at the official contract address,
one provider host, tiny caps, and `exact/eip3009`. Mainnet and additional
tokens/providers require separate allowlist changes, security review, and tests.

### 13.7 Optional modern wallet migration

A Base Account smart wallet with passkey approval is a strong later option and
can remain presented through Plawie's internal Base wallet page. It can offer a
self-custodial smart account and a user prompt for wallet interactions. Before
migration, verify Flutter/Android integration, wallet recovery, x402
EOA/smart-account compatibility, and the enabled facilitator's ERC-7710 support.

If Base Account/Sub Accounts are evaluated:

- disable Auto Spend Permissions (`funding: manual` or equivalent);
- never request a recurring Spend Permission;
- require the passkey/device prompt for every x402 payment;
- keep the approval-intent screen before the wallet prompt;
- migrate identity/funds only through an explicit user flow;
- retain the EIP-3009 EOA path until smart-account settlement is proven.

This is a security/UX migration, not a reason to delay the testnet EOA proof of
concept.

### 13.8 Provider-specific payment differences

The generic payment state machine is shared; the challenge parser and signer are
provider-specific.

- Venice may use x402 for a top-up and a separate wallet/SIWX identity for
  inference. Top-up approval and inference authorization must be separate
  intents.
- BlockRun may require a per-request `PAYMENT-SIGNATURE` and does not fit an
  API-key/top-up assumption.
- llm402 may expose x402/L402, Cashu, or prepaid flows. Each must be represented
  as a distinct payment mode.

No provider adapter may silently convert a per-request payment into a balance
top-up or vice versa.

## 14. Account, balance, and top-up boundaries

The app should show provider account actions only when the provider adapter
supports them:

- `Connect key` for a user-provided API key;
- `Open provider account` for an official browser handoff;
- `Connect wallet identity` for a provider's documented wallet verification;
- `View balance` only when the provider exposes a supported balance endpoint;
- `Top up` only when the provider documents the exact payment flow.

There will be no universal Plawie balance in the first release. A future
internal credit ledger would introduce custody, refunds, reconciliation,
chargebacks, and multi-provider accounting obligations. The first release keeps
provider balances and x402 receipts provider-specific.

## 15. Implementation phases and order

Each phase ends with tests and a focused commit. Do not combine payment signing
with the first dynamic catalog commit.

### Phase 0 — Contract and baselines

- Add this plan and link it from the existing provider roadmap.
- Add context snapshot tests around model switching.
- Record baseline tool payloads, skill capability context, and Gateway lane.
- Record native-first/PRoot fallback behavior.
- Mark `crypto_credits_service.dart` as legacy/quarantined in documentation.

Exit criteria: baseline tests prove a model switch does not mutate context,
tools, history, or runtime lane.

### Phase 1 — First-run credential hardening

- Introduce `ProviderSecretStore` and opaque one-time secret references.
- Remove plaintext `pendingApiKey` writes from `SharedPreferences`.
- Converge native and PRoot bootstrap credential consumption on one idempotent
  service with a setup ID and receipt.
- Correct first-run key-storage/network copy and clear secrets on replace, skip,
  cancel, failure cleanup, and expiry.
- Add crash/restart tests around every credential-consumption boundary.
- Keep current provider cards and static safe defaults until the dynamic catalog
  is ready.

Exit criteria: no API key enters ordinary preferences or logs, each pending key
is consumed at most once, and fresh setup still configures the provider before
the first native Gateway start without an extra restart.

### Phase 2 — Catalog data model and repository

- Add provider/model/connection/snapshot contracts.
- Add namespaced IDs and migration for existing static IDs.
- Add cache persistence, schema version, stale/error states, and redaction.
- Keep `ModelProviderCatalog` as a compatibility facade.
- Add fake providers and malformed-response fixtures.

Exit criteria: unit tests cover valid, stale, empty, malformed, duplicate, and
unknown-capability responses without affecting Gateway startup.

### Phase 3 — Discovery adapters

- Implement one provider adapter at a time, starting with a provider whose
  models endpoint is stable and whose auth semantics are already supported.
- Add timeouts, cancellation, ETag/conditional refresh where available, and one
  in-flight request per provider.
- Normalize capability, context, output, modality, and model IDs.
- Keep API-key and wallet-payment semantics separate.

Exit criteria: each adapter can fetch, cache, validate, and explain its own
failures without writing the full catalog into Gateway config.

### Phase 4 — First-run and grouped/searchable UI

- Replace the flat provider/model presentation behind a feature flag.
- Add provider grouping, search, connection state, capability badge, and safe
  wrapping for long names.
- Add explicit Connect/Manage/Refresh actions.
- Keep static fallback records visible when dynamic refresh is unavailable.
- Drive first-run provider cards from the bundled trusted provider registry.
- Add connection-method explanations, optional non-billable Test connection,
  safe default-model review, and `Ask every payment` disclosure.
- Keep dynamic model fetching off the critical setup/install/startup path.

Exit criteria: a user can find and select a model offline from cache, understand
why a model is unavailable, and configure a provider without duplicate dialogs or
notifications; first setup can also complete during a provider catalog outage.

### Phase 5 — Gateway selected-model integration

- Route selected dynamic models through `ModelExecutionPolicy` and
  `GatewayService`.
- Apply conservative local output caps and context reservation.
- Preserve the current cloud Gateway route and local NDK behavior.
- Add the model-switch context/tool invariance tests to CI.
- Run the complete tool canary matrix on each initial provider.

Exit criteria: dynamic selection works with ordinary chat and verified tools;
unknown/variable models are labeled accurately and do not overclaim support.

### Phase 6 — Account and provider management

- Add official browser/deep-link account handoffs where supported.
- Add connection validation, disconnect, re-authentication, and redacted status.
- Keep provider secrets out of model catalog records.
- Add account/key migration from current static provider settings.

Exit criteria: users can connect and manage a provider without Plawie storing a
provider password or losing an existing working API-key configuration.

### Phase 7 — Internal wallet signer hardening

- Separate ordinary wallet management from the agent-payment signer interface.
- Replace long-lived in-memory EOA credentials with address-only idle state.
- Add Android Keystore AES-GCM envelope protection for the secp256k1 key.
- Require one strong biometric/device-credential authorization per unwrap/sign.
- Add StrongBox/TEE capability reporting and a software-fallback block for x402.
- Gate export behind separate wallet-management authentication and ensure the
  payment service cannot call it.
- Add memory-lifetime/zeroization tests and log redaction tests.

Exit criteria: a payment signature cannot be produced without an approved intent
and a fresh device-authenticated cryptographic unlock; the Gateway and agent
cannot access raw key material.

### Phase 8 — x402 v2 intent and approval on Base Sepolia

- Add v2 `PAYMENT-REQUIRED` parsing and provider
  host/network/token/facilitator allowlists.
- Add `PendingPaymentIntent` and receipt records.
- Add the explicit approval screen and cancellation/expiry behavior.
- Add the Gateway-compatible provider transport and approval bridge.
- Add `exact/eip3009` EIP-712 construction and the approval-bound signer; do not
  call generic `sendUsdc`.
- Retry once with `PAYMENT-SIGNATURE`, parse `PAYMENT-RESPONSE`, and persist a
  redacted receipt.
- Test one provider on Base Sepolia USDC with tiny limits.

Exit criteria: reject/cancel/expiry paths are safe, approval is required, exact
payment details are displayed and validated, and the provider accepts one
approved payment in a controlled test with no automatic second attempt.

### Phase 9 — Provider-specific live validation

- Validate Venice top-up/inference separation if enabled.
- Validate BlockRun per-request payment semantics if enabled.
- Validate llm402 payment mode selection if enabled.
- Test wallet balance, insufficient funds, chain mismatch, expired challenge,
  duplicate request, uncertain receipt, and provider outage.

Exit criteria: each enabled provider has a documented capability/payment matrix
and a rollback switch.

### Phase 10 — Optional smart-wallet evaluation

- Prototype Base Account/passkey integration behind a separate feature flag.
- Verify Flutter/Android UX, recovery, address migration, and facilitator
  support for smart-account x402/ ERC-7710.
- Keep Auto Spend Permissions and reusable Spend Permissions disabled.
- Compare security and supportability against the hardened EOA signer.

Exit criteria: an explicit architecture decision is documented; no user is
silently migrated and no standing spend authority is introduced.

### Phase 11 — Cleanup and release hardening

- Remove dead static-only UI paths after migration telemetry is sufficient.
- Keep static safe fallback records for offline/error recovery.
- Quarantine or remove obsolete OpenRouter/LI.FI credit code when no longer used.
- Update provider roadmap, help text, privacy/security disclosures, and release
  notes.
- Add migration notes and support diagnostics without secret leakage.

Exit criteria: release build, fresh install, upgrade install, offline cache, and
PRoot fallback all pass the release checklist.

## 16. Test and acceptance matrix

### 16.1 Catalog and selection

- provider models load from the documented endpoint;
- one provider failure does not hide other providers;
- stale cache displays and refreshes without duplicate requests;
- malformed model response is rejected safely;
- duplicate native IDs remain distinct by provider namespace;
- selected model survives a failed refresh;
- selected model is not silently replaced by a default;
- credentials are required only when the selected route needs them;
- dynamic catalog fetch does not delay Gateway startup;
- refresh actions do not create duplicate notifications.

### 16.2 First-run provider and credential setup

- provider cards come only from the bundled trusted registry;
- provider selection works without a dynamic catalog response;
- the title and review distinguish provider selection from model selection;
- API-key, browser-account, wallet/x402, offline, and configure-later modes show
  the correct controls;
- API key never enters `SharedPreferences`, DataStore, logs, crash reports, or
  setup receipts;
- changing provider, back/replacement, Skip, cancel, expiry, and failure cleanup
  delete the correct pending secret;
- optional Test connection never makes a paid completion request;
- unavailable validation is `Not verified` and does not block installation;
- native bootstrap consumes a pending secret once and configures before first
  Gateway start;
- app termination before/during/after consumption resumes without duplicate
  config, restart, download, or notification;
- PRoot fallback uses the same non-logged secret reference and receipt contract;
- setup copy says the Gateway sends the key to the selected provider when needed;
- wallet/x402 setup creates or selects an address but never funds, approves,
  signs, or grants spending authority.

### 16.3 Context and tools

- fixed session/history remains byte-for-byte or structurally identical across a
  model switch;
- system prompt and mobile tool policy remain unchanged;
- native skill capability context remains unchanged;
- safe output cap never exceeds local policy;
- missing context metadata selects a safe fallback;
- oversized/contradictory metadata is clamped or blocked;
- READY, phone-tool, vibrate, canvas, media, skill, schema, continuation, and
  no-tool canaries pass or produce an honest capability state;
- NDK direct and compact bridge tests remain unchanged;
- native Gateway failure still offers the existing user-requested PRoot fallback.

### 16.4 Account and security

- API key never appears in UI logs, Gateway logs, model context, crash reports,
  or catalog snapshots;
- account handoff uses the official provider page;
- disconnect removes the intended credential/reference;
- expired/revoked credentials produce an actionable state;
- wallet private key is not reachable by agent tools or provider adapters;
- raw key export is gated and never part of an agent flow;
- idle wallet state holds an address, not a long-lived `EthPrivateKey`;
- the secp256k1 secret is wrapped by an Android Keystore AES-GCM key;
- StrongBox/TEE/software security level is observable and policy-enforced;
- biometric/device-auth failure cancels signing;
- one authentication unlocks at most one approved payment signature;
- temporary key/message buffers are cleared after success, failure, and cancel.

### 16.5 x402 payments

- non-402 request never shows a payment prompt;
- v1 headers/network names and mixed v1/v2 payloads are rejected;
- only Base Sepolia `exact/eip3009` USDC is accepted in the first release;
- invalid host/chain/token/recipient/amount challenge is blocked;
- HTTP, TLS failure, cross-origin redirect, changed method/URL/body, changed
  challenge, unsupported facilitator, and expired validity window are blocked;
- approval screen shows exact payment details;
- screenshots/non-secure displays are blocked for payment approval, and obscured
  touch events cannot press Approve;
- reject and cancel never sign or submit;
- chat “approve” text never signs;
- notification action cannot approve;
- simultaneous second intent queues or returns `approvalBusy`;
- approval expires and cannot be replayed;
- one approved intent signs exactly once;
- EIP-712 fields match the displayed EIP-3009 authorization exactly;
- provider receives v2 `PAYMENT-SIGNATURE` on the same original request;
- the original request retries at most once after proof;
- second 402 never signs again automatically;
- `PAYMENT-RESPONSE` is parsed and tied to the intent receipt;
- uncertain settlement checks receipt before any further action;
- insufficient balance and network failure are recoverable without duplicate
  charge;
- receipts are stored without private keys or reusable signatures;
- session and daily limits are enforced;
- no Permit2 allowance, Spend Permission, Auto Spend Permission, session key, or
  reusable ERC-7710 delegation is created.

### 16.6 Fresh install and upgrade

- fresh install boots native Gateway without dynamic catalog/network success;
- first setup does not download a duplicate gateway or dependency pack;
- upgrade preserves existing provider keys and selected model where compatible;
- cache migration does not create duplicate provider records;
- clear-data behavior removes intended credentials/cache and leaves no stale
  selected model;
- PRoot remains opt-in and does not become primary after a catalog error.

## 17. Rollback and migration strategy

Use feature flags at these boundaries:

- secure pending-credential setup enabled after migration verification;
- dynamic discovery enabled per provider;
- dynamic picker enabled globally;
- dynamic Gateway selection enabled per provider/model;
- x402 payment UI enabled per provider/network;
- mainnet payment disabled until explicitly released.

Rollback rules:

- disable discovery while retaining the last valid static/dynamic cache;
- fall back to the current static provider catalog;
- preserve the user's last known working model where possible;
- disable x402 payment adapters without disabling ordinary API-key chat;
- disable the payment transport/signer without hiding the ordinary Base wallet;
- never silently convert a failed paid request into a different paid route;
- keep diagnostic reason codes so a rollback is distinguishable from an auth or
  provider outage.

## 18. Risks and decisions still required

### Risk: provider metadata is incomplete or optimistic

Mitigation: local capability states, smoke canaries, conservative context caps,
and no automatic Agent-ready label.

### Risk: provider changes its models endpoint

Mitigation: adapter versioning, schema validation, stale cache, fixture tests,
and provider-specific error handling.

### Risk: context regressions are indirect

Mitigation: snapshot tests around selection and a strict separation between
advertised context and local usable context.

### Risk: x402 payment schemes differ

Mitigation: provider-specific challenge parser/signer and explicit scheme
allowlist; no generic ERC-20 transfer shortcut.

### Risk: app-controlled wallet custody is high impact

Mitigation: small testnet limits, approval-bound signing, device auth, no raw
key access from agents, Android Keystore envelope protection, receipts, and a
later Base Account/passkey evaluation. Mainnet is blocked until the signer
hardening and security review are complete.

### Risk: Android Keystore cannot portably sign Ethereum secp256k1

Mitigation: use a per-operation-authenticated Keystore AES-GCM wrapping key,
minimize/zeroize the unwrapped EOA key lifetime, report the actual hardware
security level, and never describe the EOA signature as hardware-isolated. Keep
Base Account/passkey migration as the route to stronger non-exportable signing.

### Risk: automatic x402 libraries bypass human approval

Mitigation: integrate the official v2 parser/scheme behind a custom
approval-bound signer callback. No generic `fetchWithPayment` wrapper receives a
signer capable of signing without a validated Plawie intent and fresh device
authentication.

### Risk: setup temporarily duplicates or leaks provider credentials

Mitigation: opaque one-time secret references, one canonical secret store,
idempotent consumption receipts, explicit cleanup paths, and no plaintext
`pendingApiKey` in ordinary preferences.

### Decision required before mainnet

- Which wallet identity is used for provider payment and how it is disclosed to
  the user;
- whether the payment wallet is a separate address or an explicitly selected
  existing user-wallet address;
- per-request/session/daily limits;
- minimum acceptable Keystore security level and device-auth fallback policy;
- provider allowlist and supported jurisdictions;
- support/refund behavior for an uncertain or settled provider charge.

The protocol baseline is not open: first release is x402 v2,
`exact/eip3009`, Base Sepolia USDC, with mandatory per-payment human approval and
device authentication. Mainnet keeps the same narrow scheme unless a separate
review changes it.

## 19. Commit order

The implementation should use small reviewable commits in this order:

1. `Document dynamic provider and x402 rollout contract`
2. `Move pending provider keys into one-time secure storage`
3. `Make bootstrap credential consumption idempotent`
4. `Add model catalog contracts and cache state`
5. `Add provider discovery adapter foundation`
6. `Add first dynamic provider models endpoint`
7. `Add first-run provider connection registry and review`
8. `Add grouped searchable provider model picker`
9. `Route dynamic selection through existing execution policy`
10. `Add context and tool invariance tests`
11. `Add official account connection actions`
12. `Harden the internal Base EOA signer with per-use device auth`
13. `Add x402 v2 payment intent and approval UI on Base Sepolia`
14. `Add Gateway-compatible exact EIP-3009 payment transport`
15. `Add live payment receipt and recovery tests`
16. `Evaluate Base Account passkey signing without spend permissions`
17. `Remove or quarantine superseded legacy provider/payment paths`

Do not commit generated APKs, build reports, caches, or temporary device files.
Do not stage unrelated pre-existing worktree files.

## 20. Definition of done

This plan is complete only when:

- users can discover current models without delaying Gateway startup;
- first setup can select a provider and securely save/consume its API key without
  ordinary-preference storage, duplicate bootstrap, or misleading copy;
- provider groups and search work on a small mobile screen;
- the selected model is namespaced, persisted, and safely routed;
- stale/offline/error states are honest and recoverable;
- model selection does not alter session history, system/tool payloads, or the
  native/PRoot/NDK lane;
- tool capability claims are backed by local smoke results;
- account connection uses official provider handoffs and redacted secrets;
- any x402 payment is v2 and requires a visible, exact, human approval plus a
  fresh device-authenticated wallet unlock;
- no agent or chat message can approve or access a private key;
- no standing spend permission, allowance, session key, or automatic payment
  wrapper can bypass per-transaction approval;
- payment retries are idempotent and receipt-aware;
- testnet and release acceptance matrices pass;
- current provider roadmap, help, security, and release documentation agree with
  the shipped behavior.
