
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_service.dart';

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

  const AddTaskScreen({super.key, this.taskToEdit});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  late RecurrenceType _recurrenceType;
  late List<int> _selectedWeeklyDays;
  late String _selectedColor;

  /// The predefined bright color palette for task categorization.
  /// Grey (#E0E0E0) is the default and first option.
  static const List<String> _colorPalette = [
    "#E0E0E0", // Grey (Default)
    "#2196F3", // Blue
    "#F44336", // Red
    "#4CAF50", // Green
    "#FF9800", // Orange
    "#9C27B0", // Purple
  ];

  @override
  void initState() {
    super.initState();
    final editTask = widget.taskToEdit;
    
    // Initialize fields from taskToEdit or defaults for new task
    _titleController.text = editTask?.title ?? '';
    _startDate = editTask?.startDate ?? DateTime.now();
    _endDate = editTask?.endDate ?? DateTime.now().add(const Duration(days: 30));
    _recurrenceType = editTask?.recurrenceType ?? RecurrenceType.daily;
    _selectedWeeklyDays = List.of(editTask?.weeklyDays ?? []);
    _selectedColor = editTask?.colorHex ?? _colorPalette.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  /// Persists the task to the database (INSERT or UPDATE).
  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      if (_recurrenceType == RecurrenceType.weekly && _selectedWeeklyDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one day for weekly recurrence')),
        );
        return;
      }

      final task = Task(
        id: widget.taskToEdit?.id,
        title: _titleController.text,
        startDate: _startDate,
        endDate: _endDate,
        recurrenceType: _recurrenceType,
        weeklyDays: _recurrenceType == RecurrenceType.weekly ? _selectedWeeklyDays : null,
        colorHex: _selectedColor,
      );

      if (widget.taskToEdit == null) {
        await DatabaseService.instance.insertTask(task);
      } else {
        await DatabaseService.instance.updateTask(task);
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
              const SizedBox(height: 24),
              
              // Color Selection Section
              const Text('Task Color', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colorPalette.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                                color: colorScheme.primary.withOpacity(0.4),
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
                      subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                      onTap: () => _selectDate(context, true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(DateFormat.yMMMd().format(_endDate)),
                      onTap: () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RecurrenceType>(
                value: _recurrenceType,
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
                onPressed: _saveTask,
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
