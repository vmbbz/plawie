import '../../models/chat_message.dart';
import '../../models/node_frame.dart';
import '../chat_persistence_service.dart';
import 'capability_handler.dart';

class SessionLogsCapability extends CapabilityHandler {
  SessionLogsCapability({SessionLogSource? source})
      : _source = source ?? ChatPersistenceSessionLogSource();

  static const int _defaultLimit = 10;
  static const int _defaultMaxMessageChars = 240;

  final SessionLogSource _source;

  @override
  String get name => 'session-logs';

  @override
  List<String> get commands => const ['query'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command);
    if (canonical != 'session-logs.query') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown session-logs command: $command',
      });
    }

    final action = _action(params);
    final limit = _intParam(params['limit'], _defaultLimit, 1, 100);
    final maxMessageChars = _intParam(
      params['maxMessageChars'],
      _defaultMaxMessageChars,
      40,
      2000,
    );

    try {
      final snapshot = await _source.snapshot();
      return switch (action) {
        'list' => _listSessions(snapshot, limit),
        'read' => await _readSession(snapshot, params, limit, maxMessageChars),
        'search' => await _searchSessions(
            snapshot,
            params,
            limit,
            maxMessageChars,
          ),
        _ => NodeFrame.response('', error: {
            'code': 'INVALID_ACTION',
            'message':
                'session-logs action must be one of list, read, or search.',
          }),
      };
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'SESSION_LOGS_ERROR',
        'message': error.toString(),
      });
    }
  }

  NodeFrame _listSessions(SessionLogSnapshot snapshot, int limit) {
    final sessions = snapshot.sessions.take(limit).map((session) {
      return _sessionSummary(session, snapshot.activeSessionId);
    }).toList(growable: false);

    return NodeFrame.response('', payload: {
      'runtime': 'app-native-session-logs',
      'action': 'list',
      'scope': 'app-chat-sessions',
      'totalSessionCount': snapshot.sessions.length,
      'returnedSessionCount': sessions.length,
      'activeSessionId': snapshot.activeSessionId,
      'sessions': sessions,
    });
  }

  Future<NodeFrame> _readSession(
    SessionLogSnapshot snapshot,
    Map<String, dynamic> params,
    int limit,
    int maxMessageChars,
  ) async {
    final session = _selectedSession(snapshot, params);
    if (session == null) {
      return NodeFrame.response('', error: {
        'code': 'SESSION_NOT_FOUND',
        'message': 'No matching app chat session was found.',
      });
    }

    final messages = await _source.loadMessages(session.id);
    final start = messages.length > limit ? messages.length - limit : 0;
    final selected = messages.sublist(start);
    final mapped = <Map<String, dynamic>>[];
    for (var i = 0; i < selected.length; i++) {
      mapped.add(_messageSummary(selected[i], start + i, maxMessageChars));
    }

    return NodeFrame.response('', payload: {
      'runtime': 'app-native-session-logs',
      'action': 'read',
      'scope': 'app-chat-sessions',
      'session': _sessionSummary(session, snapshot.activeSessionId),
      'totalMessageCount': messages.length,
      'returnedMessageCount': mapped.length,
      'messages': mapped,
    });
  }

  Future<NodeFrame> _searchSessions(
    SessionLogSnapshot snapshot,
    Map<String, dynamic> params,
    int limit,
    int maxMessageChars,
  ) async {
    final query = (params['query'] ?? params['text'])?.toString().trim();
    if (query == null || query.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_QUERY',
        'message': 'session-logs search requires a query.',
      });
    }

    final normalizedQuery = query.toLowerCase();
    final matches = <Map<String, dynamic>>[];
    for (final session in snapshot.sessions) {
      if (matches.length >= limit) break;
      final messages = await _source.loadMessages(session.id);
      for (var i = 0; i < messages.length; i++) {
        if (matches.length >= limit) break;
        final normalizedText = messages[i].text.toLowerCase();
        if (!normalizedText.contains(normalizedQuery)) continue;
        matches.add({
          'session': _sessionSummary(session, snapshot.activeSessionId),
          'message': _messageSummary(messages[i], i, maxMessageChars),
        });
      }
    }

    return NodeFrame.response('', payload: {
      'runtime': 'app-native-session-logs',
      'action': 'search',
      'scope': 'app-chat-sessions',
      'query': query,
      'searchedSessionCount': snapshot.sessions.length,
      'matchCount': matches.length,
      'matches': matches,
    });
  }

  static String _canonicalCommand(String command) {
    final normalized = command.trim().toLowerCase().replaceAll('_', '-');
    return switch (normalized) {
      'session-logs' ||
      'session-logs.query' ||
      'session-logs-query' ||
      'query' =>
        'session-logs.query',
      _ => normalized,
    };
  }

  static String _action(Map<String, dynamic> params) {
    final raw = (params['action'] ?? params['mode'] ?? 'list')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('_', '-');
    return switch (raw) {
      'active' || 'show' || 'read-active' => 'read',
      _ => raw,
    };
  }

  static ChatSession? _selectedSession(
    SessionLogSnapshot snapshot,
    Map<String, dynamic> params,
  ) {
    final raw = (params['sessionId'] ?? params['id'])?.toString().trim();
    final sessionId = raw == null || raw.isEmpty || raw == 'active'
        ? snapshot.activeSessionId
        : raw;
    if (sessionId == null || sessionId.isEmpty) return null;
    for (final session in snapshot.sessions) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  static Map<String, dynamic> _sessionSummary(
    ChatSession session,
    String? activeSessionId,
  ) {
    return {
      'id': session.id,
      'title': session.title,
      'createdAt': session.createdAt.toIso8601String(),
      'updatedAt': session.updatedAt.toIso8601String(),
      'active': session.id == activeSessionId,
      'hasGatewaySessionKey':
          session.gatewaySessionKey?.trim().isNotEmpty == true,
    };
  }

  static Map<String, dynamic> _messageSummary(
    ChatMessage message,
    int index,
    int maxMessageChars,
  ) {
    final textPreview = _preview(message.text, maxMessageChars);
    final toolEventNames = (message.toolEvents ?? const <ChatToolEvent>[])
        .map((event) => event.name)
        .take(8)
        .toList(growable: false);
    return {
      'index': index,
      'role': message.isUser ? 'user' : 'assistant',
      'textPreview': textPreview,
      'chars': message.text.length,
      'truncated':
          textPreview.length < _normalizeWhitespace(message.text).length,
      'hasImage': message.hasImage,
      'hasReasoning': message.hasThinkContent,
      'toolEventCount': message.toolEvents?.length ?? 0,
      if (toolEventNames.isNotEmpty) 'toolEventNames': toolEventNames,
    };
  }

  static String _preview(String value, int maxChars) {
    final normalized = _normalizeWhitespace(value);
    if (normalized.length <= maxChars) return normalized;
    if (maxChars <= 3) return normalized.substring(0, maxChars);
    return '${normalized.substring(0, maxChars - 3).trimRight()}...';
  }

  static String _normalizeWhitespace(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static int _intParam(dynamic value, int fallback, int min, int max) {
    final parsed = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()),
      _ => null,
    };
    return (parsed ?? fallback).clamp(min, max).toInt();
  }
}

abstract class SessionLogSource {
  Future<SessionLogSnapshot> snapshot();
  Future<List<ChatMessage>> loadMessages(String sessionId);
}

class SessionLogSnapshot {
  final List<ChatSession> sessions;
  final String? activeSessionId;

  const SessionLogSnapshot({
    required this.sessions,
    required this.activeSessionId,
  });
}

class ChatPersistenceSessionLogSource implements SessionLogSource {
  ChatPersistenceSessionLogSource({ChatPersistenceService? persistence})
      : _persistence = persistence ?? ChatPersistenceService();

  final ChatPersistenceService _persistence;

  @override
  Future<SessionLogSnapshot> snapshot() async {
    await _persistence.init();
    return SessionLogSnapshot(
      sessions: _persistence.sessions,
      activeSessionId: _persistence.activeSessionId,
    );
  }

  @override
  Future<List<ChatMessage>> loadMessages(String sessionId) async {
    await _persistence.init();
    return _persistence.loadMessagesForSession(sessionId);
  }
}
