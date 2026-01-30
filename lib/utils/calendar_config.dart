import 'dart:ui';

enum WeekStart { monday, sunday }

/// Central configuration for calendar weekday alignment.
/// 
/// This class serves as the single source of truth for:
/// 1. Determining the start of the week (Monday vs Sunday).
/// 2. Calculating grid offsets for the custom CalendarScreen.
/// 3. Providing the correct Locale for the system DatePicker to match alignment.
class CalendarConfig {
  /// The authoritative setting for the start of the week.
  /// Currently hardcoded to [WeekStart.monday] per Phase 2.6.2 requirements.
  static const WeekStart currentWeekStart = WeekStart.sunday;

  /// Returns the Locale that best approximates the [currentWeekStart].
  /// 
  /// - [WeekStart.monday] -> 'en_GB' (United Kingdom starts on Monday)
  /// - [WeekStart.sunday] -> 'en_US' (United States starts on Sunday)
  /// 
  /// *Note*: This is a best-effort alignment for the system Date Picker.
  static Locale getLocale() {
    switch (currentWeekStart) {
      case WeekStart.monday:
        return const Locale('en', 'GB');
      case WeekStart.sunday:
        return const Locale('en', 'US');
    }
  }

  /// Calculates the number of empty cells (leading padding) required at the
  /// start of the month grid based on the first day's weekday index.
  /// 
  /// [firstWeekdayOfMonth]: The standard Dart [DateTime.weekday] (1=Mon ... 7=Sun).
  static int getGridOffset(int firstWeekdayOfMonth) {
    switch (currentWeekStart) {
      case WeekStart.monday:
        // Mon (1) -> 0 offset
        // ...
        // Sun (7) -> 6 offset
        return (firstWeekdayOfMonth - 1) % 7;
        
      case WeekStart.sunday:
        // Sun (7) -> 0 offset
        // Mon (1) -> 1 offset
        // ...
        // Sat (6) -> 6 offset
        return firstWeekdayOfMonth % 7;
    }
  }

  /// Returns the list of weekday labels ordered according to [currentWeekStart].
  static List<String> getWeekdayLabels() {
    switch (currentWeekStart) {
      case WeekStart.monday:
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case WeekStart.sunday:
        return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    }
  }
}
