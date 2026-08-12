import 'keeperhub_models.dart';
import 'keeperhub_proof_network.dart';

enum KeeperHubExecutionPhase {
  proposed,
  awaitingApproval,
  approved,
  submitting,
  polling,
  outcomeUnknown,
  simulationFailed,
  rejected,
  completed,
  failed,
}

class KeeperHubSimulation {
  const KeeperHubSimulation({
    required this.success,
    required this.from,
    required this.to,
    required this.valueWei,
    required this.gasEstimate,
    required this.wouldRevert,
    this.code,
    this.revertReason,
  });

  final bool success;
  final String from;
  final String to;
  final String valueWei;
  final String gasEstimate;
  final bool wouldRevert;
  final String? code;
  final String? revertReason;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'success': success,
        'from': from,
        'to': to,
        'valueWei': valueWei,
        'gasEstimate': gasEstimate,
        'wouldRevert': wouldRevert,
        'code': code,
        'revertReason': revertReason,
      };

  factory KeeperHubSimulation.fromJson(Map<String, dynamic> json) =>
      KeeperHubSimulation(
        success: json['success'] == true,
        from: requireKeeperHubAddress(json['from'], 'simulation sender'),
        to: requireKeeperHubAddress(json['to'], 'simulation recipient'),
        valueWei: _decimal(json['valueWei'], 'simulation value'),
        gasEstimate: _decimal(
          json['gasEstimate'],
          'simulation gas estimate',
        ),
        wouldRevert: json['wouldRevert'] == true,
        code: _optionalText(json['code'], 80),
        revertReason: _optionalText(json['revertReason'], 320),
      );
}

class KeeperHubVerifiedReceipt {
  const KeeperHubVerifiedReceipt({
    required this.hash,
    required this.chainId,
    required this.verified,
    required this.receiptStatus,
    this.blockNumber,
    this.gasUsed,
    this.verifiedAt,
  });

  final String hash;
  final int chainId;
  final bool verified;
  final String receiptStatus;
  final int? blockNumber;
  final String? gasUsed;
  final DateTime? verifiedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hash': hash,
        'chainId': chainId,
        'verified': verified,
        'receiptStatus': receiptStatus,
        'blockNumber': blockNumber,
        'gasUsed': gasUsed,
        'verifiedAt': verifiedAt?.toUtc().toIso8601String(),
      };

  factory KeeperHubVerifiedReceipt.fromJson(Map<String, dynamic> json) {
    final hash = json['hash']?.toString().trim() ?? '';
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(hash)) {
      throw const FormatException('KeeperHub transaction hash is invalid.');
    }
    final chainId = int.tryParse(json['chainId']?.toString() ?? '');
    if (chainId == null || chainId <= 0) {
      throw const FormatException('KeeperHub receipt chain is invalid.');
    }
    final status = _requiredText(json['receiptStatus'], 'receipt status', 40);
    if (!const <String>{'success', 'reverted', 'not_found', 'timeout'}
        .contains(status)) {
      throw const FormatException('KeeperHub receipt status is invalid.');
    }
    return KeeperHubVerifiedReceipt(
      hash: hash,
      chainId: chainId,
      verified: json['verified'] == true,
      receiptStatus: status,
      blockNumber: int.tryParse(json['blockNumber']?.toString() ?? ''),
      gasUsed: json['gasUsed'] == null
          ? null
          : _decimal(json['gasUsed'], 'receipt gas used'),
      verifiedAt:
          DateTime.tryParse(json['verifiedAt']?.toString() ?? '')?.toUtc(),
    );
  }
}

class KeeperHubExecutionRecord {
  const KeeperHubExecutionRecord({
    required this.intentId,
    required this.taskId,
    required this.phase,
    required this.personalWalletAddress,
    required this.agentWalletAddress,
    required this.reason,
    required this.transfer,
    required this.createdAt,
    required this.updatedAt,
    this.simulation,
    this.simulationFingerprint,
    this.idempotencyKey,
    this.approvalExpiresAt,
    this.attestationDigest,
    this.executionId,
    this.remoteStatus,
    this.sponsored,
    this.transactionHash,
    this.transactionLink,
    this.receipts = const <KeeperHubVerifiedReceipt>[],
    this.idempotentReplay = false,
    this.errorCode,
    this.errorMessage,
  });

