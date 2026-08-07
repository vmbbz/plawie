# Hybrid Base Funding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Plawie's quote-only bridge handoff with resumable Base Mainnet
funding through reviewed protocol-compatible external wallets, LI.FI execution,
direct Base USDC transfer, or a strict Relay self-custody deposit address, while
retaining an honest unmonitored Jumper fallback.

**Architecture:** A provider-neutral bridge domain owns capabilities, validation, redacted receipts, and a one-active-intent state machine. LI.FI and Relay remain independent strategies behind that domain. External-wallet routing is protocol- and capability-based: Reown handles compatible EVM wallets, native Solana MWA is primary for Solana, and bounded Reown Solana links are fallback only. Only the foreground Base UI may connect, review, reveal, sign, submit, or broadcast, while agents receive read-only estimates and redacted status. Existing Base Keystore signing, x402 payments, native Gateway ownership, setup, and skills are not refactored by this work.

**Tech Stack:** Flutter/Dart, `http`, `shared_preferences`, `web3dart`, Reown AppKit Flutter 1.7.6, Android Kotlin platform channels, Solana Mobile Wallet Adapter clientlib-ktx 2.1.0, bounded Phantom/Solflare links through Reown, LI.FI REST, Relay REST, Flutter unit/widget tests, and Android device acceptance.

**Approved design:** `docs/superpowers/specs/2026-08-07-hybrid-base-funding-design.md`

**Approved wallet amendment:** `docs/superpowers/specs/2026-08-07-protocol-wallet-interoperability-design.md` takes precedence over wallet-brand and Solana submission language in the original design.

**Verified provider-payment boundary (2026-08-07):** Venice and BlockRun both
offer Base and Solana payment surfaces, but neither live unsigned 402 challenge
offers Robinhood Chain. Plawie's selected provider-payment rail remains its
Android-owned Base wallet. Robinhood funding therefore uses the reviewed bridge
into Base USDC before any provider top-up or per-request payment. Direct Solana
provider payment is explicitly outside this bridge plan and cannot reuse its
signing authority.

---

## Delivery boundaries

- Work in `.worktrees/wallet-reliability` on `codex/hybrid-bridge-funding-design`.
- Preserve `BridgeQuoteService` as the public estimate-only API until the new panel passes device acceptance.
- Keep connected LI.FI execution, Relay deposit funding, Reown EVM, native MWA,
  Reown Solana fallback, and Base Account behind independent release gates.
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
- `lib/services/bridge/external_wallet_transport_router.dart` — chain/capability router; never dispatches by wallet brand.
- `lib/services/bridge/reown_evm_wallet_adapter.dart` — dynamic Reown EVM wallet/session adapter.
- `lib/services/bridge/solana_mwa_wallet_adapter.dart` — Dart adapter for native MWA capability negotiation.
- `lib/services/bridge/reown_solana_fallback_adapter.dart` — bounded Phantom/Solflare sign-only fallback.
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
- `android/app/src/main/kotlin/com/openclaw/plawie/SolanaMwaBridge.kt` — native MWA authorization and capability-negotiated transaction submission.
- `test/bridge_models_test.dart`
- `test/bridge_state_machine_test.dart`
- `test/bridge_receipt_store_test.dart`
- `test/bridge_http_client_test.dart`
- `test/bridge_capability_service_test.dart`
- `test/lifi_transaction_validator_test.dart`
- `test/wallet_link_native_contract_test.dart`
- `test/solana_mwa_native_contract_test.dart`
- `test/external_wallet_session_service_test.dart`
- `test/external_wallet_transport_router_test.dart`
- `test/evm_bridge_rpc_service_test.dart`
- `test/solana_transaction_envelope_test.dart`
- `test/solana_rpc_broadcaster_test.dart`
- `test/lifi_status_service_test.dart`
- `test/relay_deposit_service_test.dart`
- `test/bridge_funding_controller_test.dart`
- `test/bridge_funding_panel_test.dart`

### Modify

- `pubspec.yaml` and `pubspec.lock` — resolved Reown AppKit and QR dependencies.
- `android/app/build.gradle.kts` — exact official Solana MWA Android dependency.
- `android/app/src/main/AndroidManifest.xml:39` — generic wallet visibility, bounded installed hints, callback intent filter, and Flutter deep-link ownership.
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
- `docs/EXTERNAL_WALLET_BRIDGING.md` — extend the established dependency/license record with the production transport contract.
- `docs/superpowers/plans/2026-08-05-external-wallet-bridge-execution.md` — already marked superseded by this planning round.

## Task 1: Establish a clean baseline and resolve SDK dependencies

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Test: existing bridge/payment test files

- [x] **Step 1: Verify branch and working-tree scope**

Run:

```powershell
git branch --show-current
git status --short
git log -3 --oneline
```

Expected: branch is `codex/hybrid-bridge-funding-design`; the plan commits are present; no source changes or generated files are present.

- [x] **Step 2: Inspect Flutter tooling without terminating processes**

Run:

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'flutter|dart|java|gradle' } |
  Select-Object ProcessName,Id,CPU,StartTime,Path
