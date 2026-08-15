import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_payment_provider_catalog.dart';
import 'commerce_receipt.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';
import 'provider_balance_service.dart';
import 'x402_payment_service.dart';

typedef X402AuthorizationSigner =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> authorization);
typedef X402ProviderBalanceRefresher =
    Future<void> Function(String providerId, String walletAddress);

class X402TransportException implements Exception {
  const X402TransportException(this.code, this.message, {this.httpStatus});

  final String code;
  final String message;
  final int? httpStatus;

  @override
  String toString() => message;
}

class PreparedX402Payment {
  const PreparedX402Payment({
    required this.provider,
    required this.intent,
    required this.requestBody,
  });

  final AiPaymentProviderOption provider;
  final PendingPaymentIntent intent;
  final Uint8List requestBody;

  double get amountUsd =>
      intent.challenge.requirement.amountUnits.toDouble() / 1000000;
}

class X402PaymentReceiptStore {
  X402PaymentReceiptStore({PreferencesService? preferences})
    : _preferences = preferences ?? PreferencesService();

  static const int maxReceipts = 40;
  final PreferencesService _preferences;

  Future<List<X402PaymentReceipt>> read() async {
    await _preferences.init();
    final receipts = <X402PaymentReceipt>[];
    for (final encoded in _preferences.x402PaymentReceipts) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map) {
          receipts.add(
            X402PaymentReceipt.fromJson(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      } catch (_) {
        // Ignore old or corrupt redacted receipts individually.
      }
    }
    receipts.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return receipts.take(maxReceipts).toList(growable: false);
  }

  Future<void> append(X402PaymentReceipt receipt) async {
    final current = await read();
    final encoded = <String>[
      jsonEncode(receipt.toJson()),
      ...current
          .where((item) => item.intentId != receipt.intentId)
          .map((item) => jsonEncode(item.toJson())),
    ].take(maxReceipts).toList(growable: false);
    await _preferences.setX402PaymentReceipts(encoded);
  }
}

