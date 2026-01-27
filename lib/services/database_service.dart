
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/task.dart';
import '../models/task_completion.dart';

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
      version: 1,
      onCreate: _createDB,
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
        colorHex TEXT NOT NULL
      )
    ''');

    // COMPLETIONS TABLE
    // FIX 1: Unique constraint on (taskId, date)
    await db.execute('''
      CREATE TABLE completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        date TEXT NOT NULL,
        isCompleted INTEGER NOT NULL,
        UNIQUE(taskId, date)
      )
    ''');
  }

  // INTENT-BASED APIs (FIX 2)

  /// Fetches all tasks once. No N+1 queries.
  Future<List<Task>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks');
    return result.map((json) => Task.fromMap(json)).toList();
  }

  /// Fetches completion implementation for a specific date.
  /// Date should be normalized to YYYY-MM-DD.
  Future<List<TaskCompletion>> getCompletionsForDate(DateTime date) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    
    final result = await db.query(
      'completions',
      where: 'date = ?',
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
      where: 'date >= ? AND date <= ?',
      whereArgs: [startStr, endStr],
    );

    return result.map((json) => TaskCompletion.fromMap(json)).toList();
  }

  /// Persists a new [Task] to the database.
  /// 
  /// If the [Task] does not provide a [colorHex], a default light grey
  /// ("#E0E0E0") is assigned here to guarantee data integrity.
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
          {'isCompleted': currentStatus ? 0 : 1},
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
        });
      }
    });
  }
}
