import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

/// Advanced Memory System with SOUL.md personality and ranked search
/// Inspired by SeekerClaw's memory architecture
class MemoryService {
  static final MemoryService _instance = MemoryService._internal();
  factory MemoryService() => _instance;
  MemoryService._internal();

  final Logger _logger = Logger();
  Database? _database;
  String? _soulMd;
  final StreamController<MemoryEvent> _eventController = StreamController.broadcast();

  Stream<MemoryEvent> get events => _eventController.stream;

  /// Initialize memory system
  Future<void> initialize() async {
    try {
      _logger.i('Initializing Memory System...');
      
      // Get application directory
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(appDir.path, 'openclaw_memory.db');
      
      // Open database
      _database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );

      // Load SOUL.md personality
      await _loadSoulMd();
      
      _logger.i('Memory System initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize Memory System: $e');
      rethrow;
    }
  }

  /// Create database schema
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        keywords TEXT,
        importance REAL DEFAULT 1.0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        session_id TEXT,
        tags TEXT,
        embedding BLOB
      )
    ''');

    await db.execute('''
      CREATE TABLE memory_search_index (
        memory_id INTEGER,
        keyword TEXT,
        frequency REAL DEFAULT 1.0,
        FOREIGN KEY (memory_id) REFERENCES memories (id),
        PRIMARY KEY (memory_id, keyword)
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_notes (
        date TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        summary TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        summary TEXT,
        memory_count INTEGER DEFAULT 0
      )
    ''');

    // Create indexes for better search performance
    await db.execute('CREATE INDEX idx_memories_type ON memories(type)');
    await db.execute('CREATE INDEX idx_memories_created_at ON memories(created_at)');
    await db.execute('CREATE INDEX idx_memories_importance ON memories(importance)');
    await db.execute('CREATE INDEX idx_search_keyword ON memory_search_index(keyword)');
    await db.execute('CREATE INDEX idx_search_frequency ON memory_search_index(frequency)');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades in future versions
  }

  /// Load SOUL.md personality file
  Future<void> _loadSoulMd() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final soulMdPath = path.join(appDir.path, 'SOUL.md');
      
      if (await File(soulMdPath).exists()) {
        _soulMd = await File(soulMdPath).readAsString();
        _logger.i('SOUL.md personality loaded');
      } else {
        // Create default SOUL.md
        _soulMd = _getDefaultSoulMd();
        await File(soulMdPath).writeAsString(_soulMd!);
        _logger.i('Created default SOUL.md');
      }
    } catch (e) {
      _logger.e('Failed to load SOUL.md: $e');
      _soulMd = _getDefaultSoulMd();
    }
  }

  /// Get default SOUL.md content
  String _getDefaultSoulMd() {
    return '''# OpenClaw AI Agent Personality

## Core Identity
I am OpenClaw, a sophisticated AI assistant designed to help users with a wide range of tasks through intelligent conversation and tool execution.

## Personality Traits
- **Helpful**: Always strive to assist users effectively
- **Knowledgeable**: Access to vast information and capabilities
- **Adaptive**: Learn from interactions and user preferences
- **Efficient**: Execute tasks quickly and accurately
- **Secure**: Prioritize user privacy and data protection

## Communication Style
- Clear and concise responses
- Context-aware interactions
- Proactive when helpful
- Respectful of user preferences
- Technical when appropriate

## Capabilities
- Multi-turn tool execution (up to 25 tools per task)
- API integrations and web services
- File management and analysis
- Natural language understanding
- Code generation and debugging
- Research and information synthesis

## Memory System
I maintain a persistent memory of our interactions to provide better service over time. This includes:
- Conversation context
- User preferences
- Task patterns
- Learned information

## Privacy
Your data is stored locally and encrypted. I do not share information with external services unless explicitly requested.

## Learning
I continuously improve from our interactions while maintaining your privacy preferences.
''';
  }

  /// Store a memory
  Future<int> storeMemory({
    required String content,
    required MemoryType type,
    List<String>? keywords,
    double importance = 1.0,
    String? sessionId,
    List<String>? tags,
  }) async {
    if (_database == null) throw Exception('Database not initialized');

    final now = DateTime.now().millisecondsSinceEpoch;
    final keywordsJson = keywords != null ? jsonEncode(keywords) : null;
    final tagsJson = tags != null ? jsonEncode(tags) : null;

    final id = await _database!.insert(
      'memories',
      {
        'content': content,
        'type': type.name,
        'keywords': keywordsJson,
        'importance': importance,
        'created_at': now,
        'updated_at': now,
        'session_id': sessionId,
        'tags': tagsJson,
      },
    );

    // Update search index
    if (keywords != null) {
      await _updateSearchIndex(id, keywords);
    }

    _eventController.add(MemoryEvent.stored(id, type, content));
    _logger.d('Stored memory $id of type ${type.name}');
    
    return id;
  }

  /// Update search index with keywords
  Future<void> _updateSearchIndex(int memoryId, List<String> keywords) async {
    if (_database == null) return;

    for (final keyword in keywords) {
      await _database!.insert(
        'memory_search_index',
        {
          'memory_id': memoryId,
          'keyword': keyword.toLowerCase(),
          'frequency': 1.0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Search memories with ranked results
  Future<List<Memory>> searchMemories(
    String query, {
    MemoryType? type,
    int limit = 20,
    double minImportance = 0.0,
  }) async {
    if (_database == null) throw Exception('Database not initialized');

    final keywords = _extractKeywords(query);
    final conditions = <String>[];
    final args = <dynamic>[];

    // Build search conditions
    if (type != null) {
      conditions.add('type = ?');
      args.add(type.name);
    }

    if (minImportance > 0) {
      conditions.add('importance >= ?');
      args.add(minImportance);
    }

    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    // Search with keyword ranking
    final results = await _database!.rawQuery('''
      SELECT DISTINCT m.*, 
             COUNT(msi.keyword) as keyword_matches,
             SUM(msi.frequency) as total_frequency,
             (m.importance * COUNT(msi.keyword) * SUM(msi.frequency)) as rank_score
      FROM memories m
      LEFT JOIN memory_search_index msi ON m.id = msi.memory_id
      $whereClause
      GROUP BY m.id
      HAVING keyword_matches > 0 OR m.content LIKE ?
      ORDER BY rank_score DESC, m.created_at DESC
      LIMIT ?
    ''', [...args, '%$query%', limit]);

    return results.map((row) => Memory.fromDatabaseRow(row)).toList();
  }

  /// Extract keywords from query
  List<String> _extractKeywords(String query) {
    // Simple keyword extraction - can be enhanced with NLP
    final words = query.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(' ');
    return words.where((word) => word.length > 2).toList();
  }

  /// Get recent memories
  Future<List<Memory>> getRecentMemories({
    MemoryType? type,
    int limit = 10,
  }) async {
    if (_database == null) throw Exception('Database not initialized');

    final conditions = <String>[];
    final args = <dynamic>[];

    if (type != null) {
      conditions.add('type = ?');
      args.add(type.name);
    }

    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final results = await _database!.rawQuery('''
      SELECT * FROM memories m
      $whereClause
      ORDER BY m.created_at DESC
      LIMIT ?
    ''', [...args, limit]);

    return results.map((row) => Memory.fromDatabaseRow(row)).toList();
  }

  /// Store daily note
  Future<void> storeDailyNote(String date, String content) async {
    if (_database == null) throw Exception('Database not initialized');

    final now = DateTime.now().millisecondsSinceEpoch;
    
    await _database!.insert(
      'daily_notes',
      {
        'date': date,
        'content': content,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _eventController.add(MemoryEvent.dailyNoteStored(date, content));
  }

  /// Get daily note
  Future<String?> getDailyNote(String date) async {
    if (_database == null) throw Exception('Database not initialized');

    final result = await _database!.query(
      'daily_notes',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    return result.isNotEmpty ? result.first['content'] as String? : null;
  }

  /// Create new session
  Future<String> createSession() async {
    if (_database == null) throw Exception('Database not initialized');

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _database!.insert(
      'sessions',
      {
        'id': sessionId,
        'started_at': now,
        'memory_count': 0,
      },
    );

    return sessionId;
  }

  /// End session with summary
  Future<void> endSession(String sessionId, String summary) async {
    if (_database == null) throw Exception('Database not initialized');

    final now = DateTime.now().millisecondsSinceEpoch;

    await _database!.update(
      'sessions',
      {
        'ended_at': now,
        'summary': summary,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Get SOUL.md personality
  String get soulMd => _soulMd ?? '';

  /// Update SOUL.md personality
  Future<void> updateSoulMd(String newSoulMd) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final soulMdPath = path.join(appDir.path, 'SOUL.md');
      
      await File(soulMdPath).writeAsString(newSoulMd);
      _soulMd = newSoulMd;
      
      _eventController.add(MemoryEvent.soulMdUpdated(newSoulMd));
      _logger.i('SOUL.md personality updated');
    } catch (e) {
      _logger.e('Failed to update SOUL.md: $e');
      rethrow;
    }
  }

  /// Get memory statistics
  Future<MemoryStats> getMemoryStats() async {
    if (_database == null) throw Exception('Database not initialized');

    final totalMemories = await _database!.rawQuery('SELECT COUNT(*) as count FROM memories');
    final memoriesByType = await _database!.rawQuery('''
      SELECT type, COUNT(*) as count 
      FROM memories 
      GROUP BY type
    ''');
    
    final recentMemories = await _database!.rawQuery('''
      SELECT COUNT(*) as count 
      FROM memories 
      WHERE created_at > ?
    ''', [DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch]);

    return MemoryStats(
      totalMemories: totalMemories.first['count'] as int,
      memoriesByType: Map.fromEntries(
        memoriesByType.map((row) => MapEntry(
          row['type'] as String,
          row['count'] as int,
        )),
      ),
      recentMemories: recentMemories.first['count'] as int,
    );
  }

  /// Dispose memory system
  Future<void> dispose() async {
    await _database?.close();
    await _eventController.close();
  }
}

/// Memory model
class Memory {
  final int id;
  final String content;
  final MemoryType type;
  final List<String> keywords;
  final double importance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sessionId;
  final List<String> tags;

  Memory({
    required this.id,
    required this.content,
    required this.type,
    required this.keywords,
    required this.importance,
    required this.createdAt,
    required this.updatedAt,
    this.sessionId,
    required this.tags,
  });

  factory Memory.fromDatabaseRow(Map<String, dynamic> row) {
    final keywordsJson = row['keywords'] as String?;
    final tagsJson = row['tags'] as String?;

    return Memory(
      id: row['id'] as int,
      content: row['content'] as String,
      type: MemoryType.values.firstWhere(
        (type) => type.name == row['type'],
        orElse: () => MemoryType.general,
      ),
      keywords: keywordsJson != null 
          ? List<String>.from(jsonDecode(keywordsJson))
          : [],
      importance: (row['importance'] as int?)?.toDouble() ?? 1.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      sessionId: row['session_id'] as String?,
      tags: tagsJson != null 
          ? List<String>.from(jsonDecode(tagsJson))
          : [],
    );
  }
}

/// Memory Type enum
enum MemoryType {
  general,
  conversation,
  task,
  preference,
  learning,
  error,
  success,
  userQuery,
  systemResponse,
}

/// Memory Event model
class MemoryEvent {
  final MemoryEventType type;
  final int? memoryId;
  final MemoryType? memoryType;
  final String? content;
  final String? date;
  final String? soulMd;

  MemoryEvent({
    required this.type,
    this.memoryId,
    this.memoryType,
    this.content,
    this.date,
    this.soulMd,
  });

  factory MemoryEvent.stored(int id, MemoryType type, String content) =>
      MemoryEvent(type: MemoryEventType.stored, memoryId: id, memoryType: type, content: content);

  factory MemoryEvent.dailyNoteStored(String date, String content) =>
      MemoryEvent(type: MemoryEventType.dailyNoteStored, date: date, content: content);

  factory MemoryEvent.soulMdUpdated(String soulMd) =>
      MemoryEvent(type: MemoryEventType.soulMdUpdated, soulMd: soulMd);
}

/// Memory Event Type enum
enum MemoryEventType {
  stored,
  updated,
  deleted,
  dailyNoteStored,
  soulMdUpdated,
}

/// Memory Statistics model
class MemoryStats {
  final int totalMemories;
  final Map<String, int> memoriesByType;
  final int recentMemories;

  MemoryStats({
    required this.totalMemories,
    required this.memoriesByType,
    required this.recentMemories,
  });
}
