# Hybrid Base Funding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Plawie's quote-only bridge handoff with resumable Base Mainnet funding through reviewed LI.FI connected-wallet execution or a strict Relay self-custody deposit address, while retaining an honest unmonitored Jumper fallback.

**Architecture:** A provider-neutral bridge domain owns capabilities, validation, redacted receipts, and a one-active-intent state machine. LI.FI and Relay remain independent strategies behind that domain; only the foreground Base UI may connect, review, reveal, sign, submit, or broadcast, while agents receive read-only estimates and redacted status. Existing Base Keystore signing, x402 payments, native Gateway ownership, setup, and skills are not refactored by this work.

**Tech Stack:** Flutter/Dart, `http`, `shared_preferences`, `web3dart`, Reown AppKit Flutter, Android Kotlin platform channels, Phantom Solana deep-link support through Reown, LI.FI REST, Relay REST, Flutter unit/widget tests, and Android device acceptance.

**Approved design:** `docs/superpowers/specs/2026-08-07-hybrid-base-funding-design.md`

---

## Delivery boundaries

- Work in `.worktrees/wallet-reliability` on `codex/hybrid-bridge-funding-design`.
- Preserve `BridgeQuoteService` as the public estimate-only API until the new panel passes device acceptance.
- Keep connected LI.FI execution and Relay deposit funding behind separate release gates.
- Never send bridge calldata to `BaseService`, `NativeBridge.signSecureEvmTransaction`, the OpenClaw Gateway, or an agent command.
- Never commit an APK, Reown project ID, API key, wallet callback, signed transaction, generated report, or device log.
- Automated tests never spend funds. Mainnet submission requires the user's visible approval at the exact device acceptance step.
- Do not kill existing Flutter, Dart, Gradle, ADB, app, or Gateway processes without identifying their owner and purpose. The pre-plan baseline command stalled behind pre-existing Flutter processes, so execution starts with an explicit tooling check.
- Before any `adb install`, `am start`, force-stop, callback launch, or data
  operation, announce it and verify the user is not in an active setup/chat/device
  test. This plan never clears app data and never uninstalls the app.

## File map

### Create

- `lib/services/bridge/bridge_models.dart` — public chains, tokens, requests, quotes, transaction payloads, receipts, and agent-safe JSON.
- `lib/services/bridge/bridge_funding_strategy.dart` — internal provider strategy contract and validated intent types.
- `lib/services/bridge/bridge_state_machine.dart` — legal state transitions and one-active-intent policy.
- `lib/services/bridge/bridge_receipt_store.dart` — versioned local persistence, migration, quarantine, and receipt limits.
- `lib/services/bridge/bridge_http_client.dart` — bounded, no-redirect HTTP and JSON-RPC transport for allowlisted hosts.
- `lib/services/bridge/bridge_capability_service.dart` — live LI.FI and Relay chain/token capability intersection.
- `lib/services/bridge/lifi_bridge_service.dart` — LI.FI estimate/executable quote parsing.
- `lib/services/bridge/lifi_transaction_validator.dart` — pure EVM/Solana executable request validation.
- `lib/services/bridge/external_wallet_session_service.dart` — provider-neutral external-wallet interface and session identity.
- `lib/services/bridge/reown_external_wallet_adapter.dart` — Reown EVM and Phantom-compatible session adapter.
- `lib/services/bridge/evm_bridge_rpc_service.dart` — allowance reads, exact approval encoding, and receipt polling.
- `lib/services/bridge/solana_transaction_envelope.dart` — bounded base58 codec and signed-message verification.
- `lib/services/bridge/solana_rpc_broadcaster.dart` — one-call Solana Mainnet broadcast and signature check.
- `lib/services/bridge/lifi_status_service.dart` — LI.FI transfer status mapping.
- `lib/services/bridge/relay_deposit_service.dart` — strict deposit quote, validation, requests lookup, and intent status.
- `lib/services/bridge/external_jumper_fallback.dart` — best-effort prefill URL with explicit unmonitored semantics.
- `lib/services/bridge/bridge_funding_controller.dart` — foreground orchestration, idempotency, polling, and Base balance reconciliation.
- `lib/widgets/bridge_funding_panel.dart` — canonical Base funding panel.
- `lib/widgets/bridge_review_sheet.dart` — exact connected-wallet review UI.
- `lib/widgets/relay_deposit_sheet.dart` — copy/QR deposit instruction and warning UI.
- `android/app/src/main/kotlin/com/openclaw/plawie/WalletLinkBridge.kt` — initial/new Android wallet callback delivery to Dart.
- `test/bridge_models_test.dart`
- `test/bridge_state_machine_test.dart`
- `test/bridge_receipt_store_test.dart`
- `test/bridge_http_client_test.dart`
- `test/bridge_capability_service_test.dart`
- `test/lifi_transaction_validator_test.dart`
- `test/wallet_link_native_contract_test.dart`
- `test/external_wallet_session_service_test.dart`
- `test/evm_bridge_rpc_service_test.dart`
- `test/solana_transaction_envelope_test.dart`
- `test/solana_rpc_broadcaster_test.dart`
- `test/lifi_status_service_test.dart`
- `test/relay_deposit_service_test.dart`
- `test/bridge_funding_controller_test.dart`
- `test/bridge_funding_panel_test.dart`
- `docs/EXTERNAL_WALLET_BRIDGING.md`

### Modify

- `pubspec.yaml` and `pubspec.lock` — resolved Reown AppKit and QR dependencies.
- `android/app/src/main/AndroidManifest.xml:39` — wallet package queries, callback intent filter, and Flutter deep-link ownership.
- `android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt:146` and `:1170` — attach and forward wallet callbacks.
- `lib/services/preferences_service.dart:39` — bridge catalog, active receipt, and receipt-list keys.
- `lib/services/bridge_quote_service.dart:1` — delegate estimate parsing without exposing executable payloads.
- `lib/screens/base_screen.dart:422` — replace the inline quote dialogs with `BridgeFundingPanel`.
- `lib/services/capabilities/ai_payments_capability.dart:33` — add read-only bridge status and receipts.
- `lib/services/app_native_chat_tool_router.dart:257`, `:732`, `:1001`, and `:2073` — route read-only bridge status/receipt intents.
- `lib/services/gateway_tool_catalog.dart:17` — allow only new read commands.
- `lib/providers/node_provider.dart:333` — advertise the read-only command snapshot.
- `lib/services/gateway_service.dart:5765` — describe the updated read-only bridge contract to the agent.
- `test/bridge_quote_service_test.dart`
- `test/bridge_app_native_adapter_test.dart`
- `test/ai_payments_capability_test.dart`
- `test/node_pairing_command_snapshot_test.dart`
- `docs/WALLET_FUNDED_MODEL_PROVIDERS.md` — document external funding before provider payment.
- `docs/DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md` — record feature gates and settlement boundaries.
- `docs/superpowers/plans/2026-08-05-external-wallet-bridge-execution.md` — already marked superseded by this planning round.

## Task 1: Establish a clean baseline and resolve SDK dependencies

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Test: existing bridge/payment test files

- [ ] **Step 1: Verify branch and working-tree scope**

Run:

```powershell
git branch --show-current
git status --short
git log -3 --oneline
```

Expected: branch is `codex/hybrid-bridge-funding-design`; the plan commits are present; no source changes or generated files are present.

- [ ] **Step 2: Inspect Flutter tooling without terminating processes**

Run:

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'flutter|dart|java|gradle' } |
  Select-Object ProcessName,Id,CPU,StartTime,Path
