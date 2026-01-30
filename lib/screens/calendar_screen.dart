import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'main_screen.dart';
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
  const CalendarScreen({super.key});

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
  /// 
  /// Logic:
  /// 1. Iterates from the 1st to the last day of [_focusedMonth] (Option B).
  /// 2. For each day, runs [RecurrenceHelper.isTaskActiveOnDate] against all tasks.
  /// 3. Builds a map for quick O(1) lookup during grid rendering.
  /// 4. Also populates the completion lookup map from pre-fetched records.
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
  ///
  /// [delta] is typically 1 for next month, or -1 for previous month.
  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
      );
      _taskMap.clear(); // Clear to avoid showing stale indicators while loading
    });
    _loadTasks();
  }

  /// Calculates the total number of days in the currently focused month.
  int _getDaysInMonth(DateTime monthDate) {
    // Adding 1 to the month and setting day to 0 returns the last day of the current month.
    return DateTime(monthDate.year, monthDate.month + 1, 0).day;
  }

  int _getFirstWeekdayOfMonth(DateTime monthDate) {
    return DateTime(monthDate.year, monthDate.month, 1).weekday;
  }
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_focusedMonth);
    final firstWeekday = _getFirstWeekdayOfMonth(_focusedMonth);
    
    // Calculate total items needed for the grid.
    final offset = CalendarConfig.getGridOffset(firstWeekday);
    final totalCells = daysInMonth + offset;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasklet'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => MainScreen.scaffoldKey.currentState?.openDrawer(),
          ),
        ),
      ),
      body: Column(
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
                childAspectRatio: 0.8, // Tall cells as requested
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                if (index < offset) {
                  // Empty space for padding leading days
                  return const SizedBox.shrink();
                }

                final dayNumber = index - offset + 1;
                final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
                final now = DateTime.now();
                final isToday = date.year == now.year &&
                                date.month == now.month &&
                                date.day == now.day;

                // Retrieve pre-computed tasks for this specific date.
                final dayTasks = _taskMap[date] ?? [];

                return _CalendarDayCell(
                  dayNumber: dayNumber,
                  isToday: isToday,
                  tasks: dayTasks,
                  date: date,
                  completionMap: _completionMap,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DayDetailScreen(selectedDate: date),
                      ),
                    );
                    _loadTasks(); // Refresh in case tasks were added/modified
                  },
                );
              },
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: isToday ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
        ),
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dayNumber.toString(),
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            _TaskIndicators(
              tasks: tasks,
              date: date,
              completionMap: completionMap,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stacked color bars
        ...visibleTasks.map((task) {
          final isCompleted = completionMap["${task.id}-$dateStr"] ?? false;
          final baseColor = _parseHexColor(task.colorHex);

          // Text Fade Logic
          final title = task.title;
          const int nOpaque = 8;
          const int mFaded = 4;
          
          String part1 = "";
          String part2 = "";

          if (title.length <= nOpaque) {
            part1 = title;
          } else {
            part1 = title.substring(0, nOpaque);
            if (title.length <= nOpaque + mFaded) {
              part2 = title.substring(nOpaque);
            } else {
              part2 = title.substring(nOpaque, nOpaque + mFaded);
            }
          }

          final textColor = _getContrastingTextColor(baseColor);
          // If task is completed, the bar itself is faded (0.2). 
          // Text contrast should calculate against the effective color or just base? 
          // Plan says "Text fade is independent of task completion state", 
          // and "Bar color and opacity logic ... same".
          // However, if bar is 0.2 opacity, white text might be invisible if background is white.
          // But strict rules say "Bar color ... logic remain EXACTLY".
          // We will assume standard contrast against the base color usually works, 
          // or just strictly follow the "contrast with bar color" rule. 
          // Since the bar is transparent-ish when completed, text might need to be darker?
          // Simplest interpretation: Contrast against the *base* color, but if the bar is very light due to opacity, 
          // functionality might vary. 
          // However, let's stick to the base color for contrast decision to be stable.

          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            height: 9,
            padding: const EdgeInsets.only(left: 2),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: baseColor.withOpacity(isCompleted ? 0.2 : 1.0),
            ),
            child: RichText(
              overflow: TextOverflow.clip,
              maxLines: 1,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 8, 
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                children: [
                  TextSpan(
                    text: part1,
                    style: TextStyle(
                      color: textColor.withOpacity(1.0),
                    ),
                  ),
                  if (part2.isNotEmpty)
                    TextSpan(
                      text: part2,
                      style: TextStyle(
                        color: textColor.withOpacity(0.3),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        // Overflow label (+n) below bars
        if (overflowCount > 0)
          Center(
            child: Text(
              '+$overflowCount',
              style: const TextStyle(fontSize: 6, color: Colors.black),
            ),
          ),
      ],
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
