import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants.dart';
import 'product_telemetry_event.dart';

enum ProductAnalyticsConsent {
  undecided,
  denied,
  granted;

  String get wireName => name;

  static ProductAnalyticsConsent fromWire(String? value) {
    return ProductAnalyticsConsent.values.firstWhere(
      (candidate) => candidate.wireName == value,
      orElse: () => ProductAnalyticsConsent.undecided,
    );
  }
}

@immutable
class ProductAnalyticsConfig {
  const ProductAnalyticsConfig({
    required this.host,
    required this.projectKey,
    required this.releaseChannel,
    required this.appVersion,
  });

  factory ProductAnalyticsConfig.fromEnvironment() {
    return const ProductAnalyticsConfig(
      host: String.fromEnvironment('PLAWIE_POSTHOG_HOST'),
      projectKey: String.fromEnvironment('PLAWIE_POSTHOG_PROJECT_KEY'),
      releaseChannel: String.fromEnvironment(
        'PLAWIE_RELEASE_CHANNEL',
        defaultValue: 'android-preview',
      ),
      appVersion: String.fromEnvironment(
        'PLAWIE_APP_VERSION',
        defaultValue: AppConstants.version,
      ),
    );
  }

  final String host;
  final String projectKey;
  final String releaseChannel;
  final String appVersion;

  Uri? get captureUri {
    final candidate = Uri.tryParse(host.trim());
    if (candidate == null ||
        candidate.scheme != 'https' ||
        !candidate.hasAuthority ||
        candidate.userInfo.isNotEmpty ||
        (candidate.path.isNotEmpty && candidate.path != '/') ||
        candidate.query.isNotEmpty ||
        candidate.fragment.isNotEmpty) {
      return null;
    }
    return candidate.replace(path: '/i/v0/e/');
  }

  bool get isConfigured {
    final key = projectKey.trim();
    return key.length >= 8 &&
        key.length <= 200 &&
        !RegExp(r'\s').hasMatch(key) &&
        !RegExp(r'^ph[svx]_').hasMatch(key) &&
        captureUri != null;
  }
}

@immutable
class QueuedProductTelemetryEvent {
  const QueuedProductTelemetryEvent({
    required this.eventId,
    required this.event,
  });

  final String eventId;
  final ProductTelemetryEvent event;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'eventId': eventId,
        'event': event.toJson(),
      };

  factory QueuedProductTelemetryEvent.fromJson(Map<String, dynamic> json) {
    final rawEvent = json['event'];
    final eventId = json['eventId']?.toString().trim() ?? '';
    if (eventId.isEmpty || rawEvent is! Map) {
      throw const FormatException('Invalid queued product telemetry event.');
    }
    return QueuedProductTelemetryEvent(
      eventId: eventId,
      event: ProductTelemetryEvent.fromJson(
        Map<String, dynamic>.from(rawEvent),
      ),
    );
  }
}

abstract class ProductTelemetryPersistence {
  Future<ProductAnalyticsConsent> readConsent();

  Future<void> writeConsent(ProductAnalyticsConsent consent);

  Future<String?> readInstallationId();

  Future<void> writeInstallationId(String? installationId);

  Future<List<QueuedProductTelemetryEvent>> readPendingEvents();

  Future<void> writePendingEvents(
    List<QueuedProductTelemetryEvent> events,
  );

  Future<Set<String>> readOnceKeys();

  Future<void> writeOnceKeys(Set<String> keys);
}

