# Provider Tool Compatibility, Model Truth, and Safe Failover Design

**Date:** 2026-08-13

**Status:** Audited design; implementation has not started

**Primary incident:** Venice-hosted Gemini 3.6 and Gemma 4 failures during
OpenClaw tool use

**Scope:** provider/model truth, OpenClaw provider compatibility, model
selection identity, tool-loop validation, phase-aware errors, and safe fallback

## 1. Decision summary

Plawie must stop treating a provider's generic function-calling flag as proof
that a model can run the complete mobile Agent loop.

The production boundary will be:

```text
provider catalog claim
        |
        v
Plawie capability assessment -----> model picker wording
        |
        v
OpenClaw provider-owned adapter ---> schema/replay/stream compatibility
        |
        v
complete tool-loop receipt --------> Agent-ready
```

The core decisions are:

1. Separate **availability**, **chat readiness**, and **tool-loop readiness**.
   A provider's `supportsFunctionCalling` or `supported_parameters=tools` is an
   advertised capability, not an `Agent-ready` receipt.
2. Keep provider quirks behind provider-owned boundaries. Venice compatibility
   must not alter direct Google, Anthropic, OpenAI, xAI, OpenRouter, Groq,
   ZenMux, BlockRun, local NDK, or native tool policy.
3. Prefer the official OpenClaw Provider Plugin SDK for runtime compatibility.
   Do not fork the downloaded Gateway, mutate npm package files, or reconstruct
   opaque Gemini state in Flutter unless the official extension seam is proven
   insufficient.
4. Preserve one canonical selected-model identity from picker to header,
   preferences, Gateway configuration, and `sessions.patch` acknowledgement.
5. Validate tools through a harmless full loop: schema accepted, tool call
   emitted, result returned, and final assistant response produced.
6. Do not silently replay work. Fallback is allowed only before a tool could
   have executed, defaults to user confirmation, stays within the same provider
   and payment contract, and uses a verified model.
7. Keep context/history policy invariant. This work does not change
   compaction, system prompts, mobile tools, skills, Node pairing, payments, or
   local/native routing.

## 2. What actually failed

The device evidence shows three different defects, not one provider outage.

| Route | Observed stage | Evidence | Classification |
| --- | --- | --- | --- |
| `venice/gemini-3-6-flash` before the current mapper | Initial request | Venice/Google rejected numeric `exclusiveMinimum` / `exclusiveMaximum` fields | Provider-specific tool-schema incompatibility; already normalized by the narrow Venice-Gemini request mapper |
| `venice/gemini-3-6-flash` after schema normalization | Continuation after a successful tool call | First request returned `200`; the next request failed because a function call lacked `thought_signature` | OpenAI-compatible Gemini replay/transport metadata loss |
| `venice/gemma-4-uncensored` | Initial request with the complete OpenClaw tool set | Venice returned `400 Invalid request parameters`; no tool ran | Exact schema/template cause still unproven; route must be quarantined from tools pending a reduced probe |
| Picker/header/session | Model selection | UI captured a Gemini selection while the header/session later presented Gemma under another label | Split model identity/state reconciliation defect |
| Chat error UI | Multiple stages | Distinct failures collapsed into “schema or tool payload” and sometimes claimed no tool ran | Missing phase-aware error contract |

KeeperHub, wallet funding, Venice balance, and the native mobile tool contract
were not the cause. The successful first Gemini request and tool invocation
prove that the action contract can run; the failure occurred while returning
the result to the model.

## 3. Critique of the previous proposal

The earlier proposal was directionally correct but too broad in four places.

### Correct conclusions

- Gemini and Gemma failed at different protocol stages.
- A full two-request tool smoke is required before displaying `Agent-ready`.
- The model picker and active session could disagree.
- Current user-facing error text is too vague.
- A compatible model can be offered when the selected route is not usable.

### Required corrections

#### 3.1 “Preserve Gemini thought signatures” needs a route diagnosis first