flutter doctor -v
```

Expected: `flutter doctor -v` completes. If it stalls, identify the owning terminal/process before asking to stop it; do not repeatedly restart the app or Gateway.

- [x] **Step 3: Run the pre-change focused baseline**

Run:

```powershell
flutter test test/bridge_quote_service_test.dart test/bridge_app_native_adapter_test.dart test/ai_payments_capability_test.dart test/node_pairing_command_snapshot_test.dart
```

Expected: all existing bridge/agent tests pass. Any pre-existing failure is recorded before source edits and fixed only if it blocks this feature.

- [x] **Step 4: Resolve current compatible packages**

Run:

```powershell
flutter pub add reown_appkit
flutter pub add qr_flutter
flutter pub deps | Select-String 'reown_appkit|qr_flutter'
```

Expected: Pub resolves current versions compatible with this repository's Flutter/Dart SDK and writes exact versions to `pubspec.lock`. Do not copy the stale versions from the superseded 2026-08-05 plan.

- [x] **Step 5: Record the resolved Reown release obligations**

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

- [x] **Step 6: Prove dependency resolution did not break the app**

Run:

```powershell
flutter test test/bridge_quote_service_test.dart test/ai_payments_capability_test.dart
flutter analyze lib/services/bridge_quote_service.dart lib/screens/base_screen.dart
```

Expected: focused tests pass and analysis introduces no dependency errors.

- [x] **Step 7: Commit dependency resolution**

```powershell
git add pubspec.yaml pubspec.lock
git commit -m "build: add external wallet bridge dependencies"
```

Completed in `1d86a68`, with documentation corrections in `426e4cb` and
`4217b2e`. The pre-change 12-test baseline and post-change focused tests passed;
bounded analysis was clean.

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

- [x] **Step 1: Write failing model and redaction tests**

Create tests that construct a connected receipt and a Relay receipt and assert:

```dart
expect(receipt.toJson()['sourceAddress'], fullSourceAddress);
expect(receipt.toAgentJson()['sourceAddress'], '0x1111…1111');
expect(jsonEncode(receipt.toAgentJson()), isNot(contains(fullSourceAddress)));
expect(jsonEncode(receipt.toJson()), isNot(contains('transactionRequest')));
expect(jsonEncode(receipt.toJson()), isNot(contains('signedTransaction')));
expect(BridgeFundingReceipt.fromJson(receipt.toJson()), receipt);
expect(receipt.toJson()['walletTransport'], 'reownEvm');
expect(receipt.toAgentJson(), isNot(contains('walletTransport')));
expect(receipt.toAgentJson(), isNot(contains('reviewedPayloadHash')));
expect(receipt.toAgentJson(), isNot(contains('sourceBlockhash')));
```

Also assert every release gate defaults to false, every transport enum has a
stable serialized name, and a schema-v1 receipt without `walletTransport`
continues to decode as `null`.

Run:

```powershell
flutter test test/bridge_models_test.dart
```

Expected: compilation fails because the typed bridge models do not exist.

- [x] **Step 2: Define the public domain types**

Implement these exact top-level contracts in `bridge_models.dart`:

```dart
enum BridgeChainType { evm, svm }
enum BridgeFundingMethod { connectedWallet, relayDeposit, externalJumper }
enum ExternalWalletTransport {
  reownEvm,
  solanaMwa,
  reownSolanaPhantom,
  reownSolanaSolflare,
  baseAccountMwp,
}
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
  static const bool reownEvmWalletsEnabled = bool.fromEnvironment(
    'ENABLE_REOWN_EVM_WALLETS',
    defaultValue: false,
  );
  static const bool solanaMwaWalletsEnabled = bool.fromEnvironment(
    'ENABLE_SOLANA_MWA_WALLETS',
    defaultValue: false,
  );
  static const bool reownSolanaFallbackEnabled = bool.fromEnvironment(
    'ENABLE_REOWN_SOLANA_FALLBACK',
    defaultValue: false,
  );
  static const bool baseAccountMwpEnabled = bool.fromEnvironment(
    'ENABLE_BASE_ACCOUNT_MWP',
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
    this.walletTransport,
    this.reviewedPayloadHash,
    this.sourceBlockhash,
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
  final ExternalWalletTransport? walletTransport;
  final String? reviewedPayloadHash;
  final String? sourceBlockhash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final DateTime? archivedAt;
  final bool depositAddressExposed;
  final bool balanceRefreshPending;
  final bool submissionOutcomeUnknown;
}
```

`BridgeFundingReceipt.toJson()` stores these public recovery identifiers and the
non-secret transport enum locally. `toAgentJson()` shortens every address and
excludes provider payloads, transaction payloads, SDK authorization/session
material, callback state, operation IDs, signed bytes, and signatures. Tests
must prove every transport gate defaults false and survives no persistence.
`reviewedPayloadHash` is a lowercase SHA-256 hex digest, never the payload
itself. For EVM it hashes a canonical UTF-8 tuple of chain ID, lowercase sender,
lowercase target, normalized value quantity, and lowercase calldata; gas is
excluded because a wallet may safely estimate it. For Solana it hashes the exact
serialized message bytes;
`sourceBlockhash` is stored only for bounded Solana expiry reconciliation. Both
are excluded from agent JSON and logs.

- [x] **Step 3: Define the internal provider strategy boundary**

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

- [x] **Step 4: Write failing transition tests**

Assert the state machine accepts only the intended paths and rejects skips:

```dart
expect(machine.canMove(BridgeFundingState.draft,
    BridgeFundingState.checkingCapabilities), isTrue);
expect(machine.canMove(BridgeFundingState.awaitingExternalWallet,
    BridgeFundingState.submitted), isTrue);
expect(machine.canMove(BridgeFundingState.awaitingExternalWallet,
    BridgeFundingState.cancelled), isFalse);
expect(machine.canMove(BridgeFundingState.awaitingExternalWallet,
    BridgeFundingState.failed), isFalse);
expect(machine.canMove(BridgeFundingState.awaitingExternalWallet,
    BridgeFundingState.expired), isFalse);
expect(
  machine.canMoveWithEvidence(
    BridgeFundingState.awaitingExternalWallet,
    BridgeFundingState.expired,
    evidence: const SolanaNoSubmissionEvidence(
      sourceChainId: BridgeConstants.solanaChainId,
      blockhashInvalid: true,
      completeHistoryScan: true,
      exactMatchFound: false,
    ),
  ),
  isTrue,
);
expect(machine.canMove(BridgeFundingState.awaitingDeposit,
    BridgeFundingState.depositDetected), isTrue);
expect(machine.canMove(BridgeFundingState.completed,
    BridgeFundingState.submitted), isFalse);
expect(() => machine.requireMove(
    BridgeFundingState.draft, BridgeFundingState.submitted), throwsStateError);
