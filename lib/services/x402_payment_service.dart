import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';
import 'package:web3dart/crypto.dart';

enum X402PaymentState {
  challengeReceived,
  awaitingHumanApproval,
  awaitingWalletUnlock,
  signing,
  submitted,
  settled,
  rejected,
  expired,
  blockedByPolicy,
  approvalBusy,
  uncertain,
  failed,
}

enum PaymentApprovalSource {
  visibleUi,
  chatText,
  toolCall,
  notificationAction,
  deepLink,
}

/// The intentionally narrow first x402 payment policy.
class X402PaymentPolicy {
  const X402PaymentPolicy({
    required this.allowedHosts,
    this.maxAmount = 5000000,
    this.maxTimeoutSeconds = 300,
  });

  static const String network = 'eip155:8453';
  static const String usdc = '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913';
  static const String transferMethod = 'eip3009';

  /// Live signing is still gated by the Android-side allowlist, hardware-backed
  /// Keystore check, one-use visible approval ticket, and exact-request retry.
  static const bool liveSigningEnabled = true;

  final Set<String> allowedHosts;
  final int maxAmount;
  final int maxTimeoutSeconds;

  bool allowsHost(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https') return false;
    final host = uri.host.toLowerCase();
    return allowedHosts.any((allowed) {
      final normalized = allowed.trim().toLowerCase();
      return host == normalized || host.endsWith('.$normalized');
    });
  }
}

class X402PaymentRequirement {
  const X402PaymentRequirement({
    required this.scheme,
    required this.network,
    required this.amount,
    required this.asset,
    required this.payTo,
    required this.maxTimeoutSeconds,
    required this.extra,
  });

  final String scheme;
  final String network;
  final String amount;
  final String asset;
  final String payTo;
  final int maxTimeoutSeconds;
  final Map<String, dynamic> extra;

  String get assetTransferMethod =>
      extra['assetTransferMethod']?.toString().toLowerCase() ??
      X402PaymentPolicy.transferMethod;

  BigInt get amountUnits => BigInt.parse(amount);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'scheme': scheme,
        'network': network,
        'amount': amount,
        'asset': asset,
        'payTo': payTo,
        'maxTimeoutSeconds': maxTimeoutSeconds,
        if (extra.isNotEmpty) 'extra': extra,
      };
}

class X402PaymentChallenge {
  const X402PaymentChallenge({
    required this.x402Version,
    required this.resource,
    required this.resourceUrl,
    required this.resourceDescription,
    required this.requirement,
    required this.challengeHash,
    this.extensions = const <String, dynamic>{},
  });

  final int x402Version;
  final Map<String, dynamic> resource;
  final Uri resourceUrl;
  final String? resourceDescription;
  final X402PaymentRequirement requirement;
  final String challengeHash;
  final Map<String, dynamic> extensions;