flutter doctor -v
```

Expected: `flutter doctor -v` completes. If it stalls, identify the owning terminal/process before asking to stop it; do not repeatedly restart the app or Gateway.

- [ ] **Step 3: Run the pre-change focused baseline**

Run:

```powershell
flutter test test/bridge_quote_service_test.dart test/bridge_app_native_adapter_test.dart test/ai_payments_capability_test.dart test/node_pairing_command_snapshot_test.dart
```

Expected: all existing bridge/agent tests pass. Any pre-existing failure is recorded before source edits and fixed only if it blocks this feature.

- [ ] **Step 4: Resolve current compatible packages**

Run:

```powershell
flutter pub add reown_appkit
flutter pub add qr_flutter
flutter pub deps | Select-String 'reown_appkit|qr_flutter'
```

Expected: Pub resolves current versions compatible with this repository's Flutter/Dart SDK and writes exact versions to `pubspec.lock`. Do not copy the stale versions from the superseded 2026-08-05 plan.

- [ ] **Step 5: Record the resolved Reown release obligations**

Run:

```powershell
$cache = flutter pub cache list | ConvertFrom-Json
$reown = $cache.packages.reown_appkit.location
Get-ChildItem -LiteralPath $reown -Filter 'LICENSE*'
Get-Content -Raw -LiteralPath (Get-ChildItem -LiteralPath $reown -Filter 'LICENSE*' | Select-Object -First 1).FullName
```

Expected: the resolved SDK license is reviewed against Plawie's release model,
Reown project limits, and attribution requirements. Record the production
decision in `docs/EXTERNAL_WALLET_BRIDGING.md`; do not enable connected mode in a
release whose use is outside the accepted terms.

- [ ] **Step 6: Prove dependency resolution did not break the app**

Run:

```powershell
flutter test test/bridge_quote_service_test.dart test/ai_payments_capability_test.dart
flutter analyze lib/services/bridge_quote_service.dart lib/screens/base_screen.dart
```

Expected: focused tests pass and analysis introduces no dependency errors.

- [ ] **Step 7: Commit dependency resolution**

```powershell
git add pubspec.yaml pubspec.lock
git commit -m "build: add external wallet bridge dependencies"
```

## Task 2: Add typed bridge models, legal transitions, and durable receipts

**Files:**
- Create: `lib/services/bridge/bridge_models.dart`
- Create: `lib/services/bridge/bridge_funding_strategy.dart`
- Create: `lib/services/bridge/bridge_state_machine.dart`
- Create: `lib/services/bridge/bridge_receipt_store.dart`
- Modify: `lib/services/preferences_service.dart`
- Test: `test/bridge_models_test.dart`
- Test: `test/bridge_state_machine_test.dart`
- Test: `test/bridge_receipt_store_test.dart`

- [ ] **Step 1: Write failing model and redaction tests**

Create tests that construct a connected receipt and a Relay receipt and assert:

```dart
expect(receipt.toJson()['sourceAddress'], fullSourceAddress);
expect(receipt.toAgentJson()['sourceAddress'], '0x1111…1111');
expect(jsonEncode(receipt.toAgentJson()), isNot(contains(fullSourceAddress)));
expect(jsonEncode(receipt.toJson()), isNot(contains('transactionRequest')));
expect(jsonEncode(receipt.toJson()), isNot(contains('signedTransaction')));
expect(BridgeFundingReceipt.fromJson(receipt.toJson()), receipt);
```

Run:

```powershell
flutter test test/bridge_models_test.dart
```

Expected: compilation fails because the typed bridge models do not exist.

- [ ] **Step 2: Define the public domain types**

Implement these exact top-level contracts in `bridge_models.dart`:

```dart
enum BridgeChainType { evm, svm }
enum BridgeFundingMethod { connectedWallet, relayDeposit, externalJumper }
enum BridgeFundingState {
  draft,
  checkingCapabilities,
  connectingWallet,
  collectingRefundAddress,
  quoting,
  awaitingPlawieReview,
  awaitingDeposit,
  awaitingExternalWallet,
  depositDetected,
  submitted,
  sourcePending,
  destinationPending,
  completed,
  failed,
  refunded,
  partial,
  expired,
  cancelled,
}

abstract final class BridgeConstants {
  static const int ethereumChainId = 1;
  static const int baseChainId = 8453;
  static const int robinhoodChainId = 4663;
  static const int solanaChainId = 1151111081099710;
  static const String baseUsdc =
      '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';
}

abstract final class BridgeFeatureConfig {
  static const bool lifiConnectedEnabled = bool.fromEnvironment(
    'ENABLE_LIFI_CONNECTED_BRIDGE',
    defaultValue: false,
  );
  static const bool relayDepositEnabled = bool.fromEnvironment(
    'ENABLE_RELAY_DEPOSIT_BRIDGE',
    defaultValue: false,
  );
}

class BridgeValidationException implements Exception {
  const BridgeValidationException(this.code, [this.message = '']);
  final String code;
  final String message;
}

class BridgePersistenceException implements Exception {
  const BridgePersistenceException(this.message);
  final String message;
}

sealed class BridgeExecutionPayload {
  const BridgeExecutionPayload();
}

final class EvmBridgeExecutionPayload extends BridgeExecutionPayload {
  const EvmBridgeExecutionPayload({
    required this.chainId,
    required this.from,
    required this.to,
    required this.valueHex,
    required this.dataHex,
    required this.gasLimitHex,
    required this.approvalAddress,
  });
  final int chainId;
  final String from;
  final String to;
  final String valueHex;
  final String dataHex;
  final String gasLimitHex;
  final String? approvalAddress;
}

final class SolanaBridgeExecutionPayload extends BridgeExecutionPayload {
  const SolanaBridgeExecutionPayload({
    required this.from,
    required this.base64Transaction,
  });
  final String from;
  final String base64Transaction;
}
```

Define the remaining immutable contracts with these fields and value equality:

```dart
final class BridgeChain {
  const BridgeChain({
    required this.id,
    required this.key,
    required this.name,
    required this.type,
    required this.nativeTokenSymbol,
  });
  final int id;
  final String key;
  final String name;
  final BridgeChainType type;
  final String nativeTokenSymbol;
}

final class BridgeToken {
  const BridgeToken({
    required this.chainId,
    required this.address,
    required this.symbol,
    required this.decimals,
    required this.solverDepositable,
  });
  final int chainId;
  final String address;
  final String symbol;
  final int decimals;
  final bool solverDepositable;
}

final class BridgeFundingRequest {
  const BridgeFundingRequest({
    required this.method,
    required this.sourceChain,
    required this.sourceToken,
    required this.amount,
    required this.amountUnits,
    required this.baseDestinationAddress,
    this.sourceAddress,
    this.refundAddress,
    this.selfCustodyConfirmed = false,
  });
  final BridgeFundingMethod method;
  final BridgeChain sourceChain;
  final BridgeToken sourceToken;
  final String amount;
  final String amountUnits;
  final String baseDestinationAddress;
  final String? sourceAddress;
  final String? refundAddress;
  final bool selfCustodyConfirmed;
}

final class BridgeEstimate {
  const BridgeEstimate({
    required this.provider,
    required this.quoteId,
    required this.request,
    required this.minimumOutputUnits,
    required this.minimumOutputDisplay,
    required this.routeTool,
    required this.quotedAt,
    required this.expiresAt,
    this.estimatedDurationSeconds,
    this.estimatedFeesUsd,
  });
  final String provider;
  final String quoteId;
  final BridgeFundingRequest request;
  final String minimumOutputUnits;
  final String minimumOutputDisplay;
  final String routeTool;
  final DateTime quotedAt;
  final DateTime expiresAt;
  final int? estimatedDurationSeconds;
  final double? estimatedFeesUsd;
}

final class BridgeExecutableQuote {
  const BridgeExecutableQuote({
    required this.estimate,
    required this.connectedSourceAddress,
    required this.destinationChainId,
    required this.destinationToken,
    required this.payload,
    required this.fingerprint,
  });
  final BridgeEstimate estimate;
  final String connectedSourceAddress;
  final int destinationChainId;
  final BridgeToken destinationToken;
  final BridgeExecutionPayload payload;
  final String fingerprint;
}

final class RelayDepositInstruction {
  const RelayDepositInstruction({
    required this.requestId,
    required this.depositAddress,
    required this.request,
    required this.minimumOutputUnits,
    required this.minimumOutputDisplay,
    required this.createdAt,
    required this.expiresAt,
  });
  final String requestId;
  final String depositAddress;
  final BridgeFundingRequest request;
  final String minimumOutputUnits;
  final String minimumOutputDisplay;
  final DateTime createdAt;
  final DateTime expiresAt;
}

final class BridgeFundingObservation {
  const BridgeFundingObservation({
    required this.state,
    required this.providerStatus,
    required this.observedAt,
    this.providerSubstatus,
    this.sourceTransactionHash,
    this.destinationTransactionHash,
    this.actualOutputUnits,
  });
  final BridgeFundingState state;
  final String providerStatus;
  final String? providerSubstatus;
  final String? sourceTransactionHash;
  final String? destinationTransactionHash;
  final String? actualOutputUnits;
  final DateTime observedAt;
}