```

Run `flutter test test/bridge_state_machine_test.dart` and expect missing symbols.

- [x] **Step 5: Implement the transition matrix**

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
    BridgeFundingState.awaitingPlawieReview,
    BridgeFundingState.submitted,
    BridgeFundingState.sourcePending,
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

Terminal states return no outgoing transitions. From `awaitingExternalWallet`,
return to review is legal only after a definitive pre-submission wallet
rejection or sign-only validation failure. The generic transition map does not
allow `expired`. `canMoveWithEvidence()` accepts that one transition only with a
`SolanaNoSubmissionEvidence` proving the source is Solana, its recent blockhash
is invalid, a complete bounded account-history scan succeeded, and no exact
reviewed-payload match exists. All other evidence combinations reject. A
ten-minute callback operation expiry alone never changes receipt state.
Ambiguous EVM or MWA submission remains active in `awaitingExternalWallet` with
`submissionOutcomeUnknown=true`; it cannot become `cancelled` or `failed`.
Archival is receipt metadata (`archivedAt`), not a false onchain terminal state.

Keep the evidence contract internal to `bridge_state_machine.dart`:

```dart
final class SolanaNoSubmissionEvidence {
  const SolanaNoSubmissionEvidence({
    required this.sourceChainId,
    required this.blockhashInvalid,
    required this.completeHistoryScan,
    required this.exactMatchFound,
  });
  final int sourceChainId;
  final bool blockhashInvalid;
  final bool completeHistoryScan;
  final bool exactMatchFound;

  bool get provesExpiry =>
      sourceChainId == BridgeConstants.solanaChainId &&
      blockhashInvalid &&
      completeHistoryScan &&
      !exactMatchFound;
}
```

`requireMove()` remains context-free and rejects this expiry. Only
`requireMoveWithEvidence()` may authorize it, and it rejects evidence for every
other transition so callers cannot use the object as a general bypass.

- [x] **Step 6: Write failing persistence tests**

Use `SharedPreferences.setMockInitialValues` to prove:

- one active non-archived receipt is enforced;
- an older receipt without `walletTransport` migrates without inventing a
  wallet identity;
- an exposed Relay instruction cannot become `cancelled`;
- an outcome-unknown external-wallet receipt cannot be cancelled, archived, or
  replaced merely because its callback token or quote expired;
- archived non-terminal receipts remain readable and status-trackable;
- corrupt records are skipped individually;
- terminal receipts are capped at 50;
- an upsert replaces by `intentId` and never duplicates.

Run `flutter test test/bridge_receipt_store_test.dart` and expect missing store/preferences members.

- [x] **Step 7: Add bridge preference keys and the receipt store**

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

- [x] **Step 8: Run tests and commit**

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

- [x] **Step 1: Write failing HTTP boundary tests**

Test HTTPS/host enforcement, redirect rejection, JSON content type, response caps, 25-second timeout mapping, `Retry-After`, malformed JSON, and redacted errors. The only provider hosts are:

```dart
const providerHosts = <String>{'li.quest', 'api.relay.link'};
```

Run `flutter test test/bridge_http_client_test.dart` and expect the client type to be absent.

- [x] **Step 2: Implement the bounded transport**

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

- [x] **Step 3: Write failing capability fixtures**

For LI.FI `/v1/chains`, `/v1/connections`, and `/v1/token`, and Relay `/chains`, prove that:

```dart
expect(snapshot.connectedChains.map((c) => c.id), containsAll(<int>[1, 1151111081099710]));
expect(snapshot.connectedChains.map((c) => c.id), contains(8453));
final directBaseToken = snapshot.connectedTokensFor(8453).single;
expect(directBaseToken.address, BridgeConstants.baseUsdc);
expect(directBaseToken.symbol, 'USDC');
expect(snapshot.relayTokensFor(1).map((t) => t.symbol), contains('USDC'));
expect(snapshot.relayTokensFor(1).every((t) => t.solverDepositable), isTrue);
expect(snapshot.relayChains.any((c) => c.id == 4663), isFalse);
```

Also reject Relay chains that are disabled, lagging, not deposit-enabled, or have no `solverCurrencies`; include Robinhood only when its live record passes every check.

- [x] **Step 4: Implement live capability intersection and cache**

`BridgeCapabilityService.refresh()`:

1. loads the last valid persisted snapshot for immediate read-only display;
2. refreshes LI.FI and Relay in parallel;
3. intersects live bridge IDs with shipped trusted IDs
   `{1, 1151111081099710, 4663}`;
4. accepts source tokens only from LI.FI-resolved native/USDC data or Relay `solverCurrencies`;
5. validates Base chain `8453` and native Base USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`;
6. adds Base `8453` plus only native Base USDC to connected capabilities as
   provider `direct_base`, independently of LI.FI route availability, when the
   Reown EVM transport and internal Base destination are available;
7. persists a versioned snapshot with `refreshedAt` and provider-specific availability reasons.

Use a ten-minute in-memory freshness window and provider ETag/`If-None-Match` when supplied. A failed refresh keeps a non-expired cached display but disables new execution until a live provider quote succeeds.

- [x] **Step 5: Run tests and commit**

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

- [x] **Step 1: Extend fixtures with executable EVM and Solana payloads**

Add an EVM fixture containing `from`, `to`, `data`, `value`, `gasLimit`, `chainId`, and `estimate.approvalAddress`. Add an SVM fixture whose `transactionRequest.data` is bounded base64. Assert the executable service retains them, while `BridgeQuoteService.quoteToBaseUsdc()` and `toAgentJson()` never expose either payload.

Run:

```powershell
flutter test test/bridge_quote_service_test.dart test/lifi_transaction_validator_test.dart
```

Expected: failures show that the current service discards `transactionRequest`.

- [x] **Step 2: Implement separate estimate and executable quote APIs**

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
service. Because the wallet and status services are created in Tasks 5 through
8, the concrete strategy is completed in Task 8 with those real dependencies;
Task 4 does not create placeholder wallet or status collaborators. Its `submit`
accepts only `ValidatedConnectedBridgeIntent`; any Relay intent throws
`BridgeValidationException('strategy_intent_mismatch')`.

- [x] **Step 3: Implement pure executable validation**

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

- [x] **Step 4: Prove hostile quote rejection**

Add tests for changed sender, destination, chain, token contract, amount, decimals, slippage, expired quote, malformed hex, malformed base64, oversized calldata, wrong Solana key case, and response redirect.

- [x] **Step 5: Run tests and commit**

```powershell
flutter test test/bridge_quote_service_test.dart test/lifi_transaction_validator_test.dart
dart analyze lib/services/bridge_quote_service.dart lib/services/bridge/lifi_bridge_service.dart lib/services/bridge/lifi_transaction_validator.dart
git add lib/services/bridge_quote_service.dart lib/services/bridge/lifi_bridge_service.dart lib/services/bridge/lifi_transaction_validator.dart test/bridge_quote_service_test.dart test/lifi_transaction_validator_test.dart
git commit -m "feat: retain validated LI.FI execution quotes"
```

