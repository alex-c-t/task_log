import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../utils/recurrence_helper.dart';
import 'day_detail_screen.dart';
import '../utils/calendar_config.dart';
import '../widgets/month_year_picker.dart';

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
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  late DateTime _initialMonth;
  late PageController _pageController;
  int _currentPage = 500;
  /// The month currently being viewed by the user (for the header).
  late ValueNotifier<DateTime> _focusedMonthNotifier;

  late Future<void> _initialLoadFuture;
  final ValueNotifier<Map<String, bool>> _completionNotifier = ValueNotifier({});
  List<Task> _allTasks = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _initialMonth = DateTime(now.year, now.month);
    _focusedMonthNotifier = ValueNotifier(_initialMonth);
    _pageController = PageController(initialPage: _currentPage);
    _initialLoadFuture = _preloadData(_focusedMonthNotifier.value);
  }

  Future<void> _preloadData(DateTime month) async {
    _allTasks = await DatabaseService.instance.getAllTasks();
    await _loadCompletionsForWindow(month);
  }

  Future<void> _loadCompletionsForWindow(DateTime centerMonth) async {
    final start = DateTime(centerMonth.year, centerMonth.month - 1, 1);
    final end = DateTime(centerMonth.year, centerMonth.month + 2, 0, 23, 59, 59);
    
    final completions = await DatabaseService.instance.getCompletionsForRange(start, end);
    
    // Update notifier without a full setState/rebuild of the parent
    final current = Map<String, bool>.from(_completionNotifier.value);
    bool changed = false;
    for (var completion in completions) {
      final key = "${completion.taskId}-${completion.date}";
      if (current[key] != completion.isCompleted) {
        current[key] = completion.isCompleted;
        changed = true;
      }
    }
    if (changed) {
      _completionNotifier.value = current;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Public method to reset to today's month
  void resetToToday() {
    if (_currentPage != 500) {
      _pageController.animateToPage(
        500,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Jump to a specific month
  void _jumpToMonth(DateTime targetMonth) {
    final monthsDiff = (targetMonth.year - _initialMonth.year) * 12 +
                       (targetMonth.month - _initialMonth.month);
    final targetPage = 500 + monthsDiff;

    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  int _refreshCount = 0;

  /// Public method to refresh all loaded data
  void refresh() {
    setState(() {
      _refreshCount++;
      _initialLoadFuture = _preloadData(_focusedMonthNotifier.value);
    });
  }

  void _onPageChanged(int page) {
    final monthsDiff = page - 500;
    final newMonth = DateTime(_initialMonth.year, _initialMonth.month + monthsDiff);
    _currentPage = page;
    _focusedMonthNotifier.value = newMonth;
    // Proactively load completions for the new window if needed.
    _loadCompletionsForWindow(newMonth);
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                tooltip: 'Previous Month',
              ),
              ValueListenableBuilder<DateTime>(
                valueListenable: _focusedMonthNotifier,
                builder: (context, focusedMonth, _) {
                  return InkWell(
                    onTap: () async {
                      final selected = await showMonthYearPicker(
                        context: context,
                        initialDate: focusedMonth,
                      );
                      if (selected != null) {
                        _jumpToMonth(selected);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat.yMMMM().format(focusedMonth),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                tooltip: 'Next Month',
              ),
            ],
          ),
        ),
        
        // Weekday Labels (Fixed)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: CalendarConfig.getWeekdayLabels().map((dayName) {
              return Expanded(
                child: Center(
                  child: Text(
                    dayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const Divider(),

        // Calendar Grid as PageView
        Expanded(
          child: _allTasks.isEmpty
              ? FutureBuilder(
                  future: _initialLoadFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildPageView();
                  },
                )
              : _buildPageView(),
        ),
      ],
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, pageIndex) {
        final monthsDiff = pageIndex - 500;
        final month = DateTime(_initialMonth.year, _initialMonth.month + monthsDiff);
        return _MonthGrid(
          key: ValueKey("${month.year}-${month.month}-$_refreshCount"),
          month: month,
          allTasks: _allTasks,
          completionNotifier: _completionNotifier,
          onDateSelected: widget.onDateSelected,
        );
      },
    );
  }
}

class _MonthGrid extends StatefulWidget {
  final DateTime month;
  final List<Task> allTasks;
  final ValueNotifier<Map<String, bool>> completionNotifier;
  final Function(DateTime) onDateSelected;

  const _MonthGrid({
    super.key,
    required this.month,
    required this.allTasks,
    required this.completionNotifier,
    required this.onDateSelected,
  });

  @override
  State<_MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<_MonthGrid> with AutomaticKeepAliveClientMixin {
  late Map<DateTime, List<Task>> _taskMap;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _computeTaskMap();
  }

  @override
  void didUpdateWidget(_MonthGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allTasks != widget.allTasks || oldWidget.month != widget.month) {
      _computeTaskMap();
    }
  }

  void _computeTaskMap() {
    final month = widget.month;
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final potentialTasks = widget.allTasks.where((task) {
      return task.startDate.isBefore(lastDay) && task.endDate.isAfter(firstDay);
    }).toList();

    final Map<DateTime, List<Task>> newMap = {};
    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(month.year, month.month, day);
      final activeTasks = potentialTasks.where((task) {
        return RecurrenceHelper.isTaskActiveOnDate(task, date);
      }).toList();

      if (activeTasks.isNotEmpty) {
        newMap[date] = activeTasks;
      }
    }
    _taskMap = newMap;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final daysInMonth = DateTime(widget.month.year, widget.month.month + 1, 0).day;
    final firstWeekday = DateTime(widget.month.year, widget.month.month, 1).weekday;
    final offset = CalendarConfig.getGridOffset(firstWeekday);
    final totalCells = daysInMonth + offset;

    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: widget.completionNotifier,
      builder: (context, completionMap, _) {
        return GridView.builder(
          padding: const EdgeInsets.all(8.0),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.5,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();

            final dayNumber = index - offset + 1;
            final date = DateTime(widget.month.year, widget.month.month, dayNumber);
            final now = DateTime.now();
            final isToday = date.year == now.year &&
                            date.month == now.month &&
                            date.day == now.day;

            return _CalendarDayCell(
              dayNumber: dayNumber,
              isToday: isToday,
              tasks: _taskMap[date] ?? [],
              date: date,
              completionMap: completionMap,
              onTap: () => widget.onDateSelected(date),
            );
          },
        );
      },
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

    const int maxVisibleDots = 5;
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
              height: 11,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: baseColor.withValues(alpha: isCompleted ? 0.2 : 1.0),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 8,
                    color: displayTextColor,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      task.title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 8,
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
