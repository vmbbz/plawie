import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_payment_provider_catalog.dart';
import 'api_key_detection_service.dart';
import 'native_bridge.dart';

enum ProviderBalanceKind {
  prepaidBalance,
  purchasedCredits,
  usageAndCost,
  dashboardOnly,
  unavailable,
}

enum ProviderBalanceState {
  available,
  low,
  depleted,
  notConfigured,
  requiresElevatedCredential,
  dashboardOnly,
  unavailable,
  error,
}

class ProviderBalanceSnapshot {
  const ProviderBalanceSnapshot({
    required this.providerId,
    required this.providerLabel,
    required this.kind,
    required this.state,
    required this.refreshedAt,
    required this.summary,
    this.remainingUsd,
    this.totalUsd,
    this.usedUsd,
    this.canConsume,
    this.minimumTopUpUsd,
    this.suggestedTopUpUsd,
    this.managementUrl,
  });

  final String providerId;
  final String providerLabel;
  final ProviderBalanceKind kind;
  final ProviderBalanceState state;
  final DateTime refreshedAt;
  final String summary;
  final double? remainingUsd;
  final double? totalUsd;
  final double? usedUsd;
  final bool? canConsume;
  final double? minimumTopUpUsd;
  final double? suggestedTopUpUsd;
  final Uri? managementUrl;

  bool get needsAttention => const <ProviderBalanceState>{
        ProviderBalanceState.low,
        ProviderBalanceState.depleted,
        ProviderBalanceState.error,
      }.contains(state);

  Map<String, dynamic> toAgentJson() => <String, dynamic>{
        'providerId': providerId,
        'providerLabel': providerLabel,
        'kind': kind.name,
        'state': state.name,
        'refreshedAt': refreshedAt.toUtc().toIso8601String(),
        'summary': summary,
        if (remainingUsd != null) 'remainingUsd': remainingUsd,
        if (totalUsd != null) 'totalUsd': totalUsd,
        if (usedUsd != null) 'usedUsd': usedUsd,
        if (canConsume != null) 'canConsume': canConsume,
        if (minimumTopUpUsd != null) 'minimumTopUpUsd': minimumTopUpUsd,
        if (suggestedTopUpUsd != null) 'suggestedTopUpUsd': suggestedTopUpUsd,
        if (managementUrl != null) 'managementUrl': managementUrl.toString(),
        'mayApproveOrSpend': false,
      };
}

typedef VeniceIdentitySigner = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> identity,
);
typedef ProviderWalletStatusReader = Future<SecureWalletStatus> Function();

