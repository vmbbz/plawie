import 'dart:convert';

import '../preferences_service.dart';
import 'bridge_models.dart';
import 'bridge_state_machine.dart';

abstract interface class BridgeReceiptPersistence {
  String? get activeBridgeReceiptJson;

  Future<bool> setActiveBridgeReceiptJson(String? value);

  List<String> get bridgeReceipts;

  Future<bool> setBridgeReceipts(List<String> value);
}

final class BridgeReceiptStore {
  BridgeReceiptStore({
    required PreferencesService preferences,
    BridgeFundingStateMachine stateMachine = const BridgeFundingStateMachine(),
  })  : _persistence = _PreferencesBridgeReceiptPersistence(preferences),
        _stateMachine = stateMachine;

  BridgeReceiptStore.withPersistence(
    BridgeReceiptPersistence persistence, {
    BridgeFundingStateMachine stateMachine = const BridgeFundingStateMachine(),
  })  : _persistence = persistence,
        _stateMachine = stateMachine;

  static const int _terminalReceiptLimit = 50;
  static const Set<BridgeFundingState> _terminalStates = <BridgeFundingState>{
    BridgeFundingState.completed,
    BridgeFundingState.failed,
    BridgeFundingState.refunded,
    BridgeFundingState.partial,
    BridgeFundingState.expired,
    BridgeFundingState.cancelled,
  };

  final BridgeReceiptPersistence _persistence;
  final BridgeFundingStateMachine _stateMachine;

  List<BridgeFundingReceipt> get receipts =>
      List<BridgeFundingReceipt>.unmodifiable(_decodeReceiptList());

  BridgeFundingReceipt? get activeReceipt {
    final stored = _decodeReceiptList();
    final active = stored.where(_isActive).toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    if (active.isNotEmpty) return active.first;

    final pointer = _decodeReceipt(_persistence.activeBridgeReceiptJson);
    if (pointer == null || !_isActive(pointer)) return null;
    if (stored.any((receipt) => receipt.intentId == pointer.intentId)) {
      return null;
    }
    return pointer;
  }

  BridgeFundingReceipt? receiptForIntent(String intentId) {
    for (final receipt in _decodeReceiptList()) {
      if (receipt.intentId == intentId) return receipt;
    }
    final pointer = _decodeReceipt(_persistence.activeBridgeReceiptJson);
    return pointer?.intentId == intentId ? pointer : null;
  }

  Future<void> upsert(
    BridgeFundingReceipt receipt, {
    SolanaNoSubmissionEvidence? evidence,
  }) async {
    receipt.toJson();
    _validateReceiptPolicy(receipt);

    final records = _recordsForUpdate();
    BridgeFundingReceipt? existing;
    for (final candidate in records) {
      if (candidate.intentId == receipt.intentId) {
        existing = candidate;
        break;
      }
    }
    if (existing == null) {
      if (evidence != null) {
        throw const BridgeValidationException(
          'unexpected_transition_evidence',
          'Transition evidence cannot create a new receipt.',
        );
      }
    } else {
      _validateUpdate(existing, receipt, evidence: evidence);
    }

    final next = <BridgeFundingReceipt>[
      for (final candidate in records)
        if (candidate.intentId != receipt.intentId) candidate,
      receipt,
    ];
    final active = next.where(_isActive).toList();
    if (active.length > 1) {
      throw const BridgeValidationException(
        'active_bridge_receipt_exists',
        'Another non-archived bridge funding receipt is still active.',
      );
    }

    final bounded = _capTerminalHistory(next);
    final encodedReceipts = <String>[
      for (final candidate in bounded) jsonEncode(candidate.toJson()),
    ];
    await _writeReceiptList(encodedReceipts);

    final activeJson =
        active.isEmpty ? null : jsonEncode(active.single.toJson());
    await _writeActiveReceipt(activeJson);
  }

  void _validateReceiptPolicy(BridgeFundingReceipt receipt) {
    if (receipt.depositAddressExposed &&
        receipt.state == BridgeFundingState.cancelled) {
      throw const BridgeValidationException(
        'exposed_deposit_cannot_cancel',
        'An exposed Relay deposit instruction cannot be cancelled.',
      );
    }
    if (receipt.submissionOutcomeUnknown && receipt.archivedAt != null) {
      throw const BridgeValidationException(
        'unknown_submission_cannot_archive',
        'An outcome-unknown wallet submission must remain active.',
      );
    }
    if (receipt.submissionOutcomeUnknown &&
        (receipt.state == BridgeFundingState.cancelled ||
            receipt.state == BridgeFundingState.failed)) {
      throw const BridgeValidationException(
        'unknown_submission_cannot_terminate',
        'An outcome-unknown wallet submission cannot be cancelled or failed.',
      );
    }
  }