  /// Parses the base64 JSON required by the x402 v2 PAYMENT-REQUIRED header.
  /// Raw JSON is accepted only for diagnostic fixtures; wire clients should
  /// always pass the encoded header value.
  factory X402PaymentChallenge.fromHeader(
    String header, {
    required X402PaymentPolicy policy,
    Uri? resourceUrlFallback,
    String? resourceDescriptionFallback,
  }) {
    final decoded = _decodeHeaderJson(header);
    final version = _positiveInt(decoded['x402Version']);
    if (version != 2) {
      throw const X402PaymentPolicyException('Only x402 version 2 is allowed.');
    }
    final rawResource = decoded['resource'];
    late final Map<dynamic, dynamic> resource;
    late final Uri resourceUrl;
    if (rawResource is Map) {
      resource = rawResource;
      final declaredUrl = Uri.tryParse(resource['url']?.toString() ?? '');
      if (declaredUrl == null || !policy.allowsHost(declaredUrl)) {
        throw const X402PaymentPolicyException(
            'x402 resource host or scheme is not allowlisted.');
      }
      resourceUrl = declaredUrl;
    } else {
      // Venice's documented top-up challenge currently has `accepts` but no
      // `resource`. Only a provider catalog entry that explicitly opts into
      // this compatibility path may supply an exact, pre-allowlisted URL.
      final fallback = resourceUrlFallback;
      if (fallback == null || !policy.allowsHost(fallback)) {
        throw const X402PaymentPolicyException('x402 resource is missing.');
      }
      resource = <String, dynamic>{
        'url': fallback.toString(),
        if (resourceDescriptionFallback != null)
          'description': resourceDescriptionFallback,
      };
      resourceUrl = fallback;
    }
    if (!policy.allowsHost(resourceUrl)) {
      throw const X402PaymentPolicyException(
          'x402 resource host or scheme is not allowlisted.');
    }
    final accepts = decoded['accepts'];
    if (accepts is! List || accepts.isEmpty) {
      throw const X402PaymentPolicyException('x402 accepts list is missing.');
    }

    X402PaymentRequirement? selected;
    for (final raw in accepts) {
      if (raw is! Map) continue;
      final candidate = _parseRequirement(raw);
      if (candidate == null) continue;
      if (_isAllowedRequirement(candidate, policy)) {
        selected = candidate;
        break;
      }
    }
    if (selected == null) {
      throw const X402PaymentPolicyException(
          'No supported Base Mainnet EIP-3009 payment requirement was offered.');
    }

    final canonical = _canonicalJson(decoded);
    final rawExtensions = decoded['extensions'];
    return X402PaymentChallenge(
      x402Version: version,
      resource: resource.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      resourceUrl: resourceUrl,
      resourceDescription: resource['description']?.toString(),
      requirement: selected,
      challengeHash: bytesToHex(keccak256(utf8.encode(canonical))),
      extensions: rawExtensions is Map
          ? rawExtensions.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{},
    );
  }
}

/// Builds the x402 v2 wire payload while keeping numeric EIP-3009 values in
/// the decimal-string form required by the protocol clients and facilitators.
/// Provider attribution may be merged into the challenge extensions without
/// discarding server-declared metadata such as Bazaar discovery information.
Map<String, dynamic> buildX402V2PaymentPayload({
  required PendingPaymentIntent intent,
  required String signature,
  required String payer,
  required int validAfter,
  required int validBefore,
  String? providerServiceCode,
}) {
  final extensions = Map<String, dynamic>.from(intent.challenge.extensions);
  final serviceCode = providerServiceCode?.trim() ?? '';
  if (serviceCode.isNotEmpty) {
    final rawBuilderCode = extensions['builder-code'];
    final builderCode = rawBuilderCode is Map
        ? rawBuilderCode.map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};
    final rawInfo = builderCode['info'];
    final info = rawInfo is Map
        ? rawInfo.map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};
    info['s'] = <String>[serviceCode];
    builderCode['info'] = info;
    extensions['builder-code'] = builderCode;
  }

  final requirement = intent.challenge.requirement;
  return <String, dynamic>{
    'x402Version': intent.challenge.x402Version,
    'resource': intent.challenge.resource,
    'accepted': requirement.toJson(),
    'payload': <String, dynamic>{
      'signature': signature,
      'authorization': <String, dynamic>{
        'from': payer,
        'to': requirement.payTo,
        'value': requirement.amount,
        'validAfter': validAfter.toString(),
        'validBefore': validBefore.toString(),
        'nonce': intent.paymentNonce,
      },
    },
    if (extensions.isNotEmpty) 'extensions': extensions,
  };
}

class PendingPaymentIntent {
  const PendingPaymentIntent({
    required this.intentId,
    required this.approvalNonce,
    required this.paymentNonce,
    required this.createdAt,
    required this.expiresAt,
    required this.requestMethod,
    required this.requestUrl,
    required this.requestBodyHash,
    required this.challenge,
    required this.state,
  });

