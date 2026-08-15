import 'dart:async';

import 'package:uuid/uuid.dart';

import '../native_bridge.dart';
import 'keeperhub_api_client.dart';
import 'keeperhub_auth_store.dart';
import 'keeperhub_models.dart';

typedef KeeperHubSiweSigner = Future<Map<String, dynamic>> Function({
  required String nonce,
  required DateTime issuedAt,
});
typedef KeeperHubKeyChallengeSigner = Future<Map<String, dynamic>> Function({
  required String challenge,
  required String operation,
});
typedef KeeperHubDelay = Future<void> Function(Duration duration);
typedef KeeperHubRevocationAuthorizer = Future<Map<String, dynamic>> Function({
  required String keyId,
  required String keyPrefix,
});

/// Explicit user-driven onboarding for the separately-custodied Agent Wallet.
/// Calling [connect] is the only account-creation path; no startup or agent tool
/// invokes it automatically.
class KeeperHubHeadlessOnboardingService {
  KeeperHubHeadlessOnboardingService({
    KeeperHubApiClient? api,
    KeeperHubAuthStore? authStore,
    KeeperHubSiweSigner? signSiwe,
    KeeperHubKeyChallengeSigner? signKeyChallenge,
    DateTime Function()? clock,
    KeeperHubDelay? delay,
    KeeperHubRevocationAuthorizer? authorizeRevocation,
    Uuid? uuid,
    this.agentWalletPollAttempts = 20,
    this.agentWalletPollInterval = const Duration(milliseconds: 1500),
  })  : _api = api ?? KeeperHubApiClient(),
        _authStore = authStore ?? KeeperHubAuthStore(),
        _signSiwe = signSiwe ?? NativeBridge.signSecureKeeperHubSiwe,
        _signKeyChallenge =
            signKeyChallenge ?? NativeBridge.signSecureKeeperHubKeyChallenge,
        _clock = clock ?? DateTime.now,
        _delay = delay ?? Future<void>.delayed,
        _authorizeRevocation = authorizeRevocation ??
            NativeBridge.authorizeSecureKeeperHubRevocation,
        _uuid = uuid ?? const Uuid();

  final KeeperHubApiClient _api;
  final KeeperHubAuthStore _authStore;
  final KeeperHubSiweSigner _signSiwe;
  final KeeperHubKeyChallengeSigner _signKeyChallenge;
  final DateTime Function() _clock;
  final KeeperHubDelay _delay;
  final KeeperHubRevocationAuthorizer _authorizeRevocation;
  final Uuid _uuid;
  final int agentWalletPollAttempts;
  final Duration agentWalletPollInterval;

  Future<KeeperHubConnectionRecord?> readConnection() async =>
      (await _authStore.read())?.record;

