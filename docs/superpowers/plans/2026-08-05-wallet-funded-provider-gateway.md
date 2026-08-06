# Wallet-Funded Provider Gateway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Venice prepaid-wallet models and BlockRun per-request x402 models discoverable and usable through the existing native OpenClaw Gateway without changing conversation context, tool schemas, skill routing, or native-first runtime behavior.

**Architecture:** A dedicated Dart `HttpServer` binds to `127.0.0.1:11436` and exposes provider-specific OpenAI-compatible paths to OpenClaw. The Gateway remains the orchestration owner and sends its normal messages/tools to this proxy. The proxy authenticates with an app-private bearer capability, maps only the namespaced model ID, applies Venice SIWE or BlockRun x402 policy, and relays ordinary/SSE responses. Human approval is brokered to foreground UI; no agent or background path can approve a payment.

**Tech Stack:** Dart `dart:io` loopback HTTP/SSE, Flutter services/widgets, native OpenClaw provider configuration, Android bounded MethodChannel signer, Web3j SIWE/EIP-3009, existing x402 v2 policy/receipt services, dynamic model catalog, Flutter/JUnit tests.

---

## Non-negotiable transport contract

- Chat UI still talks to `GatewayService`; it never calls Venice or BlockRun chat endpoints directly.
- OpenClaw still owns session IDs, context/compaction, system prompts, messages, tools, tool results, retries, and native skill/node routing.
- Proxy mutations are limited to upstream model ID and auth/payment headers. All other JSON fields are semantically identical.
- Proxy listens only on IPv4 loopback, rejects missing/wrong capability before reading a large body, rejects redirects, and allowlists only `https://api.venice.ai` and `https://blockrun.ai`.
- Maximum request body is 4 MiB, response headers 64 KiB, ordinary response 16 MiB, and each SSE line 1 MiB; timeouts are explicit.
- Logs contain provider, route, status, elapsed time, byte counts, request fingerprint prefix, and stable error code. They never contain prompts, tool arguments/results, SIWE/payment headers, signatures, challenges, private keys, full receipts, or loopback capability.
- Venice inference spends prepaid provider credit, not an on-chain transaction per call. Foreground Send grants one bounded interactive turn lease; background use has no lease and is rejected.
- Every BlockRun 402 is separately reviewed, Android-authenticated, signed, and retried once. A chat message such as “yes” is never approval.

## File map

**Create**

- `lib/services/paid_provider_proxy_models.dart`
- `lib/services/paid_provider_loopback_credential_service.dart`
- `lib/services/paid_provider_proxy_service.dart`
- `lib/services/paid_provider_http_client.dart`
- `lib/services/paid_provider_approval_broker.dart`
- `lib/services/paid_provider_turn_authorization_service.dart`
- `lib/services/venice_wallet_auth_service.dart`
- `lib/widgets/paid_provider_approval_dialog.dart`
- `test/paid_provider_loopback_credential_service_test.dart`
- `test/paid_provider_proxy_contract_test.dart`
- `test/paid_provider_proxy_stream_test.dart`
- `test/paid_provider_approval_broker_test.dart`
- `test/venice_wallet_auth_service_test.dart`
- `test/venice_paid_provider_proxy_test.dart`
- `test/blockrun_paid_provider_proxy_test.dart`
- `test/wallet_funded_provider_setup_test.dart`
- `test/wallet_funded_model_picker_test.dart`
- `docs/WALLET_FUNDED_MODEL_PROVIDERS.md`

**Modify**

- `android/app/src/main/kotlin/com/openclaw/plawie/SecureEvmWalletManager.kt`
- `android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt`
- `android/app/src/test/kotlin/com/openclaw/plawie/VeniceSiweMessageTest.kt`
- `lib/services/native_bridge.dart`
- `lib/services/provider_balance_service.dart`
- `lib/services/x402_payment_service.dart`
- `lib/services/x402_payment_transport_service.dart`
- `lib/services/ai_payment_provider_catalog.dart`
- `lib/services/model_provider_catalog.dart`
- `lib/services/provider_model_discovery_service.dart`
- `lib/services/dynamic_model_catalog.dart`
- `lib/services/provider_setup_service.dart`
- `lib/services/preferences_service.dart`
- `lib/services/gateway_service.dart`
- `lib/screens/setup_flow_screen.dart`
- `lib/screens/chat_screen.dart`
- `lib/screens/base_screen.dart`
- `lib/screens/settings_screen.dart`
- existing provider/x402 tests

