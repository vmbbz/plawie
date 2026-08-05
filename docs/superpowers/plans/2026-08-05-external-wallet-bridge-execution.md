# External Wallet Bridge Execution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing Ethereum, Solana, and Robinhood Chain to Base-USDC quote flow into a fresh-quote, externally signed, resumable LI.FI bridge flow with exact user review and settlement receipts.

**Architecture:** `BridgeQuoteService` remains a public read-only planner. `ExternalWalletSessionService` wraps Reown AppKit for EVM and Solana wallet sessions. `BridgeExecutionCoordinator` is the only foreground execution state machine: it binds the connected public address to a fresh quote, validates the returned transaction, obtains visible Plawie review, delegates signing to the external wallet, persists a redacted receipt, and polls LI.FI. Plawie's internal Base wallet never receives bridge calldata.

**Tech Stack:** Flutter/Dart, `reown_appkit` 1.8.3, `app_links` 7.2.1, WalletConnect/Reown JSON-RPC, Phantom-compatible Solana requests, LI.FI REST API, SharedPreferences-backed versioned receipts, Flutter unit/widget tests, Android intent links.

---

## Scope and security boundaries

- Source chains: Ethereum Mainnet (`eip155:1`), Solana Mainnet (`solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp` as exposed by Reown), and Robinhood Chain (`eip155:4663`). Destination is Base Mainnet (`eip155:8453`) native USDC contract `0x833589fcd6edb6e08f4c7c32d4f71b54bda02913`.
- A manually typed source address remains quote-only. Execution uses the connected session address and obtains a fresh quote after connection.
- The app requests `eth_sendTransaction` or `solana_signAndSendTransaction` only for a reviewed, validated LI.FI response. It never imports or requests an external-wallet seed/private key.
- The app-owned Base signer is not modified in this slice.
- Agent tools remain read-only: capabilities, quote, status, and redacted receipts. Only foreground Base UI can advance execution.
- `REOWN_PROJECT_ID` is supplied with `--dart-define`; an empty value disables execution with an honest reason. No sample ID is committed.
- LI.FI public API requests use no embedded partner key.

## File map

**Create**

- `lib/services/bridge_models.dart`
- `lib/services/bridge_transaction_validator.dart`
- `lib/services/external_wallet_session_service.dart`
- `lib/services/bridge_execution_coordinator.dart`
- `lib/services/bridge_receipt_store.dart`
- `lib/services/lifi_status_service.dart`
- `lib/services/evm_allowance_service.dart`
- `lib/services/wallet_callback_service.dart`
- `test/bridge_transaction_validator_test.dart`
- `test/external_wallet_session_service_test.dart`
- `test/bridge_execution_coordinator_test.dart`
- `test/bridge_receipt_store_test.dart`
- `test/lifi_status_service_test.dart`
- `test/base_bridge_execution_widget_test.dart`
- `docs/EXTERNAL_WALLET_BRIDGING.md`

**Modify**

- `pubspec.yaml`
- `pubspec.lock`
- `android/app/src/main/AndroidManifest.xml`
- `lib/main.dart`
- `lib/services/bridge_quote_service.dart`
- `lib/services/preferences_service.dart`
- `lib/services/capabilities/ai_payments_capability.dart`
- `lib/services/app_native_chat_tool_router.dart`
- `lib/screens/base_screen.dart`

## Task 1: Preserve and validate executable quote data

- [ ] **Step 1: Write failing model and validator tests**

Extend the existing LI.FI fixture in `test/bridge_quote_service_test.dart` and create `bridge_transaction_validator_test.dart`. Assert the parsed quote preserves:

- quote/tool/route identifiers and expiry;
- connected source and internal Base destination addresses;
- exact source amount, estimated and minimum destination amounts, and slippage;
- EVM `from`, `to`, `value`, `data`, `chainId`, `gasLimit`, and allowance spender;
- Solana serialized transaction and source public key;
- a maximum 256 KiB transaction payload.