/// Executes one deliberately narrow x402 v2 flow:
///
/// 1. Make the unsigned request once and require an allowlisted 402 challenge.
/// 2. Bind the challenge to method, URL, and body hash.
/// 3. Accept approval only from the visible UI.
/// 4. Ask Android's authenticated, policy-bound signer for one EIP-3009
///    authorization.
/// 5. Retry the identical request exactly once without following redirects.
///
/// It never owns a private key and never automatically approves, signs, or
/// retries a second payment.
class X402PaymentTransportService {
  X402PaymentTransportService({
    http.Client? client,
    X402PaymentApprovalService? approvalService,
    X402AuthorizationSigner? signer,
    X402PaymentReceiptStore? receiptStore,
    CommerceReceiptStore? commerceReceiptStore,
    X402ProviderBalanceRefresher? balanceRefresher,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       approvalService = approvalService ?? X402PaymentApprovalService(),
       _signer = signer ?? NativeBridge.signSecureX402Authorization,
       _balanceRefresher = balanceRefresher ?? _refreshProviderBalance,
       receiptStore = receiptStore ?? X402PaymentReceiptStore(),
       commerceReceiptStore = commerceReceiptStore ?? CommerceReceiptStore(),
       _clock = clock ?? DateTime.now;

  static const int maxChallengeHeaderBytes = 32 * 1024;
  static const int maxResponseBytes = 256 * 1024;

  final http.Client _client;
  final bool _ownsClient;
  final X402AuthorizationSigner _signer;
  final X402ProviderBalanceRefresher _balanceRefresher;
  final DateTime Function() _clock;
  final X402PaymentApprovalService approvalService;
  final X402PaymentReceiptStore receiptStore;
  final CommerceReceiptStore commerceReceiptStore;

  Future<PreparedX402Payment> prepareTopUp(
    AiPaymentProviderOption provider,
  ) async {
    final endpoint = provider.topUpEndpoint;
    if (!provider.supportsTopUp || endpoint == null) {
      throw const X402TransportException(
        'TOP_UP_UNSUPPORTED',
        'This provider does not use a prepaid x402 top-up.',
      );
    }
    final policy = X402PaymentPolicy(allowedHosts: provider.allowedHosts);
    if (!policy.allowsHost(endpoint)) {
      throw const X402TransportException(
        'HOST_BLOCKED',
        'The provider top-up endpoint is not allowlisted.',
      );
    }

    final body = Uint8List(0);
    final response = await _sendExact(
      method: 'POST',
      url: endpoint,
      body: body,
      headers: const <String, String>{'Accept': 'application/json'},
    );
    if (response.statusCode != 402) {
      throw X402TransportException(
        'CHALLENGE_EXPECTED',
        'The provider did not return the expected payment challenge.',
        httpStatus: response.statusCode,
      );
    }
    final required =
        _header(response.headers, 'payment-required') ??
        _header(response.headers, 'x-payment-required');
    if (required == null || required.isEmpty) {
      throw const X402TransportException(
        'CHALLENGE_MISSING',
        'The 402 response did not include PAYMENT-REQUIRED.',
        httpStatus: 402,
      );
    }
    if (utf8.encode(required).length > maxChallengeHeaderBytes) {
      throw const X402TransportException(
        'CHALLENGE_TOO_LARGE',
        'The payment challenge exceeded the safe size limit.',
        httpStatus: 402,
      );
    }

    final challenge = X402PaymentChallenge.fromHeader(
      required,
      policy: policy,
      resourceUrlFallback: provider.allowsResourceLessTopUpChallenge
          ? endpoint
          : null,
      resourceDescriptionFallback: '${provider.label} x402 top-up',
    );
    final intent = approvalService.createIntent(
      challenge: challenge,
      requestMethod: 'POST',
      requestUrl: endpoint,
      requestBody: body,
    );
    return PreparedX402Payment(
      provider: provider,
      intent: intent,
      requestBody: body,
    );
  }

  void reject(PreparedX402Payment payment) {
    approvalService.reject(payment.intent.intentId);
  }

  Future<X402PaymentReceipt> approveAndSubmit(
    PreparedX402Payment payment, {
    required String walletAddress,
  }) async {
    if (!X402PaymentPolicy.liveSigningEnabled) {
      throw const X402TransportException(
        'LIVE_SIGNING_DISABLED',
        'Mainnet x402 signing is disabled in this build.',
      );
    }
    final normalizedWallet = walletAddress.trim();
    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(normalizedWallet)) {
      throw const X402TransportException(
        'WALLET_REQUIRED',
        'A valid secure Base wallet is required.',
      );
    }

    var submitted = false;
    try {
      final ticket = approvalService.approve(
        payment.intent.intentId,
        source: PaymentApprovalSource.visibleUi,
      );
      final intent = approvalService.claimForSigning(ticket);
      final now = _clock().toUtc();
      final validAfter =
          now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch ~/
          1000;
      final validBefore = intent.expiresAt.millisecondsSinceEpoch ~/ 1000;
      final requirement = intent.challenge.requirement;
      final signatureResult = await _signer(<String, dynamic>{
        'host': intent.requestUrl.host,
        'chainId': 8453,
        'verifyingContract': requirement.asset,
        'from': normalizedWallet,
        'to': requirement.payTo,
        'value': requirement.amount,
        'validAfter': validAfter,
        'validBefore': validBefore,
        'nonce': intent.paymentNonce,
        'name': requirement.extra['name']?.toString(),
        'version': requirement.extra['version']?.toString(),
      });
      final signature = signatureResult['signature']?.toString() ?? '';
      final payer = signatureResult['payer']?.toString() ?? '';
      if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature) ||
          payer.toLowerCase() != normalizedWallet.toLowerCase()) {
        throw const X402TransportException(
          'SIGNATURE_INVALID',
          'The authenticated wallet returned an invalid payment signature.',
        );
      }

      final paymentPayload = buildX402V2PaymentPayload(
        intent: intent,
        signature: signature,
        payer: payer,
        validAfter: validAfter,
        validBefore: validBefore,
      );
      final paymentHeader = base64Encode(
        utf8.encode(jsonEncode(paymentPayload)),
      );

      approvalService.markSubmitted(intent.intentId);
      submitted = true;
      final response = await _sendExact(
        method: intent.requestMethod,
        url: intent.requestUrl,
        body: payment.requestBody,
        headers: <String, String>{
          'Accept': 'application/json',
          payment.provider.paymentHeaderName: paymentHeader,
        },
      );
      final settled = response.statusCode >= 200 && response.statusCode < 300;
      final receipt = approvalService.recordReceipt(
        intentId: intent.intentId,
        state: settled ? X402PaymentState.settled : X402PaymentState.failed,
        transactionHash: _transactionHash(response),
        payer: payer,
        providerId: payment.provider.id,
        httpStatus: response.statusCode,
        errorCode: settled ? null : 'SETTLEMENT_HTTP_${response.statusCode}',
      );
      await _appendSafely(receipt);
      if (settled) {
        await _refreshBalanceSafely(payment.provider.id, normalizedWallet);
      }
      return receipt;
    } catch (error) {
      final active = approvalService.activeIntent;
      if (active != null && active.intentId == payment.intent.intentId) {
        final receipt = approvalService.recordReceipt(
          intentId: active.intentId,
          state: submitted
              ? X402PaymentState.uncertain
              : X402PaymentState.failed,
          providerId: payment.provider.id,
          errorCode: submitted ? 'SETTLEMENT_UNCERTAIN' : 'SIGNING_FAILED',
        );
        await _appendSafely(receipt);
      }
      rethrow;
    }
  }

  Future<http.Response> _sendExact({
    required String method,
    required Uri url,
    required Uint8List body,
    required Map<String, String> headers,
  }) async {
    if (url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        url.fragment.isNotEmpty) {
      throw const X402TransportException(
        'REQUEST_URL_BLOCKED',
        'Payment requests require a plain HTTPS provider URL.',
      );
    }
    final request = http.Request(method, url)
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = false
      ..headers.addAll(headers)
      ..bodyBytes = body;
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in streamed.stream.timeout(
      const Duration(seconds: 30),
    )) {
      length += chunk.length;
      if (length > maxResponseBytes) {
        throw const X402TransportException(
          'RESPONSE_TOO_LARGE',
          'The provider response exceeded the safe size limit.',
        );
      }
      bytes.add(chunk);
    }
    return http.Response.bytes(
      bytes.takeBytes(),
      streamed.statusCode,
      headers: streamed.headers,
      reasonPhrase: streamed.reasonPhrase,
      request: request,
    );
  }

  String? _transactionHash(http.Response response) {
    final encoded =
        _header(response.headers, 'payment-response') ??
        _header(response.headers, 'x-payment-response');
    if (encoded != null && encoded.length <= maxChallengeHeaderBytes) {
      final decoded = _decodeHeader(encoded);
      final found = _findTransactionHash(decoded);
      if (found != null) return found;
    }
    if (response.bodyBytes.length <= maxResponseBytes) {
      try {
        return _findTransactionHash(jsonDecode(response.body));
      } catch (_) {}
    }
    return null;
  }

  Future<void> _appendSafely(X402PaymentReceipt receipt) async {
    try {
      await receiptStore.append(receipt);
    } catch (_) {
      // A provider-confirmed payment must never look retryable merely because
      // local redacted receipt persistence failed.
    }
    try {
      await commerceReceiptStore.append(CommerceReceipt.fromX402(receipt));
    } catch (_) {
      // The commerce projection is best-effort and never changes settlement
      // semantics or makes a confirmed provider payment retryable.
    }
  }

  Future<void> _refreshBalanceSafely(
    String providerId,
    String walletAddress,
  ) async {
    try {
      await _balanceRefresher(providerId, walletAddress);
    } catch (_) {
      // A provider-confirmed settlement remains terminal when a follow-up
      // balance read is temporarily unavailable.
    }
  }

  static Future<void> _refreshProviderBalance(
    String providerId,
    String walletAddress,
  ) async {
    final provider = AiPaymentProviderCatalog.byId(providerId);
    if (provider == null) return;
    await ProviderBalanceService.instance.refreshWalletProvider(
      provider: provider,
      walletAddress: walletAddress,
    );
  }

  dynamic _decodeHeader(String header) {
    try {
      return jsonDecode(utf8.decode(base64.decode(base64.normalize(header))));
    } catch (_) {
      try {
        return jsonDecode(header);
      } catch (_) {
        return null;
      }
    }
  }

  String? _header(Map<String, String> headers, String name) {
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target) return entry.value;
    }
    return null;
  }

  String? _findTransactionHash(dynamic value, [int depth = 0]) {
    if (depth > 5) return null;
    if (value is Map) {
      for (final key in const <String>[
        'transactionHash',
        'transaction',
        'txHash',
        'tx_hash',
      ]) {
        final candidate = value[key]?.toString();
        if (candidate != null &&
            RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(candidate)) {
          return candidate;
        }
      }
      for (final nested in value.values) {
        final found = _findTransactionHash(nested, depth + 1);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final nested in value) {
        final found = _findTransactionHash(nested, depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