## Task 5: Add protocol-routed external wallet sessions

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt`
- Create: `android/app/src/main/kotlin/com/openclaw/plawie/WalletLinkBridge.kt`
- Create: `android/app/src/main/kotlin/com/openclaw/plawie/SolanaMwaBridge.kt`
- Create: `lib/services/bridge/external_wallet_session_service.dart`
- Create: `lib/services/bridge/external_wallet_transport_router.dart`
- Create: `lib/services/bridge/reown_evm_wallet_adapter.dart`
- Create: `lib/services/bridge/solana_mwa_wallet_adapter.dart`
- Create: `lib/services/bridge/reown_solana_fallback_adapter.dart`
- Test: `test/wallet_link_native_contract_test.dart`
- Test: `test/solana_mwa_native_contract_test.dart`
- Test: `test/external_wallet_session_service_test.dart`
- Test: `test/external_wallet_transport_router_test.dart`

- [x] **Step 1: Write failing Android contract tests**

Read only the real `com/openclaw/plawie` Android sources, Gradle file, and
manifest. Assert:

- exact dependency
  `com.solanamobile:mobile-wallet-adapter-clientlib-ktx:2.1.0`;
- one callback filter, `singleTop`, exact `plawie://wallet-callback`, and Flutter
  built-in deep-link ownership disabled;
- current-intent and `onNewIntent` forwarding through one callback owner;
- one native MWA bridge attached to the Flutter engine;
- MWA uses the Android chooser and contains no Phantom, Solflare, Jupiter, or
  other Solana package-name branch;
- generic HTTPS wallet visibility and any bounded installed hints are ordering
  aids only, with no package allowlist in execution code.

Run both native contract tests and expect missing files/dependency failures.

- [x] **Step 2: Add callback ownership and the native MWA bridge**

`WalletLinkBridge` owns:

```kotlin
private const val EVENTS = "com.openclaw.plawie/wallet_links"
private const val METHODS = "com.openclaw.plawie/wallet_links_control"
```

It accepts only `ACTION_VIEW` links with exact scheme `plawie` and host
`wallet-callback`, retains one initial link until Dart consumes `initialLink`,
emits later links through one `EventChannel`, and never logs URI/query data.

Add the MWA dependency and implement `SolanaMwaBridge` on
`com.openclaw.plawie/solana_mwa`. It exposes `authorize`, `submitTransaction`,
and `deauthorize`. Authorization is Mainnet-only and returns only public account,
wallet label, and advertised feature/method names. `submitTransaction` accepts
one frozen base64 serialized transaction and returns exactly one tagged result:

```text
{mode: signOnly, signedTransactionBytes: <Kotlin ByteArray>}
{mode: signAndSend, signatureBase58: ...}
```

If sign-only is advertised, request it. Otherwise invoke MWA 2.0's mandatory
`signAndSendTransactions` once. SDK authorization state stays in native
SDK-scoped storage or memory and is never returned to Dart. Cancellation,
authorization failure, invalid payload, and ambiguous submission use stable
error codes and never trigger a second request.

- [x] **Step 3: Register protocol discovery and callback ownership**

Keep the exact callback filter and add only Android visibility required by the
SDKs: a generic browsable HTTPS `VIEW` intent plus bounded package hints proven
necessary by the resolved Reown fallback. Do not add `QUERY_ALL_PACKAGES`; do
not require any Solana wallet package for MWA discovery. Package visibility may
improve ordering but cannot determine support.

- [x] **Step 4: Write failing provider-neutral session and router tests**

Define and test these contracts:

```dart
enum SolanaWalletSubmissionMode { signOnly, signAndSend }

sealed class SolanaWalletSubmissionResult {
  const SolanaWalletSubmissionResult();
}

final class SignedSolanaTransaction extends SolanaWalletSubmissionResult {
  const SignedSolanaTransaction(this.signedTransaction);
  final Uint8List signedTransaction;
}

final class SubmittedSolanaTransaction extends SolanaWalletSubmissionResult {
  const SubmittedSolanaTransaction(this.signature);
  final String signature;
}

abstract interface class ExternalWalletSessionService {
  Future<List<ExternalWalletOption>> discover(BridgeChain chain);
  Future<ExternalWalletIdentity> connect(
    BridgeChain chain, {
    ExternalWalletTransport? transport,
  });
  Future<void> disconnect();
  Future<String> sendEvmTransaction(EvmBridgeExecutionPayload payload);
  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  );
  ExternalWalletIdentity? get identity;
}
```

`ExternalWalletIdentity` records only transport enum, wallet-reported label,
case-sensitive public address, chain ID/type, and approved methods/features.
Test disabled gates, EVM discovery independent of wallet name, MWA-first Solana
routing, explicit Reown fallback, Base Account's honest unavailable reason,
wrong chain/account/method, rejection, duplicate callback, expiry, disconnect,
and zero SDK session material in exported state.

- [x] **Step 5: Implement adapters and capability routing**

Require non-empty Reown release defines:

```dart
const reownProjectId = String.fromEnvironment('REOWN_PROJECT_ID');
const plawieDappUrl = String.fromEnvironment('PLAWIE_DAPP_URL');
const walletRedirect = 'plawie://wallet-callback';
```

`ReownEvmWalletAdapter` uses AppKit's dynamic Explorer catalog and requires the
exact `eip155` chain/account plus `eth_sendTransaction`; wallet display names
never select code. `SolanaMwaWalletAdapter` translates only the tagged native
contract above and preserves `signedTransactionBytes` as Dart `Uint8List`.
`ReownSolanaFallbackAdapter` exposes only the resolved Phantom and Solflare
sign-only services after their independent gate is enabled; it base58-decodes
their response once into the same raw-byte result before returning it. No
controller or verifier accepts transport-specific signed-transaction text.

`ExternalWalletTransportRouter` selects Reown EVM for EVM, native MWA first for
Solana, and a user-selected enabled Reown fallback only after MWA is unavailable.
It reports Base Account unavailable while its independent gate is false; do not
create a nonfunctional adapter merely to satisfy the enum.

Wrap connect/sign/send in one in-memory `PendingWalletOperation` containing a
128-bit `Random.secure()` ID, transport, method, account, chain, reviewed
fingerprint, and ten-minute expiry. A matching response consumes it once. SDK
session stores may persist internally, but Plawie preferences, receipts, logs,
and agents never receive session topics, authorization tokens, shared secrets,
callback envelopes, or operation IDs.

