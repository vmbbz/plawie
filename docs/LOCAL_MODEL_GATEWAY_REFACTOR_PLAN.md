# Local Model and Gateway Refactor Plan

Date: 2026-05-11

## Goal

Make OpenClaw on Android feel seamless for mainstream users while keeping the gateway stable:

- Gateway starts cleanly without pulling Ollama, NDK inference, model sync, or heavyweight local-model work into the startup path.
- Local NDK models remain available for fast on-device inference.
- Integrated Ollama remains available for gateway-compatible local models, Ollama Cloud, registry pulls, and fallback.
- A new NDK-to-HTTP provider bridge is explored behind a switch before any removal of local Ollama.
- Chat model switching becomes coordinated and predictable instead of spread across `ChatScreen`, `GatewayService`, `LocalLlmService`, and `LocalLlmScreen`.

The production dream is simple: Peter and Joe install the APK, complete setup, land in a working agent, and only pay local-model runtime cost when they explicitly choose local models.

## Current Architecture Snapshot

### Gateway Core

Current owner: `lib/services/gateway_service.dart`

Responsibilities currently mixed together:

- OpenClaw gateway process attach/start/stop.
- Token and dashboard URL discovery.
- WebSocket connection and `chat.send` streaming.
- OpenClaw config read/write and model persistence.
- Ollama provider config.
- Integrated Ollama install/start/stop/sync/pull/logs.
- Local Ollama direct fallback and diagnostics.

Problem:

`GatewayService` is now the central nervous system and also a toolbox drawer. It works, but changes are risky because local-model concerns can accidentally affect gateway startup and chat.

### NDK Local LLM

Current owner: `lib/services/local_llm_service.dart`

Strengths:

- Uses fllama/llama.cpp through NDK, no PRoot runtime needed for inference.
- Handles GGUF download and activation.
- Streams tokens.
- Supports limited tool-call loops.
- Supports device-native tools through `AgentSkillServer`.
- Supports vision hooks through mmproj paths.
- Keeps inference local and lightweight compared to Ollama-in-PRoot.

Limit:

OpenClaw gateway cannot use it as a provider because it is not exposed through an OpenAI-compatible HTTP server.

### Integrated Ollama Hub

Current owners:

- Native process: `android/app/src/main/kotlin/com/nxg/openclawproot/ProcessManager.kt`
- Bootstrap/install: `android/app/src/main/kotlin/com/nxg/openclawproot/BootstrapManager.kt`
- Dart management: `lib/services/gateway_service.dart`
- UX: `lib/screens/management/local_llm_screen.dart`

Strengths:

- Gateway-compatible provider model.
- Supports local Ollama models.
- Supports Ollama Cloud.
- Supports registry pulls.
- Good fallback while the NDK bridge is unproven.

Problems:

- More memory/process weight.
- More moving parts inside PRoot.
- UX and backend code are mixed into the same Local LLM page.
- Historically tempted to run/probe/sync during gateway lifecycle.

### Chat Model Switching

Current owner: `lib/screens/chat_screen.dart`

Responsibilities currently mixed together:

- Model dropdown state.
- Local NDK model activation.
- Ollama Hub auto-start.
- Ollama Hub auto-stop when switching to cloud.
- Persisting selected model.
- Gateway WebSocket disconnects when model changes.

Problem:

Chat UI owns runtime orchestration. This makes it easy to break chat while refactoring local engines.

## Target Architecture

### 1. GatewayService Becomes Gateway-Only

Keep:

- Gateway start/stop/attach.
- Health checks.
- Token discovery.
- Dashboard URL.
- WebSocket lifecycle.
- `chat.send` gateway routing.
- Config read/write helpers if still needed by gateway.

Move out:

- Ollama install/start/stop/sync/pull/logs.
- Ollama model registration.
- Local model catalog details.
- Local model runtime decisions.

Transitional rule:

