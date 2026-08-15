import 'package:uuid/uuid.dart';

import 'keeperhub_execution_coordinator.dart';
import 'keeperhub_execution_models.dart';
import 'keeperhub_headless_onboarding_service.dart';
import 'keeperhub_models.dart';

class KeeperHubWalletSnapshot {
  const KeeperHubWalletSnapshot({
    required this.connection,
    required this.activeExecution,
    required this.receipts,
  });

  final KeeperHubConnectionRecord? connection;
  final KeeperHubExecutionRecord? activeExecution;
  final List<KeeperHubExecutionRecord> receipts;
}

abstract interface class KeeperHubWalletController {
  Future<KeeperHubWalletSnapshot> load();

  Future<KeeperHubWalletSnapshot> connect({
    required String personalWalletAddress,
    void Function(KeeperHubOnboardingProgress progress)? onProgress,
  });

  Future<KeeperHubWalletSnapshot> prepareProof();

  Future<KeeperHubWalletSnapshot> reviewAndExecute(String intentId);

  Future<KeeperHubWalletSnapshot> resumeActive();

  Future<KeeperHubWalletSnapshot> discardPrepared(String intentId);

  Future<KeeperHubWalletSnapshot> revoke({
    void Function(KeeperHubOnboardingProgress progress)? onProgress,
  });

  void close();
}

class DefaultKeeperHubWalletController implements KeeperHubWalletController {
  DefaultKeeperHubWalletController({
    KeeperHubHeadlessOnboardingService? onboarding,
    KeeperHubExecutionCoordinator? coordinator,
    DateTime Function()? clock,
    Uuid? uuid,
  })  : _onboarding = onboarding ?? KeeperHubHeadlessOnboardingService(),
        _coordinator = coordinator ?? KeeperHubExecutionCoordinator(),
        _clock = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final KeeperHubHeadlessOnboardingService _onboarding;
  final KeeperHubExecutionCoordinator _coordinator;
  final DateTime Function() _clock;
  final Uuid _uuid;

  @override
  Future<KeeperHubWalletSnapshot> load() async {
    final connection = await _onboarding.readConnection();
    final receipts = await _coordinator.receiptStore.read();
    final active = receipts.where((record) => !record.isTerminal).toList();
    if (active.length > 1) {
      throw const KeeperHubException(
        'multiple_active_executions',
        'More than one Agent Wallet execution requires recovery.',
      );
    }
    return KeeperHubWalletSnapshot(
      connection: connection,
      activeExecution: active.firstOrNull,
      receipts: List<KeeperHubExecutionRecord>.unmodifiable(receipts),
    );
  }

  @override
  Future<KeeperHubWalletSnapshot> connect({
    required String personalWalletAddress,
    void Function(KeeperHubOnboardingProgress progress)? onProgress,
  }) async {
    await _onboarding.connect(
      personalWalletAddress: personalWalletAddress,
      onProgress: onProgress,
    );
    return load();
  }

  @override
  Future<KeeperHubWalletSnapshot> prepareProof() async {
    final now = _clock().toUtc();
    final taskId = 'mobile-proof:${now.microsecondsSinceEpoch}:${_uuid.v4()}';
    await _coordinator.prepareProof(
      taskId: taskId,
      reason: 'Prove human-governed Agent Wallet execution.',
    );
    return load();
  }

  @override
  Future<KeeperHubWalletSnapshot> reviewAndExecute(String intentId) async {
    await _coordinator.reviewAndExecute(intentId);
    return load();
  }

  @override
  Future<KeeperHubWalletSnapshot> resumeActive() async {
    await _coordinator.resumeActive();
    return load();
  }

  @override
  Future<KeeperHubWalletSnapshot> discardPrepared(String intentId) async {
    await _coordinator.discardPrepared(intentId);
    return load();
  }

  @override
  Future<KeeperHubWalletSnapshot> revoke({
    void Function(KeeperHubOnboardingProgress progress)? onProgress,
  }) async {
    if (await _coordinator.receiptStore.active() != null) {
      throw const KeeperHubException(
        'execution_active',
        'Finish, reconcile, or discard the active proof before revoking access.',
      );
    }
    await _onboarding.revoke(onProgress: onProgress);
    return load();
  }

  @override
  void close() {
    _onboarding.close();
    _coordinator.close();
  }
}