  final String intentId;
  final String approvalNonce;
  final String paymentNonce;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String requestMethod;
  final Uri requestUrl;
  final String requestBodyHash;
  final X402PaymentChallenge challenge;
  final X402PaymentState state;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  PendingPaymentIntent copyWith({
    X402PaymentState? state,
  }) {
    return PendingPaymentIntent(
      intentId: intentId,
      approvalNonce: approvalNonce,
      paymentNonce: paymentNonce,
      createdAt: createdAt,
      expiresAt: expiresAt,
      requestMethod: requestMethod,
      requestUrl: requestUrl,
      requestBodyHash: requestBodyHash,
      challenge: challenge,
      state: state ?? this.state,
    );
  }
}

class PaymentApprovalTicket {
  const PaymentApprovalTicket({
    required this.intentId,
    required this.approvalNonce,
    required this.issuedAt,
  });

  final String intentId;
  final String approvalNonce;
  final DateTime issuedAt;
}

class X402PaymentReceipt {
  const X402PaymentReceipt({
    required this.intentId,
    required this.state,
    required this.recordedAt,
    this.transactionHash,
    this.payer,
    this.errorCode,
    this.providerId,
    this.network,
    this.asset,
    this.amount,
    this.payTo,
    this.resourceUrl,
    this.challengeHash,
    this.httpStatus,
    this.requestFingerprint,
    this.modelId,
    this.paidRetryConsumed = false,
  });

  final String intentId;
  final X402PaymentState state;
  final DateTime recordedAt;
  final String? transactionHash;
  final String? payer;
  final String? errorCode;
  final String? providerId;
  final String? network;
  final String? asset;
  final String? amount;
  final String? payTo;
  final String? resourceUrl;
  final String? challengeHash;
  final int? httpStatus;
  final String? requestFingerprint;
  final String? modelId;
  final bool paidRetryConsumed;

  /// A successful paid inference response and a verified on-chain settlement
  /// are deliberately separate facts. Some providers return the model payload
  /// without exposing a payment receipt header or transaction hash. In that
  /// case the response was delivered, but settlement must remain unverified.
  bool get responseDelivered =>
      paidRetryConsumed &&
      httpStatus != null &&
      httpStatus! >= 200 &&
      httpStatus! < 300;

  bool get settlementVerified =>
      state == X402PaymentState.settled &&
      (transactionHash?.trim().isNotEmpty ?? false);

  bool get responseDeliveredSettlementUnverified =>
      responseDelivered &&
      state == X402PaymentState.uncertain &&
      !(transactionHash?.trim().isNotEmpty ?? false);

  /// A consumed paid retry is never safe to repeat automatically, regardless
  /// of whether the provider exposed enough metadata to verify settlement.
  bool get retryAllowed => !paidRetryConsumed;

  String get deliveryStatus => responseDelivered
      ? 'delivered'
      : paidRetryConsumed
          ? 'unknown'
          : 'notAttempted';

