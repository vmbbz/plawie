# Wallet Payment Release Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove superseded payment code, add explicit independently reversible release gates, align all product surfaces and documentation with live capability truth, and produce controlled device/mainnet evidence before pushing a release candidate.

**Architecture:** One immutable compile-time feature configuration gates external bridge execution, Venice inference, BlockRun inference, and live mainnet signing independently. Read-only wallet/quote/status functionality remains available when execution gates are off. Capability/readiness models become the single source for Setup, Base, Settings, Chat, and agent read-only status. Release verification inspects source, bundle contents, runtime owner, persistence, receipts, and controlled user-approved transactions.

**Tech Stack:** Flutter/Dart release defines, Kotlin/Gradle Android builds, native OpenClaw Gateway, Flutter/JUnit tests, ADB/logcat, Git, static secret/artifact scans.

---

## Prerequisites

- Complete `2026-08-05-secure-wallet-reliability.md` before any mainnet signing proof.
- Complete `2026-08-05-external-wallet-bridge-execution.md` before enabling bridge execution.
- Complete `2026-08-05-wallet-funded-provider-gateway.md` before enabling Venice or BlockRun in production UI.
- Do not use clear-data or uninstall during persistence acceptance.
- Do not spend funds in automation. Every live amount is selected and approved by the user at the visible review surfaces.

## File map

**Create**

- `lib/config/production_feature_flags.dart`
- `lib/services/production_capability_service.dart`
- `test/production_feature_flags_test.dart`
- `test/production_capability_service_test.dart`
- `test/payment_surface_truth_test.dart`
- `docs/RELEASE_WALLET_PAYMENT_CHECKLIST.md`
- `docs/RELEASE_CONFIGURATION.md`

**Modify**

- `lib/services/x402_payment_service.dart`
- `lib/services/bridge_execution_coordinator.dart`
- `lib/services/paid_provider_proxy_service.dart`
- `lib/services/ai_payment_provider_catalog.dart`
- `lib/services/model_provider_catalog.dart`
- `lib/services/gateway_service.dart`
- `lib/services/capabilities/ai_payments_capability.dart`
- `lib/services/app_native_chat_tool_router.dart`
- `lib/screens/setup_flow_screen.dart`
- `lib/screens/base_screen.dart`
- `lib/screens/chat_screen.dart`
- `lib/screens/settings_screen.dart`
- `docs/DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md`
- `docs/MODEL_PROVIDER_AND_HELP_ROADMAP.md`
- user-facing help/release notes discovered with `rg -n "x402|bridge|Venice|BlockRun|OpenRouter" docs lib`

**Remove after zero-reference proof**

- `lib/services/crypto_credits_service.dart`

## Task 1: Add independently reversible production gates

- [ ] **Step 1: Write feature-matrix tests first**

Test that each execution capability is independently disabled, that live signing off overrides provider/bridge enablement, and that read-only wallet/quote/status remains available. Since compile-time constants cannot be changed in one process, make `ProductionFeatureFlags` an immutable value with a `fromEnvironment` production constructor and direct constructor for tests.

- [ ] **Step 2: Implement one typed configuration source**

```dart
final class ProductionFeatureFlags {
  const ProductionFeatureFlags({
    required this.externalWalletBridge,
    required this.veniceWalletInference,
    required this.blockrunX402Inference,
    required this.liveMainnetSigning,
  });

  const ProductionFeatureFlags.fromEnvironment()
      : externalWalletBridge = const bool.fromEnvironment(
          'PLAWIE_EXTERNAL_WALLET_BRIDGE', defaultValue: false),
        veniceWalletInference = const bool.fromEnvironment(
          'PLAWIE_VENICE_WALLET_INFERENCE', defaultValue: false),
        blockrunX402Inference = const bool.fromEnvironment(
          'PLAWIE_BLOCKRUN_X402_INFERENCE', defaultValue: false),
        liveMainnetSigning = const bool.fromEnvironment(
          'PLAWIE_LIVE_MAINNET_SIGNING', defaultValue: false);

  final bool externalWalletBridge;
  final bool veniceWalletInference;
  final bool blockrunX402Inference;
  final bool liveMainnetSigning;
}
```