- [x] **Step 6: Verify, document the native dependency, and commit**

Record the MWA Apache-2.0 dependency and release attribution decision in
`docs/EXTERNAL_WALLET_BRIDGING.md`, then run:

```powershell
flutter test test/wallet_link_native_contract_test.dart test/solana_mwa_native_contract_test.dart test/external_wallet_session_service_test.dart test/external_wallet_transport_router_test.dart
dart analyze lib/services/bridge/external_wallet_session_service.dart lib/services/bridge/external_wallet_transport_router.dart lib/services/bridge/reown_evm_wallet_adapter.dart lib/services/bridge/solana_mwa_wallet_adapter.dart lib/services/bridge/reown_solana_fallback_adapter.dart
flutter build apk --debug
git diff --check
git add android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt android/app/src/main/kotlin/com/openclaw/plawie/WalletLinkBridge.kt android/app/src/main/kotlin/com/openclaw/plawie/SolanaMwaBridge.kt lib/services/bridge/external_wallet_session_service.dart lib/services/bridge/external_wallet_transport_router.dart lib/services/bridge/reown_evm_wallet_adapter.dart lib/services/bridge/solana_mwa_wallet_adapter.dart lib/services/bridge/reown_solana_fallback_adapter.dart test/wallet_link_native_contract_test.dart test/solana_mwa_native_contract_test.dart test/external_wallet_session_service_test.dart test/external_wallet_transport_router_test.dart docs/EXTERNAL_WALLET_BRIDGING.md
git commit -m "feat: add protocol-routed external wallet sessions"
```

Do not install, launch, or inject a callback during this task. Device interaction
is reserved for Task 12 after announcing it and checking that the user is idle.

## Task 6: Execute exact EVM bridge requests and direct Base USDC transfers

**Files:**
- Create: `lib/services/bridge/evm_bridge_rpc_service.dart`
- Create: `lib/services/bridge/bridge_funding_controller.dart`
- Test: `test/evm_bridge_rpc_service_test.dart`
- Test: `test/bridge_funding_controller_test.dart`

- [x] **Step 1: Write failing RPC, approval, and direct-transfer tests**

Cover native-token routes, sufficient allowance, insufficient allowance, exact
approval encoding, exact Base USDC `transfer(address,uint256)` encoding, maximum
allowance rejection, wrong RPC host, malformed 32-byte `eth_call`, bounded gas
estimation, pending receipt, reverted receipt, rate limit, and timeout.

Assert the approval bytes exactly equal:

```dart
expect(
  service.encodeExactApproval(spender, BigInt.from(1000000)),
  '0x095ea7b3'
  '000000000000000000000000${spender.substring(2).toLowerCase()}'
  '00000000000000000000000000000000000000000000000000000000000f4240',
);
expect(
  service.encodeExactTransfer(destination, BigInt.from(1000000)),
  '0xa9059cbb'
  '000000000000000000000000${destination.substring(2).toLowerCase()}'
  '00000000000000000000000000000000000000000000000000000000000f4240',
);
```

- [x] **Step 2: Implement shipped RPC policy and read methods**

Use only:

```dart
const evmSourceRpcUrls = <int, String>{
  1: 'https://ethereum-rpc.publicnode.com',
  8453: 'https://mainnet.base.org',
  4663: 'https://rpc.mainnet.chain.robinhood.com',
};
```

`EvmBridgeRpcService` exposes `allowance`, `encodeExactApproval`,
`encodeExactTransfer`, `estimateGas`, and `waitForReceipt`. It accepts only the
shipped RPC map, exact chain IDs, 20-byte addresses, non-negative values, and
bounded hex responses. JSON-RPC IDs are random non-secret integers; redirects
are rejected; response bodies are capped at 64 KiB. `waitForReceipt` performs
bounded reads only and never resubmits.

- [x] **Step 3: Write failing connected-flow orchestration tests**

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
11. Base Mainnet native USDC to the internal Base address creates provider
    `direct_base`, route tool `direct_transfer`, exact minimum output, zero
    allowance request, and one reviewed token transfer;
12. Base USDC direct transfer remains available when LI.FI is disabled but the
    Reown EVM gate and Base RPC are available;
13. a different Base token or non-Base source never enters the direct path.

- [x] **Step 4: Implement foreground controller EVM flow**

Expose explicit preparation and confirmation methods:

```dart
Future<void> prepareConnected(BridgeFundingRequest request);
Future<void> confirmEvmAllowance(String intentId);
Future<void> confirmConnectedBridge(String intentId);
Future<void> cancelBeforeSubmission(String intentId);
Future<void> refreshStatus(String intentId);
```

Preparation may connect and quote but cannot submit. For Ethereum or Robinhood,
it uses a validated fresh LI.FI executable quote and exact allowance flow. For
Base Mainnet native USDC, it skips LI.FI entirely and builds an immutable direct
ERC-20 transfer to the current internal Base address, with `value=0`, exact
amount units, bounded estimated gas, provider `direct_base`, and no approval.

Confirmation checks the in-memory fingerprint, connected identity, transport,
chain, account, and intent ID; persists `awaitingExternalWallet` with the
canonical exact-transaction `reviewedPayloadHash`; invokes the wallet once;
validates the returned 32-byte EVM hash; persists `submitted`; then
starts read-only receipt/status polling. If the app resumes with
`awaitingExternalWallet` and no hash, show outcome-unknown recovery guidance and
never resend automatically. A direct transfer completes only after a successful
Base receipt and Base-balance reconciliation; it never calls LI.FI status.

- [x] **Step 5: Run tests and commit**

```powershell
flutter test test/evm_bridge_rpc_service_test.dart test/bridge_funding_controller_test.dart
dart analyze lib/services/bridge/evm_bridge_rpc_service.dart lib/services/bridge/bridge_funding_controller.dart
git add lib/services/bridge/evm_bridge_rpc_service.dart lib/services/bridge/bridge_funding_controller.dart test/evm_bridge_rpc_service_test.dart test/bridge_funding_controller_test.dart
git commit -m "feat: execute reviewed EVM bridge requests"
```

## Task 7: Verify capability-negotiated Solana submission exactly once

