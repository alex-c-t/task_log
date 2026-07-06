
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/preferences_provider.dart';
import '../models/task.dart';
import '../models/subtask.dart';
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
  final _targetCompletionsController = TextEditingController();
  final _recurrenceIntervalController = TextEditingController(text: '1');
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isTargetGoal = false;
  late RecurrenceType _recurrenceType;
  late List<int> _selectedWeeklyDays;
  late String _selectedColor;
  TimeOfDay? _reminderTime;
  String? _recurrenceRule;
  List<SubTask> _subTasks = [];
  final _subtaskController = TextEditingController();
  String? _selectedCategory;

  static const List<String> _categories = [
    'Personal',
    'Work',
    'Health',
    'Home',
    'Finance',
    'Social',
    'Hobby',
  ];

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
    
    _isTargetGoal = editTask?.targetCompletions != null;
    if (_isTargetGoal) {
      _targetCompletionsController.text = editTask!.targetCompletions.toString();
    }
    
    // UX logic: Use task's date, or initial context date, or current time
    _startDate = editTask?.startDate ?? widget.initialStartDate ?? DateTime.now();
    
    _endDate = editTask?.endDate ?? (_isTargetGoal ? null : _startDate!.add(const Duration(days: 30)));
    _recurrenceType = editTask?.recurrenceType ?? RecurrenceType.daily;
    _selectedWeeklyDays = List.of(editTask?.weeklyDays ?? []);
    _selectedColor = editTask?.colorHex ?? _colorPalette.first;
    _selectedCategory = editTask?.category;
    _recurrenceRule = editTask?.recurrenceRule;
    _recurrenceIntervalController.text = (editTask?.recurrenceInterval ?? 1).toString();
    
    if (editTask?.reminderTime != null) {
      final parts = editTask!.reminderTime!.split(':');
      _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    _loadSubTasks();
  }

  Future<void> _loadSubTasks() async {
    if (widget.taskToEdit?.id != null) {
      final subs = await DatabaseService.instance.getSubTasksForTask(widget.taskToEdit!.id!);
      if (mounted) {
        setState(() {
          _subTasks = subs;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetCompletionsController.dispose();
    _recurrenceIntervalController.dispose();
    _subtaskController.dispose();
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
      if (_startDate == null) return;
      
      int? targetCompletions;
      if (_isTargetGoal) {
        targetCompletions = int.tryParse(_targetCompletionsController.text);
        if (targetCompletions == null || targetCompletions <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid target completions number')),
          );
          return;
        }
      } else {
        if (_endDate == null) return;
      }

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
        endDate: _isTargetGoal ? null : _endDate,
        recurrenceType: _recurrenceType,
        weeklyDays: _recurrenceType == RecurrenceType.weekly ? _selectedWeeklyDays : null,
        colorHex: _selectedColor,
        reminderTime: reminderStr,
        targetCompletions: targetCompletions,
        category: _selectedCategory,
        recurrenceInterval: int.tryParse(_recurrenceIntervalController.text) ?? 1,
        isFinished: widget.taskToEdit?.isFinished ?? 0,
        recurrenceRule: _recurrenceRule,
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
        targetCompletions: task.targetCompletions,
        isFinished: task.isFinished,
      );

      final ns = NotificationService.instance;
      if (savedTask.reminderTime != null) {
        await ns.scheduleTaskReminder(savedTask);
      } else {
        await ns.cancelReminder(savedTask.id!);
      }

      // Save Subtasks
      for (var sub in _subTasks) {
        if (sub.id == null) {
          await DatabaseService.instance.addSubTask(taskId, sub.title);
        }
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
    final isPro = Provider.of<PreferencesProvider>(context).isProMode;
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
              if (isPro) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category (Optional)',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
                  ],
                  onChanged: (value) => setState(() => _selectedCategory = value),
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
              ],
              
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
                  if (!_isTargetGoal)
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
              
              // Goal Toggle Section
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set Completion Goal'),
                subtitle: const Text('Track days instead of a firm deadline'),
                value: _isTargetGoal,
                onChanged: (bool value) {
                  setState(() {
                    _isTargetGoal = value;
                    if (!value && _endDate == null && _startDate != null) {
                      _endDate = _startDate!.add(const Duration(days: 30));
                    }
                  });
                },
              ),
              if (_isTargetGoal) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _targetCompletionsController,
                  decoration: const InputDecoration(
                    labelText: 'Target Completions',
                    hintText: 'e.g. 15',
                    prefixIcon: Icon(Icons.flag),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!_isTargetGoal) return null;
                    if (value == null || value.isEmpty) return 'Specify target';
                    if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Must be positive number';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              if (!_isTargetGoal) ...[
                if (isPro) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12.0, right: 12.0),
                        child: Text('Repeat every', style: TextStyle(fontSize: 16)),
                      ),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _recurrenceIntervalController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          validator: (value) {
                            if (_isTargetGoal) return null;
                            final n = int.tryParse(value ?? '');
                            if (n == null || n <= 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<RecurrenceType>(
                          initialValue: _recurrenceType,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: RecurrenceType.values.map((type) {
                            final label = type == RecurrenceType.daily ? 'Days' : 
                                        type == RecurrenceType.weekly ? 'Weeks' : 'Months';
                            return DropdownMenuItem(
                              value: type,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _recurrenceType = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ] else
                  DropdownButtonFormField<RecurrenceType>(
                    initialValue: _recurrenceType,
                    decoration: const InputDecoration(labelText: 'Repeat'),
                    items: RecurrenceType.values.map((type) {
                      final label = type == RecurrenceType.daily ? 'Daily' : 
                                  type == RecurrenceType.weekly ? 'Weekly' : 'Monthly';
                      return DropdownMenuItem(
                        value: type,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _recurrenceType = value!;
                      });
                    },
                  ),
              ] else ...[
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
              ],
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
              if (isPro && _recurrenceType == RecurrenceType.monthly) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _recurrenceRule,
                  decoration: const InputDecoration(labelText: 'Monthly Rule', prefixIcon: Icon(Icons.auto_awesome)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Same day each month')),
                    const DropdownMenuItem(value: '{"type": "last_day"}', child: Text('Last day of month')),
                    DropdownMenuItem(
                      value: '{"type": "last_weekday", "weekday": ${_startDate?.weekday ?? 1}}',
                      child: Text('Last ${DateFormat.EEEE().format(_startDate ?? DateTime.now())}'),
                    ),
                    DropdownMenuItem(
                      value: '{"type": "ordinal_weekday", "ordinal": ${(((_startDate?.day ?? 1) - 1) ~/ 7) + 1}, "weekday": ${_startDate?.weekday ?? 1}}',
                      child: Text('${_getOrdinalText((((_startDate?.day ?? 1) - 1) ~/ 7) + 1)} ${DateFormat.EEEE().format(_startDate ?? DateTime.now())}'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _recurrenceRule = v),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              if (isPro) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Checklist (Sub-Tasks)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                      onPressed: () {
                        final title = _subtaskController.text.trim();
                        if (title.isNotEmpty) {
                          setState(() {
                            _subTasks.add(SubTask(taskId: widget.taskToEdit?.id ?? 0, title: title));
                            _subtaskController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _subtaskController,
                  decoration: const InputDecoration(
                    hintText: 'Add a sub-task...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (value) {
                    final title = value.trim();
                    if (title.isNotEmpty) {
                      setState(() {
                        _subTasks.add(SubTask(taskId: widget.taskToEdit?.id ?? 0, title: title));
                        _subtaskController.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _subTasks.length,
                  itemBuilder: (context, index) {
                    final sub = _subTasks[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.subdirectory_arrow_right, size: 16),
                      title: Text(sub.title),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () async {
                          if (sub.id != null) {
                             await DatabaseService.instance.deleteSubTask(sub.id!);
                          }
                          setState(() {
                            _subTasks.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_startDate != null && (_isTargetGoal || _endDate != null)) ? _saveTask : null,
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
  String _getOrdinalText(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }
}