No component reads these environment names directly after this change.

- [ ] **Step 3: Gate at the operation boundary, not only UI**

- `BridgeExecutionCoordinator.submit` requires both bridge and live-mainnet flags.
- Venice proxy inference requires Venice flag; Venice top-up additionally requires live-mainnet signing only at its on-chain approval boundary.
- BlockRun 402 approval/sign/retry requires BlockRun and live-mainnet flags.
- Model discovery may run while inference is disabled, but readiness reports `releaseDisabled`.
- Native Android bounded policy remains authoritative even when Dart gates are true.

- [ ] **Step 4: Replace the hard-coded x402 boolean**

Remove `X402PaymentPolicy.liveSigningEnabled = true`; inject the feature value into transport/approval services. Unit tests no longer assert a global hard-coded true.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/production_feature_flags_test.dart test/production_capability_service_test.dart test/ai_payment_provider_catalog_test.dart test/x402_payment_service_test.dart test/x402_payment_transport_service_test.dart
dart analyze lib/config/production_feature_flags.dart lib/services/production_capability_service.dart lib/services/x402_payment_service.dart
git add lib/config/production_feature_flags.dart lib/services/production_capability_service.dart lib/services/x402_payment_service.dart lib/services/bridge_execution_coordinator.dart lib/services/paid_provider_proxy_service.dart test/production_feature_flags_test.dart test/production_capability_service_test.dart test/ai_payment_provider_catalog_test.dart test/x402_payment_service_test.dart test/x402_payment_transport_service_test.dart
git commit -m "feat: gate wallet payment release capabilities"
```

## Task 2: Remove the unused legacy OpenRouter crypto-credit path

- [ ] **Step 1: Prove there are no production references**

```powershell
rg -n "CryptoCreditsService|crypto_credits_service" lib test android
rg -n "Coinbase.*OpenRouter|OpenRouter.*Coinbase|crypto credit" lib test docs
```

Expected before removal: only the class definition, documentation history, or explicit legacy test references. If a live import/constructor/UI action appears, migrate it to the Base/bridge/x402 services and rerun the search before deleting anything.

- [ ] **Step 2: Add/extend replacement contract tests**

Assert OpenRouter remains BYOK/read-only credit status; Venice owns prepaid top-up; BlockRun owns per-request payment; LI.FI owns external source-to-Base bridge; no provider action references Coinbase/OpenRouter crypto top-up.

- [ ] **Step 3: Remove the dead file with a patch**

Delete `lib/services/crypto_credits_service.dart` through `apply_patch`. Remove only confirmed dead imports/docs and preserve historical architecture notes by marking them superseded rather than rewriting commit history.

- [ ] **Step 4: Verify zero references and commit**

```powershell
rg -n "CryptoCreditsService|crypto_credits_service" lib test android
flutter test test/ai_payment_provider_catalog_test.dart test/provider_balance_service_test.dart test/bridge_quote_service_test.dart test/x402_payment_transport_service_test.dart
flutter analyze
git add -u lib/services/crypto_credits_service.dart
git add docs test lib
git commit -m "refactor: remove legacy crypto credit service"
```

Expected: reference search returns no production hits; tests pass.

## Task 3: Make every surface derive from one capability truth

- [ ] **Step 1: Add a cross-surface truth table test**

For each combination of wallet state, network, feature gates, proxy health, catalog freshness, provider balance, Reown configuration, and foreground state, assert the same stable readiness/reason/action appears in Setup, Base, Chat model picker, Settings, and read-only agent capability output.

- [ ] **Step 2: Implement `ProductionCapabilitySnapshot`**

Include:

```text
walletState
baseNetwork
externalWalletBridge: available | configMissing | releaseDisabled | unavailable
venice: catalog/balance/proxy/topUp/inference state
blockrun: catalog/proxy/perRequestPayment state
lastRefreshed and stale flags
safe user actions
```

The service composes existing observations; it does not invent balances or treat a receipt intent as settlement.

- [ ] **Step 3: Replace duplicated readiness logic**

Setup records selection and explains next action. Base remains canonical for wallet, bridge, balance, top-up, receipts, and recovery. Chat may open the canonical panel/dialog. Settings links to Base/provider management. Agent capabilities expose read-only snapshot/receipts and return `foreground_approval_required` for execution requests.

- [ ] **Step 4: Correct notification ownership**

Only the native Gateway foreground service owns the persistent Gateway running/stopped notification. Downloads use one progress notification per active artifact and remove it on terminal state. Bridge/payment approvals are in-app foreground dialogs; settlement completion may use one terminal notification keyed by receipt ID. Deduplicate by stable operation ID and never emit a second “Gateway running” notification from Flutter.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/production_capability_service_test.dart test/payment_surface_truth_test.dart test/wallet_funded_provider_setup_test.dart test/wallet_funded_model_picker_test.dart test/bridge_app_native_adapter_test.dart
dart analyze lib/services/production_capability_service.dart lib/screens/setup_flow_screen.dart lib/screens/base_screen.dart lib/screens/chat_screen.dart
git add lib/services/production_capability_service.dart lib/services/capabilities lib/screens lib/widgets test/production_capability_service_test.dart test/payment_surface_truth_test.dart test/wallet_funded_provider_setup_test.dart test/wallet_funded_model_picker_test.dart
git commit -m "refactor: unify wallet payment capability truth"
```

