import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages a persistent Ed25519 device identity for OpenClaw Gateway Protocol v3.
///
/// On first launch, generates an Ed25519 key pair and persists it.
/// Provides signing and device metadata for the connect frame's `device` block.
class DeviceIdentity {
  static const _prefPrivateKey = 'openclaw_device_ed25519_private';
  static const _prefPublicKey = 'openclaw_device_ed25519_public';
  static const _prefDeviceId = 'openclaw_device_id';

  final _algorithm = Ed25519();

  String? _deviceId;
  String? _publicKeyBase64Url;
  SimpleKeyPairData? _keyPair;

  String? get deviceId => _deviceId;
  String? get publicKeyBase64Url => _publicKeyBase64Url;

  /// Load existing identity from SharedPreferences, or generate a new one.
  Future<void> loadOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existingPrivate = prefs.getString(_prefPrivateKey);
    final existingPublic = prefs.getString(_prefPublicKey);
    final existingDeviceId = prefs.getString(_prefDeviceId);

    if (existingPrivate != null && existingPublic != null && existingDeviceId != null) {
      // Restore existing keys
      _deviceId = existingDeviceId;
      _publicKeyBase64Url = existingPublic;
      final privateBytes = base64Url.decode(existingPrivate);
      final publicBytes = base64Url.decode(existingPublic);
      final publicKey = SimplePublicKey(publicBytes, type: KeyPairType.ed25519);
      _keyPair = SimpleKeyPairData(
        privateBytes,
        publicKey: publicKey,
        type: KeyPairType.ed25519,
      );
      return;
    }

    // Generate new Ed25519 key pair
    final newKeyPair = await _algorithm.newKeyPair();
    _keyPair = await newKeyPair.extract();

    // Extract raw public key bytes (32 bytes)
    final publicKey = await newKeyPair.extractPublicKey();
    final publicKeyBytes = Uint8List.fromList(publicKey.bytes);

    // Base64Url encode public key (no padding)
    _publicKeyBase64Url = base64Url.encode(publicKeyBytes).replaceAll('=', '');

    // Device ID = hex SHA-256 of raw public key
    final sha256 = Sha256();
    final hash = await sha256.hash(publicKeyBytes);
    _deviceId = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // Extract and persist private key bytes
    final extractedData = await _keyPair!.extractPrivateKeyBytes();
    final privateKeyBytes = Uint8List.fromList(extractedData);
    final privateKeyBase64Url = base64Url.encode(privateKeyBytes).replaceAll('=', '');

    // Save to SharedPreferences
    await prefs.setString(_prefPrivateKey, privateKeyBase64Url);
    await prefs.setString(_prefPublicKey, _publicKeyBase64Url!);
    await prefs.setString(_prefDeviceId, _deviceId!);
  }

  /// Build the v1/v2 auth payload string that gets signed.
  /// v1 = no nonce, v2 = with nonce (for challenge-response).
  String buildAuthPayload({
    required String clientId,
    required String clientMode,
    required String role,
    required List<String> scopes,
    required int signedAtMs,
    String? token,
    String? nonce,
  }) {
    final version = (nonce != null && nonce.isNotEmpty) ? 'v2' : 'v1';
    final scopesStr = scopes.join(',');
    final parts = <String>[
      version,
      _deviceId ?? '',
      clientId,
      clientMode,
      role,
      scopesStr,
      signedAtMs.toString(),
      token ?? '',
    ];
    if (version == 'v2') {
      parts.add(nonce ?? '');
    }
    return parts.join('|');
  }

  /// Sign a payload string with the Ed25519 private key.
  /// Returns Base64Url-encoded signature (no padding).
  Future<String?> sign(String data) async {
    if (_keyPair == null) return null;
    try {
      final signature = await _algorithm.sign(
        utf8.encode(data),
        keyPair: _keyPair!,
      );
      return base64Url.encode(signature.bytes).replaceAll('=', '');
    } catch (_) {
      return null;
    }
  }

  /// Build the full `device` JSON block for the connect frame.
  Future<Map<String, dynamic>?> buildDeviceBlock({
    required String clientId,
    required String clientMode,
    required String role,
    required List<String> scopes,
    required String? token,
    String? nonce,
  }) async {
    if (_deviceId == null || _publicKeyBase64Url == null) return null;

    final signedAtMs = DateTime.now().millisecondsSinceEpoch;
    final payload = buildAuthPayload(
      clientId: clientId,
      clientMode: clientMode,
      role: role,
      scopes: scopes,
      signedAtMs: signedAtMs,
      token: token,
      nonce: nonce,
    );
    final signature = await sign(payload);
    if (signature == null) return null;

    final block = <String, dynamic>{
      'id': _deviceId!,
      'publicKey': _publicKeyBase64Url!,
      'signature': signature,
      'signedAt': signedAtMs,
    };
    if (nonce != null && nonce.isNotEmpty) {
      block['nonce'] = nonce;
    }
    return block;
  }
}