Google requires the exact opaque signature returned with a Gemini 3 function
call to be returned in the same position in the current turn. A missing
signature causes a `400`. Official Google SDKs handle this when the complete
response object is retained; manually assembled OpenAI-compatible history must
carry the provider extension correctly.

The installed OpenClaw family already contains Gemini replay and schema helpers,
but direct-Google behavior is intentionally scoped to Google endpoints/provider
identity. Venice currently appears as a generic `openai-completions` provider on
a Plawie loopback endpoint, so direct-Google behavior must not be enabled
globally.

Before changing replay, diagnostics must determine:

1. whether Venice returns `tool_calls[].extra_content.google.thought_signature`;
2. whether the unchanged Plawie proxy relays it;
3. whether OpenClaw retains it in normalized history;
4. whether the continuation request contains it in the original call position.

Only presence/count/stage may be logged. The signature itself must never enter
logs, preferences, receipts, model context, or analytics.

#### 3.2 Gemma 4 is not inherently chat-only

Google documents native Gemma 4 function calling and a specific tool-call/tool-
response chat template. Therefore the honest current label is:

> Provider advertises tools; this Plawie/OpenClaw route has not passed the full
> tool loop.

Plawie must not claim that Gemma 4 lacks tool support. It must quarantine the
current Venice model from mobile tools until a minimal direct-Venice probe and
an OpenClaw probe identify the rejected field or template boundary.

#### 3.3 “Transparent fallback” must not mean silent execution

A fallback can change model behavior, privacy, price, provider terms, payment
approval, context, or tool choice. Replaying after a device or wallet tool might
have run can duplicate side effects.

The default is therefore **Ask before switching**. Cross-provider fallback is
never automatic. Post-tool fallback never reruns the turn.

#### 3.4 “Rejected before generation” was false for Gemini continuation

The first Gemini request generated a tool call and the tool may have completed.
Errors must carry a turn phase and a conservative side-effect status instead of
guessing from provider text alone.

## 4. Official contract audit

### 4.1 Universal tool-loop contract

OpenAI, Anthropic, xAI, Groq, OpenRouter, Google, Venice, and Gemma describe the
same conceptual lifecycle with different wire formats:

```text
request + tool definitions
  -> assistant tool call
  -> application executes the tool
  -> application returns the correlated tool result
  -> assistant returns text or another tool call
```

Advertising the first arrow does not prove the continuation arrows work through
an aggregator, proxy, compatibility layer, Gateway replay policy, and the exact
Plawie mobile tool schema.

### 4.2 Provider-specific findings

| Provider/route | Official contract finding | Plawie policy |
| --- | --- | --- |
| Direct Google Gemini | Gemini 3 function calls require exact thought-signature replay; native Google SDKs preserve it | Leave the direct Google OpenClaw transport untouched; test it as a regression control |
| Venice | `/models` reports `supportsFunctionCalling`; Chat Completions accepts OpenAI-style `tools` and `parallel_tool_calls` | Treat the catalog flag as `providerAdvertised`; use a Venice-owned compatibility profile and full-loop proof |
| Gemma 4 through Venice | Gemma 4 supports tools but uses model-specific call/response formatting | Do not invent Gemma control tokens in Flutter; isolate whether Venice or OpenClaw must adapt the route |
| OpenAI | Tool use is explicitly a multi-request correlated loop | Direct OpenAI remains a golden control and keeps native OpenClaw ownership |
| Anthropic | Claude uses native `tool_use` and `tool_result` content blocks | Do not pass it through Venice/Gemini normalization |
| xAI | Function calls are returned, executed locally, then continued with correlated results; parallel calls may occur | Keep xAI provider-native handling and test both one and parallel calls where supported |
| OpenRouter | Model metadata can advertise `supported_parameters=tools`; it routes among model/provider endpoints | `tools` means advertised request support, not Plawie verification; route/model pair needs a receipt |
| Groq | Current hosted models document local/remote tool support, with model-specific parallel support | Use live models and model-level facts; do not conflate Groq built-in tools with Plawie/OpenClaw tools |
| ZenMux | Documents an OpenAI-compatible Chat API and tool calls | Keep generic routing until a complete loop proves a specific model |
| BlockRun | Live catalog documents availability, categories, context, and pricing but does not expose a general tool-readiness field | Never infer Agent readiness from `chat`, `coding`, or `available`; preserve per-request x402 approval |
| Local NDK/native owner | App-owned compact/local path with separate tool constraints | Out of scope; no cloud compatibility hook may alter it |

