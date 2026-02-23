import 'package:uuid/uuid.dart';
import 'sync_entity_mixin.dart';

enum RecurrenceType { daily, weekly, monthly }

/// Represents a task definition with its recurrence rules and visual properties.
class Task with SyncEntity {
  final int? id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final RecurrenceType recurrenceType;
  /// 1 = Mon, 7 = Sun. Only used if [recurrenceType] is [RecurrenceType.weekly].
  final List<int>? weeklyDays;
  /// The hex color code for this task (e.g., "#E0E0E0").
  /// Every task must have a color for consistent UI rendering.
  final String colorHex;
  
  /// The time to show a daily reminder for this task (e.g., "09:00").
  final String? reminderTime;
  
  @override
  String uuid;
  @override
  DateTime createdAt;
  @override
  DateTime updatedAt;

  Task({
    this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.recurrenceType,
    this.weeklyDays,
    required this.colorHex,
    this.reminderTime,
    String? uuid,
    DateTime? createdAt,
    DateTime? updatedAt,
    int isDeleted = 0,
  }) : uuid = uuid ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now().toUtc(),
       updatedAt = updatedAt ?? DateTime.now().toUtc() {
    this.isDeleted = isDeleted;
  }

  /// Converts a [Task] into a Map for SQLite persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate.toIso8601String().substring(0, 10), // YYYY-MM-DD
      'endDate': endDate.toIso8601String().substring(0, 10), // YYYY-MM-DD
      'recurrenceType': recurrenceType.toString().split('.').last,
      'weeklyDays': weeklyDays?.join(','), // Store as "1,3,5"
      'colorHex': colorHex,
      'reminderTime': reminderTime,
      ...toMapSync(),
    };
  }

  /// Reconstructs a [Task] from a database Map.
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      recurrenceType: RecurrenceType.values.firstWhere(
        (e) => e.toString().split('.').last == map['recurrenceType'],
      ),
      weeklyDays: map['weeklyDays'] != null && map['weeklyDays'].toString().isNotEmpty
          ? map['weeklyDays'].toString().split(',').map((e) => int.parse(e)).toList()
          : null,
      colorHex: map['colorHex'] ?? "#E0E0E0", // Fallback for safety during schema migration
      reminderTime: map['reminderTime'],
      uuid: map['uuid'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      isDeleted: map['isDeleted'] ?? 0,
    );
  }
}
