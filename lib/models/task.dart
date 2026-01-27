
enum RecurrenceType { daily, weekly, monthly }

/// Represents a task definition with its recurrence rules and visual properties.
class Task {
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

  Task({
    this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.recurrenceType,
    this.weeklyDays,
    required this.colorHex,
  });

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
    );
  }
}