### 4.3 Immediate catalog freshness risk

The shipped static Groq defaults currently include:

- `llama-3.1-8b-instant`;
- `llama-3.3-70b-versatile`.

Groq schedules both for shutdown on **2026-08-16** for free/developer tiers and
recommends current GPT-OSS or Qwen replacements. This is not a Venice bug. It
requires a separate catalog-freshness hotfix and tests so the Venice change does
not become a broad provider refactor.

## 5. Current Plawie architecture audit

### 5.1 Capability overclaim

`ProviderModelDiscoveryService` currently maps a true provider field such as
Venice `model_spec.capabilities.supportsFunctionCalling` directly to
`ModelToolPolicy.reliable`. `DynamicModelRecord.agentReady` then derives true,
and the picker renders `Agent-ready`.

This collapses three distinct facts:

```text
provider says tools exist
!= provider accepted Plawie's schema
!= provider completed Plawie's result continuation
```

### 5.2 Paid-provider transport is intentionally narrow

Venice and BlockRun are app-owned loopback providers configured as
`openai-completions`. The loopback owns wallet authorization/payment while
OpenClaw owns the conversation and tools.

The request mapper currently changes only the provider-local model ID and the
known Venice-Gemini schema keywords. This narrowness is valuable. It must remain
the regression baseline until an official provider hook has parity.

### 5.3 Provider identity is split across UI/runtime state

The picker record, persisted model string, selected header state, Gateway
provider configuration, and session-resolved model are not represented by one
immutable value. The captured “Claude/Gemma/Gemini” mismatch is a symptom of
that split.

### 5.4 Error formatting has no turn phase

`GatewayService._formatGatewayProviderError` receives mostly raw text plus a
model string. It cannot reliably know whether a tool was emitted or executed,
so it collapses schema rejection, continuation metadata loss, authentication,
payment, and model binding into overlapping text heuristics.

## 6. Required invariants

Every implementation round must preserve these contracts:

- no changes to conversation content, order, compaction, or context reservation;
- no changes to system prompts, mobile tool names/schemas, Node declarations,
  skill routing, or native command allowlists;
- no change to local NDK/Node/PRoot ownership;
- no cross-provider credentials, request adapters, or replay hooks;
- no silent provider switch or new payment contract;
- no retry after a tool might have executed;
- no thought signatures, API keys, wallet authorization, prompts, or raw tool
  results in diagnostics or receipts;
- no model capability probe during setup, startup, ordinary catalog refresh, or
  background work;
- no paid BlockRun probe without the existing exact foreground approval;
- no stale Gateway package bundled into the APK; the official Gateway remains
  independently downloaded and updated.

## 7. Concern-separated target architecture

```text
ProviderModelDiscoveryService
  returns advertised metadata only
             |
             v
ModelCapabilityAssessmentService
  merges advertised facts + shipped verification + local receipts
             |
             +-----------------------> Picker/UI
             |                          honest labels/actions
             v
CanonicalModelSelection
  one immutable provider/model identity
             |
             v
Gateway session binding + ACK reconciliation
             |
             v
Provider runtime compatibility
  OpenClaw plugin/hook, scoped to provider + model family
             |
             v
Turn phase tracker -> typed failure -> safe retry/switch decision
```

### 7.1 Three independent readiness dimensions

Do not replace the current overclaim with another single overloaded enum.

