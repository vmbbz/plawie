import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/node_frame.dart';
import 'capability_handler.dart';

/// App-native weather adapter for Android.
///
/// Uses Open-Meteo's no-key geocoding and forecast APIs. This keeps the Android
/// launch weather path bounded to HTTPS instead of depending on a desktop CLI
/// or implicit PRoot fallback.
class WeatherCapability extends CapabilityHandler {
  WeatherCapability({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get name => 'weather';

  @override
  List<String> get commands => ['current', 'forecast'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command);
    if (canonical != 'weather.current' && canonical != 'weather.forecast') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown weather command: $command',
      });
    }

    try {
      final location = await _resolveLocation(params);
      if (location == null) {
        return NodeFrame.response('', error: {
          'code': 'MISSING_LOCATION',
          'message':
              'weather.current requires city/location or latitude and longitude.',
        });
      }

      final forecastDays = canonical == 'weather.forecast'
          ? _intValue(params['days'], fallback: 3).clamp(1, 7).toInt()
          : 1;
      final uri = _forecastUri(
        location,
        units: params['units']?.toString(),
        forecastDays: forecastDays,
        includeDaily: canonical == 'weather.forecast',
      );
      final response = await _client.get(uri, headers: const {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return NodeFrame.response('', error: {
          'code': 'WEATHER_HTTP_${response.statusCode}',
          'message': 'Open-Meteo forecast request failed.',
        });
      }

      final decoded = _jsonObject(response.body);
      final current = _mapValue(decoded['current']);
      final currentUnits = _mapValue(decoded['current_units']);
      if (current.isEmpty) {
        return NodeFrame.response('', error: {
          'code': 'WEATHER_EMPTY_CURRENT',
          'message': 'Open-Meteo response did not include current weather.',
        });
      }

      final weatherCode = _intOrNull(current['weather_code']);
      final payload = <String, dynamic>{
        'provider': 'open-meteo',
        'providerUrl': uri.toString(),
        'location': location.toJson(),
        'current': current,
        'currentUnits': currentUnits,
        'condition': _weatherCodeLabel(weatherCode),
        'summary': _summary(location, current, currentUnits, weatherCode),
        if (canonical == 'weather.forecast') ...{
          'daily': _mapValue(decoded['daily']),
          'dailyUnits': _mapValue(decoded['daily_units']),
          'forecastDays': forecastDays,
        },
      };

      return NodeFrame.response('', payload: payload);
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'WEATHER_ERROR',
        'message': error.toString(),
      });
    }
  }

  Future<_WeatherLocation?> _resolveLocation(
    Map<String, dynamic> params,
  ) async {
    final latitude = _numOrNull(
      params['latitude'] ?? params['lat'],
    );
    final longitude = _numOrNull(
      params['longitude'] ?? params['lng'] ?? params['lon'],
    );
    if (latitude != null && longitude != null) {
      return _WeatherLocation(
        name: _stringParam(params, const ['city', 'location', 'place']) ??
            'coordinates',
        country: params['country']?.toString(),
        latitude: latitude,
        longitude: longitude,
        timezone: params['timezone']?.toString(),
      );
    }

    final query = _stringParam(params, const [
      'city',
      'location',
      'place',
      'query',
      'q',
    ]);
    if (query == null || query.length < 2) return null;

    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': query,
        'count': '1',
        'language': 'en',
        'format': 'json',
      },
    );
    final response = await _client.get(uri, headers: const {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Open-Meteo geocoding failed: ${response.statusCode}');
    }

    final decoded = _jsonObject(response.body);
    final results = decoded['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      throw StateError('No weather location found for "$query".');
    }
    final first = Map<String, dynamic>.from(results.first as Map);
    final latitudeResult = _numOrNull(first['latitude']);
    final longitudeResult = _numOrNull(first['longitude']);
    if (latitudeResult == null || longitudeResult == null) {
      throw StateError('Open-Meteo geocoding result lacked coordinates.');
    }

    return _WeatherLocation(
      name: first['name']?.toString() ?? query,
      country: first['country']?.toString(),
      latitude: latitudeResult,
      longitude: longitudeResult,
      timezone: first['timezone']?.toString(),
      admin1: first['admin1']?.toString(),
    );
  }

  Uri _forecastUri(
    _WeatherLocation location, {
    required String? units,
    required int forecastDays,
    required bool includeDaily,
  }) {
    final imperial =
        units?.toLowerCase() == 'imperial' || units?.toLowerCase() == 'us';
    return Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current': [
        'temperature_2m',
        'relative_humidity_2m',
        'apparent_temperature',
        'is_day',
        'precipitation',
        'rain',
        'showers',
        'snowfall',
        'weather_code',
        'cloud_cover',
        'pressure_msl',
        'surface_pressure',
        'wind_speed_10m',
        'wind_direction_10m',
        'wind_gusts_10m',
      ].join(','),
      if (includeDaily)
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
          'precipitation_probability_max',
          'wind_speed_10m_max',
        ].join(','),
      'forecast_days': forecastDays.toString(),
      'timezone':
          location.timezone?.isNotEmpty == true ? location.timezone! : 'auto',
      if (imperial) ...{
        'temperature_unit': 'fahrenheit',
        'wind_speed_unit': 'mph',
        'precipitation_unit': 'inch',
      },
    });
  }

  String _summary(
    _WeatherLocation location,
    Map<String, dynamic> current,
    Map<String, dynamic> currentUnits,
    int? weatherCode,
  ) {
    final temp = _numOrNull(current['temperature_2m']);
    final tempUnit = currentUnits['temperature_2m']?.toString() ?? '';
    final wind = _numOrNull(current['wind_speed_10m']);
    final windUnit = currentUnits['wind_speed_10m']?.toString() ?? '';
    final condition = _weatherCodeLabel(weatherCode);
    final parts = <String>[
      location.displayName,
      if (temp != null) '${_formatNumber(temp)}$tempUnit',
      condition,
      if (wind != null) 'wind ${_formatNumber(wind)}$windUnit',
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(', ');
  }

  static String _canonicalCommand(String command) {
    final trimmed = command.trim().toLowerCase();
    return switch (trimmed) {
      'current' || 'weather_current' => 'weather.current',
      'forecast' || 'weather_forecast' => 'weather.forecast',
      _ => trimmed,
    };
  }

  static String? _stringParam(
    Map<String, dynamic> params,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = params[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static Map<String, dynamic> _jsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw StateError('Expected JSON object response.');
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static num? _numOrNull(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  static int? _intOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _formatNumber(num value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _weatherCodeLabel(int? code) {
    return switch (code) {
      0 => 'clear sky',
      1 || 2 || 3 => 'partly cloudy',
      45 || 48 => 'fog',
      51 || 53 || 55 => 'drizzle',
      56 || 57 => 'freezing drizzle',
      61 || 63 || 65 => 'rain',
      66 || 67 => 'freezing rain',
      71 || 73 || 75 => 'snow',
      77 => 'snow grains',
      80 || 81 || 82 => 'rain showers',
      85 || 86 => 'snow showers',
      95 => 'thunderstorm',
      96 || 99 => 'thunderstorm with hail',
      _ => 'unknown conditions',
    };
  }
}

class _WeatherLocation {
  final String name;
  final String? country;
  final num latitude;
  final num longitude;
  final String? timezone;
  final String? admin1;

  const _WeatherLocation({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    this.admin1,
  });

  String get displayName {
    final parts = <String>[
      name,
      if (admin1 != null && admin1!.isNotEmpty && admin1 != name) admin1!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (admin1 != null && admin1!.isNotEmpty) 'admin1': admin1,
        if (country != null && country!.isNotEmpty) 'country': country,
        'latitude': latitude,
        'longitude': longitude,
        if (timezone != null && timezone!.isNotEmpty) 'timezone': timezone,
      };
}
