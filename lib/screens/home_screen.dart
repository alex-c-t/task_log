
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/task_completion.dart';
import '../services/database_service.dart';
import '../utils/recurrence_helper.dart';
import '../widgets/task_tile.dart';
import 'add_task_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _currentDate = DateTime.now();
  List<Task> _allTasks = [];
  Map<int, bool> _completionStatus = {}; // taskId -> isCompleted

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Fetch all tasks (Intent-based API - Fix 2)
    final tasks = await DatabaseService.instance.getAllTasks();
    if (mounted) {
      setState(() {
        _allTasks = tasks;
      });
      // 2. Fetch completions for current date
      _loadCompletionsForDate(_currentDate);
    }
  }

  Future<void> _loadCompletionsForDate(DateTime date) async {
    final completions = await DatabaseService.instance.getCompletionsForDate(date);
    if (mounted) {
      setState(() {
        _completionStatus = {
          for (var c in completions) c.taskId: c.isCompleted,
        };
      });
    }
  }

  void _changeDate(int days) {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: days));
      _completionStatus.clear(); // Clear to prevent stale state flicker
    });
    _loadCompletionsForDate(_currentDate);
  }

  void _toggleTask(int taskId) async {
    // Optimistic UI update
    final currentStatus = _completionStatus[taskId] ?? false;
    setState(() {
      _completionStatus[taskId] = !currentStatus;
    });

    try {
      await DatabaseService.instance.toggleTaskCompletion(taskId, _currentDate);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _completionStatus[taskId] = currentStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter tasks active on _currentDate
    final activeTasks = _allTasks.where((task) {
      return RecurrenceHelper.isTaskActiveOnDate(task, _currentDate);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTaskScreen()),
              );
              _loadData(); // Refresh tasks when returning
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Helper Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _changeDate(-1)),
                Text(
                  DateFormat.yMMMEd().format(_currentDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _changeDate(1)),
              ],
            ),
          ),
          
          Expanded(
            child: activeTasks.isEmpty
                ? const Center(child: Text('No tasks for this day.'))
                : ListView.builder(
                    itemCount: activeTasks.length,
                    itemBuilder: (context, index) {
                      final task = activeTasks[index];
                      final isCompleted = _completionStatus[task.id] ?? false;
                      return TaskTile(
                        title: task.title,
                        isCompleted: isCompleted,
                        onToggle: () => _toggleTask(task.id!),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