final class BridgeCapabilitySnapshot {
  const BridgeCapabilitySnapshot({
    required this.schemaVersion,
    required this.refreshedAt,
    required this.connectedChains,
    required this.relayChains,
    required this.connectedTokensByChain,
    required this.relayTokensByChain,
    required this.availabilityReasons,
  });
  final int schemaVersion;
  final DateTime refreshedAt;
  final List<BridgeChain> connectedChains;
  final List<BridgeChain> relayChains;
  final Map<int, List<BridgeToken>> connectedTokensByChain;
  final Map<int, List<BridgeToken>> relayTokensByChain;
  final Map<String, String> availabilityReasons;
}

final class BridgeFundingReceipt {
  const BridgeFundingReceipt({
    required this.schemaVersion,
    required this.intentId,
    required this.method,
    required this.provider,
    required this.state,
    required this.sourceChainId,
    required this.sourceTokenAddress,
    required this.sourceTokenSymbol,
    required this.sourceAmountUnits,
    required this.baseDestinationAddress,
    required this.createdAt,
    required this.updatedAt,
    this.sourceAddress,
    this.refundAddress,
    this.depositAddress,
    this.providerQuoteId,
    this.providerRequestId,
    this.routeTool,
    this.minimumOutputUnits,
    this.actualOutputUnits,
    this.sourceTransactionHash,
    this.destinationTransactionHash,
    this.providerStatus,
    this.providerSubstatus,
    this.expiresAt,
    this.archivedAt,
    this.depositAddressExposed = false,
    this.balanceRefreshPending = false,
    this.submissionOutcomeUnknown = false,
  });
  final int schemaVersion;
  final String intentId;
  final BridgeFundingMethod method;
  final String provider;
  final BridgeFundingState state;
  final int sourceChainId;
  final String sourceTokenAddress;
  final String sourceTokenSymbol;
  final String sourceAmountUnits;
  final String baseDestinationAddress;
  final String? sourceAddress;
  final String? refundAddress;
  final String? depositAddress;
  final String? providerQuoteId;
  final String? providerRequestId;
  final String? routeTool;
  final String? minimumOutputUnits;
  final String? actualOutputUnits;
  final String? sourceTransactionHash;
  final String? destinationTransactionHash;
  final String? providerStatus;
  final String? providerSubstatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final DateTime? archivedAt;
  final bool depositAddressExposed;
  final bool balanceRefreshPending;
  final bool submissionOutcomeUnknown;
}
```

`BridgeFundingReceipt.toJson()` stores these public recovery identifiers locally. `toAgentJson()` shortens every address and excludes provider payloads, transaction payloads, session material, callback state, and signatures.

- [ ] **Step 3: Define the internal provider strategy boundary**

Create `bridge_funding_strategy.dart` with an interface unavailable to agent
handlers:

```dart
sealed class ValidatedBridgeFundingIntent {
  const ValidatedBridgeFundingIntent({
    required this.intentId,
    required this.request,
  });
  final String intentId;
  final BridgeFundingRequest request;
}

final class ValidatedConnectedBridgeIntent
    extends ValidatedBridgeFundingIntent {
  const ValidatedConnectedBridgeIntent({
    required super.intentId,
    required super.request,
    required this.quote,
  });
  final BridgeExecutableQuote quote;
}

final class ValidatedRelayDepositIntent extends ValidatedBridgeFundingIntent {
  const ValidatedRelayDepositIntent({
    required super.intentId,
    required super.request,
    required this.instruction,
  });
  final RelayDepositInstruction instruction;
}

abstract interface class BridgeFundingStrategy {
  Future<BridgeCapabilitySnapshot> capabilities();
  Future<BridgeEstimate> quote(BridgeFundingRequest request);
  Future<BridgeFundingReceipt> submit(ValidatedBridgeFundingIntent intent);
  Future<BridgeFundingObservation> status(BridgeFundingReceipt receipt);
}
```

The controller owns strategy instances; capability and agent services receive
read-only facades that do not expose `submit`.

- [ ] **Step 4: Write failing transition tests**

Assert the state machine accepts only the intended paths and rejects skips:

```dart
expect(machine.canMove(BridgeFundingState.draft,
    BridgeFundingState.checkingCapabilities), isTrue);
expect(machine.canMove(BridgeFundingState.awaitingExternalWallet,
    BridgeFundingState.submitted), isTrue);
expect(machine.canMove(BridgeFundingState.awaitingDeposit,
    BridgeFundingState.depositDetected), isTrue);
expect(machine.canMove(BridgeFundingState.completed,
    BridgeFundingState.submitted), isFalse);
expect(() => machine.requireMove(
    BridgeFundingState.draft, BridgeFundingState.submitted), throwsStateError);
```

Run `flutter test test/bridge_state_machine_test.dart` and expect missing symbols.

- [ ] **Step 5: Implement the transition matrix**

Use one immutable map in `bridge_state_machine.dart`:

```dart
const allowedBridgeTransitions = <BridgeFundingState, Set<BridgeFundingState>>{
  BridgeFundingState.draft: {
    BridgeFundingState.checkingCapabilities,
    BridgeFundingState.cancelled,
  },
  BridgeFundingState.checkingCapabilities: {
    BridgeFundingState.connectingWallet,
    BridgeFundingState.collectingRefundAddress,
    BridgeFundingState.failed,
    BridgeFundingState.cancelled,
  },
  BridgeFundingState.connectingWallet: {
    BridgeFundingState.quoting,
    BridgeFundingState.failed,
    BridgeFundingState.cancelled,
  },
  BridgeFundingState.collectingRefundAddress: {
    BridgeFundingState.quoting,
    BridgeFundingState.failed,
    BridgeFundingState.cancelled,
  },
  BridgeFundingState.quoting: {
    BridgeFundingState.awaitingPlawieReview,
    BridgeFundingState.awaitingDeposit,
    BridgeFundingState.failed,
    BridgeFundingState.cancelled,
  },
  BridgeFundingState.awaitingPlawieReview: {
    BridgeFundingState.awaitingExternalWallet,
    BridgeFundingState.quoting,
    BridgeFundingState.cancelled,
    BridgeFundingState.failed,
  },
  BridgeFundingState.awaitingExternalWallet: {
    BridgeFundingState.submitted,
    BridgeFundingState.sourcePending,
    BridgeFundingState.cancelled,
    BridgeFundingState.failed,
  },
  BridgeFundingState.awaitingDeposit: {
    BridgeFundingState.depositDetected,
    BridgeFundingState.expired,
    BridgeFundingState.failed,
  },
  BridgeFundingState.depositDetected: {
    BridgeFundingState.destinationPending,
    BridgeFundingState.completed,
    BridgeFundingState.refunded,
    BridgeFundingState.partial,
    BridgeFundingState.failed,
  },
  BridgeFundingState.submitted: {
    BridgeFundingState.sourcePending,
    BridgeFundingState.destinationPending,
    BridgeFundingState.completed,
    BridgeFundingState.refunded,
    BridgeFundingState.partial,
    BridgeFundingState.failed,
  },
  BridgeFundingState.sourcePending: {
    BridgeFundingState.destinationPending,
    BridgeFundingState.completed,
    BridgeFundingState.refunded,
    BridgeFundingState.partial,
    BridgeFundingState.failed,
  },
  BridgeFundingState.destinationPending: {
    BridgeFundingState.completed,
    BridgeFundingState.refunded,
    BridgeFundingState.partial,
    BridgeFundingState.failed,
  },
};
```

Terminal states return no outgoing transitions. Archival is receipt metadata (`archivedAt`), not a false onchain terminal state.

- [ ] **Step 6: Write failing persistence tests**

Use `SharedPreferences.setMockInitialValues` to prove:

- one active non-archived receipt is enforced;
- an exposed Relay instruction cannot become `cancelled`;
- archived non-terminal receipts remain readable and status-trackable;
- corrupt records are skipped individually;
- terminal receipts are capped at 50;
- an upsert replaces by `intentId` and never duplicates.

Run `flutter test test/bridge_receipt_store_test.dart` and expect missing store/preferences members.

- [ ] **Step 7: Add bridge preference keys and the receipt store**

Add these members to `PreferencesService`:

```dart
static const _keyBridgeCapabilitySnapshot = 'bridge_capability_snapshot_v1';
static const _keyActiveBridgeReceipt = 'active_bridge_receipt_v1';
static const _keyBridgeReceipts = 'bridge_receipts_v1';

