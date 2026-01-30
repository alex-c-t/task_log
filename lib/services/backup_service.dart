import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_service.dart';

class BackupService {
  
  /// Exports the current SQLite database file via the platform's share dialog.
  static Future<void> exportDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'task_log.db');
    final file = File(path);

    if (await file.exists()) {
      await Share.shareXFiles([XFile(path)], text: 'Task Log Database Backup');
    } else {
      throw Exception('Database file not found at $path');
    }
  }

  /// Restoration flow:
  /// 1. Close current DB connection (CRITICAL).
  /// 2. Pick backup file.
  /// 3. Overwrite local DB file.
  /// 4. Return true if successful, indicating App must restart.
  static Future<bool> restoreDatabase() async {
    // 1. Pick File
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) {
      return false; // Canceled
    }

    final sourcePath = result.files.single.path!;

    // 2. Validate Source is likely a DB? (Hard to do without opening, assume trust for now)
    
    // 3. Close Connection
    await DatabaseService.instance.close();

    // 4. Overwrite
    final dbPath = await getDatabasesPath();
    final targetPath = join(dbPath, 'task_log.db');
    
    // Ensure target directory exists (should, but safe check)
    // await Directory(dirname(targetPath)).create(recursive: true);

    try {
      await File(sourcePath).copy(targetPath);
      return true; // Success
    } catch (e) {
      // If copy fails, we might be in a bad state if we partially wrote? 
      // File.copy is usually atomic-ish or at least separate from the DB engine now that it's closed.
      // attempt to re-open?
      // Actually, if we closed the DB, the app is functionally dead until restart anyway.
      rethrow;
    }
  }
}