## Task 4: Update architecture, security, setup, and recovery documentation

- [ ] **Step 1: Mark implementation-plan phases accurately**

Update `DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md` phase statuses from test/build evidence only. Replace quote-only bridge boundary once execution passes. Record loopback proxy, Reown handoff, wallet state machine, dynamic Venice/BlockRun discovery, approval broker, and feature gates.

- [ ] **Step 2: Update provider/help roadmap**

List Venice/BlockRun as live only when their transport gates and tests pass. Explain provider/model lists are endpoint-driven; offline fallback entries are informational and not readiness.

- [ ] **Step 3: Write release configuration instructions**

`RELEASE_CONFIGURATION.md` gives exact build inputs without real values:

```powershell
flutter build apk --release `
  --dart-define=REOWN_PROJECT_ID=$env:REOWN_PROJECT_ID `
  --dart-define=PLAWIE_EXTERNAL_WALLET_BRIDGE=true `
  --dart-define=PLAWIE_VENICE_WALLET_INFERENCE=true `
  --dart-define=PLAWIE_BLOCKRUN_X402_INFERENCE=true `
  --dart-define=PLAWIE_LIVE_MAINNET_SIGNING=true
```

State that Reown app/package allowlisting and stable Android release signing are required. LI.FI needs no embedded key. Never include an actual project ID, wallet key, API key, seed, signature, or signed payload.

- [ ] **Step 4: Document user security and recovery**

Cover update persistence, destructive clear-data/uninstall, private-key export responsibility, external-wallet approvals, exact allowance, Base ETH gas/native USDC, Venice prepaid balance, BlockRun per-call approval, receipt uncertainty/recovery, and why agent/chat text cannot approve.

- [ ] **Step 5: Verify docs and commit**

```powershell
rg -n "TB[D]|TO[DO]|Sepolia only|generic Jumper" docs/BASE_WALLET_SECURITY_AND_RECOVERY.md docs/EXTERNAL_WALLET_BRIDGING.md docs/WALLET_FUNDED_MODEL_PROVIDERS.md docs/RELEASE_CONFIGURATION.md docs/RELEASE_WALLET_PAYMENT_CHECKLIST.md
git diff --check
git add docs/DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md docs/MODEL_PROVIDER_AND_HELP_ROADMAP.md docs/RELEASE_CONFIGURATION.md docs/RELEASE_WALLET_PAYMENT_CHECKLIST.md docs/BASE_WALLET_SECURITY_AND_RECOVERY.md docs/EXTERNAL_WALLET_BRIDGING.md docs/WALLET_FUNDED_MODEL_PROVIDERS.md
git commit -m "docs: finalize wallet payment release architecture"
```

Expected: no unresolved release marker appears in the new production docs; diff check is silent.

## Task 5: Run automated release proof and inspect artifacts

- [ ] **Step 1: Preserve unrelated worktree state**

```powershell
git status --short
```

Do not stage generated `android/build/reports/problems/problems-report.html`, stray `2`/`nul`, APKs, bundles, logs, callback captures, or user-owned unrelated changes.

- [ ] **Step 2: Run repository-wide tests**

```powershell
flutter pub get
flutter test
cd android
./gradlew.bat :app:testDebugUnitTest :app:lintDebug
cd ..
flutter analyze
git diff --check
```

Expected: tests/lint pass, analyzer has no new errors relative to the recorded baseline, and diff check is silent. Record any pre-existing analyzer findings separately; do not call them newly fixed.

- [ ] **Step 3: Run architecture regression tests explicitly**

```powershell
flutter test test/gateway_service_tool_continuation_test.dart test/gateway_required_mobile_route_test.dart test/gateway_connection_session_patch_test.dart test/paid_provider_proxy_contract_test.dart test/paid_provider_proxy_stream_test.dart test/bridge_execution_coordinator_test.dart test/base_wallet_state_test.dart
```

Expected: native Gateway/tool continuation and all new boundaries pass together.

- [ ] **Step 4: Scan source and Git for secret/artifact mistakes**

```powershell
rg -n --hidden -g '!build/**' -g '!android/.gradle/**' -g '!android/build/**' "(sk-[A-Za-z0-9_-]{16,}|0x[a-fA-F0-9]{64}|REOWN_PROJECT_ID\s*[:=]\s*['\"][^$])" .
git ls-files | rg "(^|/)(build|\.dart_tool|\.gradle)/|\.(apk|aab|log)$|(^|/)(2|nul)$"
```

Expected: no embedded secret/private-key pattern and no generated artifact tracked. Review every match manually because documentation examples may be intentionally redacted.

- [ ] **Step 5: Build release artifacts with controlled environment**

Require a non-empty environment-provided Reown project ID and use the four explicit true release defines. Build both APK and app bundle. Do not print the project ID.

```powershell
if ([string]::IsNullOrWhiteSpace($env:REOWN_PROJECT_ID)) { throw 'REOWN_PROJECT_ID is required' }
flutter build apk --release --dart-define=REOWN_PROJECT_ID=$env:REOWN_PROJECT_ID --dart-define=PLAWIE_EXTERNAL_WALLET_BRIDGE=true --dart-define=PLAWIE_VENICE_WALLET_INFERENCE=true --dart-define=PLAWIE_BLOCKRUN_X402_INFERENCE=true --dart-define=PLAWIE_LIVE_MAINNET_SIGNING=true
flutter build appbundle --release --dart-define=REOWN_PROJECT_ID=$env:REOWN_PROJECT_ID --dart-define=PLAWIE_EXTERNAL_WALLET_BRIDGE=true --dart-define=PLAWIE_VENICE_WALLET_INFERENCE=true --dart-define=PLAWIE_BLOCKRUN_X402_INFERENCE=true --dart-define=PLAWIE_LIVE_MAINNET_SIGNING=true
```

Expected: release APK/AAB are produced under `build/app/outputs`; neither is staged.

- [ ] **Step 6: Inspect signed bundle contents**

```powershell
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
jar tf build/app/outputs/bundle/release/app-release.aab | Select-String 'libnode|proot|rootfs|openclaw|assets|lib/'
```

Expected: signature verification succeeds; native `libnode.so`/required native libraries and app assets are present; no bundled OpenClaw Gateway npm release, downloaded dependency pack, PRoot rootfs, API key, wallet material, receipt, or logs are added by this work. PRoot fallback assets already intentionally present in the project are documented separately rather than mistaken for the primary runtime.

- [ ] **Step 7: Commit only source/docs/tests**

```powershell
git status --short
git add lib android/app/src/main test docs pubspec.yaml pubspec.lock
git status --short
git commit -m "chore: harden wallet payment release path"
```

Before committing, inspect the staged diff and unstage any build output/report/temp file.

## Task 6: Run controlled device and Base Mainnet acceptance

- [ ] **Step 1: Install as an update**

```powershell
adb devices -l
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Expected: install succeeds without clearing data; the wallet public address is unchanged.

