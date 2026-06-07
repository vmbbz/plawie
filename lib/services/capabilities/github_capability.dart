import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

typedef GitHubTokenProvider = Future<String?> Function();

class GitHubCapability extends CapabilityHandler {
  GitHubCapability({
    http.Client? client,
    GitHubTokenProvider? tokenProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider ?? _readNativeGitHubToken,
        _baseUri = baseUri ?? Uri.parse('https://api.github.com');

  static const int _defaultLimit = 10;
  static const int _maxLimit = 20;
  final http.Client _client;
  final GitHubTokenProvider _tokenProvider;
  final Uri _baseUri;

  @override
  String get name => 'github';

  @override
  List<String> get commands => const ['user', 'issues'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'github.user' && canonical != 'gh-issues.list') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown GitHub command: $command',
      });
    }

    final token = (await _tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_GITHUB_TOKEN',
        'message':
            'Set GITHUB_TOKEN in the Native OpenClaw environment before using GitHub tools.',
      });
    }

    try {
      return switch (canonical) {
        'github.user' => await _handleUser(token),
        _ => await _handleIssues(token, params),
      };
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'GITHUB_TIMEOUT',
        'message': 'GitHub request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'GITHUB_ERROR',
        'message': error.toString(),
      });
    }
  }

  Future<NodeFrame> _handleUser(String token) async {
    final startedAt = DateTime.now();
    final response = await _client
        .get(_baseUri.replace(path: '/user'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _httpError(response);
    }
    final json = _jsonMap(response.body);
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-github-rest',
      'action': 'user',
      'login': json['login']?.toString(),
      'id': json['id'],
      'name': json['name']?.toString(),
      'profileUrl': json['html_url']?.toString(),
      'elapsedMs': elapsedMs,
    });
  }

  Future<NodeFrame> _handleIssues(
    String token,
    Map<String, dynamic> params,
  ) async {
    final owner = params['owner']?.toString().trim();
    final repo = params['repo']?.toString().trim();
    if (!_validRepoPart(owner) || !_validRepoPart(repo)) {
      return NodeFrame.response('', error: {
        'code': 'INVALID_REPOSITORY',
        'message': 'gh-issues.list requires owner and repo.',
      });
    }
    final state = _state(params['state']);
    final limit = _intParam(params['limit'], _defaultLimit, 1, _maxLimit);
    final uri = _baseUri.replace(
      path: '/repos/$owner/$repo/issues',
      queryParameters: {
        'state': state,
        'per_page': '$limit',
      },
    );
    final startedAt = DateTime.now();
    final response = await _client.get(uri, headers: _headers(token)).timeout(
          const Duration(seconds: 15),
        );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _httpError(response);
    }
    final json = jsonDecode(response.body);
    if (json is! List) {
      return NodeFrame.response('', error: {
        'code': 'INVALID_GITHUB_RESPONSE',
        'message': 'GitHub issues response was not a list.',
      });
    }
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final issues = json
        .whereType<Map>()
        .take(limit)
        .map((item) => _issuePreview(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-github-rest',
      'action': 'issues.list',
      'repository': '$owner/$repo',
      'state': state,
      'count': issues.length,
      'issues': issues,
      'elapsedMs': elapsedMs,
    });
  }

  NodeFrame _httpError(http.Response response) {
    return NodeFrame.response('', error: {
      'code': 'GITHUB_HTTP_ERROR',
      'message': 'GitHub returned HTTP ${response.statusCode}.',
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
      'github' ||
      'github.user' ||
      'github.viewer' ||
      'user' =>
        action == 'issues' || action == 'list_issues'
            ? 'gh-issues.list'
            : 'github.user',
      'gh-issues' ||
      'gh.issues' ||
      'gh-issues.list' ||
      'github.issues' ||
      'issues' =>
        'gh-issues.list',
      _ => normalized,
    };
  }

  static Map<String, String> _headers(String token) => {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'OpenClaw-Android',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  static Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('GitHub response was not a JSON object.');
  }

  static Map<String, dynamic> _issuePreview(Map<String, dynamic> issue) => {
        'number': issue['number'],
        'title': issue['title']?.toString(),
        'state': issue['state']?.toString(),
        'htmlUrl': issue['html_url']?.toString(),
        'createdAt': issue['created_at']?.toString(),
        'updatedAt': issue['updated_at']?.toString(),
        'isPullRequest': issue['pull_request'] is Map,
        if (issue['user'] is Map)
          'user': {
            'login': (issue['user'] as Map)['login']?.toString(),
          },
      };

  static String _state(dynamic value) {
    final state = value?.toString().trim().toLowerCase();
    return switch (state) {
      'closed' => 'closed',
      'all' => 'all',
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

  static bool _validRepoPart(String? value) {
    if (value == null || value.isEmpty || value.length > 100) return false;
    return RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(value);
  }

  static Future<String?> _readNativeGitHubToken() async {
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
      return _readDotEnvKey(await envFile.readAsString(), 'GITHUB_TOKEN');
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
