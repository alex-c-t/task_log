import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../utils/recurrence_helper.dart';
import 'day_detail_screen.dart';
import '../utils/calendar_config.dart';

/// A home screen providing a month-view calendar grid.
///
/// This screen serves as the primary navigation hub. Users can:
/// 1. Browse through different months using the navigation arrows.
/// 2. Tap on any day to see tasks for that specific date in the [DayDetailScreen].
/// 3. Identify today's date through a subtle visual highlight.
class CalendarScreen extends StatefulWidget {
  final Function(DateTime) onDateSelected;

  const CalendarScreen({
    super.key,
    required this.onDateSelected,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// The month currently being viewed by the user.
  late DateTime _focusedMonth;

  /// A map of dates to the list of tasks active on that date.
  /// This is pre-computed once per month change to ensure smooth grid rendering.
  Map<DateTime, List<Task>> _taskMap = {};

  /// A lookup map for task completion status.
  /// Key: "taskId-YYYY-MM-DD", Value: true if completed.
  /// This is a read-only rendering optimization.
  Map<String, bool> _completionMap = {};

  @override
  void initState() {
    super.initState();
    // Default to the current month on launch.
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _loadTasks();
  }

  /// Fetches all task definitions and computes their occurrences for the current month.
  /// Also performs a one-time optimized fetch of completion status for the month.
  Future<void> _loadTasks() async {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);

    final tasks = await DatabaseService.instance.getAllTasks();
    final completions = await DatabaseService.instance.getCompletionsForRange(firstDay, lastDay);

    if (mounted) {
      _computeTaskMap(tasks, completions);
    }
  }

  /// Computes which tasks fall on which days of the currently focused month.
  void _computeTaskMap(List<Task> allTasks, List<dynamic> completions) {
    final daysInMonth = _getDaysInMonth(_focusedMonth);
    final Map<DateTime, List<Task>> newMap = {};
    final Map<String, bool> newCompletionMap = {};

    // Build completion lookup key: "taskId-dateStr"
    for (var completion in completions) {
      final key = "${completion.taskId}-${completion.date}";
      newCompletionMap[key] = completion.isCompleted;
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final activeTasks = allTasks.where((task) {
        return RecurrenceHelper.isTaskActiveOnDate(task, date);
      }).toList();

      if (activeTasks.isNotEmpty) {
        newMap[date] = activeTasks;
      }
    }

    setState(() {
      _taskMap = newMap;
      _completionMap = newCompletionMap;
    });
  }

  /// Navigates the calendar focus by a given number of months.
  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
      );
      _taskMap.clear(); 
    });
    _loadTasks();
  }

  /// Calculates the total number of days in the currently focused month.
  int _getDaysInMonth(DateTime monthDate) {
    return DateTime(monthDate.year, monthDate.month + 1, 0).day;
  }

  int _getFirstWeekdayOfMonth(DateTime monthDate) {
    return DateTime(monthDate.year, monthDate.month, 1).weekday;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_focusedMonth);
    final firstWeekday = _getFirstWeekdayOfMonth(_focusedMonth);
    
    // Calculate total items needed for the grid.
    final offset = CalendarConfig.getGridOffset(firstWeekday);
    final totalCells = daysInMonth + offset;

    return Column(
      children: [
        // Month Navigation Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
                tooltip: 'Previous Month',
              ),
              Text(
                DateFormat.yMMMM().format(_focusedMonth),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
                tooltip: 'Next Month',
              ),
            ],
          ),
        ),
        
        // Weekday Labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: CalendarConfig.getWeekdayLabels().map((dayName) {
              return Expanded(
                child: Center(
                  child: Text(
                    dayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const Divider(),

        // Calendar Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.8, 
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < offset) {
                return const SizedBox.shrink();
              }

              final dayNumber = index - offset + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
              final now = DateTime.now();
              final isToday = date.year == now.year &&
                              date.month == now.month &&
                              date.day == now.day;

              final dayTasks = _taskMap[date] ?? [];

              return _CalendarDayCell(
                dayNumber: dayNumber,
                isToday: isToday,
                tasks: dayTasks,
                date: date,
                completionMap: _completionMap,
                onTap: () => widget.onDateSelected(date),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single day cell within the calendar grid.
///
/// This widget handles the visual representation of a single day
/// and its distinct highlight when it matches today's date.
class _CalendarDayCell extends StatelessWidget {
  final int dayNumber;
  final bool isToday;
  final List<Task> tasks;
  final DateTime date;
  final Map<String, bool> completionMap;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.dayNumber,
    required this.isToday,
    required this.tasks,
    required this.date,
    required this.completionMap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 0.5),
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 4),
            // Centered day number with circular highlight for today
            Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? Theme.of(context).colorScheme.primary : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  dayNumber.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday 
                        ? Colors.white 
                        : (Theme.of(context).brightness == Brightness.dark 
                           ? Colors.white 
                           : Colors.black87),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _TaskIndicators(
                tasks: tasks,
                date: date,
                completionMap: completionMap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders visual indicators for tasks on a specific day with completion state.
/// 
/// **Completion Visual Rules (Phase 2.3.1):**
/// - Completed occurrences show reduced opacity and a small universal green checkmark.
/// - Pending occurrences show full opacity and no checkmark.
/// - Green is reserved exclusively for this checkmark to avoid UI ambiguity.
class _TaskIndicators extends StatelessWidget {
  final List<Task> tasks;
  final DateTime date;
  final Map<String, bool> completionMap;

  const _TaskIndicators({
    required this.tasks,
    required this.date,
    required this.completionMap,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    const int maxVisibleDots = 3;
    final visibleTasks = tasks.take(maxVisibleDots).toList();
    final overflowCount = tasks.length - maxVisibleDots;
    final dateStr = date.toIso8601String().substring(0, 10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stacked color bars
          ...visibleTasks.map((task) {
            final isCompleted = completionMap["${task.id}-$dateStr"] ?? false;
            final baseColor = _parseHexColor(task.colorHex);
            final textColor = _getContrastingTextColor(baseColor);
            final displayTextColor = isCompleted ? textColor.withValues(alpha: 0.5) : textColor;

            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              height: 14,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: baseColor.withValues(alpha: isCompleted ? 0.2 : 1.0),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 10,
                    color: displayTextColor,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      task.title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: displayTextColor,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        decorationColor: isCompleted ? textColor : null,
                        decorationThickness: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Overflow label (+n) below bars
          if (overflowCount > 0)
            Center(
              child: Text(
                '+$overflowCount',
                style: TextStyle(
                  fontSize: 6, 
                  color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Converts a hex string like "#000000" into a Flutter [Color] object.
  Color _parseHexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  /// Returns Black or White text color depending on background luminance.
  Color _getContrastingTextColor(Color color) {
    // Relative luminance: 0.2126 * R + 0.7152 * G + 0.0722 * B
    // Flutter's computeLuminance() does exactly this.
    // Threshold 0.5 is standard. white (>0.5) -> black text. dark (<0.5) -> white text.
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
