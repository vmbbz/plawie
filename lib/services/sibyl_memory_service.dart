import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

/// Guardian Policy representing user-defined financial constraints stored in Sibyl Memory
class GuardianPolicy {
  final double dailyLimitUsdc;
  final double singleTxLimitUsdc;
  final List<String> allowedRecipients; // Addresses or .base.eth names
  final bool requireExplicitApproval;
  final DateTime updatedAt;

  GuardianPolicy({
    required this.dailyLimitUsdc,
    required this.singleTxLimitUsdc,
    required this.allowedRecipients,
    this.requireExplicitApproval = true,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory GuardianPolicy.defaultPolicy() => GuardianPolicy(
        dailyLimitUsdc: 50.0,
        singleTxLimitUsdc: 25.0,
        allowedRecipients: const [],
        requireExplicitApproval: true,
      );

  Map<String, dynamic> toJson() => {
        'dailyLimitUsdc': dailyLimitUsdc,
        'singleTxLimitUsdc': singleTxLimitUsdc,
        'allowedRecipients': allowedRecipients,
        'requireExplicitApproval': requireExplicitApproval,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory GuardianPolicy.fromJson(Map<String, dynamic> json) => GuardianPolicy(
        dailyLimitUsdc: (json['dailyLimitUsdc'] as num?)?.toDouble() ?? 50.0,
        singleTxLimitUsdc:
            (json['singleTxLimitUsdc'] as num?)?.toDouble() ?? 25.0,
        allowedRecipients: (json['allowedRecipients'] as List?)
                ?.map((e) => e.toString().toLowerCase().trim())
                .toList() ??
            const [],
        requireExplicitApproval:
            json['requireExplicitApproval'] as bool? ?? true,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  String toPromptSummary() {
    final recipients = allowedRecipients.isEmpty
        ? 'None (all transfers require review)'
        : allowedRecipients.join(', ');
    return 'Active Policy: Daily limit \$${dailyLimitUsdc.toStringAsFixed(2)} USDC, Per-tx limit \$${singleTxLimitUsdc.toStringAsFixed(2)} USDC. Allowed recipients: $recipients.';
  }
}

/// Transaction journal entry stored in Sibyl Memory
class BaseTxJournalEntry {
  final String txHash;
  final String action; // send_eth or send_usdc
  final String recipient;
  final double amountUsdc;
  final String status; // 'executed', 'blocked', 'failed'
  final String policyDecisionReason;
  final DateTime timestamp;

  BaseTxJournalEntry({
    required this.txHash,
    required this.action,
    required this.recipient,
    required this.amountUsdc,
    required this.status,
    required this.policyDecisionReason,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'txHash': txHash,
        'action': action,
        'recipient': recipient,
        'amountUsdc': amountUsdc,
        'status': status,
        'policyDecisionReason': policyDecisionReason,
        'timestamp': timestamp.toIso8601String(),
      };

  factory BaseTxJournalEntry.fromJson(Map<String, dynamic> json) =>
      BaseTxJournalEntry(
        txHash: json['txHash'] ?? '',
        action: json['action'] ?? 'send_usdc',
        recipient: json['recipient'] ?? '',
        amountUsdc: (json['amountUsdc'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] ?? 'executed',
        policyDecisionReason: json['policyDecisionReason'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Structured Sibyl Memory Item
class SibylMemoryItem {
  final int id;
  final String category; // 'policy', 'journal', 'session', 'preference'
  final String key;
  final String contentJson;
  final double importance;
  final DateTime createdAt;

  SibylMemoryItem({
    required this.id,
    required this.category,
    required this.key,
    required this.contentJson,
    required this.importance,
    required this.createdAt,
  });

  Map<String, dynamic> get parsedContent {
    try {
      return jsonDecode(contentJson) as Map<String, dynamic>;
    } catch (_) {
      return {'raw': contentJson};
    }
  }
}

/// Load-bearing Sibyl Memory Service
/// Manages SQLite/FTS5 local memory store adhering to Sibyl Memory specs.
class SibylMemoryService {
  static final SibylMemoryService _instance = SibylMemoryService._internal();
  factory SibylMemoryService() => _instance;
  SibylMemoryService._internal();

  factory SibylMemoryService.inMemoryForTesting() {
    final instance = SibylMemoryService._internal();
    instance._isTestingMode = true;
    instance._initialized = true;
    instance._cachedPolicy = GuardianPolicy.defaultPolicy();
    return instance;
  }

  final Logger _logger = Logger();
  Database? _db;
  bool _initialized = false;
  bool _isTestingMode = false;
  GuardianPolicy? _cachedPolicy;
  final List<BaseTxJournalEntry> _inMemoryJournal = [];

  final StreamController<GuardianPolicy> _policyStreamController =
      StreamController<GuardianPolicy>.broadcast();
  Stream<GuardianPolicy> get policyStream => _policyStreamController.stream;

  bool get isInitialized => _initialized;
  GuardianPolicy get activePolicy => _cachedPolicy ?? GuardianPolicy.defaultPolicy();

  Future<void> initialize({Database? dbOverride, String? dbPathOverride}) async {
    if (_initialized && dbOverride == null) return;
    if (_isTestingMode) {
      _initialized = true;
      return;
    }
    try {
      _logger.i('Initializing Sibyl Memory Engine...');
      if (dbOverride != null) {
        _db = dbOverride;
      } else {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final dbPath = dbPathOverride ?? path.join(appDir.path, 'sibyl_memory_v1.db');
          _db = await openDatabase(
            dbPath,
            version: 1,
            onCreate: _onCreate,
          );
        } catch (e) {
          _logger.w('Fallback to in-memory testing mode: $e');
          _isTestingMode = true;
          _initialized = true;
          _cachedPolicy ??= GuardianPolicy.defaultPolicy();
          return;
        }
      }

      // Warm cache with active policy on startup
      _cachedPolicy = await _loadActivePolicy();
      _initialized = true;
      _logger.i('Sibyl Memory Engine initialized. Policy loaded: ${_cachedPolicy?.toPromptSummary()}');
    } catch (e) {
      _logger.e('Failed to initialize Sibyl Memory: $e');
      _isTestingMode = true;
      _initialized = true;
      _cachedPolicy ??= GuardianPolicy.defaultPolicy();
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sibyl_memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        key_name TEXT NOT NULL UNIQUE,
        content_json TEXT NOT NULL,
        importance REAL DEFAULT 1.0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sibyl_tx_journal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tx_hash TEXT NOT NULL,
        action TEXT NOT NULL,
        recipient TEXT NOT NULL,
        amount_usdc REAL NOT NULL,
        status TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_sibyl_category ON sibyl_memories(category)');
    await db.execute('CREATE INDEX idx_sibyl_key ON sibyl_memories(key_name)');
    await db.execute('CREATE INDEX idx_journal_created ON sibyl_tx_journal(created_at)');
  }

  Future<GuardianPolicy?> _loadActivePolicy() async {
    if (_db == null) return GuardianPolicy.defaultPolicy();
    final res = await _db!.query(
      'sibyl_memories',
      where: 'category = ? AND key_name = ?',
      whereArgs: ['policy', 'active_financial_policy'],
      limit: 1,
    );

    if (res.isNotEmpty) {
      final jsonStr = res.first['content_json'] as String;
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return GuardianPolicy.fromJson(map);
      } catch (e) {
        _logger.e('Error decoding stored policy: $e');
      }
    }
    return GuardianPolicy.defaultPolicy();
  }

  /// Store or update active financial policy into Sibyl Memory
  Future<void> savePolicy(GuardianPolicy policy) async {
    await initialize();
    _cachedPolicy = policy;
    _policyStreamController.add(policy);

    if (_db != null && !_isTestingMode) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final jsonStr = jsonEncode(policy.toJson());

      await _db!.insert(
        'sibyl_memories',
        {
          'category': 'policy',
          'key_name': 'active_financial_policy',
          'content_json': jsonStr,
          'importance': 2.0,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    _logger.i('Saved new financial policy to Sibyl Memory: ${policy.toPromptSummary()}');
  }

  /// Journal a transaction attempt (whether executed, blocked, or failed)
  Future<void> journalTransaction(BaseTxJournalEntry entry) async {
    await initialize();
    _inMemoryJournal.add(entry);

    if (_db != null && !_isTestingMode) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db!.insert('sibyl_tx_journal', {
        'tx_hash': entry.txHash,
        'action': entry.action,
        'recipient': entry.recipient,
        'amount_usdc': entry.amountUsdc,
        'status': entry.status,
        'reason': entry.policyDecisionReason,
        'created_at': now,
      });
    }

    _logger.i('Journaled transaction to Sibyl Memory: ${entry.action} -> ${entry.recipient} (\$${entry.amountUsdc}) [${entry.status}]');
  }

  /// Calculate cumulative USDC spent today (last 24h window) for executed transactions
  Future<double> getDailySpentUsdc() async {
    await initialize();

    final startOfDay = DateTime.now()
        .subtract(Duration(
          hours: DateTime.now().hour,
          minutes: DateTime.now().minute,
          seconds: DateTime.now().second,
        ))
        .millisecondsSinceEpoch;

    if (_db != null && !_isTestingMode) {
      final res = await _db!.rawQuery('''
        SELECT SUM(amount_usdc) as total
        FROM sibyl_tx_journal
        WHERE status = 'executed' AND created_at >= ?
      ''', [startOfDay]);

      if (res.isNotEmpty && res.first['total'] != null) {
        return (res.first['total'] as num).toDouble();
      }
    }

    double total = 0.0;
    for (final entry in _inMemoryJournal) {
      if (entry.status == 'executed' &&
          entry.timestamp.millisecondsSinceEpoch >= startOfDay) {
        total += entry.amountUsdc;
      }
    }
    return total;
  }

  /// Perform context recall for fresh-session turn initialization
  Future<List<SibylMemoryItem>> recallContext({
    String? category,
    int limit = 10,
  }) async {
    await initialize();
    if (_db == null) return [];

    final whereClause = category != null ? 'WHERE category = ?' : '';
    final args = category != null ? [category, limit] : [limit];

    final res = await _db!.rawQuery('''
      SELECT * FROM sibyl_memories
      $whereClause
      ORDER BY importance DESC, created_at DESC
      LIMIT ?
    ''', args);

    return res
        .map((row) => SibylMemoryItem(
              id: row['id'] as int,
              category: row['category'] as String,
              key: row['key_name'] as String,
              contentJson: row['content_json'] as String,
              importance: (row['importance'] as num).toDouble(),
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                  row['created_at'] as int),
            ))
        .toList();
  }

  /// Fetch recent transaction journal history
  Future<List<BaseTxJournalEntry>> getJournalHistory({int limit = 20}) async {
    await initialize();
    if (_db == null) return [];

    final res = await _db!.query(
      'sibyl_tx_journal',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return res
        .map((row) => BaseTxJournalEntry(
              txHash: row['tx_hash'] as String,
              action: row['action'] as String,
              recipient: row['recipient'] as String,
              amountUsdc: (row['amount_usdc'] as num).toDouble(),
              status: row['status'] as String,
              policyDecisionReason: row['reason'] as String,
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                  row['created_at'] as int),
            ))
        .toList();
  }

  Future<void> dispose() async {
    await _db?.close();
    await _policyStreamController.close();
  }
}