Reject wrong source/destination chain, sender, destination, USDC contract, amount, non-HTTPS LI.FI metadata, expired quote, malformed hex/base64, response redirects, and oversized bodies.

- [ ] **Step 2: Run the red tests**

```powershell
flutter test test/bridge_quote_service_test.dart test/bridge_transaction_validator_test.dart
```

Expected: missing `BridgeTransactionRequest`/validator symbols and assertions showing `transactionRequest` is currently discarded.

- [ ] **Step 3: Add versioned bridge models**

In `bridge_models.dart`, define sealed execution payloads:

```dart
sealed class BridgeTransactionRequest {
  const BridgeTransactionRequest();
}

final class EvmBridgeTransactionRequest extends BridgeTransactionRequest {
  const EvmBridgeTransactionRequest({
    required this.chainId,
    required this.from,
    required this.to,
    required this.valueHex,
    required this.dataHex,
    required this.gasLimitHex,
    required this.allowanceTarget,
  });
  final int chainId;
  final String from;
  final String to;
  final String valueHex;
  final String dataHex;
  final String gasLimitHex;
  final String? allowanceTarget;
}

final class SolanaBridgeTransactionRequest extends BridgeTransactionRequest {
  const SolanaBridgeTransactionRequest({
    required this.from,
    required this.serializedTransaction,
  });
  final String from;
  final String serializedTransaction;
}
```

Add `BridgeQuote.executableRequest`, `expiresAt`, `routeId`, `tool`, and exact amount fields. Remove `externalCompletionUrl` from the integrated-success path; keep a separate constant/manual fallback model labelled unmonitored.

- [ ] **Step 4: Parse bounded LI.FI responses**

In `BridgeQuoteService`, disable redirect following, enforce `Content-Type: application/json`, cap streamed response bytes at 256 KiB, parse `transactionRequest`, and retain only fields required by the validator. Preserve Solana address case.

- [ ] **Step 5: Implement pure validation**

`BridgeTransactionValidator.validate(quote, connectedAddress, destinationAddress, now)` returns a typed validated transaction. It compares EVM addresses case-insensitively, Solana addresses exactly, canonical decimal/hex integer values numerically, and quote expiry with a 30-second safety margin.

- [ ] **Step 6: Run tests and commit**

```powershell
flutter test test/bridge_quote_service_test.dart test/bridge_transaction_validator_test.dart
dart analyze lib/services/bridge_quote_service.dart lib/services/bridge_models.dart lib/services/bridge_transaction_validator.dart
git add lib/services/bridge_quote_service.dart lib/services/bridge_models.dart lib/services/bridge_transaction_validator.dart test/bridge_quote_service_test.dart test/bridge_transaction_validator_test.dart
git commit -m "feat: preserve validated LI.FI bridge transactions"
```

Expected: focused tests pass and analyzer reports no new findings.

## Task 2: Add Reown sessions and one-shot callback handling

- [ ] **Step 1: Add dependencies and prove resolution**

Modify `pubspec.yaml`:

```yaml
dependencies:
  app_links: ^7.2.1
  reown_appkit: ^1.8.3
```

Run:

```powershell
flutter pub get
flutter pub deps | Select-String 'app_links|reown_appkit'
```

Expected: `app_links 7.2.1` and `reown_appkit 1.8.3` resolve under Dart 3.10.x.

- [ ] **Step 2: Write the wallet-session adapter tests before implementation**

Use a fake AppKit adapter and fake callback stream. Test missing project ID, EVM connection/address extraction, Solana connection/address extraction, chain switch rejection, disconnected session, duplicate callback, wrong callback state, expired callback, and callback delivery after process resume.

```powershell
flutter test test/external_wallet_session_service_test.dart
```

Expected: missing service/adapter types.

- [ ] **Step 3: Register the Android callback**

Set Flutter deep linking off so `app_links` owns the URI, and add a `singleTop` intent filter:

```xml
<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="plawie" android:host="wallet-callback" />
</intent-filter>
```

Keep the existing package/application ID and launcher attributes unchanged.

