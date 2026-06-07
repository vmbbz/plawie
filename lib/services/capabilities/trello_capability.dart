import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

typedef TrelloCredentialsProvider = Future<TrelloCredentials?> Function();

class TrelloCredentials {
  final String apiKey;
  final String token;

  const TrelloCredentials({
    required this.apiKey,
    required this.token,
  });

  bool get isValid => apiKey.trim().isNotEmpty && token.trim().isNotEmpty;
}

class TrelloCapability extends CapabilityHandler {
  TrelloCapability({
    http.Client? client,
    TrelloCredentialsProvider? credentialsProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _credentialsProvider =
            credentialsProvider ?? _readNativeTrelloCredentials,
        _baseUri = baseUri ?? Uri.parse('https://api.trello.com');

  static const int _defaultLimit = 10;
  static const int _maxLimit = 20;

  final http.Client _client;
  final TrelloCredentialsProvider _credentialsProvider;
  final Uri _baseUri;

  @override
  String get name => 'trello';

  @override
  List<String> get commands => const ['boards'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'trello.boards') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown Trello command: $command',
      });
    }

    final credentials = await _credentialsProvider();
    if (credentials == null || !credentials.isValid) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_TRELLO_CONFIG',
        'message':
            'Set TRELLO_API_KEY and TRELLO_TOKEN in the Native OpenClaw environment before using Trello tools.',
      });
    }

    try {
      final limit = _intParam(params['limit'], _defaultLimit, 1, _maxLimit);
      final startedAt = DateTime.now();
      final response = await _client.get(
        _baseUri.replace(
          path: '/1/members/me/boards',
          queryParameters: {
            'key': credentials.apiKey.trim(),
            'token': credentials.token.trim(),
            'fields': 'name,url,closed,dateLastActivity',
            'filter': _filter(params['filter']),
          },
        ),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'OpenClaw-Android',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _httpError(response);
      }
      final json = jsonDecode(response.body);
      if (json is! List) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_TRELLO_RESPONSE',
          'message': 'Trello boards response was not a list.',
        });
      }
      final boards = json
          .whereType<Map>()
          .take(limit)
          .map((board) => _boardPreview(Map<String, dynamic>.from(board)))
          .toList(growable: false);
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      return NodeFrame.response('', payload: {
        'runtime': 'app-native-trello-rest',
        'action': 'boards',
        'count': boards.length,
        'boards': boards,
        'elapsedMs': elapsedMs,
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'TRELLO_TIMEOUT',
        'message': 'Trello request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'TRELLO_ERROR',
        'message': error.toString(),
      });
    }
  }

  NodeFrame _httpError(http.Response response) {
    return NodeFrame.response('', error: {
      'code': 'TRELLO_HTTP_ERROR',
      'message': 'Trello returned HTTP ${response.statusCode}.',
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
      'trello' || 'trello.boards' || 'boards' => action == null ||
              action.isEmpty ||
              action == 'boards' ||
              action == 'summary'
          ? 'trello.boards'
          : normalized,
      _ => normalized,
    };
  }

  static Map<String, dynamic> _boardPreview(Map<String, dynamic> board) => {
        'id': board['id']?.toString(),
        'name': board['name']?.toString(),
        'url': board['url']?.toString(),
        'closed': board['closed'] == true,
        if (board['dateLastActivity'] != null)
          'dateLastActivity': board['dateLastActivity']?.toString(),
      };

  static String _filter(dynamic value) {
    final filter = value?.toString().trim().toLowerCase();
    return switch (filter) {
      'all' => 'all',
      'closed' => 'closed',
      _ => 'open',
    };
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

  static Future<TrelloCredentials?> _readNativeTrelloCredentials() async {
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
      final env = await envFile.readAsString();
      final apiKey = _readDotEnvKey(env, 'TRELLO_API_KEY');
      final token = _readDotEnvKey(env, 'TRELLO_TOKEN');
      if (apiKey == null || token == null) return null;
      return TrelloCredentials(apiKey: apiKey, token: token);
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