```text
ModelAvailability:
  live | cached | stale | unavailable | deprecated

ModelChatReadiness:
  unknown | providerAdvertised | verified | failed

ModelToolReadiness:
  unknown | providerAdvertised | schemaAccepted | loopVerified | incompatible
```

`agentReady` is a derived display fact only when:

```text
availability is live/cached
AND chat readiness is verified
AND tool readiness is loopVerified
AND the receipt matches the current compatibility fingerprint
AND no provider/model kill switch is active
```

### 7.2 Capability evidence and expiry

An assessment may combine:

1. **Provider advertisement** from the live `/models` endpoint.
2. **Shipped compatibility profile** verified by the Plawie release test matrix.
3. **Local full-loop receipt** created only by an explicit user test or a real
   successful foreground turn.

A receipt is keyed by:

- provider ID;
- namespaced model ID and upstream model ID;
- effective provider endpoint class/fingerprint;
- OpenClaw version;
- Plawie compatibility-profile version;
- normalized mobile tool-schema digest;
- stream mode and relevant tool-mode flags;
- app version;
- observed time and catalog revision/ETag where available.

Receipts contain statuses, stage timings, response/request IDs when safe, and
sanitized error categories. They contain no prompts, tool arguments/results,
opaque reasoning metadata, credentials, or payment proofs.

Receipts are invalidated by a model alias changing target, Gateway upgrade,
adapter version change, schema digest change, endpoint change, provider
deprecation, or explicit kill switch. Ordinary app updates do not erase still-
valid receipts.

### 7.3 Canonical model identity

Introduce one immutable value, conceptually:

```text
CanonicalModelSelection {
  providerId
  namespacedModelId
  upstreamModelId
  displayLabel
  routeKind
  connectionId
  catalogRevision
  capabilityAssessmentId
}
```

The picker returns this value. The same value drives:

- header/provider label;
- persisted selected model;
- Gateway provider config materialization;
- `sessions.patch` model value;
- paid-provider foreground lease;
- readiness UI and error context.

After patching, Plawie compares the Gateway-resolved provider/model with the
expected value. On mismatch it blocks Send, displays both identities, refreshes
the session snapshot once, and offers repair. It never silently relabels one
model as another.

### 7.4 Two adapter boundaries, not one giant provider service

#### Plawie metadata/capability adapter

Owns discovery parsing, advertised facts, availability, local/shipped receipts,
labels, provider-specific error parsing, and test eligibility.

It does not mutate Gateway history or provider payloads.

#### OpenClaw runtime provider adapter

Owns provider/model-family schema normalization, replay/history rules, stream
normalization, and transport metadata through the official Provider Plugin SDK.

It does not own wallet signing, x402 approval, Plawie UI, or model selection.

The loopback paid-provider proxy continues to own only bounded wallet auth,
payment, endpoint pinning, model namespace mapping, and byte-for-byte relay
outside an explicitly allowlisted compatibility transform.

## 8. Venice Gemini resolution strategy

### 8.1 Diagnose before adapting

Add a redacted protocol trace around one deterministic read-only tool call:

```text
first outbound request:
  tools_present, normalized_schema_digest, stream

first inbound response:
  tool_call_count, thought_signature_present_count, finish_reason

continuation outbound request:
  tool_result_count, correlated_call_count,
  thought_signature_present_count, replay_profile

continuation response:
  status, provider_request_id, sanitized failure kind
```

The trace must establish exactly where the signature disappears.

### 8.2 Use official OpenClaw hooks first

Build an app-owned, versioned paid-provider plugin using OpenClaw's Provider
Plugin SDK rather than editing the official Gateway package. For Venice Gemini
models it should evaluate, in order:

1. `buildProviderToolCompatFamilyHooks("gemini")` for schema normalization;
2. the documented `passthrough-gemini` replay family for Gemini behind an
   OpenAI-compatible proxy;
