import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

typedef GoPlacesApiKeyProvider = Future<String?> Function();

class GoPlacesCapability extends CapabilityHandler {
  GoPlacesCapability({
    http.Client? client,
    GoPlacesApiKeyProvider? apiKeyProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _apiKeyProvider = apiKeyProvider ?? _readNativeGooglePlacesApiKey,
        _baseUri = baseUri ?? Uri.parse('https://places.googleapis.com');

  static const int _defaultLimit = 5;
  static const int _maxLimit = 10;
  static const String _fieldMask =
      'places.id,places.displayName,places.formattedAddress,'
      'places.location,places.googleMapsUri,places.primaryType';

  final http.Client _client;
  final GoPlacesApiKeyProvider _apiKeyProvider;
  final Uri _baseUri;

  @override
  String get name => 'goplaces';

  @override
  List<String> get commands => const ['search'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'goplaces.search') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown Google Places command: $command',
      });
    }

    final apiKey = (await _apiKeyProvider())?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_GOOGLE_PLACES_API_KEY',
        'message':
            'Set GOOGLE_PLACES_API_KEY in the Native OpenClaw environment before using goplaces.',
      });
    }

    final query = _query(params);
    if (query == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_QUERY',
        'message': 'goplaces.search requires a non-empty query.',
      });
    }

    try {
      final limit = _intParam(params['limit'], _defaultLimit, 1, _maxLimit);
      final body = <String, dynamic>{
        'textQuery': query,
        'pageSize': limit,
        if (_optionalString(params['languageCode']) != null)
          'languageCode': _optionalString(params['languageCode']),
        if (_optionalString(params['regionCode']) != null)
          'regionCode': _optionalString(params['regionCode']),
        if (_optionalString(params['includedType']) != null)
          'includedType': _optionalString(params['includedType']),
      };
      final startedAt = DateTime.now();
      final response = await _client
          .post(
            _baseUri.replace(path: '/v1/places:searchText'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': _fieldMask,
              'User-Agent': 'OpenClaw-Android',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _httpError(response);
      }
      final decoded = _jsonMap(response.body);
      final rawPlaces = decoded['places'];
      if (rawPlaces != null && rawPlaces is! List) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_GOOGLE_PLACES_RESPONSE',
          'message': 'Google Places response places field was not a list.',
        });
      }
      final places = (rawPlaces as List? ?? const <dynamic>[])
          .whereType<Map>()
          .take(limit)
          .map((place) => _placePreview(Map<String, dynamic>.from(place)))
          .toList(growable: false);
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      return NodeFrame.response('', payload: {
        'runtime': 'app-native-google-places-rest',
        'action': 'search',
        'query': query,
        'count': places.length,
        'places': places,
        'elapsedMs': elapsedMs,
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'GOOGLE_PLACES_TIMEOUT',
        'message': 'Google Places request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'GOOGLE_PLACES_ERROR',
        'message': error.toString(),
      });
    }
  }

  NodeFrame _httpError(http.Response response) {
    return NodeFrame.response('', error: {
      'code': 'GOOGLE_PLACES_HTTP_ERROR',
      'message': 'Google Places returned HTTP ${response.statusCode}.',
      'statusCode': response.statusCode,
    });
  }

  static String _canonicalCommand(
    String command,
    Map<String, dynamic> params,
  ) {
    final normalized = command.trim().toLowerCase().replaceAll('_', '.');
    final action = params['action']?.toString().trim().toLowerCase();
    return switch (normalized) {
      'goplaces' ||
      'goplaces.search' ||
      'places' ||
      'places.search' =>
        action == null || action.isEmpty || action == 'search'
            ? 'goplaces.search'
            : normalized,
      _ => normalized,
    };
  }

  static String? _query(Map<String, dynamic> params) {
    final query = (params['query'] ?? params['textQuery'])?.toString().trim();
    if (query == null || query.isEmpty) return null;
    if (query.length > 500) return query.substring(0, 500);
    return query;
  }

  static Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Google Places response was not an object.');
  }

  static Map<String, dynamic> _placePreview(Map<String, dynamic> place) {
    final displayName = place['displayName'];
    final location = place['location'];
    return {
      'id': place['id']?.toString(),
      'displayName': displayName is Map
          ? displayName['text']?.toString()
          : displayName?.toString(),
      'formattedAddress': place['formattedAddress']?.toString(),
      'googleMapsUri': place['googleMapsUri']?.toString(),
      'primaryType': place['primaryType']?.toString(),
      if (location is Map)
        'location': {
          'latitude': location['latitude'],
          'longitude': location['longitude'],
        },
    };
  }

  static String? _optionalString(dynamic value) {
    final trimmed = value?.toString().trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static int _intParam(dynamic value, int fallback, int min, int max) {
    final parsed = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()),
      _ => null,
    };
    return (parsed ?? fallback).clamp(min, max).toInt();
  }

  static Future<String?> _readNativeGooglePlacesApiKey() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final envFile = File(path.join(
        filesDir,
        'native-node-embedded',
        'native-home',
        '.openclaw',
        '.env',
      ));
      if (!await envFile.exists()) return null;
      return _readDotEnvKey(
          await envFile.readAsString(), 'GOOGLE_PLACES_API_KEY');
    } catch (_) {
      return null;
    }
  }

  static String? _readDotEnvKey(String text, String key) {
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final equals = line.indexOf('=');
      if (equals <= 0) continue;
      final name = line.substring(0, equals).trim();
      if (name != key) continue;
      var value = line.substring(equals + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      return value.trim().isEmpty ? null : value.trim();
    }
    return null;
  }
}
