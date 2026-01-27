import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../utils/recurrence_helper.dart';
import 'day_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // Default to the current month on launch.
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _loadTasks();
  }

  /// Fetches all task definitions and computes their occurrences for the current month.
  Future<void> _loadTasks() async {
    final tasks = await DatabaseService.instance.getAllTasks();
    if (mounted) {
      _computeTaskMap(tasks);
    }
  }

  /// Computes which tasks fall on which days of the currently focused month.
  /// 
  /// Logic:
  /// 1. Iterates from the 1st to the last day of [_focusedMonth] (Option B).
  /// 2. For each day, runs [RecurrenceHelper.isTaskActiveOnDate] against all tasks.
  /// 3. Builds a map for quick O(1) lookup during grid rendering.
  void _computeTaskMap(List<Task> allTasks) {
    final daysInMonth = _getDaysInMonth(_focusedMonth);
    final Map<DateTime, List<Task>> newMap = {};

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

  /// Returns the weekday index (1-7, Mon-Sun) for the first day of the month.
  int _getFirstWeekdayOfMonth(DateTime monthDate) {
    return DateTime(monthDate.year, monthDate.month, 1).weekday;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_focusedMonth);
    final firstWeekday = _getFirstWeekdayOfMonth(_focusedMonth);
    
    // Calculate total items needed for the grid.
    // firstWeekday: 1=Mon ... 7=Sun.
    // If first day is Tuesday (2), we need 1 empty cell at the start (offset = firstWeekday - 1).
    final offset = firstWeekday - 1;
    final totalCells = daysInMonth + offset;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Log'),
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
              children: List.generate(7, (index) {
                // 1=Mon, 7=Sun logic
                final dayName = DateFormat.E().format(DateTime(2024, 1, index + 1));
                return Expanded(
                  child: Center(
                    child: Text(
                      dayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
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
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.dayNumber,
    required this.isToday,
    required this.tasks,
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
        padding: const EdgeInsets.all(4),
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
            _TaskIndicators(tasks: tasks),
          ],
        ),
      ),
    );
  }
}

/// Renders visual indicators for tasks on a specific day.
/// 
/// Shows up to 3 colored dots. If there are more than 3 tasks,
/// displays a "+n" overflow label.
class _TaskIndicators extends StatelessWidget {
  final List<Task> tasks;

  const _TaskIndicators({required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    const int maxVisibleDots = 3;
    final visibleTasks = tasks.take(maxVisibleDots).toList();
    final overflowCount = tasks.length - maxVisibleDots;

    return Row(
      children: [
        // Color dots
        ...visibleTasks.map((task) => Container(
          margin: const EdgeInsets.only(right: 2),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Parse hex string back to color. Safety fallback to grey.
            color: _parseHexColor(task.colorHex),
          ),
        )),
        // Overflow label (+n)
        if (overflowCount > 0)
          Text(
            '+$overflowCount',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }

  /// Converts a hex string like "#E0E0E0" into a Flutter [Color] object.
  Color _parseHexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}
