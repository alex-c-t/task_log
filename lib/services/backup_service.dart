import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';

class BackupService {
  
  /// Exports the current database as a structured JSON file.
  /// This is more portable and transparent than a raw SQLite file.
  static Future<void> exportToJson() async {
    final db = await DatabaseService.instance.database;
    final tables = ['tasks', 'completions', 'comments', 'task_subtasks', 'subtask_completions'];
    
    Map<String, dynamic> fullBackup = {};
    for (var table in tables) {
      try {
        fullBackup[table] = await db.query(table);
      } catch (e) {
        debugPrint('BackupService: Table $table not found or error: $e');
      }
    }

    final jsonString = jsonEncode(fullBackup);
    final tempDir = await getTemporaryDirectory();
    final file = File(join(tempDir.path, 'tasklet_backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    
    await file.writeAsString(jsonString);
    await Share.shareXFiles([XFile(file.path)], text: 'Tasklet JSON Backup');
  }

  /// Exports the current SQLite database file via the platform's share dialog.
  static Future<void> exportDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'task_log.db');
    final file = File(path);

    if (await file.exists()) {
      await Share.shareXFiles([XFile(path)], text: 'Tasklet Database Backup');
    } else {
      throw Exception('Database file not found at $path');
    }
  }

  /// Restoration flow:
  /// 1. Close current DB connection (CRITICAL).
  /// 2. Pick backup file.
  /// 3. Overwrite local DB file.
  /// 4. Return true if successful.
  static Future<bool> restoreDatabase() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) {
      return false;
    }

    final sourcePath = result.files.single.path!;
    
    // Check if it's a JSON backup
    if (sourcePath.endsWith('.json')) {
      return await _importFromJson(sourcePath);
    }

    await DatabaseService.instance.close();
    final dbPath = await getDatabasesPath();
    final targetPath = join(dbPath, 'task_log.db');
    
    try {
      await File(sourcePath).copy(targetPath);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> _importFromJson(String path) async {
    final file = File(path);
    final jsonString = await file.readAsString();
    final Map<String, dynamic> data = jsonDecode(jsonString);

    final db = await DatabaseService.instance.database;
    
    await db.transaction((txn) async {
      // Clear existing data (DANGEROUS but necessary for a full restore)
      final tables = ['tasks', 'completions', 'comments', 'task_subtasks', 'subtask_completions'];
      for (var table in tables) {
        try {
          await txn.delete(table);
        } catch (e) {
          debugPrint('BackupService: Error clearing $table: $e');
        }
      }

      for (var table in data.keys) {
        if (!data.containsKey(table)) continue;
        final List<dynamic> rows = data[table];
        for (var row in rows) {
          await txn.insert(table, Map<String, dynamic>.from(row), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });

    return true;
  }
}

