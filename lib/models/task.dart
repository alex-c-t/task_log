
enum RecurrenceType { daily, weekly, monthly }

class Task {
  final int? id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final RecurrenceType recurrenceType;
  final List<int>? weeklyDays; // 1 = Mon, 7 = Sun. Only if recurrenceType == weekly

  Task({
    this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.recurrenceType,
    this.weeklyDays,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate.toIso8601String().substring(0, 10), // YYYY-MM-DD
      'endDate': endDate.toIso8601String().substring(0, 10), // YYYY-MM-DD
      'recurrenceType': recurrenceType.toString().split('.').last,
      'weeklyDays': weeklyDays?.join(','), // Store as "1,3,5"
    };
  }

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
    );
  }
}
