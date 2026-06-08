import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

typedef SlackConfigProvider = Future<SlackConfig?> Function();

class SlackConfig {
  final String botToken;
  final String? defaultChannel;

  const SlackConfig({
    required this.botToken,
    this.defaultChannel,
  });

  bool get isValid => botToken.trim().isNotEmpty;

  String? channelFor(dynamic channel) {
    final explicit = channel?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final fallback = defaultChannel?.trim();
    return fallback == null || fallback.isEmpty ? null : fallback;
  }
}

class SlackCapability extends CapabilityHandler {
  SlackCapability({
    http.Client? client,
    SlackConfigProvider? configProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _configProvider = configProvider ?? _readNativeSlackConfig,
        _baseUri = baseUri ?? Uri.parse('https://slack.com');

  static const int _maxTextPreviewChars = 240;

  final http.Client _client;
  final SlackConfigProvider _configProvider;
  final Uri _baseUri;

  @override
  String get name => 'slack';

  @override
  List<String> get commands => const ['me', 'post'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'slack.me' && canonical != 'slack.post') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown Slack command: $command',
      });
    }

    final config = await _configProvider();
    if (config == null || !config.isValid) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_SLACK_CONFIG',
        'message':
            'Set SLACK_BOT_TOKEN and channels.slack in the Native OpenClaw environment before using Slack tools.',
      });
    }

    return switch (canonical) {
      'slack.me' => await _handleMe(config),
      'slack.post' => await _handlePost(config, params),
      _ => NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown Slack command: $command',
        }),
    };
  }

  Future<NodeFrame> _handleMe(SlackConfig config) async {
    try {
      final startedAt = DateTime.now();
      final response = await _client
          .post(
            _baseUri.replace(path: '/api/auth.test'),
            headers: _headers(config.botToken),
            body: '{}',
          )
          .timeout(const Duration(seconds: 15));
      final error = _slackResponseError(response);
      if (error != null) return error;
      final json = _jsonMap(response.body);
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      return NodeFrame.response('', payload: {
        'runtime': 'app-native-slack-rest',
        'action': 'me',
        'team': json['team']?.toString(),
        'teamId': json['team_id']?.toString(),
        'url': json['url']?.toString(),
        'user': json['user']?.toString(),
        'userId': json['user_id']?.toString(),
        'botId': json['bot_id']?.toString(),
        if (config.channelFor(null) != null)
          'defaultChannel': config.channelFor(null),
        'elapsedMs': elapsedMs,
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'SLACK_TIMEOUT',
        'message': 'Slack request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'SLACK_ERROR',
        'message': error.toString(),
      });
    }
  }

  Future<NodeFrame> _handlePost(
    SlackConfig config,
    Map<String, dynamic> params,
  ) async {
    final text = params['text']?.toString().trim();
    if (text == null || text.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_SLACK_TEXT',
        'message': 'slack.post requires non-empty text.',
      });
    }
    final channel = config.channelFor(params['channel']);
    if (channel == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_SLACK_CHANNEL',
        'message':
            'slack.post requires a channel argument or configured channels.slack value.',
      });
    }

    try {
      final startedAt = DateTime.now();
      final response = await _client
          .post(
            _baseUri.replace(path: '/api/chat.postMessage'),
            headers: _headers(config.botToken),
            body: jsonEncode({
              'channel': channel,
              'text': text,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final error = _slackResponseError(response);
      if (error != null) return error;
      final json = _jsonMap(response.body);
      final message = _mapValue(json['message']);
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      return NodeFrame.response('', payload: {
        'runtime': 'app-native-slack-rest',
        'action': 'post',
        'channel': json['channel']?.toString() ?? channel,
        'ts': json['ts']?.toString(),
        'messageUser': message?['user']?.toString(),
        'textPreview': _textPreview(message?['text']?.toString() ?? text),
        'elapsedMs': elapsedMs,
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'SLACK_TIMEOUT',
        'message': 'Slack request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'SLACK_ERROR',
        'message': error.toString(),
      });
    }
  }

  NodeFrame? _slackResponseError(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return NodeFrame.response('', error: {
        'code': 'SLACK_HTTP_ERROR',
        'message': 'Slack returned HTTP ${response.statusCode}.',
        'statusCode': response.statusCode,
        if (response.headers['retry-after'] != null)
          'retryAfterSeconds': response.headers['retry-after'],
      });
    }
    final json = _jsonMap(response.body);
    if (json['ok'] == true) return null;
    return NodeFrame.response('', error: {
      'code': 'SLACK_API_ERROR',
      'message': 'Slack API returned ${json['error'] ?? 'an error'}.',
      'slackError': json['error']?.toString(),
    });
  }

  static Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer ${token.trim()}',
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        'User-Agent': 'OpenClaw-Android',
      };

  static String _canonicalCommand(
    String command,
    Map<String, dynamic> params,
  ) {
    final normalized = command.trim().toLowerCase().replaceAll('_', '.');
    final action = params['action']?.toString().trim().toLowerCase();
    return switch (normalized) {
      'slack' ||
      'slack.me' ||
      'slack.status' ||
      'status' ||
      'me' =>
        action == null || action.isEmpty || action == 'me' || action == 'status'
            ? 'slack.me'
            : normalized,
      'slack.post' || 'post' || 'message' => action == null ||
              action.isEmpty ||
              action == 'post' ||
              action == 'message'
          ? 'slack.post'
          : normalized,
      _ => normalized,
    };
  }

  static Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Slack response was not an object.');
  }

  static Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String _textPreview(String value) {
    final normalized = value.trim();
    if (normalized.length <= _maxTextPreviewChars) return normalized;
    return normalized.substring(0, _maxTextPreviewChars);
  }

  static Future<SlackConfig?> _readNativeSlackConfig() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final openClawDir = path.join(
        filesDir,
        'native-node-embedded',
        'native-home',
        '.openclaw',
      );
      final envFile = File(path.join(openClawDir, '.env'));
      final configFile = File(path.join(openClawDir, 'openclaw.json'));
      if (!await envFile.exists()) return null;

      final env = await envFile.readAsString();
      final token = _readDotEnvKey(env, 'SLACK_BOT_TOKEN');
      if (token == null) return null;

      String? defaultChannel;
      if (await configFile.exists()) {
        try {
          defaultChannel = _readJsonKey(
            await configFile.readAsString(),
            'channels.slack',
          );
        } catch (_) {
          defaultChannel = null;
        }
      }
      return SlackConfig(
        botToken: token,
        defaultChannel: defaultChannel,
      );
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

  static String? _readJsonKey(String text, String dottedKey) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) return null;
    final root = Map<String, dynamic>.from(decoded);
    final flat = root[dottedKey]?.toString().trim();
    if (flat != null && flat.isNotEmpty) return flat;

    dynamic cursor = root;
    for (final part in dottedKey.split('.')) {
      if (cursor is! Map || !cursor.containsKey(part)) return null;
      cursor = cursor[part];
    }
    final value = cursor?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}