**Files:**
- Create: `lib/services/bridge/solana_transaction_envelope.dart`
- Create: `lib/services/bridge/solana_rpc_broadcaster.dart`
- Modify: `lib/services/bridge/bridge_funding_controller.dart`
- Test: `test/solana_transaction_envelope_test.dart`
- Test: `test/solana_rpc_broadcaster_test.dart`
- Modify: `test/bridge_funding_controller_test.dart`

- [x] **Step 1: Write failing Solana envelope and signature tests**

Use fixed legacy and versioned transaction fixtures. Assert bounded base58
encode/decode, compact-u16 parsing, exact unsigned/signed message equality, first
required signer equality, non-zero first signature, derived transaction ID,
Ed25519 verification of a returned 64-byte sign-and-send signature against the
reviewed message and first required signer, malformed length rejection,
changed-message rejection, wrong signer/signature rejection, and a 1232-byte
maximum.

- [x] **Step 2: Implement the focused wire parser**

`SolanaTransactionEnvelope.verifySigned()` must:

```dart
final unsigned = base64Decode(unsignedBase64);
final unsignedParts = parseTransaction(unsigned);
final signedParts = parseTransaction(signedTransactionBytes);
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

`signedTransactionBytes` is the canonical raw `Uint8List` produced by every
adapter. Return those exact bytes and the base58-encoded first signature. Do not
decode transport text here, interpret instructions, or rebuild the LI.FI
message.

Add `verifySubmittedSignature()` for MWA sign-and-send. It parses the frozen
unsigned transaction, requires the expected wallet account to be the first
required signer, base58-decodes exactly 64 signature bytes, and verifies with
the existing `cryptography` Ed25519 implementation over the exact serialized
message. Return only the normalized base58 signature. Never reconstruct or
mutate the message.

- [x] **Step 3: Write failing broadcaster and read-only status tests**

Assert one POST to `https://api.mainnet-beta.solana.com`, method
`sendTransaction`, base64 encoding, `skipPreflight: false`,
`preflightCommitment: confirmed`, `maxRetries: 0`, returned signature equality,
no redirect, and no retry after timeout. Separately assert
`getSignatureStatuses` is read-only, accepts only a validated signature, handles
`null`/processed/confirmed/finalized/error, and never invokes `sendTransaction`.

- [x] **Step 4: Implement one-call Solana broadcasting**

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

- [x] **Step 5: Add capability-negotiated orchestration tests**

Prove both branches start from a fresh validated SVM quote, an exact Plawie
review, and a persisted `awaitingExternalWallet` receipt containing the exact
message SHA-256 `reviewedPayloadHash` and parsed `sourceBlockhash`:

1. If MWA advertises sign-only, or an enabled Reown Phantom/Solflare fallback is
   selected, send only the frozen reviewed transaction for signature; verify the
   returned signed bytes; persist the derived source signature before RPC;
   invoke Plawie's broadcaster exactly once; and resume with status polling only.
2. If MWA does not advertise sign-only, invoke native
   `signAndSendTransactions` exactly once; verify the returned signature against
   the frozen reviewed message and signer; persist it before any provider/RPC
   status call; never invoke Plawie's broadcaster; and resume with status
   polling only.
3. If sign-and-send returns an ambiguous timeout/transport failure without a
   trustworthy signature, leave the persisted receipt active with
   `submissionOutcomeUnknown=true`, explain that no trustworthy signature was
   returned, expose only the evidence-bound recovery in Task 8, and make
   automatic confirm, submit, cancel, archive, and broadcast calls impossible.
   Treat a malformed or mismatched returned sign-and-send signature the same
   way because the wallet may already have broadcast. A sign-only validation
   failure is safe to return to review because Plawie has not broadcast.
4. A duplicate callback, double tap, process resume, account change, method
   change, or late response invokes neither branch a second time.

- [x] **Step 6: Implement the two bounded submission branches**

`confirmConnectedBridge()` consumes the tagged
`SolanaWalletSubmissionResult`. `SignedSolanaTransaction` enters the verified
one-shot Plawie broadcaster path. `SubmittedSolanaTransaction` enters local
signature verification and read-only status polling directly. The receipt is
written before every irreversible boundary. Never fall from a failed
sign-and-send request into sign-only, and never retry either mode automatically.

- [x] **Step 7: Run tests and commit**

```powershell
flutter test test/solana_transaction_envelope_test.dart test/solana_rpc_broadcaster_test.dart test/bridge_funding_controller_test.dart
git add lib/services/bridge/solana_transaction_envelope.dart lib/services/bridge/solana_rpc_broadcaster.dart lib/services/bridge/bridge_funding_controller.dart test/solana_transaction_envelope_test.dart test/solana_rpc_broadcaster_test.dart test/bridge_funding_controller_test.dart
git commit -m "feat: add verified Solana bridge submission"
```

## Task 8: Track LI.FI settlement and recover without rebroadcasting

**Files:**
- Create: `lib/services/bridge/lifi_status_service.dart`
- Modify: `lib/services/bridge/bridge_funding_controller.dart`
- Modify: `lib/services/bridge/evm_bridge_rpc_service.dart`
- Modify: `lib/services/bridge/solana_transaction_envelope.dart`
- Modify: `lib/services/bridge/solana_rpc_broadcaster.dart`
- Test: `test/lifi_status_service_test.dart`
- Modify: `test/evm_bridge_rpc_service_test.dart`
- Modify: `test/solana_transaction_envelope_test.dart`
- Modify: `test/solana_rpc_broadcaster_test.dart`
- Modify: `test/bridge_funding_controller_test.dart`

- [x] **Step 1: Write failing LI.FI status tests**

Fixture `NOT_FOUND`, `PENDING/WAIT_SOURCE_CONFIRMATIONS`, `PENDING/WAIT_DESTINATION_TRANSACTION`, `DONE/COMPLETED`, `DONE/PARTIAL`, `DONE/REFUNDED`, `FAILED`, 429 with `Retry-After`, malformed JSON, wrong chains, wrong hashes, and timeout.

- [x] **Step 2: Implement status mapping**

Call only:

```text
GET https://li.quest/v1/status?txHash=<source>&fromChain=<sourceId>&toChain=8453&bridge=<tool>
```