  String get settlementStatus => settlementVerified
      ? 'verified'
      : responseDeliveredSettlementUnverified
          ? 'unverified'
          : switch (state) {
              X402PaymentState.signing ||
              X402PaymentState.submitted =>
                'pending',
              X402PaymentState.uncertain => 'unverified',
              X402PaymentState.rejected ||
              X402PaymentState.expired ||
              X402PaymentState.blockedByPolicy ||
              X402PaymentState.failed =>
                'notSettled',
              _ => 'notStarted',
            };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'intentId': intentId,
        'state': state.name,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        if (transactionHash != null) 'transactionHash': transactionHash,
        if (payer != null) 'payer': payer,
        if (errorCode != null) 'errorCode': errorCode,
        if (providerId != null) 'providerId': providerId,
        if (network != null) 'network': network,
        if (asset != null) 'asset': asset,
        if (amount != null) 'amount': amount,
        if (payTo != null) 'payTo': payTo,
        if (resourceUrl != null) 'resourceUrl': resourceUrl,
        if (challengeHash != null) 'challengeHash': challengeHash,
        if (httpStatus != null) 'httpStatus': httpStatus,
        if (requestFingerprint != null)
          'requestFingerprint': requestFingerprint,
        if (modelId != null) 'modelId': modelId,
        if (paidRetryConsumed) 'paidRetryConsumed': true,
      };

  /// Redacted, interpretation-safe shape exposed to the agent. Persistence
  /// remains backward-compatible through [toJson], while callers can no longer
  /// mistake successful content delivery for verified settlement.
  Map<String, dynamic> toAgentJson() => <String, dynamic>{
        ...toJson(),
        'deliveryStatus': deliveryStatus,
        'settlementStatus': settlementStatus,
        'retryAllowed': retryAllowed,
        if (responseDeliveredSettlementUnverified)
          'statusSummary':
              'Model response delivered; settlement proof was not returned.',
      };

  factory X402PaymentReceipt.fromJson(Map<String, dynamic> json) {
    final stateName = json['state']?.toString();
    X402PaymentState? state;
    for (final value in X402PaymentState.values) {
      if (value.name == stateName) {
        state = value;
        break;
      }
    }
    final recordedAt = DateTime.tryParse(json['recordedAt']?.toString() ?? '');
    if (state == null || recordedAt == null) {
      throw const FormatException('Invalid x402 receipt.');
    }
    return X402PaymentReceipt(
      intentId: json['intentId']?.toString() ?? '',
      state: state,
      recordedAt: recordedAt.toUtc(),
      transactionHash: json['transactionHash']?.toString(),
      payer: json['payer']?.toString(),
      errorCode: json['errorCode']?.toString(),
      providerId: json['providerId']?.toString(),
      network: json['network']?.toString(),
      asset: json['asset']?.toString(),
      amount: json['amount']?.toString(),
      payTo: json['payTo']?.toString(),
      resourceUrl: json['resourceUrl']?.toString(),
      challengeHash: json['challengeHash']?.toString(),
      httpStatus: (json['httpStatus'] as num?)?.toInt(),
      requestFingerprint: json['requestFingerprint']?.toString(),
      modelId: json['modelId']?.toString(),
      paidRetryConsumed: json['paidRetryConsumed'] == true,
    );
  }
}

class X402PaymentPolicyException implements Exception {
  const X402PaymentPolicyException(this.message);

  final String message;

  @override
  String toString() => 'X402PaymentPolicyException: $message';
}

