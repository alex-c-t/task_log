
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/task_log_date_range_picker.dart';

/// A screen for creating or editing [Task] definitions.
///
/// This screen provides a form to set task properties like title, date range,
/// recurrence rules, and a visual [colorHex].
/// 
/// **Design Decisions:**
/// - Color selection is limited to a fixed bright palette to ensure that the
///   "Completion via Brightness" rendering logic (Phase 2.3) remains effective
///   and high-contrast.
/// - Editing is restricted to this form to maintain the calendar as a
///   read-oriented navigation surface.
class AddTaskScreen extends StatefulWidget {
  /// If provided, the screen initializes in "Edit Mode" with this task's data.
  final Task? taskToEdit;

  /// If provided, new tasks will default to this start date.
  final DateTime? initialStartDate;

  const AddTaskScreen({
    super.key,
    this.taskToEdit,
    this.initialStartDate,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  late RecurrenceType _recurrenceType;
  late List<int> _selectedWeeklyDays;
  late String _selectedColor;
  TimeOfDay? _reminderTime;

  /// The predefined bright color palette for task categorization.
  /// Black (#000000) is the default and first option.
  /// 
  /// Why Black? It serves as a neutral, high-contrast base for all tasks.
  /// Why no Green? Under Phase 2.3.1 rules, green is reserved exclusively
  /// for completion status (checkmark) to avoid visual ambiguity.
  static const List<String> _colorPalette = [
  "#000000", // Black (Default) 
  "#D32F2F", // Red (darker)
  "#F57C00", // Orange (darker)
  "#FBC02D", // Yellow (darker, less glare)
  "#0097A7", // Cyan (darker)
  "#1976D2", // Blue (darker)
  "#7B1FA2", // Purple (darker)
  "#C2185B", // Magenta (darker)
  "#5D4037", // Brown (darker)
];

  @override 
  void initState() {
    super.initState();
    final editTask = widget.taskToEdit;
    
    // Initialize fields from taskToEdit or defaults for new task
    _titleController.text = editTask?.title ?? '';
    
    // UX logic: Use task's date, or initial context date, or current time
    _startDate = editTask?.startDate ?? widget.initialStartDate ?? DateTime.now();
    
    _endDate = editTask?.endDate ?? _startDate!.add(const Duration(days: 30));
    _recurrenceType = editTask?.recurrenceType ?? RecurrenceType.daily;
    _selectedWeeklyDays = List.of(editTask?.weeklyDays ?? []);
    _selectedColor = editTask?.colorHex ?? _colorPalette.first;
    
    if (editTask?.reminderTime != null) {
      final parts = editTask!.reminderTime!.split(':');
      _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    // Determine initial focused date and constraints
    final DateTime? initial = isStart ? _startDate : _endDate;
    // For End Date, create constraints based on Start Date
    final DateTime? constraint = isStart ? null : _startDate;
    // Context Date (the "other" date) for visual highlighting
    final DateTime? visualContext = isStart ? _endDate : _startDate;
    
    // Fallback focus for null fields (should rarely happen for start due to init logic)
    final DateTime focusDate = initial ?? (isStart ? DateTime.now() : _startDate ?? DateTime.now());

    final DateTime? picked = await TaskLogDatePicker.show(
      context,
      initialDate: focusDate,
      firstDate: constraint,
      contextDate: visualContext,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Invalidation Rule: If Start moves past End, End becomes invalid (null)
          if (_endDate != null && picked.isAfter(_endDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  /// Persists the task to the database (INSERT or UPDATE).
  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      // Form validation ensures these are not null via button state, but explicit check adds safety.
      if (_startDate == null || _endDate == null) return;

      if (_recurrenceType == RecurrenceType.weekly && _selectedWeeklyDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one day for weekly recurrence')),
        );
        return;
      }

      String? reminderStr;
      if (_reminderTime != null) {
        reminderStr = '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
      }

      final task = Task(
        id: widget.taskToEdit?.id,
        title: _titleController.text,
        startDate: _startDate!,
        endDate: _endDate!,
        recurrenceType: _recurrenceType,
        weeklyDays: _recurrenceType == RecurrenceType.weekly ? _selectedWeeklyDays : null,
        colorHex: _selectedColor,
        reminderTime: reminderStr,
      );

      int taskId;
      if (widget.taskToEdit == null) {
        taskId = await DatabaseService.instance.insertTask(task);
      } else {
        await DatabaseService.instance.updateTask(task);
        taskId = task.id!;
      }
      
      // Schedule or cancel reminder
      // IMPORTANT: We need the inserted ID for new tasks
      final savedTask = Task(
        id: taskId,
        title: task.title,
        startDate: task.startDate,
        endDate: task.endDate,
        recurrenceType: task.recurrenceType,
        weeklyDays: task.weeklyDays,
        colorHex: task.colorHex,
        reminderTime: task.reminderTime,
      );

      final ns = NotificationService.instance;
      if (savedTask.reminderTime != null) {
        await ns.scheduleTaskReminder(savedTask);
      } else {
        await ns.cancelReminder(savedTask.id!);
      }

      if (mounted) Navigator.pop(context);
    }
  }

  /// Shows a confirmation dialog and deletes the task if confirmed.
  void _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text(
          'This will permanently remove the task and all its completion history. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.taskToEdit?.id != null) {
      await NotificationService.instance.cancelReminder(widget.taskToEdit!.id!);
      await DatabaseService.instance.deleteTask(widget.taskToEdit!.id!);
      if (mounted) {
        // Pop back twice or to home? Let's pop once, 
        // the DayDetailScreen will refresh on resume if we handle it there.
        Navigator.pop(context); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditMode = widget.taskToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Task' : 'Add Task'),
        actions: [
          if (isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteTask,
              tooltip: 'Delete Task',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task Title'),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              
              // Reminder Section
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily Reminder'),
                subtitle: Text(_reminderTime != null 
                    ? 'Notify at ${_reminderTime!.format(context)}' 
                    : 'No reminder set'),
                value: _reminderTime != null,
                onChanged: (bool value) {
                  if (value) {
                    _selectTime(context);
                  } else {
                    setState(() => _reminderTime = null);
                  }
                },
              ),
              if (_reminderTime != null)
                TextButton.icon(
                  onPressed: () => _selectTime(context),
                  icon: const Icon(Icons.access_time, size: 18),
                  label: const Text('Change Reminder Time'),
                ),
              
              const SizedBox(height: 16),
              
              // Color Selection Section
              const Text('Task Color', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colorPalette.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final colorHex = _colorPalette[index];
                    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                    final isSelected = _selectedColor == colorHex;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = colorHex),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? colorScheme.primary : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: isSelected 
                          ? Icon(
                              Icons.check, 
                              color: index == 0 ? Colors.black54 : Colors.white,
                              size: 20,
                            ) 
                          : null,
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(_startDate != null ? DateFormat.yMMMd().format(_startDate!) : 'Select Date'),
                      onTap: () => _selectDate(context, true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(_endDate != null ? DateFormat.yMMMd().format(_endDate!) : 'Select Date'),
                      onTap: () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RecurrenceType>(
                initialValue: _recurrenceType,
                decoration: const InputDecoration(labelText: 'Recurrence'),
                items: RecurrenceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _recurrenceType = value!;
                  });
                },
              ),
              if (_recurrenceType == RecurrenceType.weekly) ...[
                const SizedBox(height: 16),
                const Text('Select Days (Mon-Sun):'),
                Wrap(
                  spacing: 8.0,
                  children: List<int>.generate(7, (index) => index + 1).map((day) {
                    final dayName = DateFormat.E().format(DateTime(2024, 1, day)); // 2024-01-01 is Monday
                    return FilterChip(
                      label: Text(dayName),
                      selected: _selectedWeeklyDays.contains(day),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedWeeklyDays.add(day);
                          } else {
                            _selectedWeeklyDays.remove(day);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_startDate != null && _endDate != null) ? _saveTask : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(isEditMode ? 'Update Task' : 'Save Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