/// Provider balances are intentionally modeled per provider. A standard API
/// key is never silently treated as an admin/billing key, and providers with
/// dashboard-only billing do not get a fabricated numeric balance.
class ProviderBalanceService {
  ProviderBalanceService({
    http.Client? client,
    VeniceIdentitySigner? veniceSigner,
    ProviderWalletStatusReader? walletStatus,
    ApiKeyDetectionService? apiKeys,
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _veniceSigner =
            veniceSigner ?? NativeBridge.signSecureVeniceBalanceIdentity,
        _walletStatus = walletStatus ?? NativeBridge.getSecureEvmWalletStatus,
        _apiKeys = apiKeys ?? ApiKeyDetectionService(),
        _clock = clock ?? DateTime.now;

  static final ProviderBalanceService instance = ProviderBalanceService();
  static const int maxResponseBytes = 128 * 1024;

  final http.Client _client;
  final bool _ownsClient;
  final VeniceIdentitySigner _veniceSigner;
  final ProviderWalletStatusReader _walletStatus;
  final ApiKeyDetectionService _apiKeys;
  final DateTime Function() _clock;
  final Map<String, ProviderBalanceSnapshot> _snapshots =
      <String, ProviderBalanceSnapshot>{};
  _CachedVeniceIdentity? _veniceIdentity;

  List<ProviderBalanceSnapshot> get cachedSnapshots {
    final values = _snapshots.values.toList(growable: false)
      ..sort((a, b) => a.providerLabel.compareTo(b.providerLabel));
    return values;
  }

  ProviderBalanceSnapshot? cached(String providerId) =>
      _snapshots[providerId.trim().toLowerCase()];

  Future<ProviderBalanceSnapshot> refresh(String providerId) async {
    final normalized = providerId.trim().toLowerCase();
    if (normalized == 'openrouter') return refreshOpenRouter();
    final provider = AiPaymentProviderCatalog.byId(normalized);
    if (provider == null) {
      throw ArgumentError.value(providerId, 'providerId', 'Unknown provider.');
    }
    if (normalized != 'venice') {
      return refreshWalletProvider(provider: provider, walletAddress: '');
    }
    final status = await _walletStatus();
    final address = status.address?.trim() ?? '';
    if (!status.isConnected || !status.authenticationAvailable) {
      return _remember(ProviderBalanceSnapshot(
        providerId: provider.id,
        providerLabel: provider.label,
        kind: ProviderBalanceKind.prepaidBalance,
        state: ProviderBalanceState.notConfigured,
        refreshedAt: _clock().toUtc(),
        summary: 'A healthy device-authenticated Base wallet is required.',
        managementUrl: Uri.parse('https://venice.ai/settings/api'),
      ));
    }
    return refreshWalletProvider(
      provider: provider,
      walletAddress: address,
    );
  }

  /// Records Venice's documented response balance hint without persisting raw
  /// headers. A malformed or implausible value is ignored.
  ProviderBalanceSnapshot? captureVeniceRemainingBalance(String value) {
    final remaining = double.tryParse(value.trim());
    if (remaining == null ||
        !remaining.isFinite ||
        remaining < 0 ||
        remaining > 1000000000000) {
      return null;
    }
    final previous = cached('venice');
    final lowThreshold =
        (previous?.minimumTopUpUsd ?? previous?.suggestedTopUpUsd ?? 1)
            .clamp(0.5, 5)
            .toDouble();
    final state = remaining <= 0
        ? ProviderBalanceState.depleted
        : remaining <= lowThreshold
            ? ProviderBalanceState.low
            : ProviderBalanceState.available;
    return _remember(ProviderBalanceSnapshot(
      providerId: 'venice',
      providerLabel: 'Venice',
      kind: ProviderBalanceKind.prepaidBalance,
      state: state,
      refreshedAt: _clock().toUtc(),
      summary: '\$${remaining.toStringAsFixed(2)} spendable',
      remainingUsd: remaining,
      canConsume: remaining > 0,
      minimumTopUpUsd: previous?.minimumTopUpUsd,
      suggestedTopUpUsd: previous?.suggestedTopUpUsd,
      managementUrl: Uri.parse('https://venice.ai/settings/api'),
    ));
  }

  Future<ProviderBalanceSnapshot> refreshWalletProvider({
    required AiPaymentProviderOption provider,
    required String walletAddress,
  }) async {
    if (provider.id != 'venice') {
      return _remember(ProviderBalanceSnapshot(
        providerId: provider.id,
        providerLabel: provider.label,
        kind: provider.fundingMode == AiPaymentFundingMode.prepaidBalance
            ? ProviderBalanceKind.prepaidBalance
            : ProviderBalanceKind.unavailable,
        state: ProviderBalanceState.unavailable,
        refreshedAt: _clock().toUtc(),
        summary: provider.fundingMode == AiPaymentFundingMode.perRequest
            ? 'This provider charges per request and has no prepaid balance.'
            : 'No verified balance adapter is available.',
      ));
    }
    return _refreshVenice(walletAddress);
  }

  Future<ProviderBalanceSnapshot> _refreshVenice(String walletAddress) async {
    final address = walletAddress.trim();
    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address)) {
      throw const FormatException('A valid Base wallet is required.');
    }
    final uri = Uri.parse(
      'https://api.venice.ai/api/v1/x402/balance/$address',
    );
    final identity = await _veniceIdentityHeader(address, uri);
    final response = await _send(
      http.Request('GET', uri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..persistentConnection = false
        ..headers['Accept'] = 'application/json'
        ..headers['X-Sign-In-With-X'] = identity,
    );
    if (response.statusCode != 200) {
      _veniceIdentity = null;
      final state = response.statusCode == 401
          ? ProviderBalanceState.error
          : ProviderBalanceState.unavailable;
      return _remember(ProviderBalanceSnapshot(
        providerId: 'venice',
        providerLabel: 'Venice',
        kind: ProviderBalanceKind.prepaidBalance,
        state: state,
        refreshedAt: _clock().toUtc(),
        summary: response.statusCode == 401
            ? 'Wallet sign-in was rejected; refresh to create a fresh identity.'
            : 'Venice balance is temporarily unavailable (HTTP ${response.statusCode}).',
        managementUrl: Uri.parse('https://venice.ai/settings/api'),
      ));
    }
    final decoded = jsonDecode(response.body);
    final body = decoded is Map && decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : decoded is Map
            ? decoded.map((key, value) => MapEntry(key.toString(), value))
            : const <String, dynamic>{};
    final remaining = _number(body['balanceUsd']);
    final minimum = _number(body['minimumTopUpUsd']);
    final suggested = _number(body['suggestedTopUpUsd']);
    final canConsume = body['canConsume'] == true;
    final state = !canConsume || (remaining != null && remaining <= 0)
        ? ProviderBalanceState.depleted
        : remaining != null &&
                remaining <= (minimum ?? suggested ?? 1).clamp(0.5, 5)
            ? ProviderBalanceState.low
            : ProviderBalanceState.available;
    return _remember(ProviderBalanceSnapshot(
      providerId: 'venice',
      providerLabel: 'Venice',
      kind: ProviderBalanceKind.prepaidBalance,
      state: state,
      refreshedAt: _clock().toUtc(),
      summary: remaining == null
          ? (canConsume
              ? 'Wallet is authorized to consume Venice services.'
              : 'Venice reports that this wallet cannot consume services.')
          : '\$${remaining.toStringAsFixed(2)} spendable',
      remainingUsd: remaining,
      canConsume: canConsume,
      minimumTopUpUsd: minimum,
      suggestedTopUpUsd: suggested,
      managementUrl: Uri.parse('https://venice.ai/settings/api'),
    ));
  }

  Future<ProviderBalanceSnapshot> refreshOpenRouter() async {
    final key = await _apiKeys.getApiKey('openrouter');
    if (key == null || key.trim().isEmpty) {
      return _remember(ProviderBalanceSnapshot(
        providerId: 'openrouter',
        providerLabel: 'OpenRouter',
        kind: ProviderBalanceKind.purchasedCredits,
        state: ProviderBalanceState.notConfigured,
        refreshedAt: _clock().toUtc(),
        summary: 'No OpenRouter key is configured.',
        managementUrl: Uri.parse('https://openrouter.ai/settings/credits'),
      ));
    }
    final request = http.Request(
      'GET',
      Uri.parse('https://openrouter.ai/api/v1/credits'),
    )
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = false
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $key';
    final response = await _send(request);
    if (response.statusCode == 403) {
      return _remember(ProviderBalanceSnapshot(
        providerId: 'openrouter',
        providerLabel: 'OpenRouter',
        kind: ProviderBalanceKind.purchasedCredits,
        state: ProviderBalanceState.requiresElevatedCredential,
        refreshedAt: _clock().toUtc(),
        summary:
            'The credits endpoint requires an OpenRouter management key; the chat key was not elevated.',
        managementUrl: Uri.parse('https://openrouter.ai/settings/credits'),
      ));
    }
    if (response.statusCode != 200) {
      return _remember(ProviderBalanceSnapshot(
        providerId: 'openrouter',
        providerLabel: 'OpenRouter',
        kind: ProviderBalanceKind.purchasedCredits,
        state: ProviderBalanceState.error,
        refreshedAt: _clock().toUtc(),
        summary:
            'OpenRouter credits are unavailable (HTTP ${response.statusCode}).',
        managementUrl: Uri.parse('https://openrouter.ai/settings/credits'),
      ));
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map && decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : const <String, dynamic>{};
    final total = _number(data['total_credits']);
    final used = _number(data['total_usage']);
    final remaining = total != null && used != null ? total - used : null;
    final state = remaining == null
        ? ProviderBalanceState.error
        : remaining <= 0
            ? ProviderBalanceState.depleted
            : remaining <= 2
                ? ProviderBalanceState.low
                : ProviderBalanceState.available;
    return _remember(ProviderBalanceSnapshot(
      providerId: 'openrouter',
      providerLabel: 'OpenRouter',
      kind: ProviderBalanceKind.purchasedCredits,
      state: state,
      refreshedAt: _clock().toUtc(),
      summary: remaining == null
          ? 'OpenRouter returned no usable credit totals.'
          : '\$${remaining.toStringAsFixed(2)} remaining',
      remainingUsd: remaining,
      totalUsd: total,
      usedUsd: used,
      managementUrl: Uri.parse('https://openrouter.ai/settings/credits'),
    ));
  }

  List<ProviderBalanceSnapshot> documentedDashboardOnlyStatuses() {
    final now = _clock().toUtc();
    return <ProviderBalanceSnapshot>[
      ProviderBalanceSnapshot(
        providerId: 'anthropic',
        providerLabel: 'Anthropic',
        kind: ProviderBalanceKind.usageAndCost,
        state: ProviderBalanceState.requiresElevatedCredential,
        refreshedAt: now,
        summary:
            'Usage/cost APIs require a separate Anthropic Admin API key; the chat key is never reused as one.',
        managementUrl:
            Uri.parse('https://console.anthropic.com/settings/billing'),
      ),
      ProviderBalanceSnapshot(
        providerId: 'google',
        providerLabel: 'Google Gemini',
        kind: ProviderBalanceKind.dashboardOnly,
        state: ProviderBalanceState.dashboardOnly,
        refreshedAt: now,
        summary:
            'Gemini prepaid balance and top-ups are managed in the AI Studio Billing page; no chat-key balance endpoint is documented.',
        managementUrl: Uri.parse('https://aistudio.google.com/'),
      ),
    ];
  }

  Future<String> _veniceIdentityHeader(String address, Uri uri) async {
    final cached = _veniceIdentity;
    final now = _clock().toUtc();
    if (cached != null &&
        cached.address.toLowerCase() == address.toLowerCase() &&
        cached.uri == uri &&
        cached.expiresAt.isAfter(now.add(const Duration(seconds: 15)))) {
      return cached.header;
    }
    final issuedAt = now;
    final expiresAt = now.add(const Duration(minutes: 5));
    final signed = await _veniceSigner(<String, dynamic>{
      'uri': uri.toString(),
      'nonce': _nonce(),
      'issuedAt': issuedAt.toIso8601String(),
      'expirationTime': expiresAt.toIso8601String(),
    });
    final payer = signed['payer']?.toString() ?? '';
    final message = signed['message']?.toString() ?? '';
    final signature = signed['signature']?.toString() ?? '';
    if (payer.toLowerCase() != address.toLowerCase() ||
        message.isEmpty ||
        !RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
      throw const FormatException('The secure wallet identity is invalid.');
    }
    final header = base64Encode(utf8.encode(jsonEncode(<String, dynamic>{
      'address': payer,
      'message': message,
      'signature': signature,
      'timestamp': issuedAt.millisecondsSinceEpoch,
      'chainId': 8453,
    })));
    _veniceIdentity = _CachedVeniceIdentity(
      address: address,
      uri: uri,
      header: header,
      expiresAt: expiresAt,
    );
    return header;
  }

  Future<http.Response> _send(http.Request request) async {
    if (request.url.scheme != 'https' || request.url.userInfo.isNotEmpty) {
      throw const FormatException('Provider balance URL must use HTTPS.');
    }
    final streamed = await _client.send(request).timeout(
          const Duration(seconds: 20),
        );
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk
        in streamed.stream.timeout(const Duration(seconds: 20))) {
      length += chunk.length;
      if (length > maxResponseBytes) {
        throw const FormatException('Provider balance response is too large.');
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

  ProviderBalanceSnapshot _remember(ProviderBalanceSnapshot snapshot) {
    _snapshots[snapshot.providerId] = snapshot;
    return snapshot;
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _nonce() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List<String>.generate(
      20,
      (_) => chars[random.nextInt(chars.length)],
      growable: false,
    ).join();
  }

  void dispose() {
    _veniceIdentity = null;
    if (_ownsClient) _client.close();
  }
}

class _CachedVeniceIdentity {
  const _CachedVeniceIdentity({
    required this.address,
    required this.uri,
    required this.header,
    required this.expiresAt,
  });

  final String address;
  final Uri uri;
  final String header;
  final DateTime expiresAt;
}
