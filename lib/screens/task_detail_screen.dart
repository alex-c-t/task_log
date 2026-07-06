import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../utils/recurrence_helper.dart';
import 'add_task_screen.dart';

/// A view-only screen that displays detailed information and statistics about a task.
///
/// Shows:
/// - Basic task information (title, dates, recurrence, color)
/// - Statistics (total occurrences, completed count, pending future count, completion %)
/// - Status (Active, Completed, Expired)
/// - Actions (Edit, Delete)
class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({
    super.key,
    required this.task,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Future<TaskStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _calculateStats();
  }

  Future<TaskStats> _calculateStats() async {
    final task = widget.task;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get all completions for this task
    final safeEndDate = task.endDate ?? DateTime(today.year + 10);
    final completions = await DatabaseService.instance.getCompletionsForRange(
      task.startDate,
      safeEndDate,
    );
    final completionMap = {
      for (var c in completions.where((c) => c.taskId == task.id))
        c.date: c.isCompleted
    };

    // Calculate all occurrence dates
    int totalOccurrences = 0;
    int completedCount = 0;
    int pendingFutureCount = 0;
    DateTime? firstOccurrence;
    DateTime? lastOccurrence;

    final current = DateTime(task.startDate.year, task.startDate.month, task.startDate.day);
    
    if (task.targetCompletions != null) {
      // Logic for Target Goal
      totalOccurrences = task.targetCompletions!;
      completedCount = completionMap.values.where((v) => v).length;
      pendingFutureCount = task.isFinished == 1 ? 0 : totalOccurrences - completedCount;
      
      final sortedDates = completionMap.keys.toList()..sort();
      if (sortedDates.isNotEmpty) {
        firstOccurrence = DateTime.parse(sortedDates.first);
        lastOccurrence = DateTime.parse(sortedDates.last);
      }
    } else {
      // Logic for Regular Scheduled Task
      final end = DateTime(task.endDate!.year, task.endDate!.month, task.endDate!.day);
          
      DateTime date = current;
      while (!date.isAfter(end)) {
        if (RecurrenceHelper.isTaskActiveOnDate(task, date)) {
          totalOccurrences++;
  
          firstOccurrence ??= date;
          lastOccurrence = date;
  
          final dateStr = date.toIso8601String().substring(0, 10);
          final isCompleted = completionMap[dateStr] ?? false;
  
          if (isCompleted) {
            completedCount++;
          } else if (date.isAfter(today)) {
            // Only count future incomplete tasks as pending
            pendingFutureCount++;
          }
        }
        date = date.add(const Duration(days: 1));
      }
    }

    final completionPercentage = totalOccurrences > 0
        ? (completedCount / totalOccurrences * 100).round()
        : 0;

    // Determine status
    TaskStatus status;
    if (task.targetCompletions != null) {
      // Status for target goal
      if (task.isFinished == 1) {
        status = TaskStatus.completed;
      } else {
        status = TaskStatus.active;
      }
    } else {
      // Status for scheduled task
      final safeEndDate = task.endDate!;
      final end = DateTime(safeEndDate.year, safeEndDate.month, safeEndDate.day);
      if (today.isAfter(end)) {
        status = TaskStatus.expired;
      } else if (completedCount == totalOccurrences && totalOccurrences > 0) {
        status = TaskStatus.completed;
      } else {
        status = TaskStatus.active;
      }
    }
    return TaskStats(
      totalOccurrences: totalOccurrences,
      completedCount: completedCount,
      pendingFutureCount: pendingFutureCount,
      completionPercentage: completionPercentage,
      firstOccurrence: firstOccurrence,
      lastOccurrence: lastOccurrence,
      status: status,
    );
  }

  Future<void> _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text(
          'Are you sure you want to delete this task? All completion history will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await DatabaseService.instance.deleteTask(widget.task.id!);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final color = _parseHexColor(task.colorHex);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Task',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTaskScreen(taskToEdit: task),
                ),
              );
              // Refresh stats after edit
              setState(() {
                _statsFuture = _calculateStats();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Task',
            onPressed: _deleteTask,
          ),
        ],
      ),
      body: FutureBuilder<TaskStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stats = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task Title with Color
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          task.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Basic Information Section
                _SectionHeader(title: 'Basic Information'),
                const SizedBox(height: 8),
                _InfoCard(
                  children: [
                    _InfoRow(
                      label: 'Start Date',
                      value: DateFormat.yMMMd().format(task.startDate),
                    ),
                    if (task.endDate != null) ...[
                      const Divider(),
                      _InfoRow(
                        label: 'End Date',
                        value: DateFormat.yMMMd().format(task.endDate!),
                      ),
                    ],
                    const Divider(),
                    _InfoRow(
                      label: 'Recurrence',
                      value: _getRecurrenceText(task),
                    ),
                    if (task.weeklyDays != null && task.weeklyDays!.isNotEmpty) ...[
                      const Divider(),
                      _InfoRow(
                        label: 'Weekly Days',
                        value: _getWeeklyDaysText(task.weeklyDays!),
                      ),
                    ],
                    if (task.reminderTime != null) ...[
                      const Divider(),
                      _InfoRow(
                        label: 'Reminder Time',
                        value: task.reminderTime!,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // Statistics Section
                _SectionHeader(title: 'Statistics'),
                const SizedBox(height: 8),
                _InfoCard(
                  children: [
                    _InfoRow(
                      label: 'Total Occurrences',
                      value: stats.totalOccurrences.toString(),
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Completed',
                      value: stats.completedCount.toString(),
                      valueColor: Colors.green,
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Pending (Future)',
                      value: stats.pendingFutureCount.toString(),
                      valueColor: Colors.orange,
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Completion',
                      value: '${stats.completionPercentage}%',
                      trailing: LinearProgressIndicator(
                        value: stats.completionPercentage / 100,
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          stats.completionPercentage >= 80
                              ? Colors.green
                              : stats.completionPercentage >= 50
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ),
                    if (stats.firstOccurrence != null) ...[
                      const Divider(),
                      _InfoRow(
                        label: 'First Occurrence',
                        value: DateFormat.yMMMd().format(stats.firstOccurrence!),
                      ),
                    ],
                    if (stats.lastOccurrence != null) ...[
                      const Divider(),
                      _InfoRow(
                        label: 'Last Occurrence',
                        value: DateFormat.yMMMd().format(stats.lastOccurrence!),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // Status Section
                _SectionHeader(title: 'Status'),
                const SizedBox(height: 8),
                _InfoCard(
                  children: [
                    _StatusChip(status: stats.status),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getRecurrenceText(Task task) {
    switch (task.recurrenceType) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
    }
  }

  String _getWeeklyDaysText(List<int> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => dayNames[d - 1]).join(', ');
  }

  Color _parseHexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: trailing != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: valueColor,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                trailing!,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: valueColor,
                      ),
                ),
              ],
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String text;

    switch (status) {
      case TaskStatus.active:
        backgroundColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue;
        icon = Icons.play_circle_outline;
        text = 'Active';
        break;
      case TaskStatus.completed:
        backgroundColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green;
        icon = Icons.check_circle_outline;
        text = 'Completed';
        break;
      case TaskStatus.expired:
        backgroundColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey;
        icon = Icons.schedule;
        text = 'Expired';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

enum TaskStatus {
  active,
  completed,
  expired,
}

class TaskStats {
  final int totalOccurrences;
  final int completedCount;
  final int pendingFutureCount;
  final int completionPercentage;
  final DateTime? firstOccurrence;
  final DateTime? lastOccurrence;
  final TaskStatus status;

  TaskStats({
    required this.totalOccurrences,
    required this.completedCount,
    required this.pendingFutureCount,
    required this.completionPercentage,
    this.firstOccurrence,
    this.lastOccurrence,
    required this.status,
  });
}
