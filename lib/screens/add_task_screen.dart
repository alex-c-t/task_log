
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  RecurrenceType _recurrenceType = RecurrenceType.daily;
  List<int> _selectedWeeklyDays = []; // 1=Mon, 7=Sun

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

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      if (_recurrenceType == RecurrenceType.weekly && _selectedWeeklyDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one day for weekly recurrence')),
        );
        return;
      }

      final task = Task(
        title: _titleController.text,
        startDate: _startDate,
        endDate: _endDate,
        recurrenceType: _recurrenceType,
        weeklyDays: _recurrenceType == RecurrenceType.weekly ? _selectedWeeklyDays : null,
      );

      await DatabaseService.instance.insertTask(task);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Task')),
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
                child: const Text('Save Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
