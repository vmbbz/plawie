import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

typedef SecureRandomBytes = Uint8List Function(int length);

/// Owns the capability used only between the local gateway and the
/// paid-provider loopback proxy. It is never exposed to UI, logs, preferences,
/// receipts, or analytics. Native Gateway continuity may restore it from the
/// app-private OpenClaw provider config after a Flutter process restart.
class PaidProviderLoopbackCredentialService {
  PaidProviderLoopbackCredentialService({SecureRandomBytes? randomBytes})
      : _randomBytes = randomBytes ?? _secureRandomBytes {
    _credential = _issueCredential();
  }

  final SecureRandomBytes _randomBytes;
  late String _credential;

  /// Narrow handoff for gateway process configuration. Do not expose this in
  /// UI state, logs, receipts, analytics, or durable storage.
  String credentialForGatewayConfiguration() => _credential;

  bool matchesAuthorizationHeader(String? authorizationHeader) {
    const prefix = 'Bearer ';
    if (authorizationHeader == null ||
        !authorizationHeader.startsWith(prefix)) {
      return false;
    }
    return _constantTimeEquals(
      authorizationHeader.substring(prefix.length),
      _credential,
    );
  }

  void rotate({required bool gatewayStopped, required bool proxyStopped}) {
    if (!gatewayStopped || !proxyStopped) {
      throw StateError(
        'The loopback capability can rotate only while gateway and proxy are stopped.',
      );
    }
    _credential = _issueCredential();
  }

  void restoreFromGatewayConfiguration(
    String credential, {
    required bool proxyStopped,
  }) {
    if (!proxyStopped) {
      throw StateError(
        'The loopback capability cannot change while the proxy is running.',
      );
    }
    if (!isValidGatewayCredential(credential)) {
      throw const FormatException('Invalid paid-provider loopback capability.');
    }
    _credential = credential;
  }

  static bool isValidGatewayCredential(String credential) =>
      RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(credential);

  String _issueCredential() {
    final bytes = _randomBytes(32);
    if (bytes.length != 32) {
      throw StateError('Secure random source did not return 32 bytes.');
    }
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static bool _constantTimeEquals(String candidate, String expected) {
    final candidateBytes = utf8.encode(candidate);
    final expectedBytes = utf8.encode(expected);
    final maxLength = max(candidateBytes.length, expectedBytes.length);
    var difference = candidateBytes.length ^ expectedBytes.length;
    for (var index = 0; index < maxLength; index++) {
      final candidateByte =
          index < candidateBytes.length ? candidateBytes[index] : 0;
      final expectedByte =
          index < expectedBytes.length ? expectedBytes[index] : 0;
      difference |= candidateByte ^ expectedByte;
    }
    return difference == 0;
  }

  @override
  String toString() => 'PaidProviderLoopbackCredentialService(inMemory: true)';
}