/// Single-active-intent gate shared by the future transport and approval UI.
///
/// This service intentionally stops before signing. The later wallet signer
/// must call [claimForSigning] only after fresh Android device authentication;
/// no method here accepts a private key or a generic wallet transfer.
class X402PaymentApprovalService {
  X402PaymentApprovalService({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  PendingPaymentIntent? _active;
  PendingPaymentIntent? _lastTerminal;
  PaymentApprovalTicket? _ticket;

  PendingPaymentIntent? get activeIntent => _active;
  PendingPaymentIntent? get lastTerminalIntent => _lastTerminal;

  PendingPaymentIntent createIntent({
    required X402PaymentChallenge challenge,
    required String requestMethod,
    required Uri requestUrl,
    required List<int> requestBody,
  }) {
    _expireIfNeeded();
    if (_active != null) {
      throw const X402PaymentPolicyException(
          'Another payment approval is already active.');
    }
    if (requestUrl.toString() != challenge.resourceUrl.toString()) {
      throw const X402PaymentPolicyException(
          'Payment resource does not match the original request.');
    }
    if (!challenge.resourceUrl.hasScheme ||
        challenge.resourceUrl.scheme != 'https') {
      throw const X402PaymentPolicyException(
          'Payment resource must use HTTPS.');
    }
    final now = _clock().toUtc();
    final maxWindow =
        Duration(seconds: challenge.requirement.maxTimeoutSeconds);
    final expiresAt = now.add(maxWindow);
    final intent = PendingPaymentIntent(
      intentId: const Uuid().v4(),
      approvalNonce: const Uuid().v4(),
      paymentNonce: _randomNonce(),
      createdAt: now,
      expiresAt: expiresAt,
      requestMethod: requestMethod.trim().toUpperCase(),
      requestUrl: requestUrl,
      requestBodyHash: bytesToHex(keccak256(Uint8List.fromList(requestBody))),
      challenge: challenge,
      state: X402PaymentState.awaitingHumanApproval,
    );
    _active = intent;
    return intent;
  }

  PaymentApprovalTicket approve(
    String intentId, {
    required PaymentApprovalSource source,
  }) {
    _expireIfNeeded();
    final intent = _requireActive(intentId);
    if (source != PaymentApprovalSource.visibleUi) {
      throw const X402PaymentPolicyException(
          'Only the visible payment approval UI can approve a payment.');
    }
    final ticket = PaymentApprovalTicket(
      intentId: intent.intentId,
      approvalNonce: intent.approvalNonce,
      issuedAt: _clock().toUtc(),
    );
    _ticket = ticket;
    _active = intent.copyWith(state: X402PaymentState.awaitingWalletUnlock);
    return ticket;
  }

  void reject(String intentId) {
    final intent = _requireActive(intentId);
    _lastTerminal = intent.copyWith(state: X402PaymentState.rejected);
    _active = null;
    _ticket = null;
  }

  /// Claims the approved intent for exactly one future cryptographic signing.
  /// The Android-authenticated signer owns the device-auth step; this method
  /// only enforces the intent/ticket/replay boundary.
  PendingPaymentIntent claimForSigning(PaymentApprovalTicket ticket) {
    _expireIfNeeded();
    final intent = _requireActive(ticket.intentId);
    if (_ticket == null ||
        _ticket!.approvalNonce != ticket.approvalNonce ||
        intent.state != X402PaymentState.awaitingWalletUnlock) {
      throw const X402PaymentPolicyException(
          'Payment approval is invalid or has already been consumed.');
    }
    _ticket = null;
    _active = intent.copyWith(state: X402PaymentState.signing);
    return _active!;
  }

  void markSubmitted(String intentId) {
    final intent = _requireActive(intentId);
    if (intent.state != X402PaymentState.signing) {
      throw const X402PaymentPolicyException(
          'Payment was not claimed for signing.');
    }
    _active = intent.copyWith(state: X402PaymentState.submitted);
  }

  X402PaymentReceipt recordReceipt({
    required String intentId,
    required X402PaymentState state,
    String? transactionHash,
    String? payer,
    String? errorCode,
    String? providerId,
    int? httpStatus,
    String? requestFingerprint,
    String? modelId,
    bool paidRetryConsumed = false,
  }) {
    final intent = _requireActive(intentId);
    if (!const {
      X402PaymentState.settled,
      X402PaymentState.uncertain,
      X402PaymentState.failed,
    }.contains(state)) {
      throw const X402PaymentPolicyException('Invalid final payment state.');
    }
    _lastTerminal = intent.copyWith(state: state);
    _active = null;
    _ticket = null;
    return X402PaymentReceipt(
      intentId: intentId,
      state: state,
      recordedAt: _clock().toUtc(),
      transactionHash: transactionHash,
      payer: payer,
      errorCode: errorCode,
      providerId: providerId,
      network: intent.challenge.requirement.network,
      asset: intent.challenge.requirement.asset,
      amount: intent.challenge.requirement.amount,
      payTo: intent.challenge.requirement.payTo,
      resourceUrl: intent.requestUrl.toString(),
      challengeHash: intent.challenge.challengeHash,
      httpStatus: httpStatus,
      requestFingerprint: requestFingerprint,
      modelId: modelId,
      paidRetryConsumed: paidRetryConsumed,
    );
  }

  void _expireIfNeeded() {
    final intent = _active;
    if (intent != null && !intent.expiresAt.isAfter(_clock().toUtc())) {
      _lastTerminal = intent.copyWith(state: X402PaymentState.expired);
      _active = null;
      _ticket = null;
    }
  }

  PendingPaymentIntent _requireActive(String intentId) {
    final intent = _active;
    if (intent == null || intent.intentId != intentId) {
      throw const X402PaymentPolicyException('Payment intent is not active.');
    }
    return intent;
  }
}

X402PaymentRequirement? _parseRequirement(Map<dynamic, dynamic> raw) {
  final scheme = raw['scheme']?.toString().trim().toLowerCase();
  final network = raw['network']?.toString().trim();
  final amount = raw['amount']?.toString().trim();
  final asset = raw['asset']?.toString().trim().toLowerCase();
  final payTo = raw['payTo']?.toString().trim();
  final timeout = raw['maxTimeoutSeconds'];
  if (scheme == null ||
      network == null ||
      amount == null ||
      asset == null ||
      payTo == null ||
      timeout is! num) {
    return null;
  }
  final extra = raw['extra'];
  return X402PaymentRequirement(
    scheme: scheme,
    network: network,
    amount: amount,
    asset: asset,
    payTo: payTo,
    maxTimeoutSeconds: timeout.toInt(),
    extra: extra is Map
        ? extra.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{},
  );
}

bool _isAllowedRequirement(
  X402PaymentRequirement requirement,
  X402PaymentPolicy policy,
) {
  final name = requirement.extra['name']?.toString().trim() ?? '';
  final version = requirement.extra['version']?.toString().trim() ?? '';
  if (requirement.scheme != 'exact' ||
      requirement.network != X402PaymentPolicy.network ||
      requirement.asset != X402PaymentPolicy.usdc ||
      requirement.assetTransferMethod != X402PaymentPolicy.transferMethod ||
      !RegExp(r'^0x[a-f0-9]{40}$').hasMatch(requirement.payTo.toLowerCase()) ||
      name.isEmpty ||
      name.length > 64 ||
      version.isEmpty ||
      version.length > 16) {
    return false;
  }
  final amount = BigInt.tryParse(requirement.amount);
  return amount != null &&
      amount > BigInt.zero &&
      amount <= BigInt.from(policy.maxAmount) &&
      requirement.maxTimeoutSeconds > 0 &&
      requirement.maxTimeoutSeconds <= policy.maxTimeoutSeconds;
}

Map<String, dynamic> _decodeHeaderJson(String header) {
  final value = header.trim();
  if (value.isEmpty) {
    throw const X402PaymentPolicyException('PAYMENT-REQUIRED is empty.');
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {}

  try {
    final decoded =
        jsonDecode(utf8.decode(base64.decode(base64.normalize(value))));
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {}
  try {
    final decoded =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(value))));
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {}
  throw const X402PaymentPolicyException('PAYMENT-REQUIRED is not valid JSON.');
}

int _positiveInt(dynamic value) {
  if (value is int && value > 0) return value;
  throw const X402PaymentPolicyException('x402 version is invalid.');
}

String _canonicalJson(dynamic value) {
  dynamic canonicalize(dynamic item) {
    if (item is Map) {
      final entries = item.entries
          .map((entry) =>
              MapEntry(entry.key.toString(), canonicalize(entry.value)))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return <String, dynamic>{
        for (final entry in entries) entry.key: entry.value
      };
    }
    if (item is List) return item.map(canonicalize).toList(growable: false);
    return item;
  }

  return jsonEncode(canonicalize(value));
}

String _randomNonce() {
  final random = Random.secure();
  final bytes = Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
  return '0x${bytesToHex(bytes)}';
}
