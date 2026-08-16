import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'runtime_credential_store.dart';

/// Manages a persistent Ed25519 device identity for OpenClaw Gateway Protocol v3.
///
/// On first launch, generates an Ed25519 key pair and persists it.
/// Provides signing and device metadata for the connect frame's `device` block.
class DeviceIdentity {
  static final DeviceIdentity _operatorInstance = DeviceIdentity._internal();
  static final DeviceIdentity _nodeInstance = DeviceIdentity._internal('node');

  /// Legacy/default identity is kept as the operator identity so existing
  /// operator pairings survive app upgrades.
  static DeviceIdentity get operator => _operatorInstance;
  static DeviceIdentity get node => _nodeInstance;

  factory DeviceIdentity() => _operatorInstance;
  static DeviceIdentity get instance => _operatorInstance;
  DeviceIdentity._internal([this._namespace = '']);

  static const _prefPublicKey = 'openclaw_device_ed25519_public';
  static const _prefDeviceId = 'openclaw_device_id';

  final String _namespace;
  final _algorithm = Ed25519();

  String? _deviceId;
  String? _publicKeyBase64Url;
  SimpleKeyPairData? _keyPair;
  Future<void>? _initFuture;

  String? get deviceId => _deviceId;
  String? get publicKeyBase64Url => _publicKeyBase64Url;

  String _key(String base) => _namespace.isEmpty ? base : '${base}_$_namespace';

  /// Verify that persisted private/public material still represents one
  /// Ed25519 identity and that its stored device ID was derived from that
  /// public key.
  ///
  /// The private key lives in Android Keystore-backed storage while the public
  /// fields live in SharedPreferences. An interrupted write or a restored
  /// preference file can therefore leave individually valid values that do not
  /// belong together. Such a split identity signs every Gateway challenge with
  /// an invalid signature until it is repaired.
  @visibleForTesting
  static Future<bool> isStoredMaterialConsistent({
    required String privateKeyBase64Url,
    required String publicKeyBase64Url,
    required String deviceId,
  }) async {
    String padBase64(String value) => value.padRight(
          value.length + (4 - value.length % 4) % 4,
          '=',
        );

    try {
      final privateBytes = base64Url.decode(padBase64(privateKeyBase64Url));
      final publicBytes = base64Url.decode(padBase64(publicKeyBase64Url));
      if (privateBytes.isEmpty || publicBytes.length != 32) return false;

      final publicKey = SimplePublicKey(
        publicBytes,
        type: KeyPairType.ed25519,
      );
      final keyPair = SimpleKeyPairData(
        privateBytes,
        publicKey: publicKey,
        type: KeyPairType.ed25519,
      );

      final hash = await Sha256().hash(publicBytes);
      final derivedDeviceId = hash.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      if (derivedDeviceId != deviceId.trim().toLowerCase()) return false;

      final probe = utf8.encode('plawie-device-identity-consistency-v1');
      final signature = await Ed25519().sign(probe, keyPair: keyPair);
      return Ed25519().verify(
        probe,
        signature: Signature(signature.bytes, publicKey: publicKey),
      );
    } catch (_) {
      return false;
    }
  }

  /// Load existing identity from SharedPreferences, or generate a new one.
  ///
  /// Initialization is single-flight because operator connection attempts can
  /// overlap during Gateway startup. Without this guard, two first-run key
  /// generations can interleave their secure/private and preference/public
  /// writes and persist a split identity.
  Future<void> init() => _initFuture ??= _initInternal();

  Future<void> _initInternal() async {
    final prefs = await SharedPreferences.getInstance();
    final credentialStore = RuntimeCredentialStore.instance;
    await credentialStore.init(prefs);
    final isNodeIdentity = _namespace == 'node';
    final existingPrivate =
        credentialStore.devicePrivateKey(node: isNodeIdentity);
    final existingPublic = prefs.getString(_key(_prefPublicKey));
    final existingDeviceId = prefs.getString(_key(_prefDeviceId));

    final hasCompleteIdentity = existingPrivate != null &&
        existingPublic != null &&
        existingDeviceId != null;
    if (hasCompleteIdentity &&
        await isStoredMaterialConsistent(
          privateKeyBase64Url: existingPrivate,
          publicKeyBase64Url: existingPublic,
          deviceId: existingDeviceId,
        )) {
      // Restore existing keys (pad safely to prevent FormatException: Invalid length)
      String padBase64(String s) =>
          s.padRight(s.length + (4 - s.length % 4) % 4, '=');

      try {
        _deviceId = existingDeviceId;
        _publicKeyBase64Url = existingPublic;
        final privateBytes = base64Url.decode(padBase64(existingPrivate));
        final publicBytes = base64Url.decode(padBase64(existingPublic));
        final publicKey =
            SimplePublicKey(publicBytes, type: KeyPairType.ed25519);
        _keyPair = SimpleKeyPairData(
          privateBytes,
          publicKey: publicKey,
          type: KeyPairType.ed25519,
        );
        return;
      } catch (e) {
        debugPrint('Device Identity Load Error ($_namespace): $e');
        await credentialStore.setDevicePrivateKey(
          node: isNodeIdentity,
          value: null,
        );
        // Fall through to rotate the identity if restoration unexpectedly
        // fails after consistency validation.
      }
    }

    final hadPersistedIdentity = existingPrivate != null ||
        existingPublic != null ||
        existingDeviceId != null;
    if (hadPersistedIdentity) {
      debugPrint(
        '[DeviceIdentity] Incomplete or inconsistent '
        '${isNodeIdentity ? 'node' : 'operator'} identity; rotating safely.',
      );
      await credentialStore.setDevicePrivateKey(
        node: isNodeIdentity,
        value: null,
      );
      if (isNodeIdentity) {
        await credentialStore.setNodeDeviceToken(null);
      } else {
        await credentialStore.setOperatorDeviceToken(null);
      }
      await prefs.remove(_key(_prefPublicKey));
      await prefs.remove(_key(_prefDeviceId));
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
    _deviceId =
        hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // Extract and persist private key bytes
    final extractedData = await _keyPair!.extractPrivateKeyBytes();
    final privateKeyBytes = Uint8List.fromList(extractedData);
    final privateKeyBase64Url =
        base64Url.encode(privateKeyBytes).replaceAll('=', '');

    // Private material is encrypted by the Android Keystore-backed runtime
    // credential store. Public identity fields remain normal preferences.
    await credentialStore.setDevicePrivateKey(
      node: isNodeIdentity,
      value: privateKeyBase64Url,
    );
    await prefs.setString(_key(_prefPublicKey), _publicKeyBase64Url!);
    await prefs.setString(_key(_prefDeviceId), _deviceId!);
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
