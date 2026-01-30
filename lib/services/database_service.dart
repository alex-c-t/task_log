
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/task_completion.dart';

import 'package:uuid/uuid.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('task_log.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
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
        isDeleted INTEGER NOT NULL DEFAULT 0
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
        UNIQUE(taskId, date)
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
  }

  // INTENT-BASED APIs (FIX 2)

  /// Fetches all tasks once. No N+1 queries.
  Future<List<Task>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query(
      'tasks',
      where: 'isDeleted = 0',
    );
    return result.map((json) => Task.fromMap(json)).toList();
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
      await txn.update(
        'tasks',
        map,
        where: 'id = ?',
        whereArgs: [task.id],
      );

      // 2. Soft-delete dependencies outside the new range
      final startStr = task.startDate.toIso8601String().substring(0, 10);
      final endStr = task.endDate.toIso8601String().substring(0, 10);
      // Soft delete completions
      await txn.update(
        'completions',
        {'isDeleted': 1, 'updatedAt': now},
        where: 'taskId = ? AND (date < ? OR date > ?)',
        whereArgs: [task.id, startStr, endStr],
      );
      // Soft delete comments
      await txn.update(
        'comments',
        {'isDeleted': 1, 'updatedAt': now},
        where: 'taskId = ? AND (date < ? OR date > ?)',
        whereArgs: [task.id, startStr, endStr],
      );
    });
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
        {'isDeleted': 1, 'updatedAt': now},
        where: 'taskId = ?',
        whereArgs: [taskId],
      );

      // 2. Soft delete all comments
      await txn.update(
        'comments',
        {'isDeleted': 1, 'updatedAt': now},
        where: 'taskId = ?',
        whereArgs: [taskId],
      );

      // 3. Soft delete the task record
      await txn.update(
        'tasks',
        {'isDeleted': 1, 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [taskId],
      );
    });
  }

  Future<int> insertTask(Task task) async {
    final db = await instance.database;
    final map = task.toMap();
    
    // Ensure colorHex is non-null and not empty at persistence time.
    if (map['colorHex'] == null || map['colorHex'].toString().isEmpty) {
      map['colorHex'] = "#E0E0E0"; // Default light grey
    }
    
    return await db.insert('tasks', map);
  }

  /// Toggles task completion status for a specific date.
  /// Handles Fix 1: Insert if not exists, Update if exists via conflict resolution or logic.
  /// Given UNIQUE constraint, we can use INSERT OR REPLACE logic, or check existance.
  /// BUT we want to TOGGLE. So we need to read current state first?
  /// Or utilize the `isCompleted` passed?
  /// The requirement says "Toggle isCompleted if a row exists".
  Future<void> toggleTaskCompletion(int taskId, DateTime date) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // Check if exists
      final List<Map<String, dynamic>> existing = await txn.query(
        'completions',
        where: 'taskId = ? AND date = ?',
        whereArgs: [taskId, dateStr],
      );

      if (existing.isNotEmpty) {
        // Toggle
        final currentStatus = existing.first['isCompleted'] == 1;
        await txn.update(
          'completions',
          {
            'isCompleted': currentStatus ? 0 : 1,
            'updatedAt': now
          },
          where: 'taskId = ? AND date = ?',
          whereArgs: [taskId, dateStr],
        );
      } else {
        // Insert new as completed (since default is pending/uncompleted)
        // If user clicks toggle on pending, it becomes completed.
        await txn.insert('completions', {
          'taskId': taskId,
          'date': dateStr,
          'isCompleted': 1, // Default to completed when created via toggle
          'uuid': const Uuid().v4(),
          'createdAt': now,
          'updatedAt': now,
          'isDeleted': 0
        });
      }
    });
  }
}
