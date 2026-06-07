import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

typedef NotionTokenProvider = Future<String?> Function();

class NotionCapability extends CapabilityHandler {
  NotionCapability({
    http.Client? client,
    NotionTokenProvider? tokenProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider ?? _readNativeNotionToken,
        _baseUri = baseUri ?? Uri.parse('https://api.notion.com');

  static const int _defaultLimit = 5;
  static const int _maxLimit = 10;
  static const String _notionVersion = '2026-03-11';

  final http.Client _client;
  final NotionTokenProvider _tokenProvider;
  final Uri _baseUri;

  @override
  String get name => 'notion';

  @override
  List<String> get commands => const ['search'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'notion.search') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown Notion command: $command',
      });
    }

    final token = (await _tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_NOTION_TOKEN',
        'message':
            'Set NOTION_TOKEN in the Native OpenClaw environment before using Notion tools.',
      });
    }

    final query = _query(params);
    if (query == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_QUERY',
        'message': 'notion.search requires a non-empty query.',
      });
    }

    try {
      final limit = _intParam(params['limit'], _defaultLimit, 1, _maxLimit);
      final objectFilter =
          _objectFilterValue(params['object'] ?? params['type']);
      final startCursor =
          _optionalString(params['startCursor'] ?? params['start_cursor']);
      final body = <String, dynamic>{
        'query': query,
        'page_size': limit,
        'sort': {
          'direction': 'descending',
          'timestamp': 'last_edited_time',
        },
        if (objectFilter != null)
          'filter': {
            'property': 'object',
            'value': objectFilter,
          },
        if (startCursor != null) 'start_cursor': startCursor,
      };
      final startedAt = DateTime.now();
      final response = await _client
          .post(
            _baseUri.replace(path: '/v1/search'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Notion-Version': _notionVersion,
              'User-Agent': 'OpenClaw-Android',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _httpError(response);
      }
      final decoded = _jsonMap(response.body);
      final rawResults = decoded['results'];
      if (rawResults != null && rawResults is! List) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_NOTION_RESPONSE',
          'message': 'Notion search response results field was not a list.',
        });
      }
      final results = (rawResults as List? ?? const <dynamic>[])
          .whereType<Map>()
          .take(limit)
          .map((item) => _resultPreview(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      return NodeFrame.response('', payload: {
        'runtime': 'app-native-notion-rest',
        'action': 'search',
        'query': query,
        'count': results.length,
        'hasMore': decoded['has_more'] == true,
        if (decoded['next_cursor'] != null)
          'nextCursor': decoded['next_cursor']?.toString(),
        'results': results,
        'elapsedMs': elapsedMs,
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'NOTION_TIMEOUT',
        'message': 'Notion request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'NOTION_ERROR',
        'message': error.toString(),
      });
    }
  }

  NodeFrame _httpError(http.Response response) {
    return NodeFrame.response('', error: {
      'code': 'NOTION_HTTP_ERROR',
      'message': 'Notion returned HTTP ${response.statusCode}.',
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
      'notion' ||
      'notion.search' ||
      'search' =>
        action == null || action.isEmpty || action == 'search'
            ? 'notion.search'
            : normalized,
      _ => normalized,
    };
  }

  static String? _query(Map<String, dynamic> params) {
    final query = (params['query'] ?? params['text'])?.toString().trim();
    if (query == null || query.isEmpty) return null;
    if (query.length > 500) return query.substring(0, 500);
    return query;
  }

  static Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Notion response was not an object.');
  }

  static Map<String, dynamic> _resultPreview(Map<String, dynamic> item) => {
        'object': item['object']?.toString(),
        'id': item['id']?.toString(),
        'title': _title(item),
        'url': item['url']?.toString(),
        if (item['public_url'] != null)
          'publicUrl': item['public_url']?.toString(),
        'createdTime': item['created_time']?.toString(),
        'lastEditedTime': item['last_edited_time']?.toString(),
        if (item['archived'] != null) 'archived': item['archived'],
        if (item['is_archived'] != null) 'archived': item['is_archived'],
        if (item['in_trash'] != null) 'inTrash': item['in_trash'],
      };

  static String? _title(Map<String, dynamic> item) {
    final title = _titleFromProperties(item['properties']);
    if (title != null) return title;
    final rawTitle = item['title'];
    if (rawTitle is List) return _plainTextFromRichText(rawTitle);
    return rawTitle?.toString();
  }

  static String? _titleFromProperties(dynamic properties) {
    if (properties is! Map) return null;
    for (final property in properties.values) {
      if (property is! Map) continue;
      final type = property['type']?.toString();
      final candidate = switch (type) {
        'title' => property['title'],
        'name' => property['name'],
        _ => property['title'] ?? property['name'],
      };
      final title = candidate is List
          ? _plainTextFromRichText(candidate)
          : candidate?.toString();
      if (title != null && title.trim().isNotEmpty) return title.trim();
    }
    return null;
  }

  static String? _plainTextFromRichText(List<dynamic> richText) {
    final text = richText
        .whereType<Map>()
        .map((item) => item['plain_text']?.toString() ?? '')
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    return text.isEmpty ? null : text;
  }

  static String? _objectFilterValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'page' || 'pages' => 'page',
      'data_source' ||
      'data-source' ||
      'data source' ||
      'database' ||
      'databases' =>
        'data_source',
      _ => null,
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

  static Future<String?> _readNativeNotionToken() async {
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
      return _readDotEnvKey(await envFile.readAsString(), 'NOTION_TOKEN');
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