## Task 1: Establish a proxy contract that cannot alter Gateway context

- [ ] **Step 1: Write semantic-equality tests before the server exists**

Create a representative Gateway payload containing system/user/assistant/tool messages, parallel tool calls, tool results, JSON schemas, `tool_choice`, stop values, temperature, max tokens, response format, stream options, and unknown extension fields. Assert `PaidProviderRequestMapper.map` changes only:

```json
{"model":"venice/llama-3.3-70b"}
```

to:

```json
{"model":"llama-3.3-70b"}
```

and preserves every other decoded value and array order. Repeat for `blockrun/...`; reject a model prefix that does not match the route.

- [ ] **Step 2: Add transport-security red tests**

Test non-loopback bind rejection, wrong/missing capability, unsupported method/path, redirect response, upstream host mismatch, oversized request/response/header/SSE line, malformed JSON, cancelled client, upstream timeout, and header redaction.

- [ ] **Step 3: Run the tests and confirm red state**

```powershell
flutter test test/paid_provider_proxy_contract_test.dart test/paid_provider_loopback_credential_service_test.dart
```

Expected: missing proxy/model/credential classes.

- [ ] **Step 4: Implement per-process loopback credentials**

Generate 32 random bytes with `Random.secure()`, encode base64url without padding, keep the value in memory, compare UTF-8 bytes in constant time, and rotate only while the native Gateway is stopped. Expose no public getter except the narrowly injected value used when writing OpenClaw provider config.

- [ ] **Step 5: Implement typed proxy routes**

Use:

```text
GET  /health
GET  /venice/v1/models
POST /venice/v1/chat/completions
POST /venice/v1/responses
GET  /blockrun/v1/models
POST /blockrun/v1/chat/completions
POST /blockrun/v1/responses
```

Return 404 for every other path and 405 with `Allow` for wrong methods. `responses` remains disabled per provider until its contract test has an upstream fixture; disabled means a structured 501 and it is not advertised to OpenClaw.

- [ ] **Step 6: Bind the minimal server**

```dart
_server = await HttpServer.bind(
  InternetAddress.loopbackIPv4,
  11436,
  shared: false,
);
```

Authenticate `Authorization: Bearer <capability>`, stream request bytes with a 4 MiB cap, and dispatch through injectable provider handlers. `/health` reports ready providers and stable error codes, never the credential.

- [ ] **Step 7: Run focused tests and commit**

```powershell
flutter test test/paid_provider_proxy_contract_test.dart test/paid_provider_loopback_credential_service_test.dart
dart analyze lib/services/paid_provider_proxy_models.dart lib/services/paid_provider_loopback_credential_service.dart lib/services/paid_provider_proxy_service.dart lib/services/paid_provider_http_client.dart
git add lib/services/paid_provider_proxy_models.dart lib/services/paid_provider_loopback_credential_service.dart lib/services/paid_provider_proxy_service.dart lib/services/paid_provider_http_client.dart test/paid_provider_proxy_contract_test.dart test/paid_provider_loopback_credential_service_test.dart
git commit -m "feat: add bounded paid-provider loopback proxy"
```

## Task 2: Prove ordinary and SSE response passthrough

- [ ] **Step 1: Add failing stream/tool-call tests**

Use a local fake upstream. Cover ordinary JSON, SSE content deltas, fragmented UTF-8, tool-call argument fragments, usage events, comments/keepalive, `[DONE]`, upstream disconnect, client cancellation, and non-2xx bodies. Assert status and safe response headers are preserved and each response byte sequence is unchanged after the proxy.

- [ ] **Step 2: Implement raw upstream relaying**

Forward only allowlisted request headers (`content-type`, `accept`, provider-required version headers) plus provider auth. Strip hop-by-hop headers. Copy upstream status; allowlist response `content-type`, request IDs, rate-limit/balance/payment metadata; write upstream body chunks directly to the Gateway response with backpressure.