String? get bridgeCapabilitySnapshotJson =>
    _p.getString(_keyBridgeCapabilitySnapshot);
Future<bool> setBridgeCapabilitySnapshotJson(String? value) => value == null
    ? _p.remove(_keyBridgeCapabilitySnapshot)
    : _p.setString(_keyBridgeCapabilitySnapshot, value);
String? get activeBridgeReceiptJson => _p.getString(_keyActiveBridgeReceipt);
Future<bool> setActiveBridgeReceiptJson(String? value) => value == null
    ? _p.remove(_keyActiveBridgeReceipt)
    : _p.setString(_keyActiveBridgeReceipt, value);
List<String> get bridgeReceipts =>
    _p.getStringList(_keyBridgeReceipts) ?? const <String>[];
Future<bool> setBridgeReceipts(List<String> value) =>
    _p.setStringList(_keyBridgeReceipts, value);
```

`BridgeReceiptStore.upsert()` validates the transition, writes the receipt list first, then updates or clears the active key. A failed write throws `BridgePersistenceException` before any external action continues.

- [ ] **Step 8: Run tests and commit**

```powershell
flutter test test/bridge_models_test.dart test/bridge_state_machine_test.dart test/bridge_receipt_store_test.dart
dart analyze lib/services/bridge/bridge_models.dart lib/services/bridge/bridge_funding_strategy.dart lib/services/bridge/bridge_state_machine.dart lib/services/bridge/bridge_receipt_store.dart lib/services/preferences_service.dart
git add lib/services/bridge/bridge_models.dart lib/services/bridge/bridge_funding_strategy.dart lib/services/bridge/bridge_state_machine.dart lib/services/bridge/bridge_receipt_store.dart lib/services/preferences_service.dart test/bridge_models_test.dart test/bridge_state_machine_test.dart test/bridge_receipt_store_test.dart
git commit -m "feat: add durable bridge funding state"
```

## Task 3: Add bounded provider transport and live capability discovery

**Files:**
- Create: `lib/services/bridge/bridge_http_client.dart`
- Create: `lib/services/bridge/bridge_capability_service.dart`
- Test: `test/bridge_http_client_test.dart`
- Test: `test/bridge_capability_service_test.dart`

- [ ] **Step 1: Write failing HTTP boundary tests**

Test HTTPS/host enforcement, redirect rejection, JSON content type, response caps, 25-second timeout mapping, `Retry-After`, malformed JSON, and redacted errors. The only provider hosts are:

```dart
const providerHosts = <String>{'li.quest', 'api.relay.link'};
```

Run `flutter test test/bridge_http_client_test.dart` and expect the client type to be absent.

- [ ] **Step 2: Implement the bounded transport**

Expose:

```dart
abstract interface class BridgeHttpTransport {
  Future<BridgeHttpResponse> getJson(Uri uri, {int maxBytes = 262144});
  Future<BridgeHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    int maxBytes = 262144,
  });
}

final class BridgeHttpResponse {
  const BridgeHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.json,
  });
  final int statusCode;
  final Map<String, String> headers;
  final Object? json;
}
```

Build `http.Request` with `followRedirects = false`, `maxRedirects = 0`, `persistentConnection = false`, `Accept: application/json`, and a 25-second timeout. Reject non-2xx redirects before parsing. Do not include API keys; public LI.FI and Relay limits are sufficient for first release.

- [ ] **Step 3: Write failing capability fixtures**

For LI.FI `/v1/chains`, `/v1/connections`, and `/v1/token`, and Relay `/chains`, prove that:

```dart
expect(snapshot.connectedChains.map((c) => c.id), containsAll(<int>[1, 1151111081099710]));
expect(snapshot.relayTokensFor(1).map((t) => t.symbol), contains('USDC'));
expect(snapshot.relayTokensFor(1).every((t) => t.solverDepositable), isTrue);
expect(snapshot.relayChains.any((c) => c.id == 4663), isFalse);
```

Also reject Relay chains that are disabled, lagging, not deposit-enabled, or have no `solverCurrencies`; include Robinhood only when its live record passes every check.

- [ ] **Step 4: Implement live capability intersection and cache**

`BridgeCapabilityService.refresh()`:

1. loads the last valid persisted snapshot for immediate read-only display;
2. refreshes LI.FI and Relay in parallel;
3. intersects live IDs with shipped trusted IDs `{1, 1151111081099710, 4663}`;
4. accepts source tokens only from LI.FI-resolved native/USDC data or Relay `solverCurrencies`;
5. validates Base chain `8453` and native Base USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`;
6. persists a versioned snapshot with `refreshedAt` and provider-specific availability reasons.

Use a ten-minute in-memory freshness window and provider ETag/`If-None-Match` when supplied. A failed refresh keeps a non-expired cached display but disables new execution until a live provider quote succeeds.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/bridge_http_client_test.dart test/bridge_capability_service_test.dart
dart analyze lib/services/bridge/bridge_http_client.dart lib/services/bridge/bridge_capability_service.dart
git add lib/services/bridge/bridge_http_client.dart lib/services/bridge/bridge_capability_service.dart test/bridge_http_client_test.dart test/bridge_capability_service_test.dart
git commit -m "feat: discover live bridge funding capabilities"
```

## Task 4: Preserve and validate executable LI.FI quotes without exposing them

**Files:**
- Create: `lib/services/bridge/lifi_bridge_service.dart`
- Create: `lib/services/bridge/lifi_transaction_validator.dart`
- Modify: `lib/services/bridge_quote_service.dart`
- Modify: `test/bridge_quote_service_test.dart`
- Test: `test/lifi_transaction_validator_test.dart`

- [ ] **Step 1: Extend fixtures with executable EVM and Solana payloads**

Add an EVM fixture containing `from`, `to`, `data`, `value`, `gasLimit`, `chainId`, and `estimate.approvalAddress`. Add an SVM fixture whose `transactionRequest.data` is bounded base64. Assert the executable service retains them, while `BridgeQuoteService.quoteToBaseUsdc()` and `toAgentJson()` never expose either payload.

Run:

```powershell
flutter test test/bridge_quote_service_test.dart test/lifi_transaction_validator_test.dart
```

Expected: failures show that the current service discards `transactionRequest`.

- [ ] **Step 2: Implement separate estimate and executable quote APIs**

`LifiBridgeService` exposes:

```dart
Future<BridgeEstimate> estimate(BridgeFundingRequest request);
Future<BridgeExecutableQuote> executableQuote(
  BridgeFundingRequest request, {
  required String connectedSourceAddress,
});
Future<BridgeToken> resolveToken(int chainId, String token);
```

Both use the same strict action/token/amount parsing. Only `executableQuote` parses `transactionRequest`. `BridgeQuoteService` delegates to `estimate` and continues returning its existing public `BridgeQuote` contract during migration.

`LifiConnectedWalletStrategy implements BridgeFundingStrategy` composes this
service, the transaction validator, external-wallet service, and LI.FI status
service. Its `submit` accepts only `ValidatedConnectedBridgeIntent`; any Relay
intent throws `BridgeValidationException('strategy_intent_mismatch')`.

- [ ] **Step 3: Implement pure executable validation**

`LifiTransactionValidator.validate()` checks:

```dart
if (quote.sourceChain.id != request.sourceChain.id ||
    quote.destinationChainId != 8453 ||
    !sameAddress(quote.sourceAddress, connectedAddress, request.sourceChain.type) ||
    !sameAddress(quote.destinationAddress, baseAddress, BridgeChainType.evm) ||
    !sameAddress(quote.destinationToken.address, baseUsdc, BridgeChainType.evm) ||
    quote.sourceAmountUnits != request.amountUnits ||
    quote.expiresAt.difference(now) < const Duration(seconds: 30)) {
  throw const BridgeValidationException('quote_mismatch');
}
```

For EVM, additionally require matching `from`, chain ID, valid 0x `to/data/value/gasLimit`, payload at most 256 KiB, and an approval target equal to `estimate.approvalAddress`. For SVM, require only `data`, valid base64, decoded length from 1 through 1232 bytes, exact-case source key, and no EVM fields.

- [ ] **Step 4: Prove hostile quote rejection**

Add tests for changed sender, destination, chain, token contract, amount, decimals, slippage, expired quote, malformed hex, malformed base64, oversized calldata, wrong Solana key case, and response redirect.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/bridge_quote_service_test.dart test/lifi_transaction_validator_test.dart
dart analyze lib/services/bridge_quote_service.dart lib/services/bridge/lifi_bridge_service.dart lib/services/bridge/lifi_transaction_validator.dart
git add lib/services/bridge_quote_service.dart lib/services/bridge/lifi_bridge_service.dart lib/services/bridge/lifi_transaction_validator.dart test/bridge_quote_service_test.dart test/lifi_transaction_validator_test.dart
git commit -m "feat: retain validated LI.FI execution quotes"
```

