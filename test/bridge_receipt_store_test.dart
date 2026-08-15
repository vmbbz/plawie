import 'dart:convert';

import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/bridge_receipt_store.dart';
import 'package:clawa/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesService preferences;
  late BridgeReceiptStore store;
  final createdAt = DateTime.utc(2026, 8, 7, 10);

  BridgeFundingReceipt receipt({
    String intentId = 'intent-1',
    BridgeFundingMethod method = BridgeFundingMethod.connectedWallet,
    BridgeFundingState state = BridgeFundingState.draft,
    DateTime? updatedAt,
    DateTime? expiresAt,
    DateTime? archivedAt,
    bool depositAddressExposed = false,
    bool submissionOutcomeUnknown = false,
    ExternalWalletTransport? walletTransport,
  }) {
    final relay = method == BridgeFundingMethod.relayDeposit;
    return BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: intentId,
      method: method,
      provider: relay ? 'relay' : 'lifi',
      state: state,
      sourceChainId: BridgeConstants.ethereumChainId,
      sourceTokenAddress: '0x3333333333333333333333333333333333333333',
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1000000',
      baseDestinationAddress: '0x2222222222222222222222222222222222222222',
      sourceAddress:
          relay ? null : '0x1111111111111111111111111111111111111111',
      refundAddress:
          relay ? '0x4444444444444444444444444444444444444444' : null,
      depositAddress:
          relay ? '0x5555555555555555555555555555555555555555' : null,
      providerQuoteId: relay ? null : 'quote-$intentId',
      providerRequestId: relay ? 'request-$intentId' : null,
      minimumOutputUnits: '990000',
      walletTransport: walletTransport,
      reviewedPayloadHash: relay
          ? null
          : 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
      expiresAt: expiresAt,
      archivedAt: archivedAt,
      depositAddressExposed: depositAddressExposed,
      submissionOutcomeUnknown: submissionOutcomeUnknown,
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = PreferencesService();
    await preferences.init();
  });

  setUp(() async {
    await preferences.setBridgeCapabilitySnapshotJson(null);
    await preferences.setActiveBridgeReceiptJson(null);
    await preferences.setBridgeReceipts(const <String>[]);
    store = BridgeReceiptStore(preferences: preferences);
  });

  test('bridge preference accessors preserve values and clear nullable keys',
      () async {
    expect(
        await preferences.setBridgeCapabilitySnapshotJson('{"v":1}'), isTrue);
    expect(preferences.bridgeCapabilitySnapshotJson, '{"v":1}');
    expect(await preferences.setBridgeCapabilitySnapshotJson(null), isTrue);
    expect(preferences.bridgeCapabilitySnapshotJson, isNull);

    expect(await preferences.setActiveBridgeReceiptJson('{"active":true}'),
        isTrue);
    expect(preferences.activeBridgeReceiptJson, '{"active":true}');
    expect(await preferences.setActiveBridgeReceiptJson(null), isTrue);
    expect(preferences.activeBridgeReceiptJson, isNull);
  });

  test('enforces one active non-archived receipt', () async {
    final first = receipt();
    final second = receipt(intentId: 'intent-2');

    await store.upsert(first);

    expect(store.activeReceipt, first);
    await expectLater(
      store.upsert(second),
      throwsA(isA<BridgeValidationException>()),
    );
    expect(store.receipts, <BridgeFundingReceipt>[first]);
    expect(store.activeReceipt, first);
  });

  test('schema-v1 receipt does not invent a wallet identity', () async {
    final legacyJson = receipt(
      state: BridgeFundingState.awaitingExternalWallet,
      walletTransport: ExternalWalletTransport.reownEvm,
    ).toJson()
      ..['schemaVersion'] = 1
      ..remove('walletTransport')
      ..remove('reviewedPayloadHash');
    final encoded = jsonEncode(legacyJson);
    await preferences.setBridgeReceipts(<String>[encoded]);
    await preferences.setActiveBridgeReceiptJson(encoded);

    final migrated = store.activeReceipt;

    expect(migrated, isNotNull);
    expect(migrated!.schemaVersion, 1);
    expect(migrated.walletTransport, isNull);
  });

  test('exposed Relay instruction cannot become cancelled', () async {
    final exposed = receipt(
      method: BridgeFundingMethod.relayDeposit,
      state: BridgeFundingState.awaitingDeposit,
      depositAddressExposed: true,
    );
    await store.upsert(exposed);

    await expectLater(
      store.upsert(receipt(
        method: BridgeFundingMethod.relayDeposit,
        state: BridgeFundingState.cancelled,
        depositAddressExposed: true,
      )),
      throwsA(isA<BridgeValidationException>()),
    );
    expect(store.activeReceipt, exposed);
  });

  test('outcome-unknown wallet receipt cannot cancel archive or replace',
      () async {
    final unknown = receipt(
      state: BridgeFundingState.awaitingExternalWallet,
      expiresAt: createdAt.subtract(const Duration(minutes: 1)),
      submissionOutcomeUnknown: true,
      walletTransport: ExternalWalletTransport.reownEvm,
    );
    await store.upsert(unknown);

    await expectLater(
      store.upsert(receipt(
        state: BridgeFundingState.cancelled,
        expiresAt: unknown.expiresAt,
        submissionOutcomeUnknown: true,
        walletTransport: ExternalWalletTransport.reownEvm,
      )),
      throwsA(isA<BridgeValidationException>()),
    );
    await expectLater(
      store.upsert(receipt(
        state: BridgeFundingState.failed,
        expiresAt: unknown.expiresAt,
        submissionOutcomeUnknown: true,
        walletTransport: ExternalWalletTransport.reownEvm,
      )),
      throwsA(isA<BridgeValidationException>()),
    );
    await expectLater(
      store.upsert(receipt(
        state: BridgeFundingState.awaitingExternalWallet,
        expiresAt: unknown.expiresAt,
        archivedAt: createdAt.add(const Duration(minutes: 1)),
        submissionOutcomeUnknown: true,
        walletTransport: ExternalWalletTransport.reownEvm,
      )),
      throwsA(isA<BridgeValidationException>()),
    );
    await expectLater(
      store.upsert(receipt(
        intentId: 'replacement',
        state: BridgeFundingState.draft,
      )),
      throwsA(isA<BridgeValidationException>()),
    );
    expect(store.activeReceipt, unknown);
  });

  test('outcome-unknown receipt cannot clear ambiguity in place', () async {
    final unknown = receipt(
      state: BridgeFundingState.awaitingExternalWallet,
      submissionOutcomeUnknown: true,
      walletTransport: ExternalWalletTransport.reownEvm,
    );
    await store.upsert(unknown);

    await expectLater(
      store.upsert(receipt(
        state: BridgeFundingState.awaitingExternalWallet,
        submissionOutcomeUnknown: false,
        walletTransport: ExternalWalletTransport.reownEvm,
      )),
      throwsA(isA<BridgeValidationException>()),
    );
  });

  test('outcome-unknown receipt cannot return to review', () async {
    final unknown = receipt(
      state: BridgeFundingState.awaitingExternalWallet,
      submissionOutcomeUnknown: true,
      walletTransport: ExternalWalletTransport.reownEvm,
    );
    await store.upsert(unknown);

    await expectLater(
      store.upsert(receipt(
        state: BridgeFundingState.awaitingPlawieReview,
        submissionOutcomeUnknown: false,
        walletTransport: ExternalWalletTransport.reownEvm,
      )),
      throwsA(isA<BridgeValidationException>()),
    );
  });

  test('archived non-terminal receipt remains readable and trackable',
      () async {
    final pending = receipt(
      method: BridgeFundingMethod.relayDeposit,
      state: BridgeFundingState.awaitingDeposit,
      depositAddressExposed: true,
    );
    final archivedAt = createdAt.add(const Duration(minutes: 1));
    await store.upsert(pending);
    await store.upsert(receipt(
      method: BridgeFundingMethod.relayDeposit,
      state: BridgeFundingState.awaitingDeposit,
      updatedAt: archivedAt,
      archivedAt: archivedAt,
      depositAddressExposed: true,
    ));

    expect(store.activeReceipt, isNull);
    expect(store.receiptForIntent('intent-1')!.archivedAt, archivedAt);

    final observedAt = createdAt.add(const Duration(minutes: 2));
    await store.upsert(receipt(
      method: BridgeFundingMethod.relayDeposit,
      state: BridgeFundingState.depositDetected,
      updatedAt: observedAt,
      archivedAt: archivedAt,
      depositAddressExposed: true,
    ));

    expect(store.receiptForIntent('intent-1')!.state,
        BridgeFundingState.depositDetected);
    expect(store.activeReceipt, isNull);

    final replacement = receipt(intentId: 'intent-2');
    await store.upsert(replacement);
    expect(store.activeReceipt, replacement);
  });

  test('corrupt records are skipped individually and quarantined on write',
      () async {
    final valid = receipt();
    final validEncoded = jsonEncode(valid.toJson());
    await preferences.setBridgeReceipts(<String>[
      validEncoded,
      '{not-json',
      jsonEncode(<String, Object>{'schemaVersion': 'invalid'}),
    ]);
    await preferences.setActiveBridgeReceiptJson('{also-not-json');

    expect(store.receipts, <BridgeFundingReceipt>[valid]);
    expect(store.activeReceipt, valid);

    final updated = receipt(
      state: BridgeFundingState.checkingCapabilities,
      updatedAt: createdAt.add(const Duration(minutes: 1)),
    );
    await store.upsert(updated);

    expect(store.receipts, <BridgeFundingReceipt>[updated]);
    expect(preferences.bridgeReceipts, hasLength(1));
    expect(
      BridgeFundingReceipt.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(preferences.bridgeReceipts.single) as Map,
        ),
      ),
      updated,
    );
  });

  test('terminal receipt history is capped at the newest 50', () async {
    for (var index = 0; index < 55; index += 1) {
      await store.upsert(receipt(
        intentId: 'terminal-$index',
        state: BridgeFundingState.completed,
        updatedAt: createdAt.add(Duration(minutes: index)),
      ));
    }

    final receipts = store.receipts;
    expect(receipts, hasLength(50));
    expect(receipts.map((item) => item.intentId), contains('terminal-54'));
    expect(
        receipts.map((item) => item.intentId), isNot(contains('terminal-4')));
  });

  test('upsert replaces by intentId and never duplicates', () async {
    await store.upsert(receipt());
    final updated = receipt(
      state: BridgeFundingState.checkingCapabilities,
      updatedAt: createdAt.add(const Duration(minutes: 1)),
    );

    await store.upsert(updated);

    expect(
      store.receipts.where((item) => item.intentId == 'intent-1'),
      <BridgeFundingReceipt>[updated],
    );
    expect(store.activeReceipt, updated);
  });

  test('receipt list is written before the active receipt', () async {
    final persistence = _RecordingBridgeReceiptPersistence();
    final orderedStore = BridgeReceiptStore.withPersistence(persistence);

    await orderedStore.upsert(receipt());

    expect(persistence.operations, <String>['list', 'active']);
    expect(persistence.receiptStrings, hasLength(1));
    expect(persistence.activeJson, isNotNull);
  });

  test('list write failure throws before active receipt write', () async {
    final persistence = _RecordingBridgeReceiptPersistence(
      listWriteSucceeds: false,
    );
    final failingStore = BridgeReceiptStore.withPersistence(persistence);

    await expectLater(
      failingStore.upsert(receipt()),
      throwsA(isA<BridgePersistenceException>()),
    );
    expect(persistence.operations, <String>['list']);
    expect(persistence.activeJson, isNull);
  });

  test('active receipt write failure is surfaced after durable list write',
      () async {
    final persistence = _RecordingBridgeReceiptPersistence(
      activeWriteSucceeds: false,
    );
    final failingStore = BridgeReceiptStore.withPersistence(persistence);

    await expectLater(
      failingStore.upsert(receipt()),
      throwsA(isA<BridgePersistenceException>()),
    );
    expect(persistence.operations, <String>['list', 'active']);
    expect(persistence.receiptStrings, hasLength(1));
  });
}

final class _RecordingBridgeReceiptPersistence
    implements BridgeReceiptPersistence {
  _RecordingBridgeReceiptPersistence({
    this.listWriteSucceeds = true,
    this.activeWriteSucceeds = true,
  });

  final bool listWriteSucceeds;
  final bool activeWriteSucceeds;
  final List<String> operations = <String>[];
  List<String> receiptStrings = <String>[];
  String? activeJson;

  @override
  String? get activeBridgeReceiptJson => activeJson;

  @override
  List<String> get bridgeReceipts => receiptStrings;

  @override
  Future<bool> setActiveBridgeReceiptJson(String? value) async {
    operations.add('active');
    if (!activeWriteSucceeds) return false;
    activeJson = value;
    return true;
  }

  @override
  Future<bool> setBridgeReceipts(List<String> value) async {
    operations.add('list');
    if (!listWriteSucceeds) return false;
    receiptStrings = List<String>.of(value);
    return true;
  }
}
