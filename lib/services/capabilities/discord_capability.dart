import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

typedef DiscordTokenProvider = Future<String?> Function();

class DiscordCapability extends CapabilityHandler {
  DiscordCapability({
    http.Client? client,
    DiscordTokenProvider? tokenProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider ?? _readNativeDiscordBotToken,
        _baseUri = baseUri ?? Uri.parse('https://discord.com');

  final http.Client _client;
  final DiscordTokenProvider _tokenProvider;
  final Uri _baseUri;

  @override
  String get name => 'discord';

  @override
  List<String> get commands => const ['me'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'discord.me') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown Discord command: $command',
      });
    }

    final token = (await _tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_DISCORD_BOT_TOKEN',
        'message':
            'Set DISCORD_BOT_TOKEN in the Native OpenClaw environment before using Discord tools.',
      });
    }

    try {
      final startedAt = DateTime.now();
      final response = await _client.get(
        _baseUri.replace(path: '/api/v10/users/@me'),
        headers: {
          'Authorization': 'Bot $token',
          'Accept': 'application/json',
          'User-Agent': 'OpenClaw-Android',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _httpError(response);
      }
      final json = _jsonMap(response.body);
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      return NodeFrame.response('', payload: {
        'runtime': 'app-native-discord-rest',
        'action': 'me',
        'id': json['id']?.toString(),
        'username': json['username']?.toString(),
        'globalName': json['global_name']?.toString(),
        'discriminator': json['discriminator']?.toString(),
        'bot': json['bot'] == true,
        if (json['avatar'] != null) 'avatar': json['avatar']?.toString(),
        'elapsedMs': elapsedMs,
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'DISCORD_TIMEOUT',
        'message': 'Discord request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'DISCORD_ERROR',
        'message': error.toString(),
      });
    }
  }

  NodeFrame _httpError(http.Response response) {
    return NodeFrame.response('', error: {
      'code': 'DISCORD_HTTP_ERROR',
      'message': 'Discord returned HTTP ${response.statusCode}.',
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
      'discord' ||
      'discord.me' ||
      'discord.status' ||
      'status' ||
      'me' =>
        action == null || action.isEmpty || action == 'me' || action == 'status'
            ? 'discord.me'
            : normalized,
      _ => normalized,
    };
  }

  static Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Discord response was not an object.');
  }

  static Future<String?> _readNativeDiscordBotToken() async {
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
      return _readDotEnvKey(await envFile.readAsString(), 'DISCORD_BOT_TOKEN');
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
