import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/calendar_config.dart';

/// A custom date range picker dialog that enforces strict, forward-only selection rules.
///
/// **Design Constraints (Phase 2.6.3):**
/// 1. **Immutable Start Date**: The [startDate] is passed in as a required argument and cannot be changed.
/// 2. **Forward-Only**: Users can only select an end date that is equal to or after the [startDate].
/// 3. **Visuals**:
///    - Start Date: Solid primary color circle.
///    - End Date: Solid primary color circle.
///    - Range: Rectangular highlight with reduced opacity.
///    - Disabled (Before Start): Muted text, non-interactive.
/// 4. **Weekday Consistency**: Uses [CalendarConfig] for headers and grid alignment.
class TaskLogDateRangePicker extends StatefulWidget {
  final DateTime startDate;
  final DateTime? initialEndDate;

  const TaskLogDateRangePicker({
    super.key,
    required this.startDate,
    this.initialEndDate,
  });

  /// Displays the picker as a dialog.
  static Future<DateTimeRange?> show(
    BuildContext context, {
    required DateTime startDate,
    DateTime? initialEndDate,
  }) {
    return showDialog<DateTimeRange>(
      context: context,
      builder: (context) => TaskLogDateRangePicker(
        startDate: startDate,
        initialEndDate: initialEndDate,
      ),
    );
  }

  @override
  State<TaskLogDateRangePicker> createState() => _TaskLogDateRangePickerState();
}

class _TaskLogDateRangePickerState extends State<TaskLogDateRangePicker> {
  late DateTime _focusedMonth;
  late DateTime? _endSelection;

  @override
  void initState() {
    super.initState();
    // Start focused on the startDate's month.
    _focusedMonth = DateTime(widget.startDate.year, widget.startDate.month);
    _endSelection = widget.initialEndDate;
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
      );
    });
  }

  void _onDateTap(DateTime date) {
    // Forward-only constraint check.
    if (date.isBefore(DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day))) {
      return;
    }

    setState(() {
      _endSelection = date;
    });
  }

  void _confirm() {
    if (_endSelection == null) {
      // If no end selected, default to single-day range (Start == End)
       Navigator.of(context).pop(DateTimeRange(start: widget.startDate, end: widget.startDate));
    } else {
       Navigator.of(context).pop(DateTimeRange(start: widget.startDate, end: _endSelection!));
    }
  }

  int _getDaysInMonth(DateTime monthDate) {
    return DateTime(monthDate.year, monthDate.month + 1, 0).day;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_focusedMonth);
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    final offset = CalendarConfig.getGridOffset(firstWeekday);
    final totalCells = daysInMonth + offset;

    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / Navigation
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat.yMMMM().format(_focusedMonth),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // Weekday Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: CalendarConfig.getWeekdayLabels().map((label) {
                return Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          SizedBox(
            height: 300, // Fixed height for grid container
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                if (index < offset) return const SizedBox.shrink();

                final dayNumber = index - offset + 1;
                final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
                
                // --- Visual State Logic ---
                final isStart = _isSameDay(date, widget.startDate);
                final isEnd = _endSelection != null && _isSameDay(date, _endSelection!);
                
                // Check in-range: Start < Date < End
                bool isInRange = false;
                if (_endSelection != null) {
                   // Normalize to start of day for accurate comparison
                   final s = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
                   final e = DateTime(_endSelection!.year, _endSelection!.month, _endSelection!.day);
                   final d = DateTime(date.year, date.month, date.day);
                   isInRange = d.isAfter(s) && d.isBefore(e);
                }

                // Disabled: Date < Start
                final isDisabled = date.isBefore(DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day));

                BoxDecoration? decoration;
                Color textColor = Colors.black;

                if (isStart || isEnd) {
                  decoration = BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  );
                  textColor = Theme.of(context).colorScheme.onPrimary;
                } else if (isInRange) {
                  decoration = BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(4),
                  );
                } else if (isDisabled) {
                   textColor = Colors.grey;
                }

                return GestureDetector(
                  onTap: () => _onDateTap(date),
                  child: Container(
                    decoration: decoration,
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _confirm,
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
