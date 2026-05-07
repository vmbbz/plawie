import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NodeIdentityService {
  static const _keyPrivate = 'openclaw_node_ed25519_private';
  static const _keyPublic = 'openclaw_node_ed25519_public';
  static const _keyDeviceId = 'openclaw_node_id';

  late SimpleKeyPair _keyPair;
  late String _deviceId;
  late String _publicKeyBase64Url;

  String get deviceId => _deviceId;

  /// Raw 32-byte public key encoded as base64url (no padding).
  String get publicKeyBase64Url => _publicKeyBase64Url;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPrivate = prefs.getString(_keyPrivate);
    final storedPublic = prefs.getString(_keyPublic);
    final storedDeviceId = prefs.getString(_keyDeviceId);

    if (storedPrivate != null && storedPublic != null && storedDeviceId != null) {
      // Restore existing keys (pad safely to prevent FormatException: Invalid length)
      String padBase64(String s) => s.padRight(s.length + (4 - s.length % 4) % 4, '=');
      
      try {
        final privateBytes = base64Url.decode(padBase64(storedPrivate));
        final publicBytes = base64Url.decode(padBase64(storedPublic));
        _publicKeyBase64Url = _toBase64Url(publicBytes);
        
        // Enforce stable Hex SHA-256 format
        final hash = await Sha256().hash(publicBytes);
        _deviceId = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        _keyPair = SimpleKeyPairData(
          privateBytes,
          publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
          type: KeyPairType.ed25519,
        );
        return;
      } catch (e) {
        // Fall through to generate new keys if corrupted
      }
    }
    await _generateAndStore(prefs);
  }

  Future<void> _generateAndStore(SharedPreferences prefs) async {
    final algorithm = Ed25519();
    final newKeyPair = await algorithm.newKeyPair();
    _keyPair = await newKeyPair.extract();

    final publicKey = await _keyPair.extractPublicKey();
    final publicBytes = Uint8List.fromList(publicKey.bytes);

    _publicKeyBase64Url = _toBase64Url(publicBytes);
    
    // deviceId = SHA-256 hex of raw 32-byte public key (stable format)
    final hash = await Sha256().hash(publicBytes);
    _deviceId = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final privateBytes = await _keyPair.extractPrivateKeyBytes();
    await prefs.setString(_keyPrivate, _toBase64Url(privateBytes));
    await prefs.setString(_keyPublic, _publicKeyBase64Url);
    await prefs.setString(_keyDeviceId, _deviceId);
  }

  /// Build the device auth payload that the gateway expects to verify.
  /// Format: "v2|deviceId|clientId|clientMode|role|scopes|signedAtMs|token|nonce"
  String buildAuthPayload({
    required String clientId,
    required String clientMode,
    required String role,
    required List<String> scopes,
    required int signedAtMs,
    String? token,
    String? nonce,
  }) {
    final parts = [
      nonce != null ? 'v2' : 'v1',
      deviceId,
      clientId,
      clientMode,
      role,
      scopes.join(','),
      signedAtMs.toString(),
      token ?? '',
    ];
    if (nonce != null) {
      parts.add(nonce);
    }
    return parts.join('|');
  }

  /// Sign the auth payload with Ed25519 private key.
  /// Returns base64url-encoded signature (no padding).
  Future<String> signPayload(String payload) async {
    final payloadBytes = utf8.encode(payload);
    final algorithm = Ed25519();
    final signature = await algorithm.sign(payloadBytes, keyPair: _keyPair);
    return _toBase64Url(Uint8List.fromList(signature.bytes));
  }

  /// Base64url encode without padding (matches gateway's format).
  static String _toBase64Url(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