- [ ] **Step 4: Initialize `AppLinks` before UI construction**

In `main.dart`, instantiate one `WalletCallbackService(AppLinks())` before `runApp`. It accepts only `plawie://wallet-callback`, stores one pending state record with 128-bit `Random.secure()` state and ten-minute expiry, consumes a match once, and forwards every Reown envelope to `ReownAppKitModal.dispatchEnvelope(uri.toString())`.

- [ ] **Step 5: Wrap Reown behind an injectable interface**

`ExternalWalletSessionService` owns one initialized `ReownAppKitModal`:

```dart
final modal = ReownAppKitModal(
  context: context,
  projectId: const String.fromEnvironment('REOWN_PROJECT_ID'),
  metadata: const PairingMetadata(
    name: 'Plawie',
    description: 'External wallet bridge approval for Plawie',
    url: 'https://github.com/vmbbz/plawie',
    icons: <String>[],
    redirect: Redirect(native: 'plawie://wallet-callback'),
  ),
  optionalNamespaces: namespaces,
);
await modal.init();
```

The namespace map requests only `eth_chainId`, `eth_sendTransaction`, `wallet_switchEthereumChain`, `wallet_addEthereumChain`, and `solana_signAndSendTransaction` on the three source chains. The service exposes public address, chain ID, wallet name, topic, connect/disconnect, switch-chain, and bounded request methods; raw sessions do not enter app state or logs.

- [ ] **Step 6: Register trusted Robinhood metadata**

Add Robinhood Chain only through shipped constants: chain ID 4663, RPC `https://rpc.mainnet.chain.robinhood.com`, explorer `https://robinhoodchain.blockscout.com`, native currency ETH. Availability additionally requires LI.FI `/chains` and `/connections` support at runtime.

- [ ] **Step 7: Run tests, Android link verification, and commit**

```powershell
flutter test test/external_wallet_session_service_test.dart
flutter build apk --debug
adb shell am start -W -a android.intent.action.VIEW -d "plawie://wallet-callback?state=unmatched" com.openclaw.plawie
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml lib/main.dart lib/services/external_wallet_session_service.dart lib/services/wallet_callback_service.dart test/external_wallet_session_service_test.dart
git commit -m "feat: add bounded external wallet sessions"
```

Expected: unmatched callback is rejected without changing bridge state; tests pass.

## Task 3: Persist an idempotent bridge state machine

- [ ] **Step 1: Write failing receipt-store and coordinator tests**

Cover transitions:

```text
draft -> connectingWallet -> quoting -> awaitingPlawieReview
-> awaitingExternalWallet -> submitted -> sourcePending
-> destinationPending -> completed | failed | refunded | partial | cancelled
```

Reject skipped/backward transitions, a second submission, wrong receipt ID, and resume that rebroadcasts. Test corrupt records are quarantined individually and do not erase valid receipts.

- [ ] **Step 2: Define versioned redacted records**

`BridgeReceipt` stores schema version, local ID, LI.FI route/tool, chains/tokens, connected source and internal destination public addresses, exact submitted/minimum/actual amounts, source/destination hashes, status/substatus, timestamps, and last check. It never stores full calldata, signed transaction bytes, session topic, callback state, or Reown URI.

- [ ] **Step 3: Add PreferencesService storage**

Add `bridge_receipts_v1` and `pending_bridge_intent_v1` string-list/string keys with async setters. Cap terminal receipts at 50; retain one pending intent until terminal/cancelled.

- [ ] **Step 4: Implement transition enforcement**