- [ ] **Step 3: Add cancellation and timeouts**

Use a 20-second connect timeout, 120-second first-byte timeout, and ten-minute streaming inactivity ceiling. Closing the Gateway request cancels upstream. Never retry ordinary inference automatically.

- [ ] **Step 4: Run tests and commit**

```powershell
flutter test test/paid_provider_proxy_stream_test.dart test/paid_provider_proxy_contract_test.dart
git add lib/services/paid_provider_proxy_service.dart lib/services/paid_provider_http_client.dart test/paid_provider_proxy_stream_test.dart test/paid_provider_proxy_contract_test.dart
git commit -m "feat: preserve paid-provider streaming responses"
```

## Task 3: Generalize Venice identity signing without adding generic signing

- [ ] **Step 1: Extend Kotlin SIWE tests first**

In `VeniceSiweMessageTest.kt`, test exact URI/path and statement for:

- `GET /api/v1/models`;
- `POST /api/v1/chat/completions`;
- `POST /api/v1/responses` only when enabled;
- existing `GET /api/v1/x402/balance/<same wallet>`.

Reject HTTP, alternate/subdomain hosts, non-443 ports, user info, query/fragment, path suffixes, wrong wallet, unsupported method, stale issue time, lifetime over five minutes, and nonce outside `[A-Za-z0-9]{8,64}`.

- [ ] **Step 2: Run red native tests**

```powershell
cd android
./gradlew.bat :app:testDebugUnitTest --tests com.openclaw.plawie.VeniceSiweMessageTest
```

Expected: inference route fixtures fail under the balance-only parser.

- [ ] **Step 3: Add a bounded native method**

Rename internal parsing to `parseVeniceProviderIdentity`; expose `signSecureVeniceProviderIdentity` while retaining `signSecureVeniceBalanceIdentity` as a compatibility wrapper. Arguments are `method`, `uri`, `nonce`, `issuedAt`, and `expirationTime`. Build the SIWE statement from a closed route table; no caller-provided statement/domain is accepted.

- [ ] **Step 4: Add Dart auth service and tests**

`VeniceWalletAuthService.authorize(method, uri)` creates a fresh cryptographic nonce/timestamps, calls the bounded native method, verifies returned payer/message, and encodes the documented `X-Sign-In-With-X` JSON envelope. Cache nothing for inference. The existing five-minute exact balance identity cache may remain limited to balance reads.

- [x] **Step 5: Run tests and commit**

```powershell
cd android
./gradlew.bat :app:testDebugUnitTest --tests com.openclaw.plawie.VeniceSiweMessageTest
cd ..
flutter test test/venice_wallet_auth_service_test.dart test/provider_balance_service_test.dart
git add android/app/src/main/kotlin/com/openclaw/plawie/SecureEvmWalletManager.kt android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt android/app/src/test/kotlin/com/openclaw/plawie/VeniceSiweMessageTest.kt lib/services/native_bridge.dart lib/services/venice_wallet_auth_service.dart lib/services/provider_balance_service.dart test/venice_wallet_auth_service_test.dart test/provider_balance_service_test.dart
git commit -m "feat: add bounded Venice inference identity signing"
```

## Task 4: Discover Venice and BlockRun models dynamically

- [ ] **Step 1: Add discovery/catalog red tests**

Extend provider catalog and discovery tests for `venice` and `blockrun`. Assert wallet-funded type, no API-key requirement, namespaced IDs, searchable/grouped records, capability parsing, cache timestamp, ETag/304, stale state, malformed models, duplicate IDs, and unavailable reason.

Venice discovery requires a healthy wallet and bounded SIWE; BlockRun `GET https://blockrun.ai/api/v1/models` is public. A shipped explanatory fallback must have `liveAvailable: false` and cannot mark the provider ready.

- [ ] **Step 2: Add provider records and config defaults**

Add providers to `ModelProviderCatalog`:

```dart
case 'venice':
  return {
    'api': 'openai-completions',
    'baseUrl': 'http://127.0.0.1:11436/venice/v1',
  };
case 'blockrun':
  return {
    'api': 'openai-completions',
    'baseUrl': 'http://127.0.0.1:11436/blockrun/v1',
  };
```