## Task 5: Add Android wallet callbacks and the Reown session adapter

**Files:**
- Create: `android/app/src/main/kotlin/com/openclaw/plawie/WalletLinkBridge.kt`
- Modify: `android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `lib/services/bridge/external_wallet_session_service.dart`
- Create: `lib/services/bridge/reown_external_wallet_adapter.dart`
- Test: `test/wallet_link_native_contract_test.dart`
- Test: `test/external_wallet_session_service_test.dart`

- [ ] **Step 1: Write native callback contract tests**

Read the manifest and Kotlin sources and assert one callback filter, `singleTop`, exact `plawie://wallet-callback`, Flutter built-in deep linking disabled, package queries for `io.metamask` and `app.phantom`, and forwarding from both current intent and `onNewIntent`.

Run `flutter test test/wallet_link_native_contract_test.dart` and expect failure.

- [ ] **Step 2: Add the Android callback bridge**

Implement `WalletLinkBridge` with these channels:

```kotlin
private const val EVENTS = "com.openclaw.plawie/wallet_links"
private const val METHODS = "com.openclaw.plawie/wallet_links_control"
```

It accepts only `ACTION_VIEW` URIs whose scheme is `plawie` and host is `wallet-callback`, retains at most one initial link until Dart consumes `initialLink`, emits later links through one `EventChannel`, and never logs the URI or query parameters. `MainActivity.configureFlutterEngine` attaches it; `onNewIntent` calls `walletLinkBridge?.onIntent(intent)` after `setIntent(intent)`.

- [ ] **Step 3: Register wallet visibility and callback ownership**

Add to `AndroidManifest.xml`:

```xml
<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="plawie" android:host="wallet-callback" />
</intent-filter>
```

Under `<queries>`, add only:

```xml
<package android:name="io.metamask" />
<package android:name="app.phantom" />
```

- [ ] **Step 4: Write failing provider-neutral wallet tests**

Use a fake adapter to test missing release configuration, EVM connect, Solana connect, wrong chain/account, unsupported method, rejected connection, duplicate callback, callback after expiry, disconnect, and no session material in exported state.

Define the contract under test as:

```dart
abstract interface class ExternalWalletSessionService {
  Future<ExternalWalletIdentity> connect(BridgeChain chain);
  Future<void> disconnect();
  Future<String> sendEvmTransaction(EvmBridgeExecutionPayload payload);
  Future<Uint8List> signSolanaTransaction(
      SolanaBridgeExecutionPayload payload);
  ExternalWalletIdentity? get identity;
}

final class ExternalWalletIdentity {
  const ExternalWalletIdentity({
    required this.walletName,
    required this.address,
    required this.chainId,
    required this.chainType,
    required this.approvedMethods,
  });
  final String walletName;
  final String address;
  final int chainId;
  final BridgeChainType chainType;
  final Set<String> approvedMethods;
}
```

- [ ] **Step 5: Implement Reown initialization and bounded methods**

Require non-empty build defines:

```dart
const reownProjectId = String.fromEnvironment('REOWN_PROJECT_ID');
const plawieDappUrl = String.fromEnvironment('PLAWIE_DAPP_URL');
const walletRedirect = 'plawie://wallet-callback';
```

An empty project ID or dapp URL disables only connected-wallet funding with a visible reason. Initialize one `ReownAppKitModal` with Plawie metadata, Ethereum, Solana, and the shipped Robinhood chain record. Dispatch only validated callback links. Before every request, compare selected chain, session-derived address, and approved methods. EVM uses `eth_sendTransaction`; Phantom-compatible Solana uses `solana_signTransaction`. Do not request `solana_signAndSendTransaction`.

Wrap each connect/sign/send request in a `PendingWalletOperation` containing a
128-bit `Random.secure()` identifier, expected method, account, chain, and a
ten-minute expiry. Only one operation may exist; matching Reown/Phantom response
delivery consumes it once. Reown may use its own SDK-scoped secure session store,
but Plawie preferences and receipts never store topics, Phantom session tokens,
shared secrets, callback envelopes, or operation IDs. Disconnect and process
death clear Plawie in-memory operation state; receipt recovery does not need it.

- [ ] **Step 6: Verify callbacks and commit**

```powershell
flutter test test/wallet_link_native_contract_test.dart test/external_wallet_session_service_test.dart
flutter build apk --debug
adb shell am start -W -a android.intent.action.VIEW -d "plawie://wallet-callback?state=unmatched" com.openclaw.plawie
git add android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt android/app/src/main/kotlin/com/openclaw/plawie/WalletLinkBridge.kt lib/services/bridge/external_wallet_session_service.dart lib/services/bridge/reown_external_wallet_adapter.dart test/wallet_link_native_contract_test.dart test/external_wallet_session_service_test.dart
git commit -m "feat: add bounded external wallet sessions"
```

Expected: the app receives the link, rejects it as unmatched, does not alter bridge state, and does not restart or clear app data.

## Task 6: Execute exact EVM allowance and bridge requests

**Files:**
- Create: `lib/services/bridge/evm_bridge_rpc_service.dart`
- Create: `lib/services/bridge/bridge_funding_controller.dart`
- Test: `test/evm_bridge_rpc_service_test.dart`
- Test: `test/bridge_funding_controller_test.dart`

- [ ] **Step 1: Write failing RPC and approval tests**

Cover native-token routes, sufficient allowance, insufficient allowance, exact approval encoding, maximum allowance rejection, wrong RPC host, malformed 32-byte `eth_call`, pending receipt, reverted receipt, rate limit, and timeout.

Assert the approval bytes exactly equal:

```dart
expect(
  service.encodeExactApproval(spender, BigInt.from(1000000)),
  '0x095ea7b3'
  '000000000000000000000000${spender.substring(2).toLowerCase()}'
  '00000000000000000000000000000000000000000000000000000000000f4240',
);
```

- [ ] **Step 2: Implement shipped RPC policy and read methods**

Use only:

```dart
const evmSourceRpcUrls = <int, String>{
  1: 'https://ethereum-rpc.publicnode.com',
  4663: 'https://rpc.mainnet.chain.robinhood.com',
};
```

`EvmBridgeRpcService` exposes `allowance`, `encodeExactApproval`, and `waitForReceipt`. JSON-RPC IDs are random non-secret integers; redirects are rejected; response bodies are capped at 64 KiB. `waitForReceipt` performs bounded reads only and never resubmits.

- [ ] **Step 3: Write failing connected-flow orchestration tests**

With fake quote, wallet, store, and RPC services, prove:

1. connected address replaces typed estimate address;
2. review state persists before wallet request;
3. ERC-20 approval has its own review and wallet confirmation;
4. approval is exact, then confirmed, then a fresh LI.FI quote is requested;
5. bridge review occurs after requote;
6. one `eth_sendTransaction` is called;
7. returned source hash persists before polling;
8. duplicate confirm calls are rejected;
9. wallet rejection returns to review without marking submitted;
10. process resume never calls a wallet method.

- [ ] **Step 4: Implement foreground controller EVM flow**

Expose explicit preparation and confirmation methods:

```dart
Future<void> prepareConnected(BridgeFundingRequest request);
Future<void> confirmEvmAllowance(String intentId);
Future<void> confirmConnectedBridge(String intentId);
Future<void> cancelBeforeSubmission(String intentId);
Future<void> refreshStatus(String intentId);
```

Preparation may connect and quote but cannot submit. Confirmation checks the in-memory quote fingerprint, connected identity, and intent ID; persists `awaitingExternalWallet`; invokes the wallet once; validates the returned 32-byte EVM hash; persists `submitted`; then starts read-only status polling. If the app resumes with `awaitingExternalWallet` and no hash, show recovery guidance and never resend automatically.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/evm_bridge_rpc_service_test.dart test/bridge_funding_controller_test.dart
dart analyze lib/services/bridge/evm_bridge_rpc_service.dart lib/services/bridge/bridge_funding_controller.dart
git add lib/services/bridge/evm_bridge_rpc_service.dart lib/services/bridge/bridge_funding_controller.dart test/evm_bridge_rpc_service_test.dart test/bridge_funding_controller_test.dart
git commit -m "feat: execute reviewed EVM bridge requests"
```

## Task 7: Verify Phantom signatures and broadcast Solana exactly once

**Files:**
- Create: `lib/services/bridge/solana_transaction_envelope.dart`
- Create: `lib/services/bridge/solana_rpc_broadcaster.dart`
- Modify: `lib/services/bridge/bridge_funding_controller.dart`
- Test: `test/solana_transaction_envelope_test.dart`
- Test: `test/solana_rpc_broadcaster_test.dart`
- Modify: `test/bridge_funding_controller_test.dart`

- [ ] **Step 1: Write failing Solana envelope tests**

Use fixed legacy and versioned transaction fixtures. Assert bounded base58 encode/decode, compact-u16 parsing, exact unsigned/signed message equality, first required signer equality, non-zero first signature, derived transaction ID, malformed length rejection, changed-message rejection, wrong signer rejection, and a 1232-byte maximum.

- [ ] **Step 2: Implement the focused wire parser**

`SolanaTransactionEnvelope.verifySigned()` must:

```dart
final unsigned = base64Decode(unsignedBase64);
final signed = base58Decode(signedBase58);
final unsignedParts = parseTransaction(unsigned);
final signedParts = parseTransaction(signed);
if (!constantTimeBytesEqual(unsignedParts.message, signedParts.message)) {
  throw const BridgeValidationException('solana_message_changed');
}
if (!constantTimeBytesEqual(
    signedParts.requiredSignerKeys.first, base58Decode(expectedSigner))) {
  throw const BridgeValidationException('solana_signer_changed');
}
if (signedParts.signatures.first.every((byte) => byte == 0)) {
  throw const BridgeValidationException('solana_signature_missing');
}
```

Return exact signed bytes and the base58 first signature. Do not interpret instructions or rebuild the LI.FI message.

- [ ] **Step 3: Write failing one-shot broadcaster tests**

Assert one POST to `https://api.mainnet-beta.solana.com`, method `sendTransaction`, base64 encoding, `skipPreflight: false`, `preflightCommitment: confirmed`, `maxRetries: 0`, returned signature equality, no redirect, and no retry after timeout.

- [ ] **Step 4: Implement one-call Solana broadcasting**

Send:

```dart
<String, Object?>{
  'jsonrpc': '2.0',
  'id': requestId,
  'method': 'sendTransaction',
  'params': <Object?>[
    base64Encode(signedBytes),
    <String, Object?>{
      'encoding': 'base64',
      'skipPreflight': false,
      'preflightCommitment': 'confirmed',
      'maxRetries': 0,
    },
  ],
};
```

Any timeout becomes `submissionOutcomeUnknown`; status recovery uses the already-derived signature and never broadcasts again.

- [ ] **Step 5: Add Solana orchestration tests and implementation**

Prove the controller requests a fresh SVM quote, persists `awaitingExternalWallet`, sends only the reviewed base58 transaction to `solana_signTransaction`, verifies returned bytes, persists the derived source signature before RPC submission, invokes the broadcaster once, and resumes with status polling only.

- [ ] **Step 6: Run tests and commit**

```powershell
flutter test test/solana_transaction_envelope_test.dart test/solana_rpc_broadcaster_test.dart test/bridge_funding_controller_test.dart
git add lib/services/bridge/solana_transaction_envelope.dart lib/services/bridge/solana_rpc_broadcaster.dart lib/services/bridge/bridge_funding_controller.dart test/solana_transaction_envelope_test.dart test/solana_rpc_broadcaster_test.dart test/bridge_funding_controller_test.dart
git commit -m "feat: add verified Solana bridge submission"
```

## Task 8: Track LI.FI settlement and recover without rebroadcasting

**Files:**
- Create: `lib/services/bridge/lifi_status_service.dart`
- Modify: `lib/services/bridge/bridge_funding_controller.dart`
- Test: `test/lifi_status_service_test.dart`
- Modify: `test/bridge_funding_controller_test.dart`

- [ ] **Step 1: Write failing LI.FI status tests**

Fixture `NOT_FOUND`, `PENDING/WAIT_SOURCE_CONFIRMATIONS`, `PENDING/WAIT_DESTINATION_TRANSACTION`, `DONE/COMPLETED`, `DONE/PARTIAL`, `DONE/REFUNDED`, `FAILED`, 429 with `Retry-After`, malformed JSON, wrong chains, wrong hashes, and timeout.

- [ ] **Step 2: Implement status mapping**

Call only:

```text
GET https://li.quest/v1/status?txHash=<source>&fromChain=<sourceId>&toChain=8453&bridge=<tool>
```

Map `NOT_FOUND` and transport timeout to non-terminal `sourcePending`; map LI.FI substatuses to the domain states; accept explorer links only from trusted HTTPS explorer hosts returned with matching hashes/chains. Persist provider status/substatus and destination hash after every observation.

- [ ] **Step 3: Add bounded polling and lifecycle tests**

Use an injected delay function and assert delays `2s, 4s, 8s, 16s, 30s, 60s`, `Retry-After` clamped to 60 seconds, pause when the app is not foreground, stop at terminal, manual refresh availability, and zero wallet/broadcast calls after resume.

- [ ] **Step 4: Reconcile Base balance without rewriting settlement**

On `completed`, persist the receipt first, then call `BaseService.refreshBalance()`. If refresh reports an error, leave `state == completed`, set `balanceRefreshPending = true`, and expose a separate refresh action.

- [ ] **Step 5: Add unknown EVM return recovery**

For a persisted `awaitingExternalWallet` receipt without a hash, display `submissionOutcomeUnknown`. Permit the user to paste a source transaction hash from wallet history; validate EVM/Solana hash shape and provider status chain/address fields before attaching it. Never offer `Submit again` on that receipt.

- [ ] **Step 6: Run tests and commit**

```powershell
flutter test test/lifi_status_service_test.dart test/bridge_funding_controller_test.dart
git add lib/services/bridge/lifi_status_service.dart lib/services/bridge/bridge_funding_controller.dart test/lifi_status_service_test.dart test/bridge_funding_controller_test.dart
git commit -m "feat: recover and track LI.FI bridge settlement"
```

## Task 9: Add strict Relay self-custody deposit funding

**Files:**
- Create: `lib/services/bridge/relay_deposit_service.dart`
- Modify: `lib/services/bridge/bridge_funding_controller.dart`
- Test: `test/relay_deposit_service_test.dart`
- Modify: `test/bridge_funding_controller_test.dart`

- [ ] **Step 1: Write failing strict request tests**

Assert the exact request body:

```dart
expect(body, <String, Object?>{
  'user': baseDestination,
  'originChainId': sourceChainId,
  'destinationChainId': 8453,
  'originCurrency': sourceTokenAddress,
  'destinationCurrency': BridgeConstants.baseUsdc,
  'amount': sourceAmountUnits,
  'tradeType': 'EXACT_INPUT',
  'recipient': baseDestination,
  'refundTo': selfCustodyRefundAddress,
  'useDepositAddress': true,
  'strict': true,
});
```

Reject absent ownership confirmation, CEX origin, invalid source/refund address, unsupported solver currency, disabled chain, non-Base destination, non-USDC destination, and non-exact trade type.

- [ ] **Step 2: Write failing instruction-validation tests**