class SharedPreferencesProductTelemetryPersistence
    implements ProductTelemetryPersistence {
  static const _consentKey = 'product_analytics_consent_v1';
  static const _installationIdKey = 'product_analytics_installation_id_v1';
  static const _pendingEventsKey = 'product_analytics_pending_events_v1';
  static const _onceKeysKey = 'product_analytics_once_keys_v1';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<ProductAnalyticsConsent> readConsent() async {
    final preferences = await _preferences;
    return ProductAnalyticsConsent.fromWire(
      preferences.getString(_consentKey),
    );
  }

  @override
  Future<void> writeConsent(ProductAnalyticsConsent consent) async {
    final preferences = await _preferences;
    await preferences.setString(_consentKey, consent.wireName);
  }

  @override
  Future<String?> readInstallationId() async {
    final preferences = await _preferences;
    final value = preferences.getString(_installationIdKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Future<void> writeInstallationId(String? installationId) async {
    final preferences = await _preferences;
    if (installationId == null || installationId.trim().isEmpty) {
      await preferences.remove(_installationIdKey);
      return;
    }
    await preferences.setString(_installationIdKey, installationId.trim());
  }

  @override
  Future<List<QueuedProductTelemetryEvent>> readPendingEvents() async {
    final preferences = await _preferences;
    final encoded =
        preferences.getStringList(_pendingEventsKey) ?? const <String>[];
    final events = <QueuedProductTelemetryEvent>[];
    for (final item in encoded) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) {
          events.add(
            QueuedProductTelemetryEvent.fromJson(
              Map<String, dynamic>.from(decoded),
            ),
          );
        }
      } catch (_) {
        // Corrupt analytics state is discarded. It must never affect startup.
      }
    }
    return events;
  }

  @override
  Future<void> writePendingEvents(
    List<QueuedProductTelemetryEvent> events,
  ) async {
    final preferences = await _preferences;
    await preferences.setStringList(
      _pendingEventsKey,
      events.map((event) => jsonEncode(event.toJson())).toList(),
    );
  }

  @override
  Future<Set<String>> readOnceKeys() async {
    final preferences = await _preferences;
    return (preferences.getStringList(_onceKeysKey) ?? const <String>[])
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> writeOnceKeys(Set<String> keys) async {
    final preferences = await _preferences;
    final sorted = keys.toList()..sort();
    await preferences.setStringList(_onceKeysKey, sorted);
  }
}

abstract class ProductTelemetryTransport {
  bool get isConfigured;

  Future<void> capture({
    required QueuedProductTelemetryEvent queuedEvent,
    required String installationId,
    required String sessionId,
  });
}

class PostHogProductTelemetryTransport implements ProductTelemetryTransport {
  PostHogProductTelemetryTransport({
    required this.config,
    http.Client? client,
    this.timeout = const Duration(seconds: 6),
  }) : _client = client ?? http.Client();

  final ProductAnalyticsConfig config;
  final http.Client _client;
  final Duration timeout;

  @override
  bool get isConfigured => config.isConfigured;

  @override
  Future<void> capture({
    required QueuedProductTelemetryEvent queuedEvent,
    required String installationId,
    required String sessionId,
  }) async {
    final captureUri = config.captureUri;
    if (!isConfigured || captureUri == null) {
      throw const ProductTelemetryTransportException('not_configured');
    }

    final event = queuedEvent.event;
    final response = await _client
        .post(
          captureUri,
          headers: const <String, String>{
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'api_key': config.projectKey.trim(),
            'event': event.name.wireName,
            'distinct_id': installationId,
            'timestamp': event.occurredAt.toUtc().toIso8601String(),
            'properties': <String, Object>{
              ...event.properties,
              'schemaVersion': ProductTelemetryEvent.schemaVersion,
              'platform': 'android',
              'appVersion': event.releaseVersion ?? config.appVersion,
              'releaseChannel': event.releaseChannel ?? config.releaseChannel,
              'plawieEventId': queuedEvent.eventId,
              r'$session_id': sessionId,
              r'$process_person_profile': false,
              r'$geoip_disable': true,
            },
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProductTelemetryTransportException(
        'http_${response.statusCode}',
      );
    }
  }
}

class ProductTelemetryTransportException implements Exception {
  const ProductTelemetryTransportException(this.code);

  final String code;

  @override
  String toString() => 'ProductTelemetryTransportException($code)';
}

typedef ProductTelemetryIdGenerator = String Function();
typedef ProductTelemetryClock = DateTime Function();

class ProductTelemetryService extends ChangeNotifier {
  ProductTelemetryService({
    required ProductAnalyticsConfig config,
    required ProductTelemetryPersistence persistence,
    required ProductTelemetryTransport transport,
    ProductTelemetryIdGenerator? idGenerator,
    ProductTelemetryClock? clock,
  })  : _config = config,
        _persistence = persistence,
        _transport = transport,
        _idGenerator = idGenerator ?? const Uuid().v4,
        _clock = clock ?? DateTime.now,
        _sessionId = (idGenerator ?? const Uuid().v4)();