Do not add a fabricated provider key here; `GatewayService` injects the current loopback capability only while configuring a running proxy.

- [ ] **Step 3: Extend discovery auth cleanly**

Add `ProviderDiscoveryAuth.veniceWalletIdentity` and inject `VeniceWalletAuthService`. The request builder awaits a per-request header resolver; unrelated provider auth branches remain unchanged. Add BlockRun’s public parser and map upstream IDs to `blockrun/<upstream>`.

- [ ] **Step 4: Keep cache truth separate from readiness**

`DynamicModelCatalog` records `fresh`, `stale`, `offlineFallback`, or `unavailable`. Setup/model picker may display stale models but cannot label payment/provider readiness without wallet/proxy/balance state.

- [x] **Step 5: Run tests and commit**

```powershell
flutter test test/model_provider_catalog_test.dart test/provider_model_discovery_service_test.dart test/dynamic_model_catalog_test.dart test/ai_payment_provider_catalog_test.dart
dart analyze lib/services/model_provider_catalog.dart lib/services/provider_model_discovery_service.dart lib/services/dynamic_model_catalog.dart lib/services/ai_payment_provider_catalog.dart
git add lib/services/model_provider_catalog.dart lib/services/provider_model_discovery_service.dart lib/services/dynamic_model_catalog.dart lib/services/ai_payment_provider_catalog.dart test/model_provider_catalog_test.dart test/provider_model_discovery_service_test.dart test/dynamic_model_catalog_test.dart test/ai_payment_provider_catalog_test.dart
git commit -m "feat: discover wallet-funded provider models"
```

## Task 5: Route Venice inference through OpenClaw

- [x] **Step 1: Add Venice proxy red tests**

Test missing/unhealthy wallet, no foreground turn lease, valid lease, exact SIWE route, model mapping, ordinary response, SSE response, tool call, balance header capture, auth rejection, upstream error, and balance-refresh failure after a successful response.

- [x] **Step 2: Implement bounded interactive turn leases**

`PaidProviderTurnAuthorizationService` creates an in-memory lease when the foreground user presses Send with a Venice model visible. Bind it to conversation/session ID, provider, selected model, creation time, and a maximum of eight proxy calls or ten minutes; close it when the Gateway turn finishes/cancels or app loses foreground. It cannot be created by an agent tool or background task.

- [x] **Step 3: Implement Venice handler**

For each allowed request: validate lease; map only model ID; obtain fresh `X-Sign-In-With-X`; send to the exact Venice route; relay response unchanged. Capture only documented balance metadata. After a successful terminal response, schedule `ProviderBalanceService.refresh('venice')`; a refresh error does not alter the completed model response.

- [x] **Step 4: Keep top-up distinct**

