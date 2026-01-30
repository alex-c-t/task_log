import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/calendar_config.dart';

/// A constrained single-date picker dialog.
///
/// **Design Logic (Phase 2.6.3 Refined & 2.6.4):**
/// - **Single Selection**: Selects ONE date at a time.
/// - **Constraints**: Supports a [firstDate] to enforce "End >= Start" logic.
/// - **Visuals**: 
///   - Primary Circle for selection AND context date.
///   - Muted text for disabled dates.
///   - Rectangular highlight for the range between selected and context dates.
/// - **UX**: Always opens to the [initialDate]'s month.
class TaskLogDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? contextDate;

  const TaskLogDatePicker({
    super.key,
    required this.initialDate,
    this.firstDate,
    this.contextDate,
  });

  /// Displays the picker as a dialog.
  /// Returns the selected [DateTime], or null if canceled.
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? contextDate,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => TaskLogDatePicker(
        initialDate: initialDate,
        firstDate: firstDate,
        contextDate: contextDate,
      ),
    );
  }

  @override
  State<TaskLogDatePicker> createState() => _TaskLogDatePickerState();
}

class _TaskLogDatePickerState extends State<TaskLogDatePicker> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month);
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
    // Constraint Constraint: Cannot select before firstDate
    if (widget.firstDate != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final constraint = DateTime(widget.firstDate!.year, widget.firstDate!.month, widget.firstDate!.day);
      if (startOfDay.isBefore(constraint)) return;
    }

    setState(() {
      _selectedDate = date;
    });
  }

  void _confirm() {
    Navigator.of(context).pop(_selectedDate);
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
            height: 300,
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
                
                final isSelected = _isSameDay(date, _selectedDate);
                final isContext = widget.contextDate != null && _isSameDay(date, widget.contextDate!);
                
                // Visual Range Logic
                bool isInRange = false;
                if (widget.contextDate != null) {
                  final s = _selectedDate.isBefore(widget.contextDate!) ? _selectedDate : widget.contextDate!;
                  final e = _selectedDate.isBefore(widget.contextDate!) ? widget.contextDate! : _selectedDate;
                  
                  // Normalize for comparison
                  final d = DateTime(date.year, date.month, date.day);
                  final start = DateTime(s.year, s.month, s.day);
                  final end = DateTime(e.year, e.month, e.day);
                  
                  isInRange = d.isAfter(start) && d.isBefore(end);
                }
                
                // Disabled Logic
                bool isDisabled = false;
                if (widget.firstDate != null) {
                   final startOfDay = DateTime(date.year, date.month, date.day);
                   final constraint = DateTime(widget.firstDate!.year, widget.firstDate!.month, widget.firstDate!.day);
                   if (startOfDay.isBefore(constraint)) isDisabled = true;
                }

                BoxDecoration? decoration;
                Color textColor = Colors.black;

                if (isSelected || isContext) {
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
                   textColor = Colors.grey.shade400; // Muted
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
         
          // buttons
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