  static final ProductTelemetryService instance = _production();

  static ProductTelemetryService _production() {
    final config = ProductAnalyticsConfig.fromEnvironment();
    return ProductTelemetryService(
      config: config,
      persistence: SharedPreferencesProductTelemetryPersistence(),
      transport: PostHogProductTelemetryTransport(config: config),
    );
  }

  static const int maxPendingEvents = 64;
  static final RegExp _installationIdPattern =
      RegExp(r'^plawie-install-[A-Za-z0-9-]{8,100}$');

  final ProductAnalyticsConfig _config;
  final ProductTelemetryPersistence _persistence;
  final ProductTelemetryTransport _transport;
  final ProductTelemetryIdGenerator _idGenerator;
  final ProductTelemetryClock _clock;
  final String _sessionId;

  ProductAnalyticsConsent _consent = ProductAnalyticsConsent.undecided;
  String? _installationId;
  List<QueuedProductTelemetryEvent> _pendingEvents =
      <QueuedProductTelemetryEvent>[];
  Set<String> _onceKeys = <String>{};
  final Set<String> _sessionOnceKeys = <String>{};
  bool _initialized = false;
  bool _sessionLifecycleRecorded = false;
  Future<void>? _initializeFuture;
  Future<void>? _flushFuture;
  Future<void> _stateLock = Future<void>.value();

  ProductAnalyticsConsent get consent => _consent;
  bool get consentGranted => _consent == ProductAnalyticsConsent.granted;
  bool get consentDecided => _consent != ProductAnalyticsConsent.undecided;
  bool get analyticsConfigured => _transport.isConfigured;
  int get pendingEventCount => _pendingEvents.length;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      _consent = await _persistence.readConsent();
      _pendingEvents = await _persistence.readPendingEvents();
      _onceKeys = await _persistence.readOnceKeys();
      if (consentGranted) {
        await _ensureInstallationId();
      } else {
        await _clearStoredAnalyticsState();
      }
    } catch (_) {
      _consent = ProductAnalyticsConsent.undecided;
      _installationId = null;
      _pendingEvents = <QueuedProductTelemetryEvent>[];
      _onceKeys = <String>{};
    }
    _initialized = true;
    notifyListeners();