Map `NOT_FOUND` and transport timeout to non-terminal `sourcePending`; map LI.FI substatuses to the domain states; accept explorer links only from trusted HTTPS explorer hosts returned with matching hashes/chains. Persist provider status/substatus and destination hash after every observation.

- [x] **Step 3: Add bounded polling and lifecycle tests**

Use an injected delay function and assert delays `2s, 4s, 8s, 16s, 30s, 60s`, `Retry-After` clamped to 60 seconds, pause when the app is not foreground, stop at terminal, manual refresh availability, and zero wallet/broadcast calls after resume.

- [x] **Step 4: Reconcile Base balance without rewriting settlement**

On `completed`, persist the receipt first, then call `BaseService.refreshBalance()`. If refresh reports an error, leave `state == completed`, set `balanceRefreshPending = true`, and expose a separate refresh action.

- [x] **Step 5: Add evidence-bound unknown-return recovery**

Every final review persists `reviewedPayloadHash` before invoking a wallet. A
persisted `awaitingExternalWallet` receipt with no source hash/signature and
`submissionOutcomeUnknown=true` never offers `Submit again`, cancel, archive, or
automatic expiry.

For LI.FI EVM, let the user paste the 32-byte hash from wallet history. Fetch the
source transaction with `eth_getTransactionByHash` from the shipped chain RPC and
require exact chain, source account, target, value, normalized calldata digest,
and reviewed payload hash before attaching it; then require LI.FI status to agree
with source/destination chains and source hash.

For provider `direct_base`, use the same RPC fetch but require Base chain, exact
source account, `to == BridgeConstants.baseUsdc`, `value == 0`, and calldata
equal to `encodeExactTransfer(baseDestinationAddress, sourceAmountUnits)` before
attaching the hash. Completion then uses only successful Base receipt plus Base
balance reconciliation; LI.FI is never called.

For unknown Solana MWA sign-and-send, `Refresh` performs no signature-status call
without a signature. The user may paste a base58 transaction signature from
wallet history, or trigger a bounded `getSignaturesForAddress` scan of at most
200 entries since `createdAt`. Fetch candidate transactions with
`getTransaction` using base64 encoding; accept only an exact reviewed message
hash and first required signer match, then attach the verified signature and
resume read-only status/LI.FI polling. Persist the source recent blockhash before
the wallet call. The receipt may become `expired` only after
`isBlockhashValid == false` and a complete, non-truncated, error-free bounded
history scan finds no exact reviewed transaction. Any RPC error, truncation, or
ambiguous candidate leaves the receipt active and blocked. The controller must
pass the successful scan result through
`BridgeStateMachine.requireMoveWithEvidence()`; it may not write `expired`
directly.

- [x] **Step 6: Run tests and commit**