  Future<KeeperHubConnectionRecord> connect({
    required String personalWalletAddress,
    void Function(KeeperHubOnboardingProgress progress)? onProgress,
  }) async {
    final personal = requireKeeperHubAddress(
      personalWalletAddress,
      'Personal Wallet',
    );
    _progress(
      onProgress,
      KeeperHubOnboardingStage.checkingWallet,
      'Checking the Personal Wallet and existing connection…',
    );
    final existing = await _authStore.read();
    if (existing != null) {
      if (existing.record.personalWalletAddress.toLowerCase() !=
          personal.toLowerCase()) {
        throw const KeeperHubException(
          'personal_wallet_mismatch',
          'This Agent Wallet belongs to a different Personal Wallet.',
        );
      }
      final validation = await _api.validateOrganizationKey(existing.apiKey);
      if (validation.statusCode == 200) {
        var refreshed = existing.record.copyWith(
          phase: existing.record.agentWalletAddress == null
              ? KeeperHubConnectionPhase.provisioning
              : KeeperHubConnectionPhase.ready,
          lastVerifiedAt: _clock().toUtc(),
          lastRequestId: validation.requestId,
        );
        if (refreshed.agentWalletAddress == null) {
          await _openSession(personal, onProgress);
          final lookup = await _pollForAgentWallet(onProgress);
          if (lookup.address == null) {
            throw const KeeperHubException(
              'agent_wallet_pending',
              'The credential is secured, but KeeperHub is still provisioning the Agent Wallet.',
            );
          }
          if (lookup.address!.toLowerCase() == personal.toLowerCase()) {
            throw const KeeperHubException(
              'agent_wallet_identity_invalid',
              'KeeperHub did not return a separate Agent Execution Wallet.',
            );
          }
          refreshed = refreshed.copyWith(
            agentWalletAddress: lookup.address,
            lastRequestId: lookup.lastRequestId ?? validation.requestId,
            phase: KeeperHubConnectionPhase.ready,
          );
        }
        await _authStore.updateRecord(refreshed);
        return refreshed;
      }
      throw const KeeperHubException(
        'stored_credential_invalid',
        'The saved Agent Wallet credential is revoked or no longer valid.',
      );
    }

    await _authStore.verifyAvailable();
    await _openSession(personal, onProgress);

    _progress(
      onProgress,
      KeeperHubOnboardingStage.authorizingCredential,
      'Requesting explicit organization-key authorization…',
    );
    final keyName = 'plawie-android-${_uuid.v4().substring(0, 8)}';
    final challengeResponse = await _api.createOrganizationKey(name: keyName);
    if (challengeResponse.statusCode != 401 ||
        challengeResponse.body['code'] != 'signature_required') {
      throw _responseFailure(
        challengeResponse,
        'key_challenge_failed',
        'KeeperHub did not return the expected key-authorization challenge.',
      );
    }
    final required = challengeResponse.body['required'];
    if (required is! List ||
        !required.contains('wallet') ||
        required.any((factor) => factor != 'wallet')) {
      throw const KeeperHubException(
        'additional_factor_required',
        'This KeeperHub account requires another human authentication factor.',
      );
    }
    final challenge = _requiredString(
      challengeResponse.body['challenge'],
      'KeeperHub key challenge',
      maxLength: 256,
    );
    final signedChallenge = await _signKeyChallenge(
      challenge: challenge,
      operation: 'create',
    );
    final challengeAddress = requireKeeperHubAddress(
      signedChallenge['walletAddress'],
      'key-authorizing Personal Wallet',
    );
    if (challengeAddress.toLowerCase() != personal.toLowerCase()) {
      throw const KeeperHubException(
        'key_wallet_mismatch',
        'Android authorized the key with a different Personal Wallet.',
      );
    }
    final keySignature = _requiredSignature(signedChallenge['signature']);
    final keyResponse = await _api.createOrganizationKey(
      name: keyName,
      signature: keySignature,
    );
    _requireSuccess(keyResponse, 'key_creation_failed');
    final apiKey = _requiredString(
      keyResponse.body['key'],
      'KeeperHub organization credential',
      maxLength: 512,
    );
    final keyId = _requiredString(
      keyResponse.body['id'] ?? keyResponse.body['keyId'],
      'KeeperHub organization key id',
      maxLength: 160,
    );
    final now = _clock().toUtc();
    var record = KeeperHubConnectionRecord(
      personalWalletAddress: personal,
      apiKeyId: keyId,
      apiKeyPrefix: apiKey.length <= 12 ? apiKey : apiKey.substring(0, 12),
      createdAt: now,
      lastRequestId: keyResponse.requestId,
      phase: KeeperHubConnectionPhase.provisioning,
    );

    _progress(
      onProgress,
      KeeperHubOnboardingStage.securingCredential,
      'Securing the returned-once credential on this device…',
    );
    await _authStore.save(apiKey: apiKey, record: record);

    try {
      final lookup = await _pollForAgentWallet(onProgress);
      final agentWallet = lookup.address;
      if (agentWallet == null) {
        throw const KeeperHubException(
          'agent_wallet_pending',
          'The credential is secured, but KeeperHub is still provisioning the Agent Wallet.',
        );
      }
      if (agentWallet.toLowerCase() == personal.toLowerCase()) {
        throw const KeeperHubException(
          'agent_wallet_identity_invalid',
          'KeeperHub did not return a separate Agent Execution Wallet.',
        );
      }

      _progress(
        onProgress,
        KeeperHubOnboardingStage.verifyingCredential,
        'Verifying organization-scoped access…',
      );
      final validation = await _api.validateOrganizationKey(apiKey);
      _requireSuccess(validation, 'credential_verification_failed');
      record = record.copyWith(
        agentWalletAddress: agentWallet,
        lastVerifiedAt: _clock().toUtc(),
        lastRequestId: validation.requestId ?? lookup.lastRequestId,
        phase: KeeperHubConnectionPhase.ready,
      );
      await _authStore.updateRecord(record);
      _progress(
        onProgress,
        KeeperHubOnboardingStage.ready,
        'Agent Execution Wallet connected.',
      );
      return record;
    } on KeeperHubException {
      // The remote credential already exists and was returned only once. Keep
      // the secure provisioning record so restart/recovery cannot orphan it.
      rethrow;
    }
  }

