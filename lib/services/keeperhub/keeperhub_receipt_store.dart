import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'keeperhub_execution_models.dart';
import 'keeperhub_models.dart';

abstract interface class KeeperHubReceiptPersistence {
  Future<List<String>> readReceipts();

  Future<bool> writeReceipts(List<String> receipts);
}

class SharedPreferencesKeeperHubReceiptPersistence
    implements KeeperHubReceiptPersistence {
  static const _storageKey = 'keeperhub_execution_receipts_v1';

  @override
  Future<List<String>> readReceipts() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_storageKey) ?? const <String>[];
  }

  @override
  Future<bool> writeReceipts(List<String> receipts) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.setStringList(_storageKey, receipts);
  }
}

class KeeperHubReceiptStore {
  KeeperHubReceiptStore({KeeperHubReceiptPersistence? persistence})
      : _persistence =
            persistence ?? SharedPreferencesKeeperHubReceiptPersistence();

  static const maxReceipts = 50;
  final KeeperHubReceiptPersistence _persistence;

  Future<List<KeeperHubExecutionRecord>> read() async {
    final decoded = <KeeperHubExecutionRecord>[];
    for (final raw in await _persistence.readReceipts()) {
      try {
        final value = jsonDecode(raw);
        if (value is Map) {
          decoded.add(
            KeeperHubExecutionRecord.fromJson(
              Map<String, dynamic>.from(value),
            ),
          );
        }
      } catch (_) {
        // Ignore each corrupt/old redacted receipt independently.
      }
    }
    decoded.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return decoded.take(maxReceipts).toList(growable: false);
  }

  Future<KeeperHubExecutionRecord?> forIntent(String intentId) async {
    for (final record in await read()) {
      if (record.intentId == intentId) return record;
    }
    return null;
  }

  Future<KeeperHubExecutionRecord?> active() async {
    final active =
        (await read()).where((record) => !record.isTerminal).toList();
    if (active.length > 1) {
      throw const KeeperHubException(
        'multiple_active_executions',
        'More than one Agent Wallet execution requires recovery.',
      );
    }
    return active.firstOrNull;
  }

  Future<void> upsert(KeeperHubExecutionRecord record) async {
    final current = await read();
    final previous = current
        .where((candidate) => candidate.intentId == record.intentId)
        .firstOrNull;
    if (previous == null) {
      if (current.any((candidate) => !candidate.isTerminal)) {
        throw const KeeperHubException(
          'execution_already_active',
          'Another Agent Wallet execution must finish or recover first.',
        );
      }
    } else {
      _validateImmutable(previous, record);
      _validateTransition(previous.phase, record.phase);
    }
    final next = <KeeperHubExecutionRecord>[
      record,
      ...current.where((candidate) => candidate.intentId != record.intentId),
    ];
    final encoded = next
        .take(maxReceipts)
        .map((candidate) => jsonEncode(candidate.toJson()))
        .toList(growable: false);
    if (!await _persistence.writeReceipts(encoded)) {
      throw const KeeperHubException(
        'receipt_write_failed',
        'The Agent Wallet execution receipt could not be persisted.',
      );
    }
  }

  void _validateImmutable(
    KeeperHubExecutionRecord previous,
    KeeperHubExecutionRecord next,
  ) {
    final unchanged = previous.taskId == next.taskId &&
        previous.personalWalletAddress.toLowerCase() ==
            next.personalWalletAddress.toLowerCase() &&
        previous.agentWalletAddress.toLowerCase() ==
            next.agentWalletAddress.toLowerCase() &&
        previous.reason == next.reason &&
        jsonEncode(previous.transfer) == jsonEncode(next.transfer) &&
        previous.createdAt == next.createdAt &&
        (previous.simulationFingerprint == null ||
            previous.simulationFingerprint == next.simulationFingerprint) &&
        (previous.idempotencyKey == null ||
            previous.idempotencyKey == next.idempotencyKey) &&
        (previous.attestationDigest == null ||
            previous.attestationDigest == next.attestationDigest) &&
        (previous.executionId == null ||
            previous.executionId == next.executionId);
    if (!unchanged) {
      throw const KeeperHubException(
        'execution_record_mutated',
        'A bound Agent Wallet execution field changed after review.',
      );
    }
  }

  void _validateTransition(
    KeeperHubExecutionPhase from,
    KeeperHubExecutionPhase to,
  ) {
    if (from == to) return;
    final allowed = <KeeperHubExecutionPhase, Set<KeeperHubExecutionPhase>>{
      KeeperHubExecutionPhase.proposed: <KeeperHubExecutionPhase>{
        KeeperHubExecutionPhase.awaitingApproval,
        KeeperHubExecutionPhase.simulationFailed,
        KeeperHubExecutionPhase.rejected,
      },
      KeeperHubExecutionPhase.awaitingApproval: <KeeperHubExecutionPhase>{
        KeeperHubExecutionPhase.approved,
        KeeperHubExecutionPhase.rejected,
      },
      KeeperHubExecutionPhase.approved: <KeeperHubExecutionPhase>{
        KeeperHubExecutionPhase.submitting,
      },
      KeeperHubExecutionPhase.submitting: <KeeperHubExecutionPhase>{
        KeeperHubExecutionPhase.polling,
        KeeperHubExecutionPhase.outcomeUnknown,
        KeeperHubExecutionPhase.failed,
      },
      KeeperHubExecutionPhase.outcomeUnknown: <KeeperHubExecutionPhase>{
        KeeperHubExecutionPhase.submitting,
        KeeperHubExecutionPhase.polling,
        KeeperHubExecutionPhase.completed,
        KeeperHubExecutionPhase.failed,
      },
      KeeperHubExecutionPhase.polling: <KeeperHubExecutionPhase>{
        KeeperHubExecutionPhase.polling,
        KeeperHubExecutionPhase.outcomeUnknown,
        KeeperHubExecutionPhase.completed,
        KeeperHubExecutionPhase.failed,
      },
    };
    if (!(allowed[from]?.contains(to) ?? false)) {
      throw KeeperHubException(
        'execution_transition_invalid',
        'Agent Wallet execution cannot move from ${from.name} to ${to.name}.',
      );
    }
  }
}
