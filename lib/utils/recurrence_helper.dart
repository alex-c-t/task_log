
import '../models/task.dart';

class RecurrenceHelper {
  /// Determines if a task should appear on the given [date].
  ///
  /// [date] should be a DateTime with time components ignored (or treated as 00:00:00).
  ///
  /// Rules:
  /// - Task must be within [startDate, endDate] (inclusive).
  /// - Weekly: [date.weekday] must be in [task.weeklyDays]. (1=Mon, 7=Sun).
  /// - Monthly: [date.day] must match [task.startDate.day].
  ///   - If the task started on the 31st, it only appears in months with 31 days.
  ///   - Strict rule: If month doesn't have that day, skip it.
  static bool isTaskActiveOnDate(Task task, DateTime date) {
    // 1. Check date range (inclusive)
    // Normalize dates to YYYY-MM-DD for comparison
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(task.startDate.year, task.startDate.month, task.startDate.day);
    final normalizedEnd = DateTime(task.endDate.year, task.endDate.month, task.endDate.day);

    if (normalizedDate.isBefore(normalizedStart) || normalizedDate.isAfter(normalizedEnd)) {
      return false;
    }

    // 2. Check recurrence type
    switch (task.recurrenceType) {
      case RecurrenceType.daily:
        return true;

      case RecurrenceType.weekly:
        if (task.weeklyDays == null || task.weeklyDays!.isEmpty) {
          return false;
        }
        // DateTime.weekday returns 1 for Monday, 7 for Sunday.
        // task.weeklyDays stores these values directly.
        return task.weeklyDays!.contains(normalizedDate.weekday);

      case RecurrenceType.monthly:
        // Strict monthly rule: Day of month must match exactly.
        // Example: Started Jan 31.
        // - Feb 28/29: Returns false (skip).
        // - Mar 31: Returns true.
        // - Apr 30: Returns false (skip).
        return normalizedDate.day == normalizedStart.day;
    }
  }
}