`BridgeExecutionCoordinator` receives quote/session/validator/receipt/status dependencies. Every transition persists before emitting UI state. `submit` writes `awaitingExternalWallet` before opening a wallet and records the source hash before polling. Resume may poll only; it cannot call a wallet request.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/bridge_receipt_store_test.dart test/bridge_execution_coordinator_test.dart
dart analyze lib/services/bridge_execution_coordinator.dart lib/services/bridge_receipt_store.dart lib/services/preferences_service.dart
git add lib/services/bridge_execution_coordinator.dart lib/services/bridge_receipt_store.dart lib/services/preferences_service.dart test/bridge_receipt_store_test.dart test/bridge_execution_coordinator_test.dart
git commit -m "feat: persist resumable bridge execution state"
```

## Task 4: Execute exact EVM allowance and bridge transactions

- [ ] **Step 1: Add red tests for EVM policy**

Test native-token routes, ERC-20 routes with sufficient allowance, insufficient allowance, exact approval amount, unlimited-approval rejection, wrong chain/account, wallet rejection, stale quote after approval, malformed hash, and duplicate request.

- [ ] **Step 2: Implement allowance reads**

`EvmAllowanceService` calls trusted source-chain RPC with `eth_call` for `allowance(owner, spender)`. It caps response size and requires a 32-byte result. The spender must equal LI.FI’s validated `approvalAddress`/allowance target.

- [ ] **Step 3: Build only an exact ERC-20 approval**

If allowance is insufficient, build `approve(spender, exactSourceAmount)`; reject `uint256.max`. Show a separate Plawie review containing token, spender, exact amount, source chain, estimated gas, and connected account. Submit with:

```dart
await modal.request(
  topic: modal.session!.topic,
  chainId: 'eip155:$chainId',
  request: SessionRequestParams(
    method: MethodsConstants.ethSendTransaction,
    params: <Map<String, dynamic>>[approvalTransaction],
  ),
);
```

- [ ] **Step 4: Wait, refresh, and submit the bridge transaction**

Wait for the approval receipt through source RPC, request a fresh LI.FI quote, rerun all validation, display final bridge review, switch to the source chain, and request exactly one `eth_sendTransaction` using the validated LI.FI fields. Never route this transaction through `SecureEvmWalletManager`.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/bridge_execution_coordinator_test.dart test/external_wallet_session_service_test.dart
git add lib/services/evm_allowance_service.dart lib/services/bridge_execution_coordinator.dart test/bridge_execution_coordinator_test.dart
git commit -m "feat: execute reviewed EVM bridge transactions"
```

## Task 5: Execute Solana transactions through a Phantom-capable session

- [ ] **Step 1: Add red tests for Solana handoff**

Test case-sensitive source matching, fresh quote binding, valid base64 transaction, wrong source, wrong callback state, expiry, user rejection, malformed signature/hash, and duplicate return.

- [ ] **Step 2: Submit only the validated serialized transaction**

Use Reown’s Phantom-capable session and request:

```dart
await modal.request(
  topic: modal.session!.topic,
  chainId: solanaChainId,
  request: SessionRequestParams(
    method: 'solana_signAndSendTransaction',
    params: <String, dynamic>{
      'transaction': validated.serializedTransaction,
      'pubkey': connectedAddress,
      'feePayer': connectedAddress,
    },
  ),
);
```

Pass the validated serialized transaction unchanged; validation is against the fresh response, connected key, bounded size, and expected Base destination embedded in LI.FI route metadata.

- [ ] **Step 3: Implement honest fallback**

When no compatible wallet/session method is available, expose `Open Jumper manually`. It opens `https://jumper.exchange/` and clearly states that Plawie will not prefill, submit, or monitor that manual transfer.

- [ ] **Step 4: Run tests and commit**

```powershell
flutter test test/bridge_execution_coordinator_test.dart test/external_wallet_session_service_test.dart
git add lib/services/bridge_execution_coordinator.dart lib/services/external_wallet_session_service.dart test/bridge_execution_coordinator_test.dart test/external_wallet_session_service_test.dart
git commit -m "feat: execute reviewed Solana bridge transactions"
```

## Task 6: Poll LI.FI and reconcile Base settlement

- [ ] **Step 1: Write failing status tests**

Fixture `/status` responses for `PENDING`, `DONE`, `FAILED`, `NOT_FOUND`, refunded, partial, rate limited, malformed, and network timeout. Assert exponential backoff with jitter, `Retry-After` support, bounded polling, app-resume continuation, and no rebroadcast.