3. a provider/model-scoped replay hook only if the generic family does not
   preserve the exact returned OpenAI-compatible extension.

The official documentation warns that `passthrough-gemini` sanitizes signatures
but does not enable native Gemini replay validation/bootstrap rewriting. It is
therefore necessary evidence, not assumed sufficient proof. The full loop must
pass on the installed official Gateway version.

### 8.3 Capability detection and double-transform prevention

At startup, inspect the installed Gateway version and plugin SDK capabilities.

- If the official Gateway already handles OpenAI-compatible Gemini replay for
  the selected route, Plawie's legacy mapper/replay hook is disabled.
- If only tool-schema hooks are available, use those for schema parity but keep
  the route Chat-only until continuation passes.
- If no safe hook exists, do not patch minified Gateway files or ship a beta
  Gateway. Keep Gemini Chat-only and upstream the narrow compatibility need.

The current `_adaptVeniceGeminiToolSchemas` remains until contract tests prove
the official hook produces equivalent or safer schemas. Its removal is a
separate commit with byte/semantic parity fixtures.

### 8.4 No fabricated opaque state

Do not generate or guess signatures. Google documents dummy bypass values for
specific manually reconstructed histories, but Plawie's normal case is a real
provider-generated call. Exact returned metadata is preferred; a bypass is not
a substitute for preserving provider state and is not part of the release
design.

## 9. Venice Gemma 4 resolution strategy

Gemma remains ordinary-chat capable but tool-quarantined until the exact `400`
is classified.

Run this reduction ladder against the same upstream model ID:

1. plain chat with no tools;
2. one minimal object-root function with one required string;
3. the same tool with `tool_choice=auto` and parallel calls disabled;
4. one representative Plawie read-only tool;
5. the normalized complete mobile tool set;
6. one tool result and final continuation.

For each stage, compare direct Venice and OpenClaw-through-loopback requests.
Capture Venice's documented bounded `details`/`issues` fields and request ID if
present. Do not expose raw bodies to users.

Decision tree:

```text
minimal direct Venice fails
  -> provider/model route does not currently accept this contract
  -> Chat-only + provider evidence

minimal direct passes, OpenClaw fails
  -> Plawie/OpenClaw adapter defect
  -> add a Gemma-specific profile only after exact diff is known

minimal passes, full schema fails
  -> isolate unsupported JSON-Schema keyword/tool size
  -> normalize only that proven difference

full loop passes
  -> issue loopVerified receipt and enable Agent-ready
```

Do not embed Gemma's raw control-token template in Flutter. Venice owns model
serving; OpenClaw/provider adapters own protocol formatting.

## 10. Full-loop compatibility probe

Use a deterministic, side-effect-free internal tool such as
`plawie_compat_echo`:

```json
{
  "value": "plawie-tool-probe",
  "sequence": 1
}
```

The tool returns a fixed, bounded object and performs no Node, skill, network,
wallet, file, notification, camera, or device action.

Required stages:

1. ordinary chat response;
2. tool schema accepted;
3. exactly one correlated tool call emitted;
4. fixed tool result accepted;
5. final response contains the expected completion marker;
6. no duplicate call;
7. streaming completes through its terminal frame;
8. optional parallel-call probe only when provider/model claims support.

### Probe policy

- CI/maintainer probes generate shipped compatibility profiles.
- On-device probes are explicit and explain token/payment cost.
- Catalog refresh never runs inference.
- Setup/startup never runs inference.
- BlockRun probes use the existing exact payment approval and cannot share a
  hidden approval lease.
- A real successful foreground tool turn can upgrade a local receipt.
- A provider failure can quarantine only the exact provider/model/fingerprint,
  not the provider globally.

## 11. Phase-aware error contract

Introduce structured values before formatting UI text:

