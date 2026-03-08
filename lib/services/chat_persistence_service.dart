import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';

/// Metadata for a single chat session.
class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

/// Multi-session chat persistence.
///
/// Storage layout:
///   chat_sessions.json     — list of ChatSession metadata
///   chat_<sessionId>.json  — messages for each session
///   chat_history.json      — legacy single-session file (migrated on first use)
class ChatPersistenceService {
  static final ChatPersistenceService _instance = ChatPersistenceService._internal();
  factory ChatPersistenceService() => _instance;
  ChatPersistenceService._internal();

  List<ChatSession> _sessions = [];
  String? _activeSessionId;

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  String? get activeSessionId => _activeSessionId;

  Future<Directory> get _dir async => await getApplicationDocumentsDirectory();

  Future<File> get _indexFile async {
    final dir = await _dir;
    return File('${dir.path}/chat_sessions.json');
  }

  Future<File> _sessionFile(String sessionId) async {
    final dir = await _dir;
    return File('${dir.path}/chat_$sessionId.json');
  }

  /// Initialize: load session index, migrate legacy data if needed.
  Future<void> init() async {
    final index = await _indexFile;
    if (await index.exists()) {
      try {
        final data = jsonDecode(await index.readAsString()) as Map<String, dynamic>;
        _sessions = (data['sessions'] as List)
            .map((j) => ChatSession.fromJson(j as Map<String, dynamic>))
            .toList();
        _activeSessionId = data['activeSessionId'] as String?;
      } catch (_) {
        _sessions = [];
      }
    } else {
      // Migrate legacy chat_history.json if it exists
      await _migrateLegacy();
    }

    // Ensure at least one session exists
    if (_sessions.isEmpty) {
      await createSession(title: 'New Chat');
    }
    _activeSessionId ??= _sessions.first.id;
  }

  Future<void> _migrateLegacy() async {
    final dir = await _dir;
    final legacyFile = File('${dir.path}/chat_history.json');
    if (await legacyFile.exists()) {
      try {
        final contents = await legacyFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        final messages = jsonList.map((j) => ChatMessage.fromJson(j)).toList();
        
        if (messages.isNotEmpty) {
          final session = ChatSession(
            id: const Uuid().v4(),
            title: _titleFromMessages(messages),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _sessions.add(session);
          _activeSessionId = session.id;
          
          // Save messages to new session file
          final file = await _sessionFile(session.id);
          await file.writeAsString(jsonEncode(messages.map((m) => m.toJson()).toList()));
          await _saveIndex();
        }
      } catch (_) {}
    }
  }

  String _titleFromMessages(List<ChatMessage> messages) {
    final firstUser = messages.where((m) => m.isUser).firstOrNull;
    if (firstUser != null) {
      final text = firstUser.text;
      return text.length > 40 ? '${text.substring(0, 40)}...' : text;
    }
    return 'Chat';
  }

  Future<void> _saveIndex() async {
    final index = await _indexFile;
    await index.writeAsString(jsonEncode({
      'sessions': _sessions.map((s) => s.toJson()).toList(),
      'activeSessionId': _activeSessionId,
    }));
  }

  /// Create a new chat session and make it active.
  Future<ChatSession> createSession({String title = 'New Chat'}) async {
    final session = ChatSession(
      id: const Uuid().v4(),
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _sessions.insert(0, session);
    _activeSessionId = session.id;
    await _saveIndex();
    return session;
  }

  /// Switch to a different session.
  Future<void> switchSession(String sessionId) async {
    if (_sessions.any((s) => s.id == sessionId)) {
      _activeSessionId = sessionId;
      await _saveIndex();
    }
  }

  /// Delete a session and its messages.
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    final file = await _sessionFile(sessionId);
    if (await file.exists()) await file.delete();
    
    if (_activeSessionId == sessionId) {
      if (_sessions.isEmpty) {
        await createSession();
      } else {
        _activeSessionId = _sessions.first.id;
      }
    }
    await _saveIndex();
  }

  /// Rename a session.
  Future<void> renameSession(String sessionId, String newTitle) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    session.title = newTitle;
    await _saveIndex();
  }

  /// Load messages for the active session.
  Future<List<ChatMessage>> loadMessages() async {
    if (_activeSessionId == null) return [];
    try {
      final file = await _sessionFile(_activeSessionId!);
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save messages for the active session. Auto-titles from first user message.
  Future<void> saveMessages(List<ChatMessage> messages) async {
    if (_activeSessionId == null) return;
    try {
      final file = await _sessionFile(_activeSessionId!);
      final jsonList = messages.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      
      // Auto-update title from first user message
      final session = _sessions.firstWhere((s) => s.id == _activeSessionId);
      if (session.title == 'New Chat') {
        session.title = _titleFromMessages(messages);
      }
      session.updatedAt = DateTime.now();
      await _saveIndex();
    } catch (e) {
      print('Error saving messages: $e');
    }
  }
}
