import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'keeperhub_models.dart';

abstract interface class KeeperHubSecretBackend {
  Future<void> write(String key, String value);

  Future<String?> read(String key);

  Future<void> delete(String key);
}

class FlutterKeeperHubSecretBackend implements KeeperHubSecretBackend {
  FlutterKeeperHubSecretBackend({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stores both the returned-once organization credential and its minimal
/// reconnect metadata in Android-encrypted storage. Session cookies never enter
/// this store.
class KeeperHubAuthStore {
  KeeperHubAuthStore({KeeperHubSecretBackend? secrets})
      : _secrets = secrets ?? FlutterKeeperHubSecretBackend();

  static const _apiKeyStorageKey = 'plawie.keeperhub.org-api-key.v1';
  static const _recordStorageKey = 'plawie.keeperhub.connection.v1';

  final KeeperHubSecretBackend _secrets;

  /// Verifies secure storage before a remote returned-once credential exists.
  Future<void> verifyAvailable() async {
    const probeKey = 'plawie.keeperhub.storage-probe.v1';
    const probeValue = 'keeperhub-secure-storage-ready';
    try {
      await _secrets.write(probeKey, probeValue);
      if (await _secrets.read(probeKey) != probeValue) {
        throw const KeeperHubException(
          'credential_store_unavailable',
          'Android could not verify secure Agent Wallet storage.',
        );
      }
    } finally {
      await _secrets.delete(probeKey);
    }
  }

  Future<KeeperHubStoredCredential?> read() async {
    final key = await _secrets.read(_apiKeyStorageKey);
    final encoded = await _secrets.read(_recordStorageKey);
    if (key == null && encoded == null) return null;
    if (key == null || encoded == null) {
      throw const KeeperHubException(
        'credential_store_incomplete',
        'Agent Wallet secure storage is incomplete. Reconnect or revoke access.',
      );
    }
    final normalizedKey = _validateApiKey(key);
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) throw const FormatException('Expected an object.');
      final record = KeeperHubConnectionRecord.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return KeeperHubStoredCredential(
        record: record,
        apiKey: normalizedKey,
      );
    } on FormatException catch (error) {
      throw KeeperHubException(
        'credential_store_invalid',
        'Agent Wallet metadata is invalid: ${error.message}',
      );
    }
  }

  Future<void> save({
    required String apiKey,
    required KeeperHubConnectionRecord record,
  }) async {
    final normalizedKey = _validateApiKey(apiKey);
    final encoded = jsonEncode(record.toJson());
    await _secrets.write(_apiKeyStorageKey, normalizedKey);
    try {
      await _secrets.write(_recordStorageKey, encoded);
      final verifiedKey = await _secrets.read(_apiKeyStorageKey);
      final verifiedRecord = await _secrets.read(_recordStorageKey);
      if (verifiedKey != normalizedKey || verifiedRecord != encoded) {
        throw const KeeperHubException(
          'credential_store_verification_failed',
          'Android could not verify the saved Agent Wallet credential.',
        );
      }
    } catch (_) {
      await clear();
      rethrow;
    }
  }

  Future<void> updateRecord(KeeperHubConnectionRecord record) async {
    final existing = await read();
    if (existing == null) {
      throw const KeeperHubException(
        'credential_store_missing',
        'The Agent Wallet credential is not connected.',
      );
    }
    await save(apiKey: existing.apiKey, record: record);
  }

  Future<void> clear() async {
    await _secrets.delete(_recordStorageKey);
    await _secrets.delete(_apiKeyStorageKey);
  }

  String _validateApiKey(String value) {
    final key = value.trim();
    if (!key.startsWith('kh_') ||
        key.length < 12 ||
        key.length > 512 ||
        key.contains(RegExp(r'\s'))) {
      throw const KeeperHubException(
        'credential_invalid',
        'KeeperHub returned an invalid organization credential.',
      );
    }
    return key;
  }
}