```text
ProviderTurnPhase:
  binding
  initialRequest
  toolCallReceived
  toolExecutionStarted
  toolResultSubmitted
  continuation
  finalization

ProviderFailureKind:
  modelBindingMismatch
  authentication
  paymentRequired
  insufficientBalance
  rateLimited
  providerUnavailable
  modelUnavailableOrDeprecated
  toolSchemaRejected
  toolResultRejected
  continuationMetadataMissing
  contextLimit
  malformedProviderResponse
  unknown

SideEffectCertainty:
  none
  notStarted
  mayHaveRun
  completed
  unknown
```

Examples:

- “Gemma 4 rejected the tool definitions before any tool ran. Continue in
  Chat-only mode or switch to a verified Venice Agent model.”
- “Gemini called the tool, but Venice rejected the follow-up because required
  continuation metadata was missing. The tool was not repeated.”
- “The Gateway resolved `venice/gemma-4-uncensored`, but Plawie selected
  `venice/gemini-3-6-flash`. Sending was stopped before generation.”

Raw provider details remain in a redacted diagnostic export, not the chat
bubble. The UI includes provider, selected model, resolved model, phase,
request ID if safe, whether a tool may have run, and a deliberate next action.

## 12. Safe fallback policy

### 12.1 Default behavior

`Ask before switching` is the default. The user sees:

- why the selected model cannot complete the requested Agent route;
- whether any tool ran;
- proposed verified replacement;
- provider/payment/privacy continuity;
- whether the original message will be reused.

### 12.2 Eligibility

A candidate is eligible only when all are true:

- no tool call was emitted and side-effect certainty is `none/notStarted`;
- same provider, connection, authentication mode, and payment semantics;
- candidate has a matching `loopVerified` receipt;
- required modalities and safe context reservation are satisfied;
- candidate is not deprecated/quarantined;
- switching does not require a new unapproved BlockRun payment;
- the user confirms, unless they explicitly enabled same-provider pre-tool
  fallback.

Cross-provider fallback always requires a new explicit selection. A Venice
prepaid model never silently falls into BYOK, BlockRun, local, or another
provider.

### 12.3 Post-tool recovery

After a tool call/result, Plawie never resends the original turn automatically.
It preserves the immutable tool-result receipt and offers:

1. retry final narration only if the Gateway/provider supports a proven
   continuation resume that cannot rerun the tool;
2. start a new user turn that references the visible result; or
3. copy/export diagnostics.

Wallet, bridge, payment, file-write, message-send, app-control, camera, and
other consequential tools always use this stricter branch.

## 13. Provider isolation and feature flags

Use exact-scope flags, not global “disable tools” switches:

```text
provider.<id>.enabled
provider.<id>.tools.enabled
provider.<id>.model.<upstreamId>.tools.enabled
provider.<id>.compat.<profileVersion>.enabled
provider.<id>.fallback.enabled
```

Resolution order is model kill switch, provider tool switch, compatibility
profile, then generic policy. Disabling Venice Gemini tools must not affect
Venice GLM, direct Google Gemini, OpenRouter Gemini, or BlockRun.

Suggested initial state from current physical-device evidence:

| Route | Initial release state |
| --- | --- |
| Venice GLM 5.2 exact tested ID | Candidate Agent-ready only after formal full-loop receipt is captured |
| Venice Gemini 3.6 | Chat-only until exact signature replay passes |
| Venice Gemma 4 uncensored | Chat-only/tool-quarantined until reduction ladder passes |
| BlockRun models | Keep current successful behavior; no capability promotion from catalog categories |
| Direct BYOK providers | Unchanged; run as regression controls |
| OpenRouter/ZenMux dynamic models | Provider-advertised until route/model full-loop evidence exists |
| Groq deprecated static Llama IDs | Mark deprecated and replace in a separate urgent catalog commit |
| Local NDK/native models | Unchanged and outside provider failover |

## 14. Regression matrix

### Contract tests

