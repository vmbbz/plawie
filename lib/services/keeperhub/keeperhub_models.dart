enum KeeperHubConnectionPhase {
  provisioning,
  ready,
  credentialInvalid,
  revocationUnknown,
}

class KeeperHubConnectionRecord {
  const KeeperHubConnectionRecord({
    required this.personalWalletAddress,
    required this.apiKeyId,
    required this.apiKeyPrefix,
    required this.createdAt,
    required this.phase,
    this.agentWalletAddress,
    this.lastVerifiedAt,
    this.lastRequestId,
  });

  final String personalWalletAddress;
  final String apiKeyId;
  final String apiKeyPrefix;
  final String? agentWalletAddress;
  final DateTime createdAt;
  final DateTime? lastVerifiedAt;
  final String? lastRequestId;
  final KeeperHubConnectionPhase phase;

  bool get isReady =>
      phase == KeeperHubConnectionPhase.ready && agentWalletAddress != null;

  KeeperHubConnectionRecord copyWith({
    String? agentWalletAddress,
    DateTime? lastVerifiedAt,
    String? lastRequestId,
    KeeperHubConnectionPhase? phase,
  }) {
    return KeeperHubConnectionRecord(
      personalWalletAddress: personalWalletAddress,
      apiKeyId: apiKeyId,
      apiKeyPrefix: apiKeyPrefix,
      agentWalletAddress: agentWalletAddress ?? this.agentWalletAddress,
      createdAt: createdAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      lastRequestId: lastRequestId ?? this.lastRequestId,
      phase: phase ?? this.phase,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 1,
        'personalWalletAddress': personalWalletAddress,
        'apiKeyId': apiKeyId,
        'apiKeyPrefix': apiKeyPrefix,
        'agentWalletAddress': agentWalletAddress,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'lastVerifiedAt': lastVerifiedAt?.toUtc().toIso8601String(),
        'lastRequestId': lastRequestId,
        'phase': phase.name,
      };

  Map<String, dynamic> toAgentJson() => <String, dynamic>{
        'connected': isReady,
        'phase': phase.name,
        'personalWalletAddress': personalWalletAddress,
        'agentWalletAddress': agentWalletAddress,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'lastVerifiedAt': lastVerifiedAt?.toUtc().toIso8601String(),
        'mayApproveOrExecute': false,
      };

  factory KeeperHubConnectionRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported Agent Wallet record version.');
    }
    final personal = _requiredAddress(
      json['personalWalletAddress'],
      'personal wallet',
    );
    final agentRaw = json['agentWalletAddress'];
    final agent =
        agentRaw == null ? null : _requiredAddress(agentRaw, 'agent wallet');
    final keyId = _requiredBoundedString(json['apiKeyId'], 'API key id', 160);
    final keyPrefix =
        _requiredBoundedString(json['apiKeyPrefix'], 'API key prefix', 32);
    if (!keyPrefix.startsWith('kh_')) {
      throw const FormatException('Agent Wallet credential prefix is invalid.');
    }
    final createdAt = _requiredDate(json['createdAt'], 'creation time');
    final verifiedRaw = json['lastVerifiedAt'];
    final requestRaw = json['lastRequestId'];
    final phaseName =
        _requiredBoundedString(json['phase'], 'connection phase', 40);
    final phase = KeeperHubConnectionPhase.values
        .where((value) => value.name == phaseName)
        .firstOrNull;
    if (phase == null) {
      throw const FormatException('Agent Wallet connection phase is invalid.');
    }
    return KeeperHubConnectionRecord(
      personalWalletAddress: personal,
      apiKeyId: keyId,
      apiKeyPrefix: keyPrefix,
      agentWalletAddress: agent,
      createdAt: createdAt,
      lastVerifiedAt: verifiedRaw == null
          ? null
          : _requiredDate(verifiedRaw, 'verification time'),
      lastRequestId: requestRaw == null
          ? null
          : _requiredBoundedString(requestRaw, 'request id', 160),
      phase: phase,
    );
  }
}

class KeeperHubStoredCredential {
  const KeeperHubStoredCredential({
    required this.record,
    required this.apiKey,
  });

  final KeeperHubConnectionRecord record;
  final String apiKey;
}

enum KeeperHubOnboardingStage {
  checkingWallet,
  requestingSignIn,
  verifyingSession,
  authorizingCredential,
  securingCredential,
  provisioningAgentWallet,
  verifyingCredential,
  ready,
  authorizingRevocation,
  revokingCredential,
  revoked,
}

class KeeperHubOnboardingProgress {
  const KeeperHubOnboardingProgress(this.stage, this.message);

  final KeeperHubOnboardingStage stage;
  final String message;
}

class KeeperHubException implements Exception {
  const KeeperHubException(this.code, this.message, {this.retryAfter});

  final String code;
  final String message;
  final Duration? retryAfter;

  @override
  String toString() => 'KeeperHubException($code): $message';
}

final RegExp _evmAddressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');

String requireKeeperHubAddress(Object? value, String label) =>
    _requiredAddress(value, label);

String _requiredAddress(Object? value, String label) {
  final text = value?.toString().trim() ?? '';
  if (!_evmAddressPattern.hasMatch(text)) {
    throw FormatException('The $label address is invalid.');
  }
  return text;
}

String _requiredBoundedString(Object? value, String label, int maxLength) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.length > maxLength) {
    throw FormatException('The $label is invalid.');
  }
  return text;
}

DateTime _requiredDate(Object? value, String label) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) throw FormatException('The $label is invalid.');
  return parsed.toUtc();
}