  void _validateUpdate(
    BridgeFundingReceipt existing,
    BridgeFundingReceipt replacement, {
    required SolanaNoSubmissionEvidence? evidence,
  }) {
    if (existing.archivedAt != null && replacement.archivedAt == null) {
      throw const BridgeValidationException(
        'archival_is_permanent',
        'An archived bridge receipt cannot be made active again.',
      );
    }
    if (existing.depositAddressExposed &&
        replacement.state == BridgeFundingState.cancelled) {
      throw const BridgeValidationException(
        'exposed_deposit_cannot_cancel',
        'An exposed Relay deposit instruction cannot be cancelled.',
      );
    }
    if (existing.submissionOutcomeUnknown &&
        existing.archivedAt == null &&
        replacement.archivedAt != null) {
      throw const BridgeValidationException(
        'unknown_submission_cannot_archive',
        'An outcome-unknown wallet submission must remain active.',
      );
    }
    if (existing.submissionOutcomeUnknown &&
        existing.state == replacement.state &&
        !replacement.submissionOutcomeUnknown) {
      throw const BridgeValidationException(
        'unknown_submission_cannot_be_cleared',
        'Submission ambiguity can be cleared only by reconciliation.',
      );
    }
    if (existing.submissionOutcomeUnknown &&
        replacement.state == BridgeFundingState.awaitingPlawieReview) {
      throw const BridgeValidationException(
        'unknown_submission_cannot_return_to_review',
        'An outcome-unknown wallet submission cannot return to review.',
      );
    }

    if (existing.state == replacement.state) {
      if (evidence != null) {
        throw const BridgeValidationException(
          'unexpected_transition_evidence',
          'Transition evidence is valid only for an evidenced state change.',
        );
      }
      return;
    }

    try {
      if (evidence == null) {
        _stateMachine.requireMove(existing.state, replacement.state);
      } else {
        _stateMachine.requireMoveWithEvidence(
          existing.state,
          replacement.state,
          evidence: evidence,
        );
      }
    } on StateError catch (error) {
      throw BridgeValidationException(
        'illegal_bridge_transition',
        error.message.toString(),
      );
    }
  }

  List<BridgeFundingReceipt> _recordsForUpdate() {
    final records = _decodeReceiptList();
    if (records.any(_isActive)) return records;

    final pointer = _decodeReceipt(_persistence.activeBridgeReceiptJson);
    if (pointer != null &&
        _isActive(pointer) &&
        !records.any((receipt) => receipt.intentId == pointer.intentId)) {
      records.add(pointer);
    }
    return records;
  }

  List<BridgeFundingReceipt> _decodeReceiptList() {
    final byIntentId = <String, BridgeFundingReceipt>{};
    for (final raw in _persistence.bridgeReceipts) {
      final receipt = _decodeReceipt(raw);
      if (receipt == null) continue;
      final existing = byIntentId[receipt.intentId];
      if (existing == null || !receipt.updatedAt.isBefore(existing.updatedAt)) {
        byIntentId[receipt.intentId] = receipt;
      }
    }
    return byIntentId.values.toList();
  }

  BridgeFundingReceipt? _decodeReceipt(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return BridgeFundingReceipt.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on FormatException {
      return null;
    } on BridgeValidationException {
      return null;
    } on TypeError {
      return null;
    }
  }

  List<BridgeFundingReceipt> _capTerminalHistory(
    List<BridgeFundingReceipt> receipts,
  ) {
    final nonTerminal =
        receipts.where((receipt) => !_isTerminal(receipt.state));
    final terminal = receipts
        .where((receipt) => _isTerminal(receipt.state))
        .toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return <BridgeFundingReceipt>[
      ...nonTerminal,
      ...terminal.take(_terminalReceiptLimit),
    ];
  }

  Future<void> _writeReceiptList(List<String> receipts) async {
    try {
      final succeeded = await _persistence.setBridgeReceipts(receipts);
      if (!succeeded) {
        throw const BridgePersistenceException(
          'Could not persist the bridge receipt list.',
        );
      }
    } on BridgePersistenceException {
      rethrow;
    } catch (error) {
      throw BridgePersistenceException(
        'Could not persist the bridge receipt list: $error',
      );
    }
  }

  Future<void> _writeActiveReceipt(String? receiptJson) async {
    try {
      final succeeded =
          await _persistence.setActiveBridgeReceiptJson(receiptJson);
      if (!succeeded) {
        throw const BridgePersistenceException(
          'Could not persist the active bridge receipt.',
        );
      }
    } on BridgePersistenceException {
      rethrow;
    } catch (error) {
      throw BridgePersistenceException(
        'Could not persist the active bridge receipt: $error',
      );
    }
  }

  bool _isActive(BridgeFundingReceipt receipt) =>
      receipt.archivedAt == null && !_isTerminal(receipt.state);

  bool _isTerminal(BridgeFundingState state) => _terminalStates.contains(state);
}

final class _PreferencesBridgeReceiptPersistence
    implements BridgeReceiptPersistence {
  const _PreferencesBridgeReceiptPersistence(this._preferences);

  final PreferencesService _preferences;

  @override
  String? get activeBridgeReceiptJson => _preferences.activeBridgeReceiptJson;

  @override
  List<String> get bridgeReceipts => _preferences.bridgeReceipts;

  @override
  Future<bool> setActiveBridgeReceiptJson(String? value) =>
      _preferences.setActiveBridgeReceiptJson(value);

  @override
  Future<bool> setBridgeReceipts(List<String> value) =>
      _preferences.setBridgeReceipts(value);
}