- [ ] **Step 2: Implement LI.FI status requests**

Call `/status` with source chain, destination chain, source transaction hash, and tool. Follow no redirects, enforce HTTPS/JSON/size limits, map LI.FI substatuses into the app states, and persist each observation.

- [ ] **Step 3: Reconcile completion**

Declare bridge `completed` only after LI.FI terminal success. Then call `BaseService.refreshBalance()`. If balance refresh fails, keep terminal bridge success and expose `balanceRefreshPending` rather than reverting to failed.

- [ ] **Step 4: Run tests and commit**

```powershell
flutter test test/lifi_status_service_test.dart test/bridge_execution_coordinator_test.dart
git add lib/services/lifi_status_service.dart lib/services/bridge_execution_coordinator.dart test/lifi_status_service_test.dart test/bridge_execution_coordinator_test.dart
git commit -m "feat: track LI.FI settlement and Base receipt state"
```

## Task 7: Replace quote-only Base UI with the canonical execution panel

- [ ] **Step 1: Write widget tests first**

Test quote-only address entry, Connect Wallet, connected address replacement, final review fields, separate ERC-20 approval review, wallet rejection, app return, pending/resume, terminal receipt, missing Reown configuration, Robinhood unsupported, and manual fallback language.

- [ ] **Step 2: Build a state-driven bridge panel**

The Base page owns source chain/token/amount, connected wallet identity, destination Plawie address, quote, review, execution progress, receipt, retry status, and disconnect. Disable mutable inputs after review until cancel/requote.

- [ ] **Step 3: Keep chat capability read-only but truthful**

Extend `bridge.status`/`bridge.receipts`; keep `bridge.quote`. Any execute-like agent request returns `foreground_approval_required` with a route to the Base page and performs no wallet/session action.

- [ ] **Step 4: Add user documentation**

Document external-wallet custody, source gas, exact allowance, LI.FI status semantics, Phantom/MetaMask/Reown handoff, Robinhood runtime gating, manual fallback limitations, and Base destination verification.

- [ ] **Step 5: Run slice verification**

```powershell
flutter test test/bridge_quote_service_test.dart test/bridge_transaction_validator_test.dart test/external_wallet_session_service_test.dart test/bridge_execution_coordinator_test.dart test/bridge_receipt_store_test.dart test/lifi_status_service_test.dart test/base_bridge_execution_widget_test.dart test/bridge_app_native_adapter_test.dart
flutter analyze
flutter build apk --debug
git diff --check
```

Expected: all tests pass, analyzer has no new errors, APK builds, diff check is silent.

- [ ] **Step 6: Commit UI and docs**

```powershell
git add lib/screens/base_screen.dart lib/services/capabilities/ai_payments_capability.dart lib/services/app_native_chat_tool_router.dart test/base_bridge_execution_widget_test.dart test/bridge_app_native_adapter_test.dart docs/EXTERNAL_WALLET_BRIDGING.md
git commit -m "feat: add external wallet bridge execution UI"
```

## Device acceptance gate

- [ ] Install with `adb install -r`; do not clear data.
- [ ] Missing `REOWN_PROJECT_ID` disables execution and leaves quote/manual fallback usable.
- [ ] With the allowlisted release ID, connect MetaMask or another EVM wallet and confirm the source address is session-derived.
- [ ] Connect Phantom for Solana and confirm callback replay is rejected.
- [ ] On Robinhood, require both live LI.FI support and wallet chain-switch/add success.
- [ ] Use a user-selected small mainnet amount only after exact review; automated tests spend nothing.
- [ ] Observe source hash, pending status, terminal LI.FI status, destination hash, and Base balance refresh.
- [ ] Force-stop/reopen during pending status and confirm polling resumes without resubmission.
- [ ] Verify no full calldata/session topic/callback state appears in logs or persisted receipts.
- [ ] Commit acceptance documentation only; never commit APKs, credentials, callback captures, or generated build reports.