- [ ] **Step 2: Confirm native-first runtime**

Open Gateway logs/status and verify runtime owner is native, native `libnode.so` starts the Gateway, and PRoot is not launched or downloaded unless the user explicitly requests fallback. Verify only one persistent Gateway notification exists.

- [ ] **Step 3: Verify bridge with a user-selected small amount**

Connect the chosen external wallet, inspect the exact source chain/token/amount/address/allowance/route, approve in Plawie and the external wallet, record source hash, observe LI.FI terminal status and destination hash, and refresh Base USDC. Stop if any displayed field differs from the connected session or fresh quote.

- [ ] **Step 4: Verify Venice through OpenClaw**

Refresh dynamic models, top up a user-selected small amount through exact x402 approval, confirm provider balance, select a Venice model, send one normal turn and one tool/skill turn, and verify the same OpenClaw conversation/session continues. Confirm no second on-chain approval appears for prepaid inference.

- [ ] **Step 5: Verify BlockRun through OpenClaw**

Select a BlockRun model, send one turn, verify the live 402 amount/payee/resource dialog, cancel once and confirm no retry/payment, then repeat and approve once. Verify one Android authentication, one paid retry, one redacted receipt, and a model response in the same Gateway session. If the Gateway retries or changes its request body, verify the same visible message never opens a second payment approval; a further paid call requires a new user message.