Parse `requestId`, `depositAddress`, `details.currencyIn`, `details.currencyOut`, exact input, minimum output, fees, and quote timestamps. Reject missing or duplicate deposit steps, wrong VM address, changed input/output currency, changed recipient/refund identity, impossible amount, absent request ID, and oversized response.

- [ ] **Step 3: Implement strict quote creation**

POST to `https://api.relay.link/quote/v2` only after the user checks `I am sending from a wallet I control`. Validate the response completely, persist `awaitingDeposit`, then reveal the address. A persistence failure prevents reveal.

`RelayDepositAddressStrategy implements BridgeFundingStrategy` composes Relay
quote/status operations. Its `submit` accepts only
`ValidatedRelayDepositIntent`; any connected intent throws
`BridgeValidationException('strategy_intent_mismatch')`.

- [ ] **Step 4: Write failing status and archive tests**

Cover `/requests/v2?depositAddress=...&includeChildRequests=true`, `/intents/status/v3?requestId=...`, waiting, depositing, pending, submitted, delayed, success, refund/refunded, failure, child request replacement, exact input under/overpayment, expired unsent instruction, and archive behavior.

- [ ] **Step 5: Implement read-only Relay tracking**

Track by deposit address first and request ID second. Map `inTxHashes` to source/deposit hashes and `txHashes` to Base destination hashes. Do not call Relay reindex automatically. `Hide instructions` sets `archivedAt`; it never marks the provider request cancelled or deletes status history. A new instruction requires a warning that the old address may still receive funds and must not be reused.

- [ ] **Step 6: Run tests and commit**

```powershell
flutter test test/relay_deposit_service_test.dart test/bridge_funding_controller_test.dart
dart analyze lib/services/bridge/relay_deposit_service.dart lib/services/bridge/bridge_funding_controller.dart
git add lib/services/bridge/relay_deposit_service.dart lib/services/bridge/bridge_funding_controller.dart test/relay_deposit_service_test.dart test/bridge_funding_controller_test.dart
git commit -m "feat: add strict Relay deposit funding"
```

## Task 10: Build the canonical Base funding panel and honest fallback

**Files:**
- Create: `lib/services/bridge/external_jumper_fallback.dart`
- Create: `lib/widgets/bridge_funding_panel.dart`
- Create: `lib/widgets/bridge_review_sheet.dart`
- Create: `lib/widgets/relay_deposit_sheet.dart`
- Modify: `lib/screens/base_screen.dart`
- Test: `test/bridge_funding_panel_test.dart`

- [ ] **Step 1: Write failing widget tests for entry and capability states**

Test absent internal wallet, Base Sepolia, capability loading/error/cache, connected method default, Relay method visibility, missing Reown configuration, Robinhood disabled reason, long chain/token names, 320-pixel width, and text scaling at 200 percent.

- [ ] **Step 2: Write failing connected-flow widget tests**

Test source/token/amount selection, Connect Wallet, session-derived address display, exact estimate, separate exact ERC-20 approval review, fresh final review, wallet rejection, source hash, pending/resume, terminal receipt, unknown-return recovery, and no duplicate submit button while busy.

- [ ] **Step 3: Write failing Relay widget tests**

Test self-custody ownership checkbox, explicit CEX disablement, personal refund input, persisted-before-reveal behavior, exact chain/token/amount/address display, QR semantics, copy action, expiry, hide/archive, old-address warning, provider refund, and no local `I sent it` transition.

- [ ] **Step 4: Implement the state-driven widgets**

`BridgeFundingPanel` takes injected controller and Base destination for tests. In production, `BaseScreen` supplies the current `BaseService.address`, `useSepolia`, and `refreshBalance`. Use `ChoiceChip` for method selection, constrained bottom sheets for reviews, `SelectableText` for full addresses, and `QrImageView(data: instruction.depositAddress)` labelled `Address only — send the exact token and amount shown above`.

Inputs freeze after review or address reveal. Every method change discards only in-memory quote/review data and never deletes a persisted receipt.

- [ ] **Step 5: Implement truthful Jumper prefill**

`ExternalJumperFallback.build()` creates only:

```dart
Uri.https('jumper.exchange', '/', <String, String>{
  'fromAmount': request.amount,
  'fromChain': request.sourceChain.id.toString(),
  'fromToken': request.sourceToken.address,
  'toChain': '8453',
  'toToken': BridgeConstants.baseUsdc,
  'toAddress': request.baseDestinationAddress,
});
```

Before opening, show: `Jumper will create a new route. Plawie will not submit or monitor it. Verify the Base destination before approving.` Opening the URL never changes a bridge receipt to submitted or completed.

- [ ] **Step 6: Remove the obsolete inline quote dialogs**

In `BaseScreen`, replace `_buildBridgePanel`, `_showBridgeQuoteDialog`, and `_showBridgeQuoteResult` with the new panel. Keep `_bridgeQuotes` only if another read-only surface still uses it; otherwise dispose it with the old dialog code. Do not alter x402 panels, wallet creation/recovery, send/receive, provider balances, or Gateway controls.

- [ ] **Step 7: Run widget tests and commit**

```powershell
flutter test test/bridge_funding_panel_test.dart test/bridge_quote_service_test.dart
dart analyze lib/widgets/bridge_funding_panel.dart lib/widgets/bridge_review_sheet.dart lib/widgets/relay_deposit_sheet.dart lib/screens/base_screen.dart
git add lib/services/bridge/external_jumper_fallback.dart lib/widgets/bridge_funding_panel.dart lib/widgets/bridge_review_sheet.dart lib/widgets/relay_deposit_sheet.dart lib/screens/base_screen.dart test/bridge_funding_panel_test.dart
git commit -m "feat: add canonical Base funding panel"
```

## Task 11: Expose read-only bridge status to agents and update documentation

**Files:**
- Modify: `lib/services/capabilities/ai_payments_capability.dart`
- Modify: `lib/services/app_native_chat_tool_router.dart`
- Modify: `lib/services/gateway_tool_catalog.dart`
- Modify: `lib/providers/node_provider.dart`
- Modify: `lib/services/gateway_service.dart`
- Modify: `test/ai_payments_capability_test.dart`
- Modify: `test/bridge_app_native_adapter_test.dart`
- Modify: `test/node_pairing_command_snapshot_test.dart`
- Create: `docs/EXTERNAL_WALLET_BRIDGING.md`
- Modify: `docs/WALLET_FUNDED_MODEL_PROVIDERS.md`
- Modify: `docs/DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md`

- [ ] **Step 1: Write failing agent-boundary tests**

Require declared commands:

```dart
const expectedBridgeCommands = <String>{
  'bridge.capabilities',
  'bridge.quote',
  'bridge.status',
  'bridge.receipts',
};
```

Assert `bridge.execute`, `bridge.connect`, `bridge.approve`, `bridge.sign`, `bridge.submit`, `bridge.broadcast`, and `bridge.deposit.create` are absent from capability commands, node snapshots, and `GatewayToolCatalog.mobileNodeAllowCommands`.

- [ ] **Step 2: Add redacted status and receipt handlers**

`bridge.status` returns the active receipt's agent JSON plus `mayApproveOrSpend: false`. `bridge.receipts` returns at most 20 redacted receipts. Execute-like natural-language requests route to `bridge.capabilities` with `foregroundApprovalRequired: true` and a Base-page explanation; they invoke no controller, wallet, Relay mutation, or broadcast method.

- [ ] **Step 3: Update Gateway instructions and command snapshots**

Advertise only the four read commands. Update the agent prompt to say that quotes are estimates, connected execution and deposit-address creation require visible Base UI, and agent status refresh is read-only. Preserve wildcard/tool-profile logic outside these explicit node commands.

- [ ] **Step 4: Write production operations documentation**

`docs/EXTERNAL_WALLET_BRIDGING.md` documents:

- non-custodial boundaries and internal Base destination;
- exact EVM allowance and double-review flow;
- Phantom sign-only and one-call Solana broadcast;
- Relay self-custody-only rule and CEX exclusion;
- strict deposit amount/token/refund warnings;
- receipt/status recovery and no automatic resend;
- `REOWN_PROJECT_ID` and `PLAWIE_DAPP_URL` release defines;
- resolved Reown license, usage limits, and attribution decision;
- independent `ENABLE_LIFI_CONNECTED_BRIDGE` and `ENABLE_RELAY_DEPOSIT_BRIDGE` release gates;
- honest Jumper fallback;
- controlled Mainnet acceptance and incident rollback.

