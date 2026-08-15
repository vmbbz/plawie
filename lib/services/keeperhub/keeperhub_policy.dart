import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'keeperhub_execution_models.dart';
import 'keeperhub_models.dart';
import 'keeperhub_proof_network.dart';

class KeeperHubProofPolicy {
  static final RegExp _taskPattern = RegExp(r'^[A-Za-z0-9._:%|/-]{1,100}$');

  static Map<String, dynamic> transferBody(String agentWalletAddress) {
    final address = requireKeeperHubAddress(
      agentWalletAddress,
      'Agent Execution Wallet',
    );
    return <String, dynamic>{
      'chainId': KeeperHubProofNetwork.chainId,
      'recipientAddress': address,
      'amount': '0',
    };
  }

  static void validateProofTransfer({
    required Map<String, dynamic> transfer,
    required String expectedAgentWallet,
  }) {
    const expectedKeys = <String>{'chainId', 'recipientAddress', 'amount'};
    if (transfer.length != expectedKeys.length ||
        !transfer.keys.every(expectedKeys.contains) ||
        transfer['chainId'] is! int ||
        transfer['chainId'] != KeeperHubProofNetwork.chainId ||
        transfer['amount'] is! String ||
        transfer['amount'] != '0') {
      throw const KeeperHubException(
        'proof_transfer_invalid',
        'The stored Agent Wallet proof is not the allowlisted zero-value transfer.',
      );
    }
    final recipient = requireKeeperHubAddress(
      transfer['recipientAddress'],
      'proof recipient',
    );
    final expected = requireKeeperHubAddress(
      expectedAgentWallet,
      'Agent Execution Wallet',
    );
    if (recipient.toLowerCase() != expected.toLowerCase()) {
      throw const KeeperHubException(
        'proof_transfer_identity_mismatch',
        'The stored proof recipient is not the connected Agent Wallet.',
      );
    }
  }

  static String normalizeTaskId(String value) {
    final taskId = value.trim();
    if (!_taskPattern.hasMatch(taskId)) {
      throw const KeeperHubException(
        'task_id_invalid',
        'The Agent Wallet task ID is invalid.',
      );
    }
    return taskId;
  }

  static String normalizeReason(String value) {
    final reason = value.trim();
    if (reason.isEmpty ||
        reason.length > 240 ||
        reason.contains(RegExp(r'[\r\n]'))) {
      throw const KeeperHubException(
        'reason_invalid',
        'A short single-line reason is required.',
      );
    }
    return reason;
  }

  static KeeperHubSimulation parseSimulation({
    required Map<String, dynamic> body,
    required String expectedAgentWallet,
  }) {
    final from = requireKeeperHubAddress(body['from'], 'simulation sender');
    final to = requireKeeperHubAddress(body['to'], 'simulation recipient');
    final expected = requireKeeperHubAddress(
      expectedAgentWallet,
      'Agent Execution Wallet',
    );
    if (from.toLowerCase() != expected.toLowerCase() ||
        to.toLowerCase() != expected.toLowerCase()) {
      throw const KeeperHubException(
        'simulation_identity_mismatch',
        'KeeperHub simulated with an unexpected wallet or recipient.',
      );
    }
    final value = body['value']?.toString().trim() ?? '';
    if (value != '0') {
      throw const KeeperHubException(
        'simulation_value_mismatch',
        'KeeperHub simulation changed the zero-value proof.',
      );
    }
    final wouldRevert = body['wouldRevert'] == true;
    final gasRaw = body['gasEstimate']?.toString().trim() ?? '';
    final gas = gasRaw.isEmpty && wouldRevert ? '0' : gasRaw;
    if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(gas)) {
      throw const KeeperHubException(
        'simulation_gas_invalid',
        'KeeperHub simulation did not return a valid gas estimate.',
      );
    }
    return KeeperHubSimulation(
      success: body['success'] == true,
      from: from,
      to: to,
      valueWei: value,
      gasEstimate: gas,
      wouldRevert: wouldRevert,
      code: _bounded(body['code'], 80),
      revertReason: _bounded(body['revertReason'] ?? body['error'], 320),
    );
  }

  static String simulationFingerprint({
    required Map<String, dynamic> transfer,
    required KeeperHubSimulation simulation,
  }) {
    final bound = <String, dynamic>{
      'request': <String, dynamic>{
        'chainId': transfer['chainId'],
        'recipientAddress': transfer['recipientAddress'],
        'amount': transfer['amount'],
      },
      'simulation': <String, dynamic>{
        'success': simulation.success,
        'from': simulation.from,
        'to': simulation.to,
        'value': simulation.valueWei,
        'gasEstimate': simulation.gasEstimate,
        'wouldRevert': simulation.wouldRevert,
      },
    };
    return sha256.convert(utf8.encode(jsonEncode(bound))).toString();
  }

  static String idempotencyKey({
    required String taskId,
    required String recipientAddress,
  }) {
    final stableTask =
        normalizeTaskId(taskId).replaceAll('%', '%25').replaceAll('|', '%7C');
    final recipient = requireKeeperHubAddress(
      recipientAddress,
      'Agent Execution Wallet',
    ).toLowerCase();
    final canonical =
        '$stableTask|${KeeperHubProofNetwork.chainId}|$recipient|0|';
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static bool isLegacyTestnetTransfer(Map<String, dynamic> transfer) =>
      transfer['chainId'] == KeeperHubProofNetwork.legacyBaseSepoliaChainId;

  static String canonicalTransferJson(Map<String, dynamic> transfer) =>
      jsonEncode(<String, dynamic>{
        'chainId': transfer['chainId'],
        'recipientAddress': transfer['recipientAddress'],
        'amount': transfer['amount'],
      });

  static String? _bounded(Object? value, int maxLength) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text.length <= maxLength ? text : text.substring(0, maxLength);
  }
}