Do not break public methods immediately. Keep thin delegator methods in `GatewayService` while moving implementations into focused services. Remove delegators only after UI and callers are migrated.

### 2. OllamaHubService Owns Ollama

New file:

- `lib/services/ollama_hub_service.dart`

Owns:

- `isInstalled`
- `install`
- `isRunning`
- `start`
- `stop`
- `checkHealth`
- `syncDownloadedGgufs`
- `configureProvider`
- `pullModel`
- `registerPulledModel`
- `getLogs`
- `checkCredentials`
- `fetchRegistryModels`

Important behavior:

- Never starts during app boot.
- Never starts during gateway boot unless selected model requires it.
- Starts only from:
  - Local LLM Hub UX.
  - Chat model switch to local `ollama/*`.
  - Cloud Ollama activation if required.

### 3. LocalModelCatalog Becomes Shared

New file:

- `lib/models/local_model_catalog.dart`

Move:

- `LocalLlmModel`
- `_modelCatalog`
- Ollama-name conversion helpers if shared.
- Capability flags:
  - supports tool calls
  - supports vision
  - minimum RAM
  - recommended thread count
  - preferred local engine

Reason:

The catalog is currently inside `LocalLlmService`, but both NDK and Ollama need to reason about the same GGUF files.

### 4. ModelRuntimeCoordinator Owns Model Switching

New file:

- `lib/services/model_runtime_coordinator.dart`

Owns:

- Activate selected model.
- Persist selected model.
- Start required runtime.
- Stop unused runtime when safe.
- Disconnect/reconnect gateway if needed.
- Expose model availability state for UI.

Public shape:

```dart
Future<ModelActivationResult> activate(String modelId);
Future<void> stopUnusedFor(String modelId);
bool needsGateway(String modelId);
bool needsOllama(String modelId);
bool needsNdk(String modelId);
```

Rules:

- `local-llm/*` starts NDK and does not require gateway for direct chat.
- `ollama/*:cloud` requires Ollama Hub and gateway-compatible provider routing.
- local `ollama/*` requires Ollama Hub.
- normal cloud models require gateway only.
- switching to pure cloud may stop local Ollama after a short grace window.
- switching to `local-llm/*` should not auto-stop gateway.

### 5. LocalProviderBridgeServer Experiments With NDK Gateway Provider

New file:

- `lib/services/local_provider_bridge_server.dart`

Purpose:

Expose the NDK/fllama engine through an OpenAI-compatible HTTP API so the OpenClaw gateway can use it like a provider.

Initial endpoints:

- `GET /health`
- `GET /v1/models`
- `POST /v1/chat/completions`

Initial route:

- Bind to `127.0.0.1:11435`.
- Configure OpenClaw provider base URL to `http://127.0.0.1:11435/v1`.

Streaming contract:

- Must support SSE:
  - `Content-Type: text/event-stream`
  - chunks shaped like OpenAI chat completion deltas
  - final `[DONE]`

Non-streaming contract:

- Return OpenAI-style JSON response for `stream: false`.

Tool-call contract:

- Accept `tools` and `tool_choice`.
- Pass tool definitions into fllama.
- Stream or return assistant tool calls in OpenAI-compatible format.

Do not replace Ollama until this passes gateway integration tests.

## Implementation Sequence

### Phase 0: Protect Current Working APK

Status: current APK is being tested.

Do now:

- Do not refactor while install testing is underway unless the test exposes a blocker.
- Record APK behavior:
  - install page step 4
  - first gateway startup
  - onboarding completion
  - first cloud chat
  - Local LLM page open
  - Ollama Hub idle state

Gate to proceed:

- Current APK has no setup blocker.
- Or if setup fails, fix setup first before architecture refactor.

### Phase 1: No-Behavior-Change Extraction

Objective:

Make the code easier to reason about without changing runtime behavior.

Steps:

