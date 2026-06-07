import 'dart:async';

import 'package:http/http.dart' as http;

import '../../models/node_frame.dart';
import 'capability_handler.dart';
import 'xurl_capability.dart';

class BlogWatcherCapability extends CapabilityHandler {
  BlogWatcherCapability({http.Client? client})
      : _client = client ?? http.Client();

  static const int _defaultLimit = 5;
  static const int _defaultMaxBytes = 200 * 1024;
  static const int _maxPreviewChars = 320;

  final http.Client _client;

  @override
  String get name => 'blogwatcher';

  @override
  List<String> get commands => const ['check'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command);
    if (canonical != 'blogwatcher.check') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown blogwatcher command: $command',
      });
    }

    final uri = _uriFromParams(params);
    if (uri == null) {
      return NodeFrame.response('', error: {
        'code': 'INVALID_URL',
        'message': 'blogwatcher.check requires an absolute http or https URL.',
      });
    }
    if (_blockedHost(uri.host)) {
      return NodeFrame.response('', error: {
        'code': 'BLOCKED_HOST',
        'message':
            'blogwatcher.check blocks loopback, private, and link-local hosts.',
      });
    }

    final limit = _intParam(params['limit'], _defaultLimit, 1, 20);
    final maxBytes =
        _intParam(params['maxBytes'], _defaultMaxBytes, 1024, 512 * 1024);
    final knownIds = _stringSet(params['knownIds']);

    try {
      final startedAt = DateTime.now();
      final response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/rss+xml, application/atom+xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 15));
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      if (response.bodyBytes.length > maxBytes) {
        return NodeFrame.response('', error: {
          'code': 'FEED_TOO_LARGE',
          'message': 'blogwatcher.check response exceeded $maxBytes bytes.',
        });
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return NodeFrame.response('', error: {
          'code': 'HTTP_ERROR',
          'message': 'Feed returned HTTP ${response.statusCode}.',
        });
      }

      final parsed = _parseFeed(response.body);
      final items = parsed.items.take(limit).toList(growable: false);
      final newItems = items.where((item) {
        final id = item['id']?.toString();
        return id == null || !knownIds.contains(id);
      }).toList(growable: false);

      return NodeFrame.response('', payload: {
        'runtime': 'app-native-feed-check',
        'feedUrl': uri.toString(),
        'feedTitle': parsed.title,
        'statusCode': response.statusCode,
        'contentType': response.headers['content-type'],
        'bytes': response.bodyBytes.length,
        'itemCount': items.length,
        'newItemCount': newItems.length,
        'truncated': parsed.items.length > items.length,
        'elapsedMs': elapsedMs,
        'items': items,
        'newItems': newItems,
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'BLOGWATCHER_TIMEOUT',
        'message': 'blogwatcher.check timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'BLOGWATCHER_ERROR',
        'message': error.toString(),
      });
    }
  }

  static String _canonicalCommand(String command) {
    final normalized = command.trim().toLowerCase().replaceAll('_', '.');
    return switch (normalized) {
      'blogwatcher' || 'check' || 'blogwatcher.check' => 'blogwatcher.check',
      _ => normalized,
    };
  }

  static Uri? _uriFromParams(Map<String, dynamic> params) {
    final raw = (params['url'] ?? params['feedUrl'] ?? params['uri'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    return uri;
  }

  static bool _blockedHost(String host) {
    final normalized =
        host.trim().toLowerCase().replaceAll('[', '').replaceAll(']', '');
    if (normalized == 'localhost' ||
        normalized.endsWith('.local') ||
        XurlCapability.isLoopbackHostForPolicy(normalized)) {
      return true;
    }
    final parts = normalized.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList(growable: false);
    if (octets.any((value) => value == null)) return false;
    final a = octets[0]!;
    final b = octets[1]!;
    if (a == 10 || a == 0 || a == 127 || a == 169 && b == 254) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
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

  static Set<String> _stringSet(dynamic value) {
    if (value is! List) return const <String>{};
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  static _ParsedFeed _parseFeed(String xml) {
    final title = _tagText(xml, 'title') ?? 'Untitled feed';
    final blocks = _blocks(xml, 'item');
    final itemBlocks = blocks.isNotEmpty ? blocks : _blocks(xml, 'entry');
    final items = <Map<String, dynamic>>[];
    for (final block in itemBlocks) {
      final title = _tagText(block, 'title') ?? 'Untitled item';
      final id = _tagText(block, 'guid') ??
          _tagText(block, 'id') ??
          _tagText(block, 'link') ??
          _tagAttribute(block, 'link', 'href') ??
          title;
      final link =
          _tagText(block, 'link') ?? _tagAttribute(block, 'link', 'href');
      final published = _tagText(block, 'pubDate') ??
          _tagText(block, 'published') ??
          _tagText(block, 'updated');
      final summary = _tagText(block, 'description') ??
          _tagText(block, 'summary') ??
          _tagText(block, 'content');
      items.add({
        'id': id,
        'title': title,
        if (link != null && link.isNotEmpty) 'link': link,
        if (published != null && published.isNotEmpty) 'published': published,
        if (summary != null && summary.isNotEmpty)
          'summaryPreview': _preview(summary),
      });
    }
    return _ParsedFeed(title: title, items: items);
  }

  static List<String> _blocks(String xml, String tag) {
    return RegExp(
      '<$tag\\b[^>]*>(.*?)</$tag>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(xml).map((match) => match.group(1) ?? '').toList();
  }

  static String? _tagText(String xml, String tag) {
    final match = RegExp(
      '<$tag\\b[^>]*>(.*?)</$tag>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(xml);
    final raw = match?.group(1);
    if (raw == null) return null;
    return _cleanText(raw);
  }

  static String? _tagAttribute(String xml, String tag, String attribute) {
    final match = RegExp(
      '<$tag\\b[^>]*\\s$attribute=["\']([^"\']+)["\'][^>]*>',
      caseSensitive: false,
    ).firstMatch(xml);
    return match == null ? null : _decodeXml(match.group(1) ?? '').trim();
  }

  static String _cleanText(String raw) {
    final withoutCdata = raw
        .replaceAll(RegExp(r'<!\[CDATA\[', caseSensitive: false), '')
        .replaceAll(RegExp(r'\]\]>'), '');
    final withoutTags = withoutCdata.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return _decodeXml(withoutTags).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _preview(String text) {
    if (text.length <= _maxPreviewChars) return text;
    return '${text.substring(0, _maxPreviewChars - 3).trimRight()}...';
  }

  static String _decodeXml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}

class _ParsedFeed {
  final String title;
  final List<Map<String, dynamic>> items;

  const _ParsedFeed({
    required this.title,
    required this.items,
  });
}