Update `docs/WALLET_FUNDED_MODEL_PROVIDERS.md` with the user-facing path from
external wallet to Base USDC to an approved provider payment. Update
`docs/DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md` so bridge execution
is recorded as feature-gated until controlled Mainnet acceptance, without
claiming a provider credit purchase is complete merely because Base USDC
arrived.

Confirm the old 2026-08-05 connected-only plan remains marked superseded; do not
blend its deprecated `solana_signAndSendTransaction` instructions into this
plan.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/ai_payments_capability_test.dart test/bridge_app_native_adapter_test.dart test/node_pairing_command_snapshot_test.dart
git add lib/services/capabilities/ai_payments_capability.dart lib/services/app_native_chat_tool_router.dart lib/services/gateway_tool_catalog.dart lib/providers/node_provider.dart lib/services/gateway_service.dart test/ai_payments_capability_test.dart test/bridge_app_native_adapter_test.dart test/node_pairing_command_snapshot_test.dart docs/EXTERNAL_WALLET_BRIDGING.md docs/WALLET_FUNDED_MODEL_PROVIDERS.md docs/DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md
git commit -m "docs: finalize external wallet funding contract"
```

## Task 12: Run full regression and controlled Android acceptance

**Files:**
- Modify only files required by observed failures within this feature's scope
- Do not commit: `build/`, APKs, `android/build/reports/`, callback captures, or logs

- [ ] **Step 1: Run all bridge-focused tests**

```powershell
flutter test test/bridge_models_test.dart test/bridge_state_machine_test.dart test/bridge_receipt_store_test.dart test/bridge_http_client_test.dart test/bridge_capability_service_test.dart test/bridge_quote_service_test.dart test/lifi_transaction_validator_test.dart test/wallet_link_native_contract_test.dart test/external_wallet_session_service_test.dart test/evm_bridge_rpc_service_test.dart test/solana_transaction_envelope_test.dart test/solana_rpc_broadcaster_test.dart test/lifi_status_service_test.dart test/relay_deposit_service_test.dart test/bridge_funding_controller_test.dart test/bridge_funding_panel_test.dart test/bridge_app_native_adapter_test.dart test/ai_payments_capability_test.dart test/node_pairing_command_snapshot_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 2: Run wallet/payment/Gateway regressions**

```powershell
flutter test test/base_wallet_state_test.dart test/base_wallet_recovery_view_model_test.dart test/base_wallet_legacy_migration_contract_test.dart test/base_transfer_approval_test.dart test/android_wallet_authenticator_policy_test.dart test/x402_payment_service_test.dart test/x402_payment_transport_service_test.dart test/paid_provider_secure_surface_contract_test.dart test/paid_provider_context_invariance_test.dart test/provider_setup_service_test.dart test/wallet_funded_provider_setup_test.dart test/gateway_paid_provider_lifecycle_contract_test.dart
```

Expected: internal Base wallet, x402, provider, and native Gateway contracts remain green.

- [ ] **Step 3: Analyze and build without committing artifacts**

```powershell
flutter analyze
git diff --check
flutter build apk --debug --dart-define=REOWN_PROJECT_ID=$env:REOWN_PROJECT_ID --dart-define=PLAWIE_DAPP_URL=$env:PLAWIE_DAPP_URL --dart-define=ENABLE_LIFI_CONNECTED_BRIDGE=true --dart-define=ENABLE_RELAY_DEPOSIT_BRIDGE=true
git status --short
```

Expected: analysis has no new errors, diff check is silent, debug APK builds, and generated reports/APKs remain untracked or ignored.

- [ ] **Step 4: Install without clearing persisted wallet/app state**

```powershell
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.openclaw.plawie/.MainActivity
```

Expected: the same internal Base address remains after update; native Gateway remains primary; setup is not rerun; only the converged Gateway foreground notification is persistent.

- [ ] **Step 5: Verify non-spending device paths**

On device:

1. confirm missing Reown configuration disables only connected mode;
2. load live Ethereum/Solana capabilities and verify Robinhood's live gate;
3. connect and reject MetaMask once;
4. connect and reject Phantom once;
5. generate a Relay instruction only after explicit self-custody confirmation, verify every field, then archive it without sending;
6. force-stop/reopen and prove no wallet request or broadcast repeats;
7. confirm Jumper says it creates a new unmonitored route;
8. inspect filtered logs for duplicate callbacks, full addresses, calldata, signed bytes, session topics, secrets, or private keys.

- [ ] **Step 6: Perform controlled Mainnet proof only with fresh user approval**

The user chooses method, source wallet, token, and deliberately small amount in the UI. Stream filtered wallet/bridge logs while the user approves. For each enabled method, capture only redacted evidence of source hash/deposit detection, provider terminal status, destination hash, and Base balance refresh. Never automate confirmation or spend from the internal Base wallet.

- [ ] **Step 7: Commit only evidence-driven source corrections**

```powershell
git status --short
git diff --check
git log --oneline --decorate -15
```

If device acceptance required source corrections, rerun the affected focused and regression tests, then commit only source/tests/docs with a message describing the observed defect. If no correction was required, create no empty commit.

## Final acceptance checklist

- [ ] Connected LI.FI execution is enabled only with valid release configuration and a live provider route.
- [ ] Relay strict deposit funding is independently gated and self-custody-only.
- [ ] Strict Relay instructions require exact input, a personal refund address,
      and a live solver-depositable source currency; CEX-originated funding is
      rejected without creating a Plawie recovery wallet.
- [ ] Every external transaction receives a Plawie exact review and the wallet's own approval.
- [ ] ERC-20 allowances are exact, never unlimited.
- [ ] Phantom signs only the reviewed message; Plawie broadcasts returned bytes at most once.
- [ ] A revealed Relay address is persisted first, cannot be cancelled, and is never represented as reusable.
- [ ] Resume/status paths cannot connect, sign, submit, create an address, or rebroadcast.
- [ ] Only one active non-terminal intent exists; archived exposed addresses
      remain status-trackable and are never represented as reusable.
- [ ] Provider status, transaction hashes, and Base balance evidence determine
      completion; local button taps do not.
- [ ] Agent commands remain read-only and return redacted data.
- [ ] Receipts, logs, and callbacks expose no raw calldata, signed bytes,
      session topics, shared secrets, private keys, or unredacted agent data.
- [ ] Ethereum, Solana, and dynamically supported Robinhood routes have explicit
      available, degraded, and unavailable states.
- [ ] Automated tests spend nothing; controlled Mainnet acceptance requires a
      fresh visible approval from the user.
- [ ] Base wallet persistence, x402, setup, native Gateway ownership, skills, and model context are unchanged.
- [ ] Jumper is a new, explicitly unmonitored external route rather than continuation of a Plawie quote.
- [ ] No secret, transaction payload, APK, generated report, or device capture is committed.

## Primary implementation references

- [LI.FI quote and transaction request](https://docs.li.fi/api-reference/get-a-quote-for-a-token-transfer)
- [LI.FI Solana transaction execution](https://docs.li.fi/introduction/user-flows-and-examples/solana-tx-execution)
- [LI.FI status tracking](https://docs.li.fi/introduction/user-flows-and-examples/status-tracking)
- [LI.FI token approvals](https://docs.li.fi/agents/workflows/approvals)
- [Reown AppKit Flutter installation](https://docs.reown.com/appkit/flutter/core/installation)
- [Reown AppKit Flutter actions](https://docs.reown.com/appkit/flutter/core/actions)
- [Phantom connect](https://docs.phantom.com/phantom-deeplinks/provider-methods/connect)
- [Phantom sign transaction](https://docs.phantom.com/phantom-deeplinks/provider-methods/signtransaction)
- [Relay strict deposit addresses](https://docs.relay.link/features/deposit-addresses)
- [Relay quote v2](https://docs.relay.link/references/api/get-quote-v2)
- [Relay intent status v3](https://docs.relay.link/references/api/get-intents-status-v3)
- [Relay supported tokens and routes](https://docs.relay.link/references/api/api_resources/supported-routes)