- advertised capability never produces `loopVerified` by itself;
- picker label reflects assessment state accurately;
- canonical model identity drives header, config, patch, and paid lease;
- model ACK mismatch blocks Send;
- generic providers remain byte/semantically unchanged by Venice adapters;
- Venice Gemini schema adapter changes only proven unsupported keywords;
- thought-signature diagnostics record booleans/counts, never values;
- Gemma quarantine is exact-model scoped;
- no fallback after `toolCallReceived`;
- fallback candidate must preserve provider/payment/auth/modality;
- raw error and secrets are redacted;
- receipt invalidation follows fingerprint changes;
- catalog refresh performs no inference/payment.

### Golden provider controls

| Control | Required checks |
| --- | --- |
| Direct Google Gemini | plain chat, one tool, continuation, streaming signature preservation |
| Direct OpenAI | standard correlated tool loop |
| Direct Anthropic | native tool-use/result blocks |
| Direct xAI | one tool; parallel path only where supported |
| OpenRouter | advertised-vs-verified label, endpoint/model route receipt |
| Groq current replacement | one local function loop; parallel policy from live model facts |
| ZenMux | plain chat and complete OpenAI-compatible loop |
| Venice GLM | currently successful path remains successful |
| Venice Gemini | schema acceptance plus exact continuation |
| Venice Gemma | reduction ladder and honest quarantine |
| BlockRun | one approved paid request; no hidden extra approval or fallback payment |
| Local NDK/native | model switch does not alter lane, context policy, or tools |

### Physical-device acceptance

1. Select each target model and verify the same identity in picker, header,
   session snapshot, and Gateway logs.
2. Run the side-effect-free tool probe.
3. Run one representative read-only Node tool.
4. Run one consequential tool in reject-first mode and prove no automatic
   retry/fallback.
5. Disconnect/reconnect during continuation and prove no duplicate tool call.
6. Refresh catalogs and prove no inference/payment occurs.
7. Restart/update the app and verify valid receipts survive without preserving
   opaque provider state.

## 15. Implementation order and commit boundaries

### Phase 0 — Urgent independent catalog hotfix

- Replace/retire the two Groq IDs scheduled for 2026-08-16 shutdown using the
  official live replacements.
- Add deprecation parsing/display and catalog tests.
- Commit independently from Venice work.

**Exit:** no default picker route points at a scheduled-dead Groq model.

### Phase 1 — Truthful capability states

- Add the three readiness dimensions and assessment repository.
- Change discovery parsing so provider tool flags remain advertisements.
- Update model-card/picker labels and Chat-only actions.
- Migrate existing cached records conservatively to `unknown/advertised`.

**Exit:** Gemini/Gemma cannot be labeled Agent-ready without a receipt.

### Phase 2 — Canonical model identity

- Introduce `CanonicalModelSelection`.
- Drive picker, header, preferences, Gateway config, session patch, and paid
  provider lease from it.
- Reconcile exact provider/model ACK before enabling Send.

**Exit:** no displayed/selected/resolved model mismatch is possible.

### Phase 3 — Typed turn failures and no-duplicate recovery

- Track turn phase and side-effect certainty from Gateway events.
- Replace text-only heuristics with typed classification plus provider parsers.
- Add user-safe recovery actions and diagnostic export.

**Exit:** errors state what failed, whether a tool may have run, and what can be
done safely.

### Phase 4 — Probe and receipt framework

- Add the deterministic internal tool and staged probe runner.
- Add shipped profiles, local receipts, invalidation, and model-scoped
  quarantine.
- Keep probes off automatic lifecycle paths.

**Exit:** `Agent-ready` means the complete loop passed for the effective
fingerprint.

### Phase 5 — Venice runtime provider plugin

- Add the versioned app-owned OpenClaw provider plugin.
- Diagnose signature presence/loss.
- Adopt official Gemini tool/replay hooks behind model-family detection.
- Retain the existing mapper until parity passes.
- Run the Gemma reduction ladder and add only evidence-backed normalization.

**Exit:** Venice Gemini completes the full loop or remains honestly Chat-only;
Gemma is enabled only if its full loop passes; other providers are unchanged.