  Future<void> revoke({
    void Function(KeeperHubOnboardingProgress progress)? onProgress,
  }) async {
    final credential = await _authStore.read();
    if (credential == null) return;
    final record = credential.record;
    _progress(
      onProgress,
      KeeperHubOnboardingStage.authorizingRevocation,
      'Waiting for device-authenticated revocation approval…',
    );
    final authorization = await _authorizeRevocation(
      keyId: record.apiKeyId,
      keyPrefix: record.apiKeyPrefix,
    );
    final wallet = requireKeeperHubAddress(
      authorization['walletAddress'],
      'revocation-authorizing Personal Wallet',
    );
    final digest = authorization['authorizationDigest']?.toString() ?? '';
    if (wallet.toLowerCase() != record.personalWalletAddress.toLowerCase() ||
        authorization['keyId'] != record.apiKeyId ||
        authorization['keyPrefix'] != record.apiKeyPrefix ||
        !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(digest)) {
      throw const KeeperHubException(
        'revocation_authorization_mismatch',
        'Android authorized different KeeperHub revocation details.',
      );
    }

    _progress(
      onProgress,
      KeeperHubOnboardingStage.revokingCredential,
      'Revoking the remote organization credential…',
    );
    KeeperHubApiResponse response;
    try {
      response = await _api.revokeOrganizationKey(
        apiKey: credential.apiKey,
        keyId: record.apiKeyId,
      );
    } on KeeperHubException {
      await _markRevocationUnknown(record);
      throw const KeeperHubException(
        'revocation_unknown',
        'Remote revocation could not be confirmed. The credential remains secured for a safe retry.',
      );
    }

    final revoked = response.statusCode == 204 ||
        (response.isSuccess && response.body['success'] == true);
    final alreadyUnavailable =
        response.statusCode == 401 || response.statusCode == 404;
    if (revoked || alreadyUnavailable) {
      await _authStore.clear();
      _progress(
        onProgress,
        KeeperHubOnboardingStage.revoked,
        'Remote Agent Wallet access revoked.',
      );
      return;
    }
    await _markRevocationUnknown(record);
    throw const KeeperHubException(
      'revocation_unknown',
      'KeeperHub did not confirm remote revocation. The credential remains secured for a safe retry.',
    );
  }

  void close() => _api.close();

  Future<void> _markRevocationUnknown(
    KeeperHubConnectionRecord record,
  ) async {
    await _authStore.updateRecord(
      record.copyWith(phase: KeeperHubConnectionPhase.revocationUnknown),
    );
  }