  final String intentId;
  final String taskId;
  final KeeperHubExecutionPhase phase;
  final String personalWalletAddress;
  final String agentWalletAddress;
  final String reason;
  final Map<String, dynamic> transfer;
  final KeeperHubSimulation? simulation;
  final String? simulationFingerprint;
  final String? idempotencyKey;
  final DateTime? approvalExpiresAt;
  final String? attestationDigest;
  final String? executionId;
  final String? remoteStatus;
  final bool? sponsored;
  final String? transactionHash;
  final String? transactionLink;
  final List<KeeperHubVerifiedReceipt> receipts;
  final bool idempotentReplay;
  final String? errorCode;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isTerminal => const <KeeperHubExecutionPhase>{
        KeeperHubExecutionPhase.simulationFailed,
        KeeperHubExecutionPhase.rejected,
        KeeperHubExecutionPhase.completed,
        KeeperHubExecutionPhase.failed,
      }.contains(phase);

  KeeperHubExecutionRecord copyWith({
    KeeperHubExecutionPhase? phase,
    KeeperHubSimulation? simulation,
    String? simulationFingerprint,
    String? idempotencyKey,
    DateTime? approvalExpiresAt,
    String? attestationDigest,
    String? executionId,
    String? remoteStatus,
    bool? sponsored,
    String? transactionHash,
    String? transactionLink,
    List<KeeperHubVerifiedReceipt>? receipts,
    bool? idempotentReplay,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
    DateTime? updatedAt,
  }) =>
      KeeperHubExecutionRecord(
        intentId: intentId,
        taskId: taskId,
        phase: phase ?? this.phase,
        personalWalletAddress: personalWalletAddress,
        agentWalletAddress: agentWalletAddress,
        reason: reason,
        transfer: Map<String, dynamic>.unmodifiable(transfer),
        simulation: simulation ?? this.simulation,
        simulationFingerprint:
            simulationFingerprint ?? this.simulationFingerprint,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        approvalExpiresAt: approvalExpiresAt ?? this.approvalExpiresAt,
        attestationDigest: attestationDigest ?? this.attestationDigest,
        executionId: executionId ?? this.executionId,
        remoteStatus: remoteStatus ?? this.remoteStatus,
        sponsored: sponsored ?? this.sponsored,
        transactionHash: transactionHash ?? this.transactionHash,
        transactionLink: transactionLink ?? this.transactionLink,
        receipts: receipts ?? this.receipts,
        idempotentReplay: idempotentReplay ?? this.idempotentReplay,
        errorCode: clearError ? errorCode : errorCode ?? this.errorCode,
        errorMessage:
            clearError ? errorMessage : errorMessage ?? this.errorMessage,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 1,
        'intentId': intentId,
        'taskId': taskId,
        'phase': phase.name,
        'personalWalletAddress': personalWalletAddress,
        'agentWalletAddress': agentWalletAddress,
        'reason': reason,
        'transfer': transfer,
        'simulation': simulation?.toJson(),
        'simulationFingerprint': simulationFingerprint,
        'idempotencyKey': idempotencyKey,
        'approvalExpiresAt': approvalExpiresAt?.toUtc().toIso8601String(),
        'attestationDigest': attestationDigest,
        'executionId': executionId,
        'remoteStatus': remoteStatus,
        'sponsored': sponsored,
        'transactionHash': transactionHash,
        'transactionLink': transactionLink,
        'receipts': receipts.map((receipt) => receipt.toJson()).toList(),
        'idempotentReplay': idempotentReplay,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toAgentJson() => <String, dynamic>{
        'intentId': intentId,
        'phase': phase.name,
        'chainId': transfer['chainId'],
        'recipientAddress': transfer['recipientAddress'],
        'amount': transfer['amount'],
        'reason': reason,
        'simulation': simulation?.toJson(),
        'executionId': executionId,
        'remoteStatus': remoteStatus,
        'sponsored': sponsored,
        'transactionHash': transactionHash,
        'transactionLink': transactionLink,
        'receiptVerified': receipts.isNotEmpty &&
            receipts.every(
              (receipt) =>
                  receipt.verified && receipt.receiptStatus == 'success',
            ),
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'mayApproveOrExecute': false,
      };

  factory KeeperHubExecutionRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported execution record version.');
    }
    final phaseName = _requiredText(json['phase'], 'execution phase', 40);
    final phase = KeeperHubExecutionPhase.values
        .where((value) => value.name == phaseName)
        .firstOrNull;
    if (phase == null) {
      throw const FormatException('KeeperHub execution phase is invalid.');
    }
    final transferRaw = json['transfer'];
    if (transferRaw is! Map) {
      throw const FormatException('KeeperHub transfer body is invalid.');
    }
    final simulationRaw = json['simulation'];
    final receiptsRaw = json['receipts'];
    final personalWalletAddress = requireKeeperHubAddress(
      json['personalWalletAddress'],
      'Personal Wallet',
    );
    final agentWalletAddress = requireKeeperHubAddress(
      json['agentWalletAddress'],
      'Agent Wallet',
    );
    final transfer = Map<String, dynamic>.from(transferRaw);
    _validateStoredProofTransfer(transfer, agentWalletAddress);
    final sponsoredRaw = json['sponsored'];
    if (sponsoredRaw != null && sponsoredRaw is! bool) {
      throw const FormatException('KeeperHub sponsorship state is invalid.');
    }
    return KeeperHubExecutionRecord(
      intentId: _requiredText(json['intentId'], 'intent id', 128),
      taskId: _requiredText(json['taskId'], 'task id', 128),
      phase: phase,
      personalWalletAddress: personalWalletAddress,
      agentWalletAddress: agentWalletAddress,
      reason: _requiredText(json['reason'], 'reason', 240),
      transfer: Map<String, dynamic>.unmodifiable(transfer),
      simulation: simulationRaw is Map
          ? KeeperHubSimulation.fromJson(
              Map<String, dynamic>.from(simulationRaw),
            )
          : null,
      simulationFingerprint: _optionalDigest(json['simulationFingerprint']),
      idempotencyKey: _optionalDigest(json['idempotencyKey']),
      approvalExpiresAt:
          DateTime.tryParse(json['approvalExpiresAt']?.toString() ?? '')
              ?.toUtc(),
      attestationDigest: _optionalHexDigest(json['attestationDigest']),
      executionId: _optionalText(json['executionId'], 160),
      remoteStatus: _optionalText(json['remoteStatus'], 40),
      sponsored: sponsoredRaw as bool?,
      transactionHash: _optionalTransactionHash(json['transactionHash']),
      transactionLink: _optionalHttpsLink(json['transactionLink']),
      receipts: receiptsRaw is List
          ? receiptsRaw
              .whereType<Map>()
              .map(
                (value) => KeeperHubVerifiedReceipt.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              )
              .toList(growable: false)
          : const <KeeperHubVerifiedReceipt>[],
      idempotentReplay: json['idempotentReplay'] == true,
      errorCode: _optionalText(json['errorCode'], 80),
      errorMessage: _optionalText(json['errorMessage'], 320),
      createdAt: _requiredDate(json['createdAt'], 'creation time'),
      updatedAt: _requiredDate(json['updatedAt'], 'update time'),
    );
  }
}