```powershell
flutter test test/lifi_status_service_test.dart test/evm_bridge_rpc_service_test.dart test/solana_transaction_envelope_test.dart test/solana_rpc_broadcaster_test.dart test/bridge_funding_controller_test.dart
git add lib/services/bridge/lifi_status_service.dart lib/services/bridge/evm_bridge_rpc_service.dart lib/services/bridge/solana_transaction_envelope.dart lib/services/bridge/solana_rpc_broadcaster.dart lib/services/bridge/bridge_funding_controller.dart test/lifi_status_service_test.dart test/evm_bridge_rpc_service_test.dart test/solana_transaction_envelope_test.dart test/solana_rpc_broadcaster_test.dart test/bridge_funding_controller_test.dart
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

Test absent internal wallet, Base Sepolia, capability loading/error/cache,
connected method default, Relay method visibility, each independently disabled
wallet transport, Base Account's honest unavailable state, Robinhood disabled
reason, long chain/token/wallet names, 320-pixel width, and text scaling at 200
percent.

- [ ] **Step 2: Write failing connected-flow widget tests**

Test source/token/amount selection; Reown's searchable dynamic EVM wallet modal;
installed hint and QR/copy fallback; Solana's `Choose compatible wallet` MWA
chooser; explicit Phantom/Solflare fallback only after MWA unavailability;
session-derived address; exact estimate; direct Base USDC transfer label and
review; separate exact LI.FI ERC-20 approval review; fresh final review; wallet
rejection; unsupported chain/method/account-change errors; source signature/hash;
pending/resume; terminal receipt; sign-and-send unknown-return recovery; and no
duplicate submit button while busy. Outcome-unknown UI offers only an
evidence-bound EVM hash or Solana signature/history reconciliation path; it has
no submit-again, cancel, archive, or generic status action that cannot work
without an identifier.

- [ ] **Step 3: Write failing Relay widget tests**

Test self-custody ownership checkbox, explicit CEX disablement, personal refund input, persisted-before-reveal behavior, exact chain/token/amount/address display, QR semantics, copy action, expiry, hide/archive, old-address warning, provider refund, and no local `I sent it` transition.

- [ ] **Step 4: Implement the state-driven widgets**

`BridgeFundingPanel` takes injected controller and Base destination for tests. In
production, `BaseScreen` supplies the current `BaseService.address`,
`useSepolia`, and `refreshBalance`. Ask for source chain/token/amount before
wallet selection. EVM opens Reown's live searchable catalog; it does not render
a static brand list. Solana opens the native MWA chooser, then offers only
enabled compatible fallback transports if MWA is unavailable. Capability errors
name the missing transport/chain/method and offer another wallet or funding
method without claiming installation alone makes it compatible.

Use `ChoiceChip` for method selection, constrained bottom sheets for reviews,
`SelectableText` for full addresses, and
`QrImageView(data: instruction.depositAddress)` labelled
`Address only — send the exact token and amount shown above`. A Base Mainnet
native-USDC source is labelled `Direct transfer on Base — no bridge provider`
and still receives exact Plawie review plus wallet confirmation.

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
- Modify: `docs/EXTERNAL_WALLET_BRIDGING.md`
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
- protocol/capability routing rather than a wallet-brand allowlist;
- Reown dynamic EVM discovery, native MWA primary, and bounded Reown Solana
  fallback behavior;
- exact EVM allowance and double-review flow;
- direct Base USDC transfer without LI.FI or an allowance;
- MWA sign-only verification plus one-call Plawie broadcast when supported;
- mandatory MWA sign-and-send review, returned-signature verification,
  persistence, status polling, and unknown-outcome no-resubmit behavior;
- Relay self-custody-only rule and CEX exclusion;
- strict deposit amount/token/refund warnings;
- receipt/status recovery and no automatic resend;
- `REOWN_PROJECT_ID` and `PLAWIE_DAPP_URL` release defines;
- resolved Reown license, usage limits, and attribution decision;
- independent `ENABLE_LIFI_CONNECTED_BRIDGE`, `ENABLE_RELAY_DEPOSIT_BRIDGE`,
  `ENABLE_REOWN_EVM_WALLETS`, `ENABLE_SOLANA_MWA_WALLETS`,
  `ENABLE_REOWN_SOLANA_FALLBACK`, and default-off `ENABLE_BASE_ACCOUNT_MWP`
  release gates;
- current wallet compatibility is negotiated at runtime; named wallets are
  device acceptance fixtures, not permanent support claims;
- honest Jumper fallback;
- controlled Mainnet acceptance and incident rollback.

Update `docs/WALLET_FUNDED_MODEL_PROVIDERS.md` with the user-facing path from
external wallet to Base USDC to an approved provider payment. Update
`docs/DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md` so bridge execution
is recorded as feature-gated until controlled Mainnet acceptance, without
claiming a provider credit purchase is complete merely because Base USDC
arrived.

Confirm the old 2026-08-05 connected-only plan remains marked superseded. Its
wallet-specific deep-link execution and deprecated RPC method names do not
override the approved MWA 2.0 capability-negotiated contract.

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
flutter test test/bridge_models_test.dart test/bridge_state_machine_test.dart test/bridge_receipt_store_test.dart test/bridge_http_client_test.dart test/bridge_capability_service_test.dart test/bridge_quote_service_test.dart test/lifi_transaction_validator_test.dart test/wallet_link_native_contract_test.dart test/solana_mwa_native_contract_test.dart test/external_wallet_session_service_test.dart test/external_wallet_transport_router_test.dart test/evm_bridge_rpc_service_test.dart test/solana_transaction_envelope_test.dart test/solana_rpc_broadcaster_test.dart test/lifi_status_service_test.dart test/relay_deposit_service_test.dart test/bridge_funding_controller_test.dart test/bridge_funding_panel_test.dart test/bridge_app_native_adapter_test.dart test/ai_payments_capability_test.dart test/node_pairing_command_snapshot_test.dart
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
flutter build apk --debug --dart-define=REOWN_PROJECT_ID=$env:REOWN_PROJECT_ID --dart-define=PLAWIE_DAPP_URL=$env:PLAWIE_DAPP_URL --dart-define=ENABLE_LIFI_CONNECTED_BRIDGE=true --dart-define=ENABLE_RELAY_DEPOSIT_BRIDGE=true --dart-define=ENABLE_REOWN_EVM_WALLETS=true --dart-define=ENABLE_SOLANA_MWA_WALLETS=true --dart-define=ENABLE_REOWN_SOLANA_FALLBACK=true --dart-define=ENABLE_BASE_ACCOUNT_MWP=false
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

1. confirm missing Reown configuration disables Reown transports without
   disabling native MWA, Relay, Jumper, or the internal Base wallet;
2. load live Ethereum/Solana capabilities and verify Robinhood's live gate;
3. use Reown search to connect then reject at least two compatible EVM wallets
   from different vendors; prove an unlisted compatible wallet remains
   discoverable through search or WalletConnect QR/copy;
4. launch the MWA chooser without a package-specific selection, cancel once,
   then verify the chosen wallet's advertised sign-only/sign-and-send mode;
5. when installed and available, verify Phantom and Solflare are capability-
   detected through MWA; exercise one enabled Reown fallback cancellation and
   prove it remains sign-only;
6. verify Base Account remains honestly unavailable while its gate is false,
   while another Base-capable EVM wallet can select direct Base USDC transfer;
7. generate a Relay instruction only after explicit self-custody confirmation,
   verify every field, then archive it without sending;
8. force-stop/reopen and prove no wallet request, submission, or broadcast
   repeats;
9. confirm Jumper says it creates a new unmonitored route;
10. inspect filtered logs for duplicate callbacks, full addresses, calldata,
    signed bytes/signatures, authorization/session material, secrets, or private
    keys.

- [ ] **Step 6: Perform controlled Mainnet proof only with fresh user approval**

The user chooses method, source wallet, token, and deliberately small amount in
the UI. Stream filtered wallet/bridge logs while the user approves. For a Solana
proof, record the advertised MWA mode before approval: sign-only must show one
Plawie broadcast; sign-and-send must show zero Plawie broadcasts and one
persisted returned signature. For direct Base USDC, prove LI.FI and allowance
calls are absent. For each enabled method, capture only redacted evidence of
source signature/hash or deposit detection, provider/chain terminal status,
destination hash, and Base balance refresh. Never automate confirmation or
spend from the internal Base wallet.

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
- [ ] Wallet display names never select execution code; compatibility is based
      on negotiated namespace, chain, account, method, and transport gates.
- [ ] Reown exposes compatible EVM wallets through dynamic search/QR without a
      hardcoded support allowlist.
- [ ] Native MWA invokes the Android-compatible wallet chooser without a Solana
      wallet package allowlist.
- [ ] MWA sign-only verifies reviewed bytes and Plawie broadcasts at most once;
      MWA sign-and-send verifies/persists its returned signature and triggers
      zero Plawie broadcasts or automatic resubmissions.
- [ ] Reown Phantom/Solflare links remain fallback-only and sign-only.
- [ ] Base USDC already on Base uses one reviewed direct transfer, not LI.FI and
      not an allowance.
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
- [Solana Mobile native MWA client](https://docs.solanamobile.com/android-native/using_mobile_wallet_adapter)
- [MWA 2.0 wallet migration](https://docs.solanamobile.com/mwa/migration/wallets/walletlib)
- [Phantom connect](https://docs.phantom.com/phantom-deeplinks/provider-methods/connect)
- [Phantom sign transaction](https://docs.phantom.com/phantom-deeplinks/provider-methods/signtransaction)
- [Relay strict deposit addresses](https://docs.relay.link/features/deposit-addresses)
- [Relay quote v2](https://docs.relay.link/references/api/get-quote-v2)
- [Relay intent status v3](https://docs.relay.link/references/api/get-intents-status-v3)
- [Relay supported tokens and routes](https://docs.relay.link/references/api/api_resources/supported-routes)
