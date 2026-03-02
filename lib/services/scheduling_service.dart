import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Natural Language Scheduling Service
/// Converts natural language time expressions to scheduled tasks
/// Inspired by SeekerClaw's natural scheduling capabilities
class SchedulingService {
  static final SchedulingService _instance = SchedulingService._internal();
  factory SchedulingService() => _instance;
  SchedulingService._internal();

  final Logger _logger = Logger();
  Database? _database;
  final Map<String, Timer> _activeTimers = {};
  final StreamController<SchedulingEvent> _eventController = StreamController.broadcast();

  Stream<SchedulingEvent> get events => _eventController.stream;

  /// Initialize scheduling service
  Future<void> initialize() async {
    try {
      _logger.i('Initializing Scheduling Service...');
      
      // Get application directory
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(appDir.path, 'scheduling.db');
      
      // Open database
      _database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _createDatabase,
      );

      // Load and start scheduled tasks
      await _loadScheduledTasks();
      
      _logger.i('Scheduling Service initialized');
    } catch (e) {
      _logger.e('Failed to initialize Scheduling Service: $e');
      rethrow;
    }
  }

  /// Create database schema
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scheduled_tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        natural_expression TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        next_execution INTEGER,
        last_execution INTEGER,
        execution_count INTEGER DEFAULT 0,
        enabled INTEGER DEFAULT 1,
        task_type TEXT NOT NULL,
        task_data TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE task_executions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id TEXT NOT NULL,
        executed_at INTEGER NOT NULL,
        success INTEGER DEFAULT 1,
        result TEXT,
        error TEXT,
        FOREIGN KEY (task_id) REFERENCES scheduled_tasks (id)
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_scheduled_tasks_next_execution ON scheduled_tasks(next_execution)');
    await db.execute('CREATE INDEX idx_scheduled_tasks_enabled ON scheduled_tasks(enabled)');
    await db.execute('CREATE INDEX idx_task_executions_task_id ON task_executions(task_id)');
  }

  /// Load and start scheduled tasks
  Future<void> _loadScheduledTasks() async {
    if (_database == null) return;

    try {
      final tasks = await _database!.query(
        'scheduled_tasks',
        where: 'enabled = 1 AND next_execution > ?',
        whereArgs: [DateTime.now().millisecondsSinceEpoch],
      );

      for (final task in tasks) {
        _startTaskTimer(ScheduledTask.fromDatabaseRow(task));
      }

      _logger.i('Loaded ${tasks.length} scheduled tasks');
    } catch (e) {
      _logger.e('Failed to load scheduled tasks: $e');
    }
  }

  /// Parse natural language time expression
  Future<ScheduledTask?> scheduleNaturalTask({
    required String title,
    required String naturalExpression,
    String? description,
    required TaskType taskType,
    Map<String, dynamic>? taskData,
  }) async {
    try {
      final executionTime = _parseNaturalTime(naturalExpression);
      if (executionTime == null) {
        throw Exception('Unable to parse time expression: $naturalExpression');
      }

      final task = ScheduledTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        naturalExpression: naturalExpression,
        createdAt: DateTime.now(),
        nextExecution: executionTime,
        taskType: taskType,
        taskData: taskData ?? {},
        enabled: true,
      );

      // Save to database
      await _saveTask(task);

      // Start timer
      _startTaskTimer(task);

      _eventController.add(SchedulingEvent.taskScheduled(task.id));
      _logger.i('Scheduled task: $title at $naturalExpression');

      return task;
    } catch (e) {
      _logger.e('Failed to schedule task: $e');
      return null;
    }
  }

  /// Parse natural language to DateTime
  DateTime? _parseNaturalTime(String naturalExpression) {
    final expression = naturalExpression.toLowerCase().trim();
    final now = DateTime.now();

    // Handle "in X minutes/hours"
    if (expression.contains('in') && expression.contains('minute')) {
      final match = RegExp(r'in (\d+) minute').firstMatch(expression);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        return now.add(Duration(minutes: minutes));
      }
    }

    if (expression.contains('in') && expression.contains('hour')) {
      final match = RegExp(r'in (\d+) hour').firstMatch(expression);
      if (match != null) {
        final hours = int.parse(match.group(1)!);
        return now.add(Duration(hours: hours));
      }
    }

    // Handle "tomorrow"
    if (expression.contains('tomorrow')) {
      return DateTime(now.year, now.month, now.day + 1, 9, 0, 0);
    }

    // Handle specific times
    if (expression.contains('am') || expression.contains('pm')) {
      return _parseSpecificTime(expression, now);
    }

    // Handle "daily", "weekly", etc.
    if (expression.contains('daily') || expression.contains('every day')) {
      return DateTime(now.year, now.month, now.day + 1, 9, 0, 0);
    }

    return null;
  }

  /// Parse specific time
  DateTime? _parseSpecificTime(String expression, DateTime now) {
    final timeMatch = RegExp(r'(\d{1,2}):?(\d{0,2})\s*(am|pm)').firstMatch(expression);
    if (timeMatch != null) {
      var hour = int.parse(timeMatch.group(1)!);
      final minute = timeMatch.group(2)?.isNotEmpty == true 
          ? int.parse(timeMatch.group(2)!)
          : 0;
      final period = timeMatch.group(3)!;

      // Convert to 24-hour format
      if (period == 'pm' && hour != 12) {
        hour += 12;
      } else if (period == 'am' && hour == 12) {
        hour = 0;
      }

      DateTime scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(Duration(days: 1));
      }

      return scheduledTime;
    }

    return null;
  }

  /// Save task to database
  Future<void> _saveTask(ScheduledTask task) async {
    if (_database == null) return;

    await _database!.insert(
      'scheduled_tasks',
      {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'natural_expression': task.naturalExpression,
        'created_at': task.createdAt.millisecondsSinceEpoch,
        'next_execution': task.nextExecution?.millisecondsSinceEpoch,
        'enabled': task.enabled ? 1 : 0,
        'task_type': task.taskType.name,
        'task_data': jsonEncode(task.taskData),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Start timer for task
  void _startTaskTimer(ScheduledTask task) {
    if (task.nextExecution == null) return;

    final delay = task.nextExecution!.difference(DateTime.now());
    if (delay.isNegative) return;

    final timer = Timer(delay, () => _executeTask(task));
    _activeTimers[task.id] = timer;
  }

  /// Execute scheduled task
  Future<void> _executeTask(ScheduledTask task) async {
    try {
      _logger.i('Executing scheduled task: ${task.title}');
      _eventController.add(SchedulingEvent.taskExecuting(task.id));

      dynamic result;
      bool success = true;

      // Execute based on task type
      switch (task.taskType) {
        case TaskType.reminder:
          result = await _executeReminder(task);
          break;
        case TaskType.notification:
          result = await _executeNotification(task);
          break;
        case TaskType.system:
          result = await _executeSystemTask(task);
          break;
        case TaskType.custom:
          result = await _executeCustomTask(task);
          break;
      }

      // Update task
      task.lastExecution = DateTime.now();
      task.executionCount++;

      await _saveTask(task);
      await _logTaskExecution(task.id, success, result);

      _eventController.add(SchedulingEvent.taskExecuted(task.id, result));

      _logger.i('Task executed successfully: ${task.title}');
    } catch (e) {
      _logger.e('Failed to execute task ${task.title}: $e');
      await _logTaskExecution(task.id, false, null, e.toString());
      _eventController.add(SchedulingEvent.taskError(task.id, e.toString()));
    }
  }

  /// Execute reminder task
  Future<String> _executeReminder(ScheduledTask task) async {
    final message = task.taskData['message'] as String? ?? task.title;
    // This would integrate with notification system
    return 'Reminder: $message';
  }

  /// Execute notification task
  Future<String> _executeNotification(ScheduledTask task) async {
    final message = task.taskData['message'] as String? ?? task.title;
    // This would integrate with notification system
    return 'Notification sent: $message';
  }

  /// Execute system task
  Future<String> _executeSystemTask(ScheduledTask task) async {
    final action = task.taskData['action'] as String? ?? 'unknown';
    // This would integrate with system operations
    return 'System task executed: $action';
  }

  /// Execute custom task
  Future<String> _executeCustomTask(ScheduledTask task) async {
    final customData = task.taskData;
    // This would integrate with custom execution logic
    return 'Custom task executed: ${customData.toString()}';
  }

  /// Log task execution
  Future<void> _logTaskExecution(
    String taskId,
    bool success,
    dynamic result,
    [String? error]
  ) async {
    if (_database == null) return;

    await _database!.insert(
      'task_executions',
      {
        'task_id': taskId,
        'executed_at': DateTime.now().millisecondsSinceEpoch,
        'success': success ? 1 : 0,
        'result': result != null ? jsonEncode(result) : null,
        'error': error,
      },
    );
  }

  /// Cancel scheduled task
  Future<bool> cancelTask(String taskId) async {
    try {
      // Stop timer
      final timer = _activeTimers.remove(taskId);
      timer?.cancel();

      // Update database
      if (_database != null) {
        await _database!.update(
          'scheduled_tasks',
          {'enabled': 0},
          where: 'id = ?',
          whereArgs: [taskId],
        );
      }

      _eventController.add(SchedulingEvent.taskCancelled(taskId));
      _logger.i('Cancelled task: $taskId');
      return true;
    } catch (e) {
      _logger.e('Failed to cancel task $taskId: $e');
      return false;
    }
  }

  /// Get all scheduled tasks
  Future<List<ScheduledTask>> getAllTasks() async {
    if (_database == null) return [];

    final results = await _database!.query('scheduled_tasks');
    return results.map((row) => ScheduledTask.fromDatabaseRow(row)).toList();
  }

  /// Get active tasks
  Future<List<ScheduledTask>> getActiveTasks() async {
    if (_database == null) return [];

    final results = await _database!.query(
      'scheduled_tasks',
      where: 'enabled = 1',
      orderBy: 'next_execution ASC',
    );
    return results.map((row) => ScheduledTask.fromDatabaseRow(row)).toList();
  }

  /// Get task execution history
  Future<List<TaskExecution>> getTaskHistory(String taskId, {int limit = 10}) async {
    if (_database == null) return [];

    final results = await _database!.query(
      'task_executions',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'executed_at DESC',
      limit: limit,
    );
    return results.map((row) => TaskExecution.fromDatabaseRow(row)).toList();
  }

  /// Dispose scheduling service
  Future<void> dispose() async {
    // Cancel all active timers
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();

    await _database?.close();
    await _eventController.close();
  }
}

/// Scheduled Task model
class ScheduledTask {
  final String id;
  final String title;
  final String? description;
  final String naturalExpression;
  final DateTime createdAt;
  DateTime? nextExecution;
  DateTime? lastExecution;
  int executionCount;
  bool enabled;
  final TaskType taskType;
  final Map<String, dynamic> taskData;

  ScheduledTask({
    required this.id,
    required this.title,
    this.description,
    required this.naturalExpression,
    required this.createdAt,
    this.nextExecution,
    this.lastExecution,
    this.executionCount = 0,
    this.enabled = true,
    required this.taskType,
    required this.taskData,
  });

  factory ScheduledTask.fromDatabaseRow(Map<String, dynamic> row) {
    return ScheduledTask(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      naturalExpression: row['natural_expression'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      nextExecution: row['next_execution'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['next_execution'] as int)
          : null,
      lastExecution: row['last_execution'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_execution'] as int)
          : null,
      executionCount: row['execution_count'] as int? ?? 0,
      enabled: (row['enabled'] as int? ?? 1) == 1,
      taskType: TaskType.values.firstWhere(
        (type) => type.name == row['task_type'],
        orElse: () => TaskType.reminder,
      ),
      taskData: row['task_data'] != null
          ? Map<String, dynamic>.from(jsonDecode(row['task_data'] as String))
          : {},
    );
  }
}

/// Task Execution model
class TaskExecution {
  final int id;
  final String taskId;
  final DateTime executedAt;
  final bool success;
  final dynamic result;
  final String? error;

  TaskExecution({
    required this.id,
    required this.taskId,
    required this.executedAt,
    required this.success,
    this.result,
    this.error,
  });

  factory TaskExecution.fromDatabaseRow(Map<String, dynamic> row) {
    return TaskExecution(
      id: row['id'] as int,
      taskId: row['task_id'] as String,
      executedAt: DateTime.fromMillisecondsSinceEpoch(row['executed_at'] as int),
      success: (row['success'] as int? ?? 1) == 1,
      result: row['result'] != null ? jsonDecode(row['result'] as String) : null,
      error: row['error'] as String?,
    );
  }
}

/// Task Type enum
enum TaskType {
  reminder,
  notification,
  system,
  custom,
}

/// Scheduling Event model
class SchedulingEvent {
  final SchedulingEventType type;
  final String? taskId;
  final dynamic result;
  final String? error;

  SchedulingEvent({
    required this.type,
    this.taskId,
    this.result,
    this.error,
  });

  factory SchedulingEvent.taskScheduled(String taskId) =>
      SchedulingEvent(type: SchedulingEventType.taskScheduled, taskId: taskId);

  factory SchedulingEvent.taskExecuting(String taskId) =>
      SchedulingEvent(type: SchedulingEventType.taskExecuting, taskId: taskId);

  factory SchedulingEvent.taskExecuted(String taskId, dynamic result) =>
      SchedulingEvent(type: SchedulingEventType.taskExecuted, taskId: taskId, result: result);

  factory SchedulingEvent.taskError(String taskId, String error) =>
      SchedulingEvent(type: SchedulingEventType.taskError, taskId: taskId, error: error);

  factory SchedulingEvent.taskCancelled(String taskId) =>
      SchedulingEvent(type: SchedulingEventType.taskCancelled, taskId: taskId);
}

/// Scheduling Event Type enum
enum SchedulingEventType {
  taskScheduled,
  taskExecuting,
  taskExecuted,
  taskError,
  taskCancelled,
}