  Future<void> _openSession(
    String personal,
    void Function(KeeperHubOnboardingProgress progress)? onProgress,
  ) async {
    _progress(
      onProgress,
      KeeperHubOnboardingStage.requestingSignIn,
      'Requesting a one-use KeeperHub sign-in challenge…',
    );
    final nonceResponse = await _api.requestNonce(personal);
    _requireSuccess(nonceResponse, 'siwe_nonce_failed');
    final nonce = _requiredString(
      nonceResponse.body['nonce'],
      'KeeperHub sign-in nonce',
      maxLength: 96,
    );
    if (!RegExp(r'^[A-Za-z0-9]{8,96}$').hasMatch(nonce)) {
      throw const KeeperHubException(
        'siwe_nonce_invalid',
        'KeeperHub returned an invalid sign-in nonce.',
      );
    }

    final issuedAt = _clock().toUtc();
    final signedSiwe = await _signSiwe(nonce: nonce, issuedAt: issuedAt);
    final signedAddress = requireKeeperHubAddress(
      signedSiwe['walletAddress'],
      'signed Personal Wallet',
    );
    if (signedAddress.toLowerCase() != personal.toLowerCase()) {
      throw const KeeperHubException(
        'siwe_wallet_mismatch',
        'Android signed with a different Personal Wallet.',
      );
    }
    final message = _requiredString(
      signedSiwe['message'],
      'signed KeeperHub message',
      maxLength: 1024,
    );
    final signature = _requiredSignature(signedSiwe['signature']);

    _progress(
      onProgress,
      KeeperHubOnboardingStage.verifyingSession,
      'Verifying the bounded wallet sign-in…',
    );
    final verify = await _api.verifySiwe(
      message: message,
      signature: signature,
      walletAddress: personal,
    );
    _requireSuccess(verify, 'siwe_verify_failed');
  }

  Future<({String? address, String? lastRequestId})> _pollForAgentWallet(
    void Function(KeeperHubOnboardingProgress progress)? onProgress,
  ) async {
    _progress(
      onProgress,
      KeeperHubOnboardingStage.provisioningAgentWallet,
      'Waiting for the separate Agent Execution Wallet…',
    );
    String? lastRequestId;
    for (var attempt = 0; attempt < agentWalletPollAttempts; attempt++) {
      final user = await _api.readUser();
      _requireSuccess(user, 'agent_wallet_lookup_failed');
      lastRequestId = user.requestId ?? lastRequestId;
      final value = user.body['walletAddress'];
      if (value != null && value.toString().trim().isNotEmpty) {
        return (
          address: requireKeeperHubAddress(value, 'Agent Execution Wallet'),
          lastRequestId: lastRequestId,
        );
      }
      if (attempt + 1 < agentWalletPollAttempts) {
        await _delay(agentWalletPollInterval);
      }
    }
    return (address: null, lastRequestId: lastRequestId);
  }

  void _progress(
    void Function(KeeperHubOnboardingProgress progress)? listener,
    KeeperHubOnboardingStage stage,
    String message,
  ) {
    listener?.call(KeeperHubOnboardingProgress(stage, message));
  }

  void _requireSuccess(KeeperHubApiResponse response, String code) {
    if (!response.isSuccess) {
      throw _responseFailure(
        response,
        code,
        'KeeperHub rejected the secure onboarding request.',
      );
    }
  }

  KeeperHubException _responseFailure(
    KeeperHubApiResponse response,
    String fallbackCode,
    String message,
  ) {
    final remoteCode = response.body['code']?.toString().trim();
    final retrySeconds = int.tryParse(response.headers['retry-after'] ?? '');
    return KeeperHubException(
      remoteCode == null || remoteCode.isEmpty ? fallbackCode : remoteCode,
      message,
      retryAfter: retrySeconds == null ? null : Duration(seconds: retrySeconds),
    );
  }

  String _requiredString(
    Object? value,
    String label, {
    required int maxLength,
  }) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.length > maxLength) {
      throw KeeperHubException(
        'response_invalid',
        '$label is missing or invalid.',
      );
    }
    return text;
  }

  String _requiredSignature(Object? value) {
    final signature = value?.toString().trim() ?? '';
    if (!RegExp(r'^0x[0-9a-fA-F]{130}$').hasMatch(signature)) {
      throw const KeeperHubException(
        'native_signature_invalid',
        'Android returned an invalid bounded signature.',
      );
    }
    return signature;
  }
}
