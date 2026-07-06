import 'dart:convert';
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
  static bool isTaskActiveOnDate(
    Task task,
    DateTime date, {
    bool isCompletedOnDate = false,
    bool checkRecurrenceForPastGoals = false,
  }) {
    // 1. Check date range (inclusive)
    // Normalize dates to YYYY-MM-DD for comparison
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(task.startDate.year, task.startDate.month, task.startDate.day);

    if (normalizedDate.isBefore(normalizedStart)) {
      return false;
    }

    if (task.targetCompletions != null) {
      // It's a Target Goal
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      if (normalizedDate.isBefore(today)) {
        // For past dates, show if it was completed on that day,
        // OR if checkRecurrenceForPastGoals is true and it matches the recurrence rule.
        if (isCompletedOnDate) return true;
        if (checkRecurrenceForPastGoals) {
          return _checkRecurrence(task, normalizedDate);
        }
        return false;
      } else if (normalizedDate.isAfter(today)) {
        // Never artificially clutter the future calendar with open goals
        return false;
      } else {
        // For today, only show if the goal isn't completely finished yet, OR it was completed today
        if (task.isFinished == 1 && !isCompletedOnDate) return false;
      }
    } else {
      // It's a Regular Task with an End Date
      if (task.endDate != null) {
        final normalizedEnd = DateTime(task.endDate!.year, task.endDate!.month, task.endDate!.day);
        if (normalizedDate.isAfter(normalizedEnd)) {
          return false;
        }
      }
    }

    // 2. Check recurrence type
    return _checkRecurrence(task, normalizedDate);
  }

  /// Determines if a task is scheduled on a date, ignoring completion/goal state.
  static bool isTaskScheduledOnDate(Task task, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(task.startDate.year, task.startDate.month, task.startDate.day);
    if (d.isBefore(start)) return false;

    if (task.targetCompletions == null && task.endDate != null) {
      final end = DateTime(task.endDate!.year, task.endDate!.month, task.endDate!.day);
      if (d.isAfter(end)) return false;
    }

    return _checkRecurrence(task, d);
  }

  static bool _checkRecurrence(Task task, DateTime date) {
    final interval = task.recurrenceInterval;
    final start = DateTime(task.startDate.year, task.startDate.month, task.startDate.day);

    switch (task.recurrenceType) {
      case RecurrenceType.daily:
        if (interval <= 1) return true;
        final diffDays = date.difference(start).inDays;
        return diffDays % interval == 0;

      case RecurrenceType.weekly:
        // 1. Check if the specific weekday is selected
        if (task.weeklyDays == null || !task.weeklyDays!.contains(date.weekday)) {
          return false;
        }
        if (interval <= 1) return true;

        // 2. Check if this is the correct week in the interval
        // We find the "ISO Week" start (Monday) for both dates
        final taskWeekStart = start.subtract(Duration(days: start.weekday - 1));
        final dateWeekStart = date.subtract(Duration(days: date.weekday - 1));
        final diffWeeks = dateWeekStart.difference(taskWeekStart).inDays ~/ 7;
        
        return diffWeeks % interval == 0;

      case RecurrenceType.monthly:
        // 1. Check if this is the correct month in the interval
        final diffMonths = (date.year - start.year) * 12 + (date.month - start.month);
        if (diffMonths % interval != 0) return false;

        // 2. Check for Advanced Rules
        if (task.recurrenceRule != null) {
          try {
            final rule = jsonDecode(task.recurrenceRule!);
            if (rule['type'] == 'last_day') {
              final lastDay = DateTime(date.year, date.month + 1, 0).day;
              return date.day == lastDay;
            }
            if (rule['type'] == 'last_weekday') {
              final weekday = rule['weekday'] as int;
              if (date.weekday != weekday) return false;
              final nextWeekSameDay = date.add(const Duration(days: 7));
              return nextWeekSameDay.month != date.month;
            }
            if (rule['type'] == 'ordinal_weekday') {
              final ordinal = rule['ordinal'] as int; // 1, 2, 3, 4
              final weekday = rule['weekday'] as int;
              if (date.weekday != weekday) return false;
              final currentOrdinal = ((date.day - 1) ~/ 7) + 1;
              return currentOrdinal == ordinal;
            }
          } catch (_) {
            // Fallback to day of month if rule parsing fails
          }
        }

        // 3. Fallback: Check if the day of month matches
        return date.day == start.day;
    }
  }
}