The existing Venice top-up remains in `X402PaymentTransportService`. On its terminal receipt, refresh Venice balance and transaction history. Do not call top-up from model inference or infer chat readiness from a top-up intent alone.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/venice_paid_provider_proxy_test.dart test/venice_wallet_auth_service_test.dart test/provider_balance_service_test.dart test/x402_payment_transport_service_test.dart
git add lib/services/paid_provider_turn_authorization_service.dart lib/services/paid_provider_proxy_service.dart lib/services/venice_wallet_auth_service.dart lib/services/provider_balance_service.dart lib/services/x402_payment_transport_service.dart test/venice_paid_provider_proxy_test.dart test/provider_balance_service_test.dart test/x402_payment_transport_service_test.dart
git commit -m "feat: route Venice wallet inference through OpenClaw"
```

## Task 6: Broker exact per-request BlockRun x402 approvals

- [x] **Step 1: Add broker and BlockRun red tests**

Cover no-payment 200, exact 402 parse, wrong version/network/asset/payee/resource/host/amount/expiry, policy cap, background request, approval displayed, cancel, Android auth cancel, sign failure, same-body single retry, second 402, receipt success, network loss after payment, receipt recovery, duplicate fingerprint, and concurrent requests.

- [x] **Step 2: Add a foreground-only approval broker**

`PaidProviderApprovalBroker` publishes `PendingPaidProviderApproval` through a stream and waits on a private `Completer`. The intent contains provider/model, exact USDC amount, payee, resource, expiry, request fingerprint, and user-facing reason. Only the canonical dialog can call `approve(intentId)`/`cancel(intentId)`; stale or mismatched IDs fail. If there is no foreground listener, return `approval_required` immediately.

- [x] **Step 3: Reuse the x402 policy as a pure validator**

Extract or expose the current challenge parser/policy from `x402_payment_service.dart` so top-up and inference share version-2, Base Mainnet, native-USDC, allowlisted-host, time-window, amount-cap, and nonce validation. Keep transport-specific orchestration separate.

- [x] **Step 4: Implement exactly one paid retry**

Compute SHA-256 over provider, method, exact upstream URI, and mapped request body bytes. Send once without payment. On a valid 402, persist pending intent, await visible approval, call `NativeBridge.signSecureX402Authorization`, build `PAYMENT-SIGNATURE`, and retry the same method/URI/body bytes once. A second 402 or connection ambiguity enters receipt-recovery and never signs/retries blindly.

- [x] **Step 5: Persist a redacted inference receipt**

Extend receipt schema with request fingerprint, provider, model, upstream resource, amount/payee/network/asset, challenge fingerprint, provider receipt/transaction hash when returned, status, timestamp, and `paidRetryConsumed`. Omit signature, payment header, raw challenge, prompts, and response body.

- [x] **Step 6: Run tests and commit**

```powershell
flutter test test/paid_provider_approval_broker_test.dart test/blockrun_paid_provider_proxy_test.dart test/x402_payment_service_test.dart test/x402_payment_transport_service_test.dart
git add lib/services/paid_provider_approval_broker.dart lib/services/paid_provider_proxy_service.dart lib/services/x402_payment_service.dart lib/services/x402_payment_transport_service.dart lib/services/preferences_service.dart test/paid_provider_approval_broker_test.dart test/blockrun_paid_provider_proxy_test.dart test/x402_payment_service_test.dart test/x402_payment_transport_service_test.dart
git commit -m "feat: add approved BlockRun x402 inference"
```

## Task 7: Integrate proxy lifecycle and provider config with Gateway startup

- [x] **Step 1: Add Gateway integration red tests**

Test startup order, current capability injection, provider defaults, stop/rotation, port collision, health failure, paid provider selected while proxy unavailable, and unchanged BYOK/NDK/native routes. Add a regression asserting `gatewayRuntimeOwner` remains native and no PRoot path is selected.

- [x] **Step 2: Start proxy before native Gateway configuration**

`GatewayService` starts/health-checks the paid proxy, obtains the current capability, merges Venice/BlockRun base URLs and `apiKey` capability into OpenClaw config, then starts the native Gateway. Stop the proxy after Gateway stop. On port collision, verify whether the endpoint answers the current capability; never attach to an unknown process.

- [x] **Step 3: Preserve provider configuration merge rules**

Extend `_ensureCatalogProviderDefaults` without overwriting user BYOK providers. Paid-provider fields may replace only Plawie-owned `baseUrl`, `api`, current loopback `apiKey`, and dynamic model list. Remove stale paid-provider capability when the proxy is disabled.

- [x] **Step 4: Add end-to-end context/tool invariance tests**

Feed the same Gateway request through a fake BYOK upstream and each paid route. Deep-compare system prompt, history, tools, tool results, session metadata, and stream tool-call events. Permit only provider/model endpoint/header differences. Assert native skill routing and tool continuation tests remain green.

- [x] **Step 5: Run tests and commit**

```powershell
flutter test test/paid_provider_proxy_contract_test.dart test/paid_provider_proxy_stream_test.dart test/gateway_service_tool_continuation_test.dart test/gateway_required_mobile_route_test.dart test/gateway_connection_session_patch_test.dart
dart analyze lib/services/gateway_service.dart lib/services/paid_provider_proxy_service.dart
git add lib/services/gateway_service.dart lib/services/paid_provider_proxy_service.dart test/paid_provider_proxy_contract_test.dart test/paid_provider_proxy_stream_test.dart test/gateway_service_tool_continuation_test.dart test/gateway_required_mobile_route_test.dart
git commit -m "feat: register paid providers with native Gateway"
```

## Task 8: Align setup, model picker, Chat, Base, and Settings

- [ ] **Step 1: Write widget/service tests before UI changes**

Test BYOK key input remains unchanged; Venice/BlockRun show no key field; setup records selection without creating/funding/spending; searchable grouped models; wallet-funded badges; stale catalog; missing wallet; Venice balance/top-up actions; BlockRun per-request label; approval modal details/cancel; background refusal; and switching back to BYOK in the same conversation.

- [ ] **Step 2: Update first setup**

Wallet-funded selection explains Base Mainnet, ETH gas, native USDC, wallet backup, Venice prepaid top-up versus BlockRun per-request approval, and that setup performs no blockchain action. Completion routes to a clear Base funding action when not ready.

- [x] **Step 3: Use one canonical approval surface**

`PaidProviderApprovalDialog` is opened by the top-level foreground UI listener and shows provider/model, exact amount, payee short address with copy/full-view, Base Mainnet, expiry, and request reason. Approve leads to Android authentication; Cancel completes the broker with no payment. Chat and Settings link to this same mechanism rather than creating alternate flows.

- [ ] **Step 4: Make model readiness honest**

Model cards/picker expose: catalog freshness, wallet state, Venice balance freshness, proxy health, `Fund wallet`, `Top up Venice`, `Manage`, or `Payment per request`. Do not label BlockRun funded; do not label Venice ready from wallet existence alone.

- [ ] **Step 5: Update help and provider docs**

Document dynamic discovery, SIWE identity, interactive lease, prepaid versus per-request payment, human approval, balance freshness, exact error/recovery states, and the fact that context/tools stay in OpenClaw.

- [ ] **Step 6: Run the complete slice verification**

```powershell
flutter test test/model_provider_catalog_test.dart test/provider_model_discovery_service_test.dart test/dynamic_model_catalog_test.dart test/provider_setup_service_test.dart test/wallet_funded_provider_setup_test.dart test/wallet_funded_model_picker_test.dart test/paid_provider_proxy_contract_test.dart test/paid_provider_proxy_stream_test.dart test/venice_wallet_auth_service_test.dart test/venice_paid_provider_proxy_test.dart test/paid_provider_approval_broker_test.dart test/blockrun_paid_provider_proxy_test.dart test/provider_balance_service_test.dart test/x402_payment_service_test.dart test/x402_payment_transport_service_test.dart test/gateway_service_tool_continuation_test.dart
cd android
./gradlew.bat :app:testDebugUnitTest
cd ..
flutter analyze
flutter build apk --debug
git diff --check
```

Expected: all listed tests and Android tests pass, analyzer has no new errors, APK builds, and diff check is silent.

- [ ] **Step 7: Commit UI and documentation**

```powershell
git add lib/screens lib/widgets/paid_provider_approval_dialog.dart lib/services/provider_setup_service.dart docs/WALLET_FUNDED_MODEL_PROVIDERS.md test/wallet_funded_provider_setup_test.dart test/wallet_funded_model_picker_test.dart
git commit -m "feat: expose wallet-funded model management"
```

## Completion gate

- [ ] Venice and BlockRun model lists are dynamic and namespaced.
- [ ] Setup never asks wallet-funded providers for an API key.
- [ ] Native OpenClaw remains the Gateway/runtime owner; PRoot remains user-selected fallback only.
- [ ] Proxy binds only to loopback and rejects every wrong capability/host/path/redirect.
- [ ] Gateway messages, context, tools, and tool results are invariant apart from model mapping.
- [ ] Venice inference requires a foreground turn lease and fresh bounded identity signature.
- [ ] Venice top-up and inference remain separate; balance refresh follows both successful operations.
- [ ] Every BlockRun paid call receives exact foreground approval and Android authentication.
- [ ] BlockRun retries identical upstream bytes once and persists a redacted receipt.
- [ ] Agent/background paths cannot create a lease, approve, sign, retry, or spend.
- [ ] BYOK, offline NDK, skills, and native node routes pass existing regression tests.
- [ ] No provider secret, payment header, signature, prompt, tool payload, or loopback capability appears in logs/tests/docs.
- [ ] APKs, generated reports, secrets, and temporary files remain untracked/uncommitted.
