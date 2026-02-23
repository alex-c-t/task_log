import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_comment.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../utils/recurrence_helper.dart';
import '../widgets/task_tile.dart';
import 'add_task_screen.dart';

/// This screen allows users to:
/// 1. See all tasks active on the [selectedDate] based on recurrence rules.
/// 2. Toggle the completion status of these tasks.
/// 3. Navigate back to the calendar view.
/// 4. Edit or delete task definitions via the edit icon (✏️).
/// 
/// **Note**: Editing is only available here to ensure users manage tasks
/// in the context of the days they are active on. Deleting here removes
/// all history for that task definition.
class DayDetailScreen extends StatefulWidget {
  /// The date for which tasks are being displayed.
  final DateTime selectedDate;
  final Function(DateTime)? onDateChanged;

  const DayDetailScreen({
    super.key,
    required this.selectedDate,
    this.onDateChanged,
  });

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  late DateTime _currentDate;
  List<Task> _allTasks = [];
  Map<int, bool> _completionStatus = {}; // taskId -> isCompleted
  Map<int, TaskComment> _commentsMap = {}; // taskId -> TaskComment

  @override
  void initState() {
    super.initState();
    _currentDate = widget.selectedDate;
    _loadData();
  }

  @override
  void didUpdateWidget(covariant DayDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _currentDate = widget.selectedDate;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    // 1. Fetch all tasks (Intent-based API - Fix 2)
    final tasks = await DatabaseService.instance.getAllTasks();
    if (mounted) {
      setState(() {
        _allTasks = tasks;
      });
      // 2. Fetch completions & comments for current date
      _loadDayContext(_currentDate);
    }
  }

  Future<void> _loadDayContext(DateTime date) async {
    final completions = await DatabaseService.instance.getCompletionsForDate(date);
    final comments = await DatabaseService.instance.getCommentsMapForDate(date);
    
    if (mounted) {
      setState(() {
        _completionStatus = {
          for (var c in completions) c.taskId: c.isCompleted,
        };
        _commentsMap = comments;
      });
    }
  }

  void _changeDate(int days) {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: days));
      _completionStatus.clear(); // Clear to prevent stale state flicker
      _commentsMap.clear();
    });
    widget.onDateChanged?.call(_currentDate);
    _loadDayContext(_currentDate);
  }

  Future<void> _toggleTask(int taskId) async {
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

  Future<void> _handleComment(Task task) async {
    final existingComment = _commentsMap[task.id];
    final controller = TextEditingController(text: existingComment?.text ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existingComment == null ? 'Add Comment' : 'Edit Comment'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter comment...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final text = controller.text.trim();
                
                if (text.isEmpty) {
                  // Treat empty as delete
                  if (existingComment != null) {
                     await DatabaseService.instance.deleteComment(task.id!, _currentDate);
                  }
                } else {
                  // Upsert
                  await DatabaseService.instance.saveComment(task.id!, _currentDate, text);
                }
                
                // MANDATORY: Re-fetch source of truth
                _loadDayContext(_currentDate);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter tasks active on _currentDate
    final activeTasks = _allTasks.where((task) {
      return RecurrenceHelper.isTaskActiveOnDate(task, _currentDate);
    }).toList();

    return Column(
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
                    final comment = _commentsMap[task.id];
                    
                    return TaskTile(
                      title: task.title,
                      isCompleted: isCompleted,
                      comment: comment?.text,
                      onCommentTap: () => _handleComment(task),
                      onToggle: () => _toggleTask(task.id!),
                      onEdit: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTaskScreen(taskToEdit: task),
                          ),
                        );
                        _loadData(); // Refresh tasks
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