### Phase 6 — User-confirmed safe fallback

- Rank only same-provider, same-contract, verified candidates.
- Add the pre-tool switch confirmation.
- Add post-tool result-preserving recovery without replay.

**Exit:** a compatibility failure has a useful path forward with no silent
provider/payment change and no duplicated action.

### Phase 7 — Release matrix and rollback

- Run contract, integration, Gateway-version, and physical-device matrices.
- Document exact verified provider/model fingerprints.
- Ship model/provider compatibility kill switches.

**Exit:** each provider can be rolled back independently without disabling
chat, wallets, tools, or another provider.

## 16. Files expected to change during implementation

The exact split can evolve after tests, but provider concerns should land near:

- `lib/services/dynamic_model_catalog.dart` — advertised versus verified state;
- `lib/services/provider_model_discovery_service.dart` — provider facts only;
- a new capability-assessment/receipt service — merged readiness truth;
- `lib/widgets/dynamic_model_picker_panel.dart` — honest labels and actions;
- `lib/screens/chat_screen.dart` — canonical selection and recovery UI;
- `lib/services/gateway_service.dart` — typed phase/error plumbing, not provider
  schema hacks;
- `lib/services/paid_provider_proxy_models.dart` — existing narrow mapper until
  plugin parity;
- a new app-owned OpenClaw paid-provider plugin — Venice runtime hooks;
- focused provider contract tests and physical-device runbook updates.

Do not put Venice/Gemini conditionals into generic model execution policy,
wallet services, Node tools, skill services, setup flow, or local model code.

## 17. Release acceptance checklist

- [ ] Provider catalog flags are displayed as advertised, not verified.
- [ ] Only a matching full-loop receipt produces `Agent-ready`.
- [ ] Venice Gemini's exact thought signature is either preserved or the route
      stays Chat-only.
- [ ] No opaque signature is logged or persisted.
- [ ] Venice Gemma has exact direct/Gateway evidence before tool enablement.
- [ ] Venice GLM's known-good path remains green.
- [ ] BlockRun approval/payment behavior is unchanged.
- [ ] Direct BYOK and local/native golden controls pass.
- [ ] Selected, displayed, configured, and resolved model IDs match.
- [ ] Errors report phase and side-effect certainty.
- [ ] No post-tool automatic replay exists.
- [ ] No cross-provider automatic fallback exists.
- [ ] Context, history, tools, skills, Node policy, and native routing snapshots
      are unchanged.
- [ ] Scheduled-dead Groq defaults are removed in their own commit.
- [ ] Every compatibility change has an exact provider/model kill switch.

## 18. Primary references

- [Google Gemini thought signatures](https://ai.google.dev/gemini-api/docs/generate-content/thought-signatures)
- [Google Gemini OpenAI compatibility](https://ai.google.dev/gemini-api/docs/openai)
- [Google Gemma 4 function calling](https://ai.google.dev/gemma/docs/capabilities/text/function-calling-gemma4)
- [Venice model catalog](https://docs.venice.ai/api-reference/endpoint/models/list)
- [Venice Chat Completions](https://docs.venice.ai/api-reference/endpoint/chat/completions)
- [OpenClaw Provider Plugin SDK](https://docs.openclaw.ai/plugins/sdk-provider-plugins)
- [OpenAI function calling](https://developers.openai.com/api/docs/guides/function-calling)
- [Anthropic tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools)
- [xAI function calling](https://docs.x.ai/developers/tools/function-calling)
- [OpenRouter model metadata](https://openrouter.ai/docs/guides/overview/models)
- [OpenRouter tool calling](https://openrouter.ai/docs/guides/features/tool-calling)
- [Groq tool use](https://console.groq.com/docs/tool-use/overview)
- [Groq deprecations](https://console.groq.com/docs/deprecations)
- [ZenMux documentation](https://zenmux.ai/docs)
- [BlockRun models](https://blockrun.ai/docs/api-reference/models)