1. Add `LocalModelCatalog`.
2. Move catalog data out of `LocalLlmService`.
3. Add `OllamaHubService`.
4. Move Ollama methods from `GatewayService` into `OllamaHubService`.
5. Leave `GatewayService` delegator methods so callers keep working.
6. Run analyzer/build.
7. Commit and push.

Watchouts:

- Do not change method names used by `LocalLlmScreen`.
- Do not change `GatewayState` shape yet.
- Do not move `sendMessage` routing yet.
- Do not change chat model prefixes.

Validation:

- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter build apk --release`
- Manual:
  - Gateway starts.
  - Cloud chat works.
  - Local LLM page opens.
  - Ollama install/start/stop buttons still call through.

Rollback:

- Revert only extraction commit if behavior changes.

### Phase 2: Split Local LLM UX Into Sections

Objective:

Make the UX reflect the architecture.

Steps:

1. Create `lib/screens/management/local_llm/widgets/`.
2. Extract widgets:
   - `NdkLocalModelsSection`
   - `OllamaHubSection`
   - `OllamaCloudSection`
   - `LocalDiagnosticsSection`
   - `HubDiagnosticsSection`
3. Keep state in parent screen at first.
4. Only after extraction is stable, consider local controllers/view models.

Watchouts:

- Do not introduce nested cards or bloated UX.
- Keep the Local LLM page useful immediately, not explanatory only.
- Preserve existing button behavior.
- Preserve cloud model sign-in/activation flow.

Validation:

- Same as Phase 1.
- Manual visual pass on phone.

### Phase 3: Add ModelRuntimeCoordinator

Objective:

Stop making `ChatScreen` manage engine lifecycle directly.

Steps:

1. Add coordinator.
2. Move model activation rules out of the popup callback in `ChatScreen`.
3. Replace direct calls:
   - `GatewayService().startInternalOllama()`
   - `GatewayService().stopInternalOllama()`
   - `LocalLlmService().activateModel(...)`
   - `GatewayService().persistModel(...)`
4. Keep UI state updates in `ChatScreen`.
5. Coordinator returns result messages/status flags for UI.

Watchouts:

- Preserve `_cloudFallbackModel`.
- Preserve `PreferencesService().configuredModel`.
- Preserve WebSocket disconnect when gateway model changes.
- Do not auto-stop Ollama Cloud sessions too aggressively.

Validation:

- Switch cloud -> cloud.
- Switch cloud -> local NDK.
- Switch local NDK -> cloud.
- Switch cloud -> local Ollama.
- Switch local Ollama -> cloud.
- Switch Ollama Cloud -> normal cloud.

### Phase 4: Build NDK HTTP Bridge Behind a Flag

Objective:

Determine whether NDK can replace local Ollama for gateway-compatible local provider routing.

New service:

- `LocalProviderBridgeServer`

Feature flag:

- Preference key: `enable_ndk_gateway_bridge`
- Default: false.

Endpoints:

- `GET /health`
- `GET /v1/models`
- `POST /v1/chat/completions`

Implementation notes:

- Use Dart `HttpServer`, same pattern as `AgentSkillServer`.
- Do not start bridge on app startup by default.
- Start bridge when:
  - selected model is `local-llm/*`
  - experimental bridge flag is enabled
  - NDK model is ready
- Return a useful 503 JSON when no NDK model is active.
- Serialize inference requests. Mobile should run one local generation at a time.
- Use existing `LocalLlmService` where possible.

Streaming response shape:

```text
data: {"id":"chatcmpl-local","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"..."}}]}

data: [DONE]
```

Tool-call concerns:

- fllama callback exposes `openaiResponseJsonString`.
- We need to preserve tool call chunks, not only text deltas.
- Gateway may expect OpenAI-compatible tool call deltas.
- This is the hardest part and decides whether Ollama can be retired.

Validation:

- Direct curl/test from app process where possible.
- Gateway configured to custom provider.
- Gateway dashboard shows local provider run.
- Simple chat streams.
- Tool call request works.
- Tool result loop works.
- Timeout/cancel works.
- Model switch does not leave stale request running.

Failure mode:

- If bridge chat works but tool calls fail, keep bridge for direct local chat only and keep Ollama for full gateway agent loop.

### Phase 5: Provider Decision

Only after Phase 4 tests:

Option A: NDK bridge passes full gateway tests.

- Make NDK bridge default for local downloaded GGUFs.
- Keep Ollama for:
  - Ollama Cloud
  - Ollama registry/library pulls
  - compatibility fallback
- Local LLM page labels:
  - "On-device engine"
  - "Ollama compatibility hub"

Option B: NDK bridge fails tool-call parity.

- Keep current architecture:
  - NDK for direct local/private chat and vision.
  - Ollama for gateway-compatible local agent loop.
- Still keep cleanup/refactor benefits.

## Things Most Likely To Break

### Gateway config reload

Risk:

OpenClaw schema rejects unexpected fields and may skip reload.

Mitigation:

- Keep provider config minimal.
- Avoid `contextWindow` or unknown provider keys.
- Prefer writing known-good `models.providers.*` shape.

### Tool calls through NDK bridge

Risk:

Streaming tool calls are not equivalent to plain text streaming.

Mitigation:

- Start with non-streaming tool-call test.
- Then implement streaming deltas.
- Compare payload shape with gateway-accepted OpenAI/Ollama frames.

### Chat screen stale model state

Risk:

Switching models can leave UI selected on a runtime that is stopped.

Mitigation:

- Centralize activation in coordinator.
- Return explicit activation result.
- Only update `_selectedModel` after activation succeeds or enters a known starting state.

### Local Ollama auto-start

Risk:

Ollama starts during normal gateway startup again.

Mitigation:

- Keep model-gated startup rule:
  - only probe/start/sync for local model choices.
- Add search checks before commits:
  - `rg "startInternalOllama|syncLocalModelsWithOllama|checkOllamaHealth" lib`

### PRoot process lifetime

Risk:

Backgrounding Ollama incorrectly can let PRoot shell exit and kill the child.

Mitigation:

- Keep native command foregrounded under PRoot process.
- Do not append `&` to `ollama serve` while using `--kill-on-exit`.

### Memory pressure

Risk:

NDK and Ollama loaded at the same time can crush mid-range phones.

Mitigation:

- Coordinator prevents both local engines being active unless explicitly allowed.
- Stop local Ollama before activating NDK where safe.
- Stop/cancel NDK inference before activating local Ollama.

## Commit Strategy

Each phase gets its own commit and push:

1. `refactor: extract local model catalog`
2. `refactor: isolate ollama hub service`
3. `refactor: split local llm management UI`
4. `refactor: centralize model runtime activation`
5. `feat: add experimental ndk provider bridge`
6. `feat: route local gateway models through ndk bridge` only if tests pass

No mega-commit. No mixed UI/backend/runtime commits unless unavoidable.

## Test Checklist Per Milestone

Automated:

```powershell
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build apk --release
```

Manual:

- Fresh install completes setup.
- Gateway starts after setup.
- Dashboard opens with token.
- Normal cloud chat works.
- Local LLM page opens without starting Ollama.
- NDK model download/activate works.
- NDK direct chat works.
- Ollama Hub install/start/stop works.
- Ollama sync sees downloaded GGUF models.
- Ollama local chat works through gateway.
- Ollama Cloud model selection works.
- Switching away from local models frees runtime where expected.

## Start Recommendation

Start the refactor after the current APK installation test confirms setup is stable.

If the current APK fails setup:

1. Stop architecture work.
2. Fix setup chain first.
3. Commit and push setup fix.
4. Resume Phase 1.

If the current APK passes setup:

Start with Phase 1 immediately. It has the best risk/reward ratio because it makes every later change easier without intentionally changing behavior.
