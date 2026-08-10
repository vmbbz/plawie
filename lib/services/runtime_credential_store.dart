import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal backend contract for app-runtime credentials.
///
/// Provider BYOK handoff and wallet key material have their own stores. This
/// store owns only Gateway authentication, pairing tokens, and the two Ed25519
/// device-identity private keys that older builds placed in SharedPreferences.
abstract interface class RuntimeCredentialBackend {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterRuntimeCredentialBackend
    implements RuntimeCredentialBackend {
  FlutterRuntimeCredentialBackend({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Android-Keystore-backed cache for credentials needed by synchronous legacy
/// call sites.
///
/// [init] performs a verified one-time migration before deleting the old
/// plaintext preference. Public identity fields remain in SharedPreferences;
/// only private/authentication material moves here.
final class RuntimeCredentialStore {
  RuntimeCredentialStore({RuntimeCredentialBackend? backend})
      : _backend = backend ?? FlutterRuntimeCredentialBackend();

  static final RuntimeCredentialStore instance = RuntimeCredentialStore();

  static const legacyGatewayTokenKey = 'gateway_token';
  static const legacyNodeGatewayTokenKey = 'node_gateway_token';
  static const legacyNodeDeviceTokenKey = 'node_device_token';
  static const legacyOperatorDeviceTokenKey = 'openclaw_operator_device_token';
  static const legacyOperatorPrivateKey = 'openclaw_device_ed25519_private';
  static const legacyNodePrivateKey = 'openclaw_device_ed25519_private_node';

  static const _secureGatewayTokenKey = 'plawie.runtime.gateway-token.v1';
  static const _secureNodeGatewayTokenKey =
      'plawie.runtime.node-gateway-token.v1';
  static const _secureNodeDeviceTokenKey =
      'plawie.runtime.node-device-token.v1';
  static const _secureOperatorDeviceTokenKey =
      'plawie.runtime.operator-device-token.v1';
  static const _secureOperatorPrivateKey =
      'plawie.runtime.operator-ed25519-private.v1';
  static const _secureNodePrivateKey = 'plawie.runtime.node-ed25519-private.v1';

  static const Map<String, String> _legacyToSecure = <String, String>{
    legacyGatewayTokenKey: _secureGatewayTokenKey,
    legacyNodeGatewayTokenKey: _secureNodeGatewayTokenKey,
    legacyNodeDeviceTokenKey: _secureNodeDeviceTokenKey,
    legacyOperatorDeviceTokenKey: _secureOperatorDeviceTokenKey,
    legacyOperatorPrivateKey: _secureOperatorPrivateKey,
    legacyNodePrivateKey: _secureNodePrivateKey,
  };

  final RuntimeCredentialBackend _backend;
  final Map<String, String> _values = <String, String>{};
  Future<void>? _initializing;
  bool _initialized = false;
  bool _secureBackendAvailable = true;

  Future<void> init(SharedPreferences legacyPreferences) {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize(legacyPreferences);
  }

  Future<void> _initialize(SharedPreferences legacyPreferences) async {
    try {
      for (final entry in _legacyToSecure.entries) {
        final legacyValue = legacyPreferences.getString(entry.key);
        var secureValue = await _backend.read(entry.value);

        if ((secureValue == null || secureValue.isEmpty) &&
            legacyValue != null &&
            legacyValue.isNotEmpty) {
          await _backend.write(entry.value, legacyValue);
          secureValue = await _backend.read(entry.value);
          if (secureValue != legacyValue) {
            throw StateError(
              'Secure runtime credential migration could not be verified.',
            );
          }
        }

        if (secureValue != null && secureValue.isNotEmpty) {
          _values[entry.value] = secureValue;
          if (legacyPreferences.containsKey(entry.key)) {
            await legacyPreferences.remove(entry.key);
          }
        }
      }
      _initialized = true;
    } catch (error) {
      // Flutter unit tests do not register platform plugins. Keep their legacy
      // values memory-only, but never use this fallback in a release build.
      final bindingUnavailable =
          error.toString().contains('Binding has not yet been initialized');
      if (!kDebugMode ||
          (error is! MissingPluginException && !bindingUnavailable)) {
        rethrow;
      }
      _secureBackendAvailable = false;
      for (final entry in _legacyToSecure.entries) {
        final value = legacyPreferences.getString(entry.key);
        if (value != null && value.isNotEmpty) {
          _values[entry.value] = value;
        }
      }
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  void _requireInitialized() {
    if (!_initialized) {
      throw StateError(
        'RuntimeCredentialStore not initialized. Initialize preferences first.',
      );
    }
  }

  String? _read(String key) {
    _requireInitialized();
    return _values[key];
  }

  Future<void> _write(String key, String? value) async {
    _requireInitialized();
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      _values.remove(key);
      if (_secureBackendAvailable) await _backend.delete(key);
      return;
    }

    // Update memory before the first await so synchronous compatibility
    // getters observe the newly accepted token immediately.
    _values[key] = normalized;
    if (_secureBackendAvailable) await _backend.write(key, normalized);
  }

  String get gatewayToken => _read(_secureGatewayTokenKey) ?? '';
  Future<void> setGatewayToken(String? value) =>
      _write(_secureGatewayTokenKey, value);

  String? get nodeGatewayToken => _read(_secureNodeGatewayTokenKey);
  Future<void> setNodeGatewayToken(String? value) =>
      _write(_secureNodeGatewayTokenKey, value);

  String? get nodeDeviceToken => _read(_secureNodeDeviceTokenKey);
  Future<void> setNodeDeviceToken(String? value) =>
      _write(_secureNodeDeviceTokenKey, value);

  String? get operatorDeviceToken => _read(_secureOperatorDeviceTokenKey);
  Future<void> setOperatorDeviceToken(String? value) =>
      _write(_secureOperatorDeviceTokenKey, value);

  String? devicePrivateKey({required bool node}) =>
      _read(node ? _secureNodePrivateKey : _secureOperatorPrivateKey);

  Future<void> setDevicePrivateKey({
    required bool node,
    required String? value,
  }) =>
      _write(node ? _secureNodePrivateKey : _secureOperatorPrivateKey, value);
}

/// Deterministic test backend; values never touch platform storage.
final class InMemoryRuntimeCredentialBackend
    implements RuntimeCredentialBackend {
  InMemoryRuntimeCredentialBackend([Map<String, String>? seed])
      : values = <String, String>{...?seed};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
