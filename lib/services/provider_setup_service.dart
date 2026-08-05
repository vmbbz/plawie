import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'preferences_service.dart';
import 'model_provider_catalog.dart';

/// Small abstraction around the platform secure store so setup lifecycle tests
/// can exercise cleanup and recovery without depending on Android storage.
abstract interface class ProviderSecretBackend {
  Future<void> write(String key, String value);

  Future<String?> read(String key);

  Future<Map<String, String>> readAll();

  Future<void> delete(String key);
}

class FlutterProviderSecretBackend implements ProviderSecretBackend {
  FlutterProviderSecretBackend({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

enum PendingProviderSetupState {
  pending,
  applying,
}

class PendingProviderSetup {
  const PendingProviderSetup({
    required this.setupId,
    required this.providerId,
    required this.modelId,
    required this.state,
    this.secretReference,
  });

  final String setupId;
  final String providerId;
  final String modelId;
  final PendingProviderSetupState state;
  final String? secretReference;

  bool get requiresApiKey =>
      secretReference != null && secretReference!.trim().isNotEmpty;
}

/// Owns the temporary provider/key handoff from first-run UI to bootstrap.
///
/// Provider IDs, model IDs, and state are non-secret preferences. API keys are
/// stored only in [ProviderSecretBackend] and are referenced by a random,
/// one-time identifier. The pending secret is deleted after successful
/// consumption or explicit cancellation.
class ProviderSetupService {
  ProviderSetupService({
    PreferencesService? preferences,
    ProviderSecretBackend? secrets,
    Uuid? uuid,
  })  : _preferences = preferences ?? PreferencesService(),
        _secrets = secrets ?? FlutterProviderSecretBackend(),
        _uuid = uuid ?? const Uuid();

  static const _secretPrefix = 'plawie.pending.provider.api-key.';

  final PreferencesService _preferences;
  final ProviderSecretBackend _secrets;
  final Uuid _uuid;

  Future<void> init() => _preferences.init();

  /// Stages a provider selection and optional API key for setup.
  ///
  /// Any previous pending secret is deleted before the new record is written,
  /// preventing a provider change from leaving an old key recoverable.
  Future<PendingProviderSetup> stage({
    required String providerId,
    required String modelId,
    String? apiKey,
  }) async {
    await init();
    await migrateLegacyPendingApiKey();

    final setupId = _uuid.v4();
    final normalizedProvider = providerId.trim();
    final normalizedModel = modelId.trim();
    if (normalizedProvider.isEmpty || normalizedModel.isEmpty) {
      throw ArgumentError('Provider and model are required for setup.');
    }

    await clearPending();

    String? secretReference;
    final normalizedKey = apiKey?.trim() ?? '';
    if (normalizedKey.isNotEmpty) {
      secretReference = '$_secretPrefix$setupId';
      await _secrets.write(secretReference, normalizedKey);
    }

    _preferences.pendingSetupId = setupId;
    _preferences.pendingProvider = normalizedProvider;
    _preferences.pendingSetupModel = normalizedModel;
    _preferences.pendingApiKeyReference = secretReference;
    _preferences.pendingSetupState = PendingProviderSetupState.pending.name;
    _preferences.pendingSetupReceiptId = null;

    return PendingProviderSetup(
      setupId: setupId,
      providerId: normalizedProvider,
      modelId: normalizedModel,
      state: PendingProviderSetupState.pending,
      secretReference: secretReference,
    );
  }

  /// Loads the current pending setup, migrating the legacy plaintext key once
  /// when an older app version left one in SharedPreferences.
  Future<PendingProviderSetup?> readPending() async {
    await init();
    await migrateLegacyPendingApiKey();

    final provider = (_preferences.pendingProvider ?? '').trim();
    if (provider.isEmpty) return null;

    final setupId = (_preferences.pendingSetupId ?? '').trim();
    final modelId = (_preferences.pendingSetupModel ?? '').trim();
    if (setupId.isEmpty || modelId.isEmpty) {
      // Do not allow an incomplete record to consume a secret. The next setup
      // attempt can safely replace it.
      await clearPending();
      return null;
    }

    final stateName = _preferences.pendingSetupState;
    final state = stateName == PendingProviderSetupState.applying.name
        ? PendingProviderSetupState.applying
        : PendingProviderSetupState.pending;
    return PendingProviderSetup(
      setupId: setupId,
      providerId: provider,
      modelId: modelId,
      state: state,
      secretReference: _preferences.pendingApiKeyReference,
    );
  }

  Future<String?> readPendingApiKey(PendingProviderSetup setup) async {
    await init();
    if (_preferences.pendingSetupId != setup.setupId) {
      throw StateError('Pending provider setup changed before secret access.');
    }
    final reference = setup.secretReference?.trim() ?? '';
    if (reference.isEmpty) return null;
    if (!reference.startsWith(_secretPrefix)) {
      throw StateError('Pending provider secret reference is invalid.');
    }
    if (_preferences.pendingApiKeyReference != reference) {
      throw StateError('Pending provider secret reference changed.');
    }
    return _secrets.read(reference);
  }

  Future<void> markApplying(PendingProviderSetup setup) async {
    await init();
    if (_preferences.pendingSetupId != setup.setupId) {
      throw StateError('Pending provider setup changed during bootstrap.');
    }
    _preferences.pendingSetupState = PendingProviderSetupState.applying.name;
  }

  /// Marks setup complete and removes every pending provider secret.
  Future<String> complete(PendingProviderSetup setup) async {
    await init();
    if (_preferences.pendingSetupId != setup.setupId) {
      throw StateError('Pending provider setup changed before completion.');
    }

    final receiptId = _uuid.v4();
    _preferences.lastProviderSetupReceiptId = receiptId;
    _preferences.pendingSetupReceiptId = receiptId;
    await clearPendingSecrets();
    _preferences.pendingSetupId = null;
    _preferences.pendingProvider = null;
    _preferences.pendingSetupModel = null;
    _preferences.pendingApiKeyReference = null;
    _preferences.pendingSetupState = null;
    _preferences.pendingSetupReceiptId = null;
    return receiptId;
  }

  /// Cancels setup and removes all pending provider secrets.
  Future<void> clearPending() async {
    await init();
    await clearPendingSecrets();
    _preferences.legacyPendingApiKey = null;
    _preferences.pendingSetupId = null;
    _preferences.pendingProvider = null;
    _preferences.pendingSetupModel = null;
    _preferences.pendingApiKeyReference = null;
    _preferences.pendingSetupState = null;
    _preferences.pendingSetupReceiptId = null;
  }

  Future<void> clearPendingSecrets() async {
    final all = await _secrets.readAll();
    for (final key in all.keys.where((key) => key.startsWith(_secretPrefix))) {
      await _secrets.delete(key);
    }
  }

  /// Migrates the old plaintext preference into secure storage and removes it
  /// immediately. This is intentionally idempotent for upgrade recovery.
  Future<void> migrateLegacyPendingApiKey() async {
    await init();
    final legacy = (_preferences.legacyPendingApiKey ?? '').trim();
    if (legacy.isEmpty) return;

    final existingReference =
        (_preferences.pendingApiKeyReference ?? '').trim();
    if (existingReference.isNotEmpty) {
      _preferences.legacyPendingApiKey = null;
      return;
    }

    final provider = (_preferences.pendingProvider ?? '').trim();
    if (provider.isEmpty) {
      _preferences.legacyPendingApiKey = null;
      return;
    }

    final setupId = (_preferences.pendingSetupId ?? '').trim().isNotEmpty
        ? _preferences.pendingSetupId!.trim()
        : _uuid.v4();
    final modelId = (_preferences.pendingSetupModel ?? '').trim().isNotEmpty
        ? _preferences.pendingSetupModel!.trim()
        : ModelProviderCatalog.setupSafeModelForProvider(provider);

    final reference = '$_secretPrefix$setupId';
    await _secrets.write(reference, legacy);
    _preferences.pendingSetupId = setupId;
    _preferences.pendingSetupModel = modelId;
    _preferences.pendingApiKeyReference = reference;
    _preferences.pendingSetupState ??= PendingProviderSetupState.pending.name;
    _preferences.legacyPendingApiKey = null;
  }
}

/// Test-only backend that still follows the same async secret-store contract.
class InMemoryProviderSecretBackend implements ProviderSecretBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<Map<String, String>> readAll() async => Map.unmodifiable(values);

  @override
  Future<void> delete(String key) async => values.remove(key);
}
