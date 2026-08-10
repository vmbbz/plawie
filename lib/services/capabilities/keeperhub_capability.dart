import 'package:uuid/uuid.dart';

import '../../models/node_frame.dart';
import '../keeperhub/keeperhub_auth_store.dart';
import '../keeperhub/keeperhub_execution_coordinator.dart';
import '../keeperhub/keeperhub_models.dart';
import 'capability_handler.dart';

/// Bounded agent view of KeeperHub.
///
/// The model may inspect local state and prepare a zero-value testnet proposal.
/// It cannot consume the foreground approval, authenticate, submit, retry,
/// revoke credentials, or invoke KeeperHub's generic write-capable MCP tools.
class KeeperHubCapability extends CapabilityHandler {
  KeeperHubCapability({
    KeeperHubAuthStore? authStore,
    KeeperHubExecutionCoordinator? coordinator,
    DateTime Function()? clock,
    Uuid? uuid,
  })  : _authStore = authStore ?? KeeperHubAuthStore(),
        _coordinator = coordinator ?? KeeperHubExecutionCoordinator(),
        _clock = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final KeeperHubAuthStore _authStore;
  final KeeperHubExecutionCoordinator _coordinator;
  final DateTime Function() _clock;
  final Uuid _uuid;

  @override
  String get name => 'keeperhub';

  @override
  List<String> get commands => const <String>[
        'capabilities',
        'status',
        'receipts',
        'prepare',
      ];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(
    String command,
    Map<String, dynamic> params,
  ) async {
    try {
      return switch (command) {
        'keeperhub.capabilities' => NodeFrame.response(
            '',
            payload: _capabilities(),
          ),
        'keeperhub.status' => await _status(),
        'keeperhub.receipts' => await _receipts(),
        'keeperhub.prepare' => await _prepare(params),
        _ => NodeFrame.response('', error: <String, dynamic>{
            'code': 'UNKNOWN_COMMAND',
            'message': 'Unknown KeeperHub command: $command',
          }),
      };
    } on KeeperHubException catch (error) {
      return NodeFrame.response('', error: <String, dynamic>{
        'code': error.code.toUpperCase(),
        'message': error.message,
      });
    } on FormatException {
      return NodeFrame.response('', error: const <String, dynamic>{
        'code': 'KEEPERHUB_INPUT_INVALID',
        'message': 'The KeeperHub request contains invalid input.',
      });
    } catch (_) {
      return NodeFrame.response('', error: const <String, dynamic>{
        'code': 'KEEPERHUB_STATUS_ERROR',
        'message': 'KeeperHub state could not be read safely.',
      });
    }
  }

  Map<String, dynamic> _capabilities() => const <String, dynamic>{
        'mode': 'human-governed-managed-agent-wallet',
        'proofNetwork': 'Base Sepolia',
        'proofChainId': 84532,
        'proofAmount': '0 ETH',
        'custody': 'KeeperHub/Turnkey managed Agent Execution Wallet',
        'agentPermissions': <String, bool>{
          'readStatus': true,
          'readRedactedReceipts': true,
          'prepareZeroValueTestnetProof': true,
          'openApprovalUi': false,
          'approve': false,
          'authenticate': false,
          'sign': false,
          'submit': false,
          'retry': false,
          'revokeCredential': false,
          'executeGenericWorkflow': false,
          'moveMainnetValue': false,
        },
        'humanApprovalContract':
            'A prepared proof remains inert until the user opens Wallet, reviews the exact simulation, approves visibly, and completes fresh Android authentication.',
      };

  Future<NodeFrame> _status() async {
    final credential = await _authStore.read();
    final active = await _coordinator.receiptStore.active();
    return NodeFrame.response('', payload: <String, dynamic>{
      'connection': credential?.record.toAgentJson() ??
          const <String, dynamic>{
            'connected': false,
            'phase': 'notConnected',
            'mayApproveOrExecute': false,
          },
      'activeExecution': active?.toAgentJson(),
      'foregroundPage': 'Wallet > Agent Execution Wallet',
      'networkRefreshPerformed': false,
      'credentialExposed': false,
      'mayApproveOrExecute': false,
    });
  }

  Future<NodeFrame> _receipts() async {
    final receipts = await _coordinator.receiptStore.read();
    return NodeFrame.response('', payload: <String, dynamic>{
      'count': receipts.length,
      'receipts': receipts
          .take(20)
          .map((receipt) => receipt.toAgentJson())
          .toList(growable: false),
      'redacted': true,
      'containsCredential': false,
      'containsSignature': false,
      'mayApproveOrExecute': false,
    });
  }

  Future<NodeFrame> _prepare(Map<String, dynamic> params) async {
    final objective = _objective(params['objective']);
    final now = _clock().toUtc();
    final taskId = 'agent-proof:${now.microsecondsSinceEpoch}:${_uuid.v4()}';
    final record = await _coordinator.prepareProof(
      taskId: taskId,
      reason: objective,
    );
    return NodeFrame.response('', payload: <String, dynamic>{
      'proposal': record.toAgentJson(),
      'submitted': false,
      'approvalOpened': false,
      'nextHumanAction':
          'Open Wallet > Agent Execution Wallet, refresh if needed, then review or discard the zero-value testnet proof.',
      'mayApproveOrExecute': false,
    });
  }

  String _objective(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.length > 160 || text.contains(RegExp(r'[\r\n]'))) {
      return 'Prove human-governed Agent Wallet execution.';
    }
    return text;
  }

  void close() => _coordinator.close();
}