void _validateStoredProofTransfer(
  Map<String, dynamic> transfer,
  String agentWalletAddress,
) {
  const expectedKeys = <String>{'chainId', 'recipientAddress', 'amount'};
  if (transfer.length != expectedKeys.length ||
      !transfer.keys.every(expectedKeys.contains) ||
      transfer['chainId'] is! int ||
      !const <int>{
        KeeperHubProofNetwork.chainId,
        KeeperHubProofNetwork.legacyBaseSepoliaChainId,
      }.contains(transfer['chainId']) ||
      transfer['amount'] is! String ||
      transfer['amount'] != '0') {
    throw const FormatException('Stored KeeperHub proof transfer is invalid.');
  }
  final recipient = requireKeeperHubAddress(
    transfer['recipientAddress'],
    'proof recipient',
  );
  if (recipient.toLowerCase() != agentWalletAddress.toLowerCase()) {
    throw const FormatException(
      'Stored KeeperHub proof recipient does not match the Agent Wallet.',
    );
  }
}

String _decimal(Object? value, String label) {
  final text = value?.toString().trim() ?? '';
  if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(text)) {
    throw FormatException('The $label is invalid.');
  }
  return text;
}

String _requiredText(Object? value, String label, int maxLength) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty ||
      text.length > maxLength ||
      text.contains(RegExp(r'[\r\n]'))) {
    throw FormatException('The $label is invalid.');
  }
  return text;
}

String? _optionalText(Object? value, int maxLength) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  if (text.length > maxLength || text.contains(RegExp(r'[\r\n]'))) {
    throw const FormatException('A KeeperHub receipt field is invalid.');
  }
  return text;
}

String? _optionalDigest(Object? value) {
  final text = _optionalText(value, 64);
  if (text == null) return null;
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw const FormatException('KeeperHub digest is invalid.');
  }
  return text;
}

String? _optionalHexDigest(Object? value) {
  final text = _optionalText(value, 66);
  if (text == null) return null;
  if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(text)) {
    throw const FormatException('KeeperHub attestation digest is invalid.');
  }
  return text;
}

String? _optionalTransactionHash(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(text)) {
    throw const FormatException('KeeperHub transaction hash is invalid.');
  }
  return text;
}

String? _optionalHttpsLink(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  final uri = Uri.tryParse(text);
  if (text.length > 500 ||
      uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('KeeperHub transaction link is invalid.');
  }
  return text;
}

DateTime _requiredDate(Object? value, String label) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) throw FormatException('The $label is invalid.');
  return parsed.toUtc();
}