    if (_canCapture) {
      await _recordSessionLifecycle();
      unawaited(flush());
    }
  }

  Future<bool> setConsent(ProductAnalyticsConsent consent) async {
    await initialize();
    if (_consent == consent) return true;

    try {
      await _withStateLock(() async {
        _consent = consent;
        await _persistence.writeConsent(consent);
        if (consent == ProductAnalyticsConsent.granted) {
          await _ensureInstallationId();
        } else {
          await _clearStoredAnalyticsState();
        }
      });
    } catch (_) {
      return false;
    }

    if (_canCapture) {
      await _recordSessionLifecycle();
      unawaited(flush());
    }
    notifyListeners();
    return true;
  }

  Future<bool> record(
    ProductTelemetryEventName name, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    await initialize();
    return _recordInitialized(name, properties: properties);
  }

  Future<bool> recordOnce(
    ProductTelemetryEventName name, {
    required String onceKey,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    await initialize();
    return _recordInitialized(
      name,
      properties: properties,
      onceKey: onceKey,
    );
  }

  Future<bool> recordSessionOnce(
    ProductTelemetryEventName name, {
    required String sessionKey,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    await initialize();
    return _recordInitialized(
      name,
      properties: properties,
      sessionOnceKey: sessionKey,
    );
  }

  Future<bool> _recordInitialized(
    ProductTelemetryEventName name, {
    Map<String, Object?> properties = const <String, Object?>{},
    String? onceKey,
    String? sessionOnceKey,
  }) async {
    if (!_canCapture ||
        (onceKey != null && _onceKeys.contains(onceKey)) ||
        (sessionOnceKey != null && _sessionOnceKeys.contains(sessionOnceKey))) {
      return false;
    }

    try {
      final event = ProductTelemetryEvent(
        name: name,
        occurredAt: _clock(),
        releaseVersion: _config.appVersion,
        releaseChannel: _config.releaseChannel,
        properties: properties,
      );
      final queued = await _withStateLock(() async {
        if (!_canCapture ||
            (onceKey != null && _onceKeys.contains(onceKey)) ||
            (sessionOnceKey != null &&
                _sessionOnceKeys.contains(sessionOnceKey)) ||
            _pendingEvents.length >= maxPendingEvents) {
          return false;
        }
        _pendingEvents.add(
          QueuedProductTelemetryEvent(
            eventId: _idGenerator(),
            event: event,
          ),
        );
        await _persistence.writePendingEvents(_pendingEvents);
        if (onceKey != null) {
          _onceKeys.add(onceKey);
          await _persistence.writeOnceKeys(_onceKeys);
        }
        if (sessionOnceKey != null) {
          _sessionOnceKeys.add(sessionOnceKey);
        }
        return true;
      });
      if (!queued) return false;
      unawaited(flush());
      return true;
    } catch (_) {
      // Invalid dimensions or local storage failure never affect product flow.
      return false;
    }
  }

  Future<void> _recordSessionLifecycle() async {
    if (_sessionLifecycleRecorded || !_canCapture) return;
    await _recordInitialized(
      ProductTelemetryEventName.appFirstOpened,
      onceKey: 'app_first_opened_v1',
      properties: const <String, Object?>{'source': 'android_app'},
    );
    _sessionLifecycleRecorded = await _recordInitialized(
      ProductTelemetryEventName.appOpened,
      properties: const <String, Object?>{'source': 'android_app'},
    );
  }

  Future<void> flush() {
    final active = _flushFuture;
    if (active != null) return active;
    final next = _flushPending();
    _flushFuture = next;
    return next.whenComplete(() {
      if (identical(_flushFuture, next)) _flushFuture = null;
    });
  }

  Future<void> _flushPending() async {
    while (_canCapture) {
      final queuedEvent = await _withStateLock(
        () async => _pendingEvents.isEmpty ? null : _pendingEvents.first,
      );
      final installationId = _installationId;
      if (queuedEvent == null || installationId == null) return;

      try {
        await _transport.capture(
          queuedEvent: queuedEvent,
          installationId: installationId,
          sessionId: _sessionId,
        );
      } catch (_) {
        return;
      }

      await _withStateLock(() async {
        if (_pendingEvents.isNotEmpty &&
            _pendingEvents.first.eventId == queuedEvent.eventId) {
          _pendingEvents.removeAt(0);
          await _persistence.writePendingEvents(_pendingEvents);
        }
      });
    }
  }

  bool get _canCapture =>
      consentGranted && _transport.isConfigured && _installationId != null;

  Future<void> _ensureInstallationId() async {
    final existing =
        _installationId ?? (await _persistence.readInstallationId())?.trim();
    if (existing != null && _installationIdPattern.hasMatch(existing)) {
      _installationId = existing;
      return;
    }
    _installationId = 'plawie-install-${_idGenerator()}';
    await _persistence.writeInstallationId(_installationId);
  }

  Future<void> _clearStoredAnalyticsState() async {
    _installationId = null;
    _pendingEvents = <QueuedProductTelemetryEvent>[];
    _onceKeys = <String>{};
    _sessionOnceKeys.clear();
    _sessionLifecycleRecorded = false;
    await _persistence.writeInstallationId(null);
    await _persistence.writePendingEvents(_pendingEvents);
    await _persistence.writeOnceKeys(_onceKeys);
  }

  Future<T> _withStateLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _stateLock = _stateLock.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

abstract final class ProductTelemetryBuckets {
  static String duration(Duration duration) {
    if (duration < const Duration(seconds: 2)) return 'under_2s';
    if (duration < const Duration(seconds: 10)) return '2_10s';
    if (duration < const Duration(seconds: 30)) return '10_30s';
    if (duration < const Duration(minutes: 2)) return '30_120s';
    return 'over_120s';
  }
}
