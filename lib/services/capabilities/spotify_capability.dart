import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/node_frame.dart';
import 'capability_handler.dart';
import 'native_env.dart';

typedef SpotifyTokenProvider = Future<String?> Function();

class SpotifyCapability extends CapabilityHandler {
  SpotifyCapability({
    http.Client? client,
    SpotifyTokenProvider? tokenProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider ?? _readNativeSpotifyToken,
        _baseUri = baseUri ?? Uri.parse('https://api.spotify.com');

  final http.Client _client;
  final SpotifyTokenProvider _tokenProvider;
  final Uri _baseUri;

  @override
  String get name => 'spotify-player';

  @override
  List<String> get commands => const ['profile', 'currently-playing'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'spotify-player.profile' &&
        canonical != 'spotify-player.currently-playing') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown Spotify command: $command',
      });
    }

    final token = (await _tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_SPOTIFY_ACCESS_TOKEN',
        'message':
            'Set SPOTIFY_ACCESS_TOKEN in the Native OpenClaw environment before using Spotify tools.',
      });
    }

    try {
      return switch (canonical) {
        'spotify-player.currently-playing' =>
          await _handleCurrentlyPlaying(token),
        _ => await _handleProfile(token),
      };
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'SPOTIFY_TIMEOUT',
        'message': 'Spotify request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'SPOTIFY_ERROR',
        'message': error.toString(),
      });
    }
  }

  Future<NodeFrame> _handleProfile(String token) async {
    final startedAt = DateTime.now();
    final response = await _client
        .get(
          _baseUri.replace(path: '/v1/me'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _httpError(response);
    }
    final json = _jsonMap(response.body);
    final externalUrls = json['external_urls'];
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-spotify-rest',
      'action': 'profile',
      'id': json['id']?.toString(),
      'displayName': json['display_name']?.toString(),
      'product': json['product']?.toString(),
      if (externalUrls is Map)
        'profileUrl': externalUrls['spotify']?.toString(),
      'elapsedMs': elapsedMs,
    });
  }

  Future<NodeFrame> _handleCurrentlyPlaying(String token) async {
    final startedAt = DateTime.now();
    final response = await _client
        .get(
          _baseUri.replace(path: '/v1/me/player/currently-playing'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 204) {
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      return NodeFrame.response('', payload: {
        'runtime': 'app-native-spotify-rest',
        'action': 'currently-playing',
        'isPlaying': false,
        'item': null,
        'elapsedMs': elapsedMs,
      });
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _httpError(response);
    }
    final json = _jsonMap(response.body);
    final item = json['item'];
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-spotify-rest',
      'action': 'currently-playing',
      'isPlaying': json['is_playing'] == true,
      if (item is Map) 'item': _itemPreview(Map<String, dynamic>.from(item)),
      'elapsedMs': elapsedMs,
    });
  }

  NodeFrame _httpError(http.Response response) {
    return NodeFrame.response('', error: {
      'code': 'SPOTIFY_HTTP_ERROR',
      'message': 'Spotify returned HTTP ${response.statusCode}.',
      'statusCode': response.statusCode,
    });
  }

  static String _canonicalCommand(
    String command,
    Map<String, dynamic> params,
  ) {
    final normalized =
        command.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    final action = params['action']?.toString().trim().toLowerCase();
    if (action == 'currently-playing' ||
        action == 'current' ||
        action == 'now-playing') {
      return 'spotify-player.currently-playing';
    }
    if (action == 'profile' || action == 'status' || action == 'me') {
      return 'spotify-player.profile';
    }
    return switch (normalized) {
      'spotify' ||
      'spotify-player' ||
      'spotify.profile' ||
      'spotify-player.profile' ||
      'spotify-status' ||
      'spotify.status' ||
      'profile' ||
      'me' ||
      'status' =>
        'spotify-player.profile',
      'spotify.currently-playing' ||
      'spotify-player.currently-playing' ||
      'spotify-now-playing' ||
      'spotify.current' ||
      'currently-playing' ||
      'now-playing' =>
        'spotify-player.currently-playing',
      _ => normalized,
    };
  }

  static Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'OpenClaw-Android',
      };

  static Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Spotify response was not a JSON object.');
  }

  static Map<String, dynamic> _itemPreview(Map<String, dynamic> item) => {
        'id': item['id']?.toString(),
        'name': item['name']?.toString(),
        'type': item['type']?.toString(),
        if (item['artists'] is List)
          'artists': (item['artists'] as List)
              .whereType<Map>()
              .map((artist) => artist['name']?.toString())
              .whereType<String>()
              .take(5)
              .toList(growable: false),
        if (item['external_urls'] is Map)
          'url': (item['external_urls'] as Map)['spotify']?.toString(),
      };

  static Future<String?> _readNativeSpotifyToken() =>
      NativeEnv.readFirst(const ['SPOTIFY_ACCESS_TOKEN', 'SPOTIFY_TOKEN']);
}
