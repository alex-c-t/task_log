import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/task_completion.dart';
import '../models/task_comment.dart';
import '../models/subtask.dart';
import 'notification_service.dart';
import '../utils/recurrence_helper.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('task_log.db');
    return _database!;
  }

  Future<void> close() async {
    final db = await instance.database;
    _database = null;
    await db.close();
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // TASKS TABLE
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        recurrenceType TEXT NOT NULL,
        weeklyDays TEXT,
        colorHex TEXT NOT NULL,
        uuid TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        reminderTime TEXT,
        targetCompletions INTEGER,
        isFinished INTEGER NOT NULL DEFAULT 0,
        category TEXT,
        recurrenceInterval INTEGER NOT NULL DEFAULT 1,
        recurrenceRule TEXT,
        isDirty INTEGER NOT NULL DEFAULT 0,
        userId TEXT,
        sortOrder REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // COMPLETIONS TABLE
    await db.execute('''
      CREATE TABLE completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        date TEXT NOT NULL,
        isCompleted INTEGER NOT NULL,
        uuid TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        isDirty INTEGER NOT NULL DEFAULT 0,
        userId TEXT,
        UNIQUE(taskId, date)
      )
    ''');

    // COMMENTS TABLE
    await db.execute('''
      CREATE TABLE comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        date TEXT NOT NULL,
        text TEXT NOT NULL,
        uuid TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        isDirty INTEGER NOT NULL DEFAULT 0,
        userId TEXT,
        UNIQUE(taskId, date)
      )
    ''');

    // SUBTASKS (DEFINITIONS)
    await db.execute('''
      CREATE TABLE task_subtasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        title TEXT NOT NULL,
        uuid TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        isDirty INTEGER NOT NULL DEFAULT 0,
        userId TEXT
      )
    ''');

    // SUBTASK COMPLETIONS (HISTORY)
    await db.execute('''
      CREATE TABLE subtask_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subtaskId INTEGER NOT NULL,
        date TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        uuid TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        isDirty INTEGER NOT NULL DEFAULT 0,
        userId TEXT,
        UNIQUE(subtaskId, date)
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Alter 'tasks' table
      await db.execute('ALTER TABLE tasks ADD COLUMN uuid TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN createdAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN updatedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN isDeleted INTEGER DEFAULT 0');

      // 2. Alter 'completions' table
      await db.execute('ALTER TABLE completions ADD COLUMN uuid TEXT');
      await db.execute('ALTER TABLE completions ADD COLUMN createdAt TEXT');
      await db.execute('ALTER TABLE completions ADD COLUMN updatedAt TEXT');
      await db.execute('ALTER TABLE completions ADD COLUMN isDeleted INTEGER DEFAULT 0');

      // 3. Create 'comments' table
      await db.execute('''
        CREATE TABLE comments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          taskId INTEGER NOT NULL,
          date TEXT NOT NULL,
          text TEXT NOT NULL,
          uuid TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          isDeleted INTEGER NOT NULL DEFAULT 0,
          UNIQUE(taskId, date)
        )
      ''');

      // 4. Backfill Data
      final now = DateTime.now().toUtc().toIso8601String();
      final uuidGen = const Uuid();

      // Backfill Tasks
      final tasks = await db.query('tasks');
      for (var task in tasks) {
        await db.update(
          'tasks',
          {
            'uuid': uuidGen.v4(),
            'createdAt': now,
            'updatedAt': now,
            'isDeleted': 0
          },
          where: 'id = ?',
          whereArgs: [task['id']],
        );
      }

      // Backfill Completions
      final completions = await db.query('completions');
      for (var completion in completions) {
        await db.update(
          'completions',
          {
            'uuid': uuidGen.v4(),
            'createdAt': now,
            'updatedAt': now,
            'isDeleted': 0
          },
          where: 'id = ?',
          whereArgs: [completion['id']],
        );
      }
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN reminderTime TEXT');
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN targetCompletions INTEGER');
      await db.execute('ALTER TABLE tasks ADD COLUMN isFinished INTEGER NOT NULL DEFAULT 0');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE task_subtasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          taskId INTEGER NOT NULL,
          title TEXT NOT NULL,
          isDeleted INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE subtask_completions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subtaskId INTEGER NOT NULL,
          date TEXT NOT NULL,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          isDeleted INTEGER NOT NULL DEFAULT 0,
          UNIQUE(subtaskId, date)
        )
      ''');
    }

    if (oldVersion < 6) {
      await db.execute('ALTER TABLE tasks ADD COLUMN category TEXT');
    }

    if (oldVersion < 7) {
      await db.execute('ALTER TABLE tasks ADD COLUMN recurrenceInterval INTEGER NOT NULL DEFAULT 1');
    }
    
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE tasks ADD COLUMN recurrenceRule TEXT');
    }

    if (oldVersion < 9) {
      // 1. Add userId and isDirty to all tables
      final tables = ['tasks', 'completions', 'comments', 'task_subtasks', 'subtask_completions'];
      for (var table in tables) {
        await db.execute('ALTER TABLE $table ADD COLUMN userId TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN isDirty INTEGER DEFAULT 0');
      }

      // 2. Add missing sync fields to subtask tables
      await db.execute('ALTER TABLE task_subtasks ADD COLUMN uuid TEXT');
      await db.execute('ALTER TABLE task_subtasks ADD COLUMN createdAt TEXT');
      await db.execute('ALTER TABLE task_subtasks ADD COLUMN updatedAt TEXT');

      await db.execute('ALTER TABLE subtask_completions ADD COLUMN uuid TEXT');
      await db.execute('ALTER TABLE subtask_completions ADD COLUMN createdAt TEXT');
      await db.execute('ALTER TABLE subtask_completions ADD COLUMN updatedAt TEXT');

      // 3. Backfill missing sync fields for subtasks
      final now = DateTime.now().toUtc().toIso8601String();
      final uuidGen = const Uuid();

      final subtasks = await db.query('task_subtasks');
      for (var s in subtasks) {
        if (s['uuid'] == null) {
          await db.update('task_subtasks', 
            {'uuid': uuidGen.v4(), 'createdAt': now, 'updatedAt': now},
            where: 'id = ?', whereArgs: [s['id']]);
        }
      }

      final subtaskCompletions = await db.query('subtask_completions');
      for (var sc in subtaskCompletions) {
        if (sc['uuid'] == null) {
          await db.update('subtask_completions', 
            {'uuid': uuidGen.v4(), 'createdAt': now, 'updatedAt': now},
            where: 'id = ?', whereArgs: [sc['id']]);
        }
      }
    }

    if (oldVersion < 10) {
      await db.execute('ALTER TABLE tasks ADD COLUMN sortOrder REAL NOT NULL DEFAULT 0.0');
      // Set distinct sort orders for existing tasks based on their ID + timestamp base
      final timestampBase = DateTime.now().millisecondsSinceEpoch.toDouble();
      await db.execute('UPDATE tasks SET sortOrder = ? + CAST(id AS REAL)', [timestampBase]);
    }
  }

  // INTENT-BASED APIs (FIX 2)

  /// Fetches all tasks once. No N+1 queries.
  Future<List<Task>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query(
      'tasks',
      where: 'isDeleted = 0',
      orderBy: 'sortOrder ASC, id ASC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  /// Updates the sort order for a specific task.
  Future<void> updateTaskSortOrder(int taskId, double newSortOrder) async {
    final db = await instance.database;
    await db.update(
      'tasks',
      {
        'sortOrder': newSortOrder,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'isDirty': 1,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
    notifyListeners();
  }

  /// Fetches a single task by its ID.
  Future<Task?> getTaskById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Task.fromMap(result.first);
  }

  /// Fetches completion implementation for a specific date.
  /// Date should be normalized to YYYY-MM-DD.
  Future<List<TaskCompletion>> getCompletionsForDate(DateTime date) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    
    final result = await db.query(
      'completions',
      where: 'date = ? AND isDeleted = 0',
      whereArgs: [dateStr],
    );
    
    return result.map((json) => TaskCompletion.fromMap(json)).toList();
  }

  /// Fetches completion records for a specific date range.
  ///
  /// This is a read-only performance optimization used to avoid per-day
  /// database queries when rendering views like the monthly calendar.
  /// It does NOT alter or infer completion state.
  Future<List<TaskCompletion>> getCompletionsForRange(DateTime start, DateTime end) async {
    final db = await instance.database;
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);

    final result = await db.query(
      'completions',
      where: 'date >= ? AND date <= ? AND isDeleted = 0',
      whereArgs: [startStr, endStr],
    );

    return result.map((json) => TaskCompletion.fromMap(json)).toList();
  }

  /// Persists a new [Task] to the database.
  /// 
  /// If the [Task] does not provide a [colorHex], a default light grey
  /// ("#E0E0E0") is assigned here to guarantee data integrity.
  /// Updates an existing [Task] definition.
  ///
  /// This method also ensures data integrity by SOFT DELETING [TaskCompletion]
  /// records that fall outside the new [startDate] and [endDate] range.
  Future<void> updateTask(Task task) async {
    final db = await instance.database;
    final map = task.toMap();
    
    // Always update updatedAt to now (UTC)
    final now = DateTime.now().toUtc().toIso8601String();
    map['updatedAt'] = now;
    
    await db.transaction((txn) async {
      // 1. Update the task itself
      map['isDirty'] = 1;
      await txn.update(
        'tasks',
        map,
        where: 'id = ?',
        whereArgs: [task.id],
      );

      // 2. Soft-delete dependencies outside the new range
      final startStr = task.startDate.toIso8601String().substring(0, 10);
      
      if (task.endDate != null) {
        final endStr = task.endDate!.toIso8601String().substring(0, 10);
        await txn.update(
          'completions',
          {'isDeleted': 1, 'updatedAt': now, 'isDirty': 1},
          where: 'taskId = ? AND (date < ? OR date > ?)',
          whereArgs: [task.id, startStr, endStr],
        );
        await txn.update(
          'comments',
          {'isDeleted': 1, 'updatedAt': now, 'isDirty': 1},
          where: 'taskId = ? AND (date < ? OR date > ?)',
          whereArgs: [task.id, startStr, endStr],
        );
      } else {
        await txn.update(
          'completions',
          {'isDeleted': 1, 'updatedAt': now, 'isDirty': 1},
          where: 'taskId = ? AND date < ?',
          whereArgs: [task.id, startStr],
        );
        await txn.update(
          'comments',
          {'isDeleted': 1, 'updatedAt': now, 'isDirty': 1},
          where: 'taskId = ? AND date < ?',
          whereArgs: [task.id, startStr],
        );
      }
    });
    notifyListeners();
  }

  /// Deletes a [Task] and all its associated completion history.
  ///
  /// This is a SOFT DELETE operation. Records remain in DB but are marked
  /// isDeleted = 1.
  Future<void> deleteTask(int taskId) async {
    final db = await instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    
    await db.transaction((txn) async {
      // 1. Soft delete all completion history
      await txn.update(
        'completions',
        {'isDeleted': 1, 'updatedAt': now, 'isDirty': 1},
        where: 'taskId = ?',
        whereArgs: [taskId],
      );

      // 2. Soft delete all comments
      await txn.update(
        'comments',
        {'isDeleted': 1, 'updatedAt': now, 'isDirty': 1},
        where: 'taskId = ?',
        whereArgs: [taskId],
      );

      // 3. Soft delete the task record
      await txn.update(
        'tasks',
        {'isDeleted': 1, 'updatedAt': now, 'isDirty': 1},
        where: 'id = ?',
        whereArgs: [taskId],
      );
    });
    notifyListeners();
  }

  Future<int> insertTask(Task task) async {
    final db = await instance.database;
    final map = task.toMap();
    
    map['isDirty'] = 1;
    // Note: userId will be null for now (local user)
    
    final id = await db.insert('tasks', map);
    notifyListeners();
    return id;
  }

  /// Toggles task completion status for a specific date.
  /// Handles Fix 1: Insert if not exists, Update if exists via conflict resolution or logic.
  /// Given UNIQUE constraint, we can use INSERT OR REPLACE logic, or check existance.
  /// BUT we want to TOGGLE. So we need to read current state first?
  /// Or utilize the `isCompleted` passed?
  /// The requirement says "Toggle isCompleted if a row exists".
  Future<bool> toggleTaskCompletion(int taskId, DateTime date, {bool skipNotificationUpdate = false, bool? forceStatus}) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final now = DateTime.now().toUtc().toIso8601String();
    bool goalGained = false;

    await db.transaction((txn) async {
      // Check if exists
      final List<Map<String, dynamic>> existing = await txn.query(
        'completions',
        where: 'taskId = ? AND date = ?',
        whereArgs: [taskId, dateStr],
      );

      if (existing.isNotEmpty) {
        // Toggle or Force
        final currentStatus = existing.first['isCompleted'] == 1;
        final newStatus = forceStatus ?? !currentStatus;
        await txn.update(
          'completions',
          {
            'isCompleted': newStatus ? 1 : 0,
            'isDeleted': 0,
            'updatedAt': now,
            'isDirty': 1
          },
          where: 'taskId = ? AND date = ?',
          whereArgs: [taskId, dateStr],
        );
      } else {
        // Insert new
        await txn.insert('completions', {
          'taskId': taskId,
          'date': dateStr,
          'isCompleted': (forceStatus ?? true) ? 1 : 0, 
          'uuid': const Uuid().v4(),
          'createdAt': now,
          'updatedAt': now,
          'isDeleted': 0,
          'isDirty': 1
        });
      }

      // Check if this task is a goal with target completions
      final taskResult = await txn.query('tasks', where: 'id = ?', whereArgs: [taskId]);
      if (taskResult.isNotEmpty) {
        final taskData = taskResult.first;
        if (taskData['targetCompletions'] != null) {
          final target = taskData['targetCompletions'] as int;
          
          final completionsCountResult = await txn.rawQuery(
            'SELECT COUNT(*) as count FROM completions WHERE taskId = ? AND isCompleted = 1 AND isDeleted = 0',
            [taskId]
          );
          final count = Sqflite.firstIntValue(completionsCountResult) ?? 0;
          
          final bool wasFinished = taskData['isFinished'] == 1;
          final bool isNowFinished = count >= target;

          if (!wasFinished && isNowFinished) {
            goalGained = true;
          }

          await txn.update(
            'tasks',
            {
              'isFinished': isNowFinished ? 1 : 0,
              'updatedAt': now,
              'isDirty': 1
            },
            where: 'id = ?',
            whereArgs: [taskId],
          );
        }
      }
    });

    // Post-toggle logic: Update notification schedule
    if (!skipNotificationUpdate) {
      final task = await getTaskById(taskId);
      if (task != null) {
        await NotificationService.instance.updateTaskReminderState(task);
      }
    }
    
    notifyListeners();
    return goalGained;
  }

  // STREAK API
  /// Returns the total number of times this task has been completed.
  Future<int> getTaskCompletedCount(int taskId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM completions WHERE taskId = ? AND isCompleted = 1 AND isDeleted = 0',
      [taskId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Deprecated: Streaks are currently replaced by total completion count as per user request
  Future<int> getTaskStreak(Task task) async {
    return await getTaskCompletedCount(task.id!);
  }

  // COMMENTS API (Phase 2.5.1)

  /// Fetches active (non-deleted) comments for a specific date.
  /// Returns a map of taskId -> TaskComment for O(1) lookup.
  Future<Map<int, TaskComment>> getCommentsMapForDate(DateTime date) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    
    final result = await db.query(
      'comments',
      where: 'date = ? AND isDeleted = 0',
      whereArgs: [dateStr],
    );

    final Map<int, TaskComment> commentMap = {};
    for (var json in result) {
      final comment = TaskComment.fromMap(json);
      commentMap[comment.taskId] = comment;
    }
    return commentMap;
  }

  /// Upserts a comment for a task on a specific date.
  /// 
  /// - Updates existing record (re-enabling it if it was soft deleted)
  /// - Inserts new record if none exists for (taskId, date)
  /// - Always updates updatedAt to now (UTC)
  Future<void> saveComment(int taskId, DateTime date, String text) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // Check if ANY record exists (including deleted ones)
      final existing = await txn.query(
        'comments',
        where: 'taskId = ? AND date = ?',
        whereArgs: [taskId, dateStr],
      );

      if (existing.isNotEmpty) {
        // Update existing record
        await txn.update(
          'comments',
          {
            'text': text,
            'isDeleted': 0,
            'updatedAt': now,
            'isDirty': 1
          },
          where: 'taskId = ? AND date = ?',
          whereArgs: [taskId, dateStr],
        );
      } else {
        // Insert new record
        await txn.insert('comments', {
          'taskId': taskId,
          'date': dateStr,
          'text': text,
          'uuid': const Uuid().v4(),
          'createdAt': now,
          'updatedAt': now,
          'isDeleted': 0,
          'isDirty': 1
        });
      }
    });
  }

  /// Soft deletes a comment for a transaction.
  Future<void> deleteComment(int taskId, DateTime date) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      'comments',
      {
        'isDeleted': 1,
        'updatedAt': now,
        'isDirty': 1
      },
      where: 'taskId = ? AND date = ?',
      whereArgs: [taskId, dateStr],
    );
    notifyListeners();
  }

  // SUBTASKS API

  /// Fetches all subtask definitions for a specific task.
  Future<List<SubTask>> getSubTasksForTask(int taskId) async {
    final db = await instance.database;
    final result = await db.query(
      'task_subtasks',
      where: 'taskId = ? AND isDeleted = 0',
      whereArgs: [taskId],
    );
    return result.map((json) => SubTask.fromMap(json)).toList();
  }

  /// Fetches all subtask completions for a specific date.
  /// Map of subtaskId -> SubTaskCompletion object for fast lookups.
  Future<Map<int, SubTaskCompletion>> getSubTaskCompletionsForDate(DateTime date) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    
    final result = await db.query(
      'subtask_completions',
      where: 'date = ? AND isDeleted = 0',
      whereArgs: [dateStr],
    );

    final Map<int, SubTaskCompletion> completionMap = {};
    for (var json in result) {
      final completion = SubTaskCompletion.fromMap(json);
      completionMap[completion.subtaskId] = completion;
    }
    return completionMap;
  }

  /// Toggles a subtask's completion status for a given date.
  Future<void> toggleSubTaskCompletion(int subtaskId, DateTime date, {bool? forceStatus}) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);

    await db.transaction((txn) async {
      final List<Map<String, dynamic>> existing = await txn.query(
        'subtask_completions',
        where: 'subtaskId = ? AND date = ?',
        whereArgs: [subtaskId, dateStr],
      );

      if (existing.isNotEmpty) {
        final currentStatus = existing.first['isCompleted'] == 1;
        final newStatus = forceStatus ?? !currentStatus;
        await txn.update(
          'subtask_completions',
          {
            'isCompleted': newStatus ? 1 : 0, 
            'isDeleted': 0, 
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
            'isDirty': 1
          },
          where: 'subtaskId = ? AND date = ?',
          whereArgs: [subtaskId, dateStr],
        );
      } else {
        final now = DateTime.now().toUtc().toIso8601String();
        await txn.insert('subtask_completions', {
          'subtaskId': subtaskId,
          'date': dateStr,
          'isCompleted': (forceStatus ?? true) ? 1 : 0,
          'uuid': const Uuid().v4(),
          'createdAt': now,
          'updatedAt': now,
          'isDeleted': 0,
          'isDirty': 1
        });
      }
    });

    notifyListeners();
  }

  /// Adds a new subtask definition to a task blueprint.
  Future<int> addSubTask(int taskId, String title) async {
    final db = await instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = await db.insert('task_subtasks', {
      'taskId': taskId,
      'title': title,
      'uuid': const Uuid().v4(),
      'createdAt': now,
      'updatedAt': now,
      'isDeleted': 0,
      'isDirty': 1
    });
    notifyListeners();
    return id;
  }

  /// Soft deletes a subtask definition.
  Future<void> deleteSubTask(int subtaskId) async {
    final db = await instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'task_subtasks',
      {
        'isDeleted': 1,
        'updatedAt': now,
        'isDirty': 1
      },
      where: 'id = ?',
      whereArgs: [subtaskId],
    );
    notifyListeners();
  }
}
