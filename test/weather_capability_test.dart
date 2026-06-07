import 'dart:convert';

import 'package:clawa/services/capabilities/weather_capability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('weather.current resolves a city and returns Open-Meteo current data',
      () async {
    final requests = <Uri>[];
    final capability = WeatherCapability(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          expect(request.url.queryParameters['name'], 'Johannesburg');
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'name': 'Johannesburg',
                  'country': 'South Africa',
                  'admin1': 'Gauteng',
                  'latitude': -26.2041,
                  'longitude': 28.0473,
                  'timezone': 'Africa/Johannesburg',
                }
              ],
            }),
            200,
          );
        }
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.queryParameters['latitude'], '-26.2041');
        expect(request.url.queryParameters['longitude'], '28.0473');
        expect(
          request.url.queryParameters['current'],
          contains('temperature_2m'),
        );
        return http.Response(
          jsonEncode({
            'current_units': {
              'temperature_2m': 'C',
              'wind_speed_10m': 'km/h',
            },
            'current': {
              'time': '2026-06-07T01:00',
              'temperature_2m': 12.4,
              'weather_code': 2,
              'wind_speed_10m': 9.0,
            },
          }),
          200,
        );
      }),
    );

    final frame = await capability.handle(
      'weather.current',
      {'city': 'Johannesburg'},
    );

    expect(frame.isError, isFalse);
    expect(frame.payload?['provider'], 'open-meteo');
    expect(frame.payload?['condition'], 'partly cloudy');
    expect(frame.payload?['summary'], contains('Johannesburg'));
    expect(requests.map((uri) => uri.host), [
      'geocoding-api.open-meteo.com',
      'api.open-meteo.com',
    ]);
  });

  test('weather.forecast can use direct coordinates and imperial units',
      () async {
    final capability = WeatherCapability(
      client: MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.queryParameters['temperature_unit'], 'fahrenheit');
        expect(request.url.queryParameters['wind_speed_unit'], 'mph');
        expect(request.url.queryParameters['forecast_days'], '2');
        expect(request.url.queryParameters['daily'], contains('weather_code'));
        return http.Response(
          jsonEncode({
            'current_units': {
              'temperature_2m': 'F',
              'wind_speed_10m': 'mph',
            },
            'current': {
              'time': '2026-06-07T01:00',
              'temperature_2m': 54.0,
              'weather_code': 61,
              'wind_speed_10m': 6.0,
            },
            'daily_units': {
              'temperature_2m_max': 'F',
              'temperature_2m_min': 'F',
            },
            'daily': {
              'time': ['2026-06-07', '2026-06-08'],
              'weather_code': [61, 3],
              'temperature_2m_max': [58, 62],
              'temperature_2m_min': [45, 49],
            },
          }),
          200,
        );
      }),
    );

    final frame = await capability.handle(
      'weather.forecast',
      {
        'latitude': 40.7128,
        'longitude': -74.0060,
        'units': 'imperial',
        'days': 2,
      },
    );

    expect(frame.isError, isFalse);
    expect(frame.payload?['condition'], 'rain');
    expect(frame.payload?['forecastDays'], 2);
    expect(frame.payload?['daily'], isA<Map<String, dynamic>>());
  });
}
