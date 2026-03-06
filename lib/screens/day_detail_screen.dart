import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';
import '../models/task_comment.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../services/database_service.dart';
import '../utils/recurrence_helper.dart';
import '../widgets/task_tile.dart';
import 'task_detail_screen.dart';

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
  final int? highlightTaskId;

  const DayDetailScreen({
    super.key,
    required this.selectedDate,
    this.onDateChanged,
    this.highlightTaskId,
  });

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> with WidgetsBindingObserver {
  late DateTime _currentDate;
  List<Task> _allTasks = [];
  Map<int, bool> _completionStatus = {}; // taskId -> isCompleted
  Map<int, TaskComment> _commentsMap = {}; // taskId -> TaskComment
  Map<int, int> _streaks = {}; // taskId -> streak
  List<SubTask> _allSubTasks = [];
  Map<int, bool> _subTaskCompletions = {}; // subtaskId -> isCompleted
  int? _highlightTaskId;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _currentDate = widget.selectedDate;
    _highlightTaskId = widget.highlightTaskId;
    _startHighlightTimer();
    
    _loadData();
    DatabaseService.instance.addListener(_loadData);
    WidgetsBinding.instance.addObserver(this);
  }

  void _startHighlightTimer() {
    if (_highlightTaskId != null) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _highlightTaskId = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    DatabaseService.instance.removeListener(_loadData);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant DayDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _currentDate = widget.selectedDate;
      _loadData();
    }
    if (widget.highlightTaskId != oldWidget.highlightTaskId) {
      setState(() {
        _highlightTaskId = widget.highlightTaskId;
      });
      _startHighlightTimer();
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
    final subCompletions = await DatabaseService.instance.getSubTaskCompletionsForDate(date);
    final comments = await DatabaseService.instance.getCommentsMapForDate(date);
    
    if (mounted) {
      setState(() {
        _completionStatus = {
          for (var c in completions) c.taskId: c.isCompleted,
        };
        _subTaskCompletions = {
          for (var id in subCompletions.keys) id: subCompletions[id]!.isCompleted,
        };
        _commentsMap = comments;
      });

      // Fetch all relevant subtask definitions
      List<SubTask> allSubs = [];
      for (var task in _allTasks) {
        final subs = await DatabaseService.instance.getSubTasksForTask(task.id!);
        allSubs.addAll(subs);
      }

      // Calculate streaks for visible tasks
      final Map<int, int> streaks = {};
      final activeTasks = _allTasks.where((task) {
        final isCompleted = _completionStatus[task.id] ?? false;
        return RecurrenceHelper.isTaskActiveOnDate(task, date, isCompletedOnDate: isCompleted);
      });

      for (var task in activeTasks) {
        streaks[task.id!] = await DatabaseService.instance.getTaskStreak(task);
      }

      if (mounted) {
        setState(() {
          _allSubTasks = allSubs;
          _streaks = streaks;
        });
      }
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

  Future<void> _toggleSubTask(int subtaskId) async {
    HapticFeedback.lightImpact();

    final current = _subTaskCompletions[subtaskId] ?? false;
    setState(() {
      _subTaskCompletions[subtaskId] = !current;
    });

    try {
      await DatabaseService.instance.toggleSubTaskCompletion(subtaskId, _currentDate);
    } catch (e) {
      if (mounted) {
        setState(() {
          _subTaskCompletions[subtaskId] = current;
        });
      }
    }
  }

  Future<void> _toggleTask(int taskId) async {
    // Haptic feedback
    HapticFeedback.lightImpact();

    // Optimistic UI update
    final currentStatus = _completionStatus[taskId] ?? false;
    setState(() {
      _completionStatus[taskId] = !currentStatus;
    });

    try {
      final goalJustFinished = await DatabaseService.instance.toggleTaskCompletion(taskId, _currentDate);
      if (goalJustFinished) {
        _confettiController.play();
      }
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
      final isCompleted = _completionStatus[task.id] ?? false;
      return RecurrenceHelper.isTaskActiveOnDate(task, _currentDate, isCompletedOnDate: isCompleted);
    }).toList();

    return Stack(
      children: [
        Column(
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
                    
                    final subTasks = _allSubTasks.where((s) => s.taskId == task.id).toList();
                    
                    return TaskTile(
                      title: task.title,
                      isCompleted: isCompleted,
                      isHighlighted: task.id == _highlightTaskId,
                      comment: comment?.text,
                      streak: _streaks[task.id] ?? 0,
                      category: task.category,
                      subTasks: subTasks,
                      subTaskCompletions: _subTaskCompletions,
                      onSubTaskToggle: _toggleSubTask,
                      onCommentTap: () => _handleComment(task),
                      onToggle: () => _toggleTask(task.id!),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskDetailScreen(task: task),
                          ),
                        );
                        _loadData(); // Refresh in case of edits/deletes
                      },
                    );
                  },
                ),
        ),
      ],
    ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
          ),
        ),
      ],
    );
  }
}