- [ ] **Step 6: Verify interruption/recovery**

Force-stop only after a submitted bridge or settled payment receipt has been safely recorded. Relaunch and verify polling/receipt recovery occurs without rebroadcast, duplicate signing, duplicate approval, or duplicate notification.

- [ ] **Step 7: Record redacted evidence**

Update `RELEASE_WALLET_PAYMENT_CHECKLIST.md` with build commit, app/device versions, runtime owner, wallet address match (shortened), source/destination transaction explorer links, LI.FI terminal status, provider request IDs, receipt IDs, balance observations, and pass/fail. Exclude signatures, payment headers, raw challenges, prompts, API keys, private keys, and complete wallet addresses when publication is unnecessary.

- [ ] **Step 8: Commit acceptance record and push**

```powershell
git add docs/RELEASE_WALLET_PAYMENT_CHECKLIST.md
git commit -m "docs: record wallet payment release acceptance"
git status --short --branch
git push origin HEAD
```

Expected: only known unrelated/generated uncommitted files remain; branch pushes successfully. APK/AAB files remain local and untracked.

## Final release gate

- [ ] Wallet creation root cause and update persistence are evidenced.
- [ ] External bridge callbacks, exact allowance, submission, polling, and resume are evidenced.
- [ ] Venice and BlockRun run through native OpenClaw with context/tool parity.
- [ ] Human approval is mandatory at every blockchain payment boundary.
- [ ] Agent/background/chat text cannot approve or sign.
- [ ] Provider balances and readiness are observations with freshness, not invented accounting.
- [ ] Feature gates disable execution independently without disabling wallet/read-only/BYOK/native Gateway.
- [ ] Legacy crypto-credit code has zero references and is removed.
- [ ] One Gateway notification and one operation notification per stable ID are enforced.
- [ ] Release APK/AAB contain no bundled fast-aging OpenClaw Gateway release or downloaded dependency packs introduced by this work.
- [ ] Full automated tests, artifact inspection, controlled mainnet proof, commits, and push are complete.
