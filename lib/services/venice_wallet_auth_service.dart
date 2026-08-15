import 'dart:convert';
import 'dart:math';

import 'native_bridge.dart';

typedef VeniceProviderIdentitySigner = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> identity,
);
typedef SecureWalletStatusReader = Future<SecureWalletStatus> Function();

class VeniceWalletAuthException implements Exception {
  const VeniceWalletAuthException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'VeniceWalletAuthException($code): $message';
}

/// Produces one fresh, bounded Venice X-Sign-In-With-X envelope. The Android
/// signer independently validates the same closed route table and never accepts
/// a caller-provided SIWE domain or statement.
class VeniceWalletAuthService {
  VeniceWalletAuthService({
    VeniceProviderIdentitySigner? signer,
    SecureWalletStatusReader? walletStatus,
    DateTime Function()? clock,
    String Function()? nonceFactory,
    this.responsesEnabled = false,
  })  : _signer = signer ?? NativeBridge.signSecureVeniceProviderIdentity,
        _walletStatus = walletStatus ?? NativeBridge.getSecureEvmWalletStatus,
        _clock = clock ?? DateTime.now,
        _nonceFactory = nonceFactory ?? _secureNonce;

  final VeniceProviderIdentitySigner _signer;
  final SecureWalletStatusReader _walletStatus;
  final DateTime Function() _clock;
  final String Function() _nonceFactory;
  final bool responsesEnabled;

  Future<String> authorize(String method, Uri uri) async {
    final status = await _walletStatus();
    final address = status.address?.trim() ?? '';
    if (!status.isConnected ||
        !status.authenticationAvailable ||
        !_addressPattern.hasMatch(address)) {
      throw const VeniceWalletAuthException(
        'wallet_not_ready',
        'A healthy device-authenticated Base wallet is required.',
      );
    }
    _validateRoute(method, uri, address);

    final issuedAt = _clock().toUtc();
    final expirationTime = issuedAt.add(const Duration(minutes: 5));
    final nonce = _nonceFactory();
    if (!_noncePattern.hasMatch(nonce)) {
      throw const VeniceWalletAuthException(
        'invalid_nonce',
        'The Venice identity nonce is invalid.',
      );
    }
    final issuedAtText = _iso8601(issuedAt);
    final expirationTimeText = _iso8601(expirationTime);
    final signed = await _signer(<String, dynamic>{
      'method': method,
      'uri': uri.toString(),
      'nonce': nonce,
      'issuedAt': issuedAtText,
      'expirationTime': expirationTimeText,
    });

    final payer = signed['payer']?.toString().trim() ?? '';
    final message = signed['message']?.toString() ?? '';
    final signature = signed['signature']?.toString() ?? '';
    final expectedMessage = _message(
      address: payer,
      uri: uri,
      nonce: nonce,
      issuedAt: issuedAtText,
      expirationTime: expirationTimeText,
    );
    if (!_addressPattern.hasMatch(payer) ||
        payer.toLowerCase() != address.toLowerCase() ||
        message != expectedMessage ||
        !_signaturePattern.hasMatch(signature)) {
      throw const VeniceWalletAuthException(
        'invalid_native_identity',
        'The secure Venice wallet identity did not match the requested route.',
      );
    }

    return base64Encode(utf8.encode(jsonEncode(<String, dynamic>{
      'address': payer,
      'message': message,
      'signature': signature,
      'timestamp': issuedAt.millisecondsSinceEpoch,
      'chainId': 8453,
    })));
  }

  void _validateRoute(String method, Uri uri, String address) {
    final modelsTextQuery = uri.path == '/api/v1/models' &&
        uri.queryParameters.length == 1 &&
        uri.queryParameters['type'] == 'text';
    if (uri.scheme != 'https' ||
        uri.host != 'api.venice.ai' ||
        (uri.hasPort && uri.port != 443) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasQuery && !modelsTextQuery) ||
        uri.hasFragment) {
      throw const VeniceWalletAuthException(
        'route_not_allowed',
        'The Venice identity origin is not allowed.',
      );
    }

    final balancePrefix = '/api/v1/x402/balance/';
    final allowed = (method == 'GET' && uri.path == '/api/v1/models') ||
        (method == 'POST' && uri.path == '/api/v1/chat/completions') ||
        (responsesEnabled &&
            method == 'POST' &&
            uri.path == '/api/v1/responses') ||
        (method == 'GET' &&
            uri.path.startsWith(balancePrefix) &&
            uri.path.substring(balancePrefix.length).toLowerCase() ==
                address.toLowerCase());
    if (!allowed) {
      throw const VeniceWalletAuthException(
        'route_not_allowed',
        'The Venice identity method and route are not allowed.',
      );
    }
  }

  static String _message({
    required String address,
    required Uri uri,
    required String nonce,
    required String issuedAt,
    required String expirationTime,
  }) =>
      'api.venice.ai wants you to sign in with your Ethereum account:\n'
      '$address\n\n'
      'Sign in to Venice AI\n\n'
      'URI: $uri\n'
      'Version: 1\n'
      'Chain ID: 8453\n'
      'Nonce: $nonce\n'
      'Issued At: $issuedAt\n'
      'Expiration Time: $expirationTime';

  static String _iso8601(DateTime value) {
    final encoded = value.toUtc().toIso8601String();
    return encoded.endsWith('.000Z')
        ? '${encoded.substring(0, encoded.length - 5)}Z'
        : encoded;
  }

  static String _secureNonce() {
    const characters =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List<String>.generate(
      20,
      (_) => characters[random.nextInt(characters.length)],
      growable: false,
    ).join();
  }

  static final _addressPattern = RegExp(r'^0x[a-fA-F0-9]{40}$');
  static final _signaturePattern = RegExp(r'^0x[a-fA-F0-9]{130}$');
  static final _noncePattern = RegExp(r'^[A-Za-z0-9]{8,64}$');
}
