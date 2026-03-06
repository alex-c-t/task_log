import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => TaskListScreenState();
}

class TaskListScreenState extends State<TaskListScreen> {
  DateTime _focusedMonth = DateTime.now();
  String _filter = 'Active'; // Active, Completed, All

  void resetToToday() {
    setState(() {
      _focusedMonth = DateTime.now();
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  Future<List<Task>> _loadTasks() async {
    final allTasks = await DatabaseService.instance.getAllTasks();
    
    // Month Bounds
    final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final monthEnd = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0, 23, 59, 59);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return allTasks.where((task) {
      // 1. Pagination Filter: Must overlap with focused month
      final endsAfterStart = task.endDate == null || task.endDate!.isAfter(monthStart);
      final overlapsMonth = task.startDate.isBefore(monthEnd) && endsAfterStart;
      if (!overlapsMonth) return false;

      // 2. Chip Filter using "Lifecycle" logic
      // Active: definition is still valid (endDate >= today or null)
      // Completed: definition is expired (endDate < today) or finished goal
      
      if (_filter == 'All') return true;

      bool isExpiredOrFinished = false;
      if (task.targetCompletions != null) {
        isExpiredOrFinished = task.isFinished == 1;
      } else if (task.endDate != null) {
        final taskEnd = DateTime(task.endDate!.year, task.endDate!.month, task.endDate!.day, 23, 59, 59);
        isExpiredOrFinished = taskEnd.isBefore(today);
      }

      if (_filter == 'Active') return !isExpiredOrFinished;
      if (_filter == 'Completed') return isExpiredOrFinished;

      return true;
    }).toList();
  }

  void _navigateToDetail(Task task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(task: task),
      ),
    );
    setState(() {}); // Refresh list on return
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Month Pagination Controls moved from AppBar to Body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat.yMMM().format(_focusedMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildFilterChip('Active'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed'),
                const SizedBox(width: 8),
                _buildFilterChip('All'),
              ],
            ),
          ),

          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Scheduled Tasks'),
              Tab(text: 'Target Goals'),
            ],
          ),
          
          Expanded(
            child: FutureBuilder<List<Task>>(
              future: _loadTasks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final allTasks = snapshot.data ?? [];
                final scheduledTasks = allTasks.where((t) => t.targetCompletions == null).toList();
                final targetGoals = allTasks.where((t) => t.targetCompletions != null).toList();

                return TabBarView(
                  children: [
                    _buildTaskList(scheduledTasks),
                    _buildTaskList(targetGoals),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks found'));
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        bool isExpiredOrFinished = false;
        if (task.targetCompletions != null) {
          isExpiredOrFinished = task.isFinished == 1;
        } else if (task.endDate != null) {
          final taskEnd = DateTime(task.endDate!.year, task.endDate!.month, task.endDate!.day, 23, 59, 59);
          isExpiredOrFinished = taskEnd.isBefore(today);
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: HexColor.fromHex(task.colorHex),
              radius: 12,
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: isExpiredOrFinished ? TextDecoration.lineThrough : null,
                decorationColor: isExpiredOrFinished ? Colors.grey[800] : null,
                decorationThickness: 2.0,
                color: isExpiredOrFinished ? Colors.grey : null,
              ),
            ),
            subtitle: Text(_formatRecurrence(task)),
            onTap: () => _navigateToDetail(task),
            trailing: const Icon(Icons.chevron_right, size: 20),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    return FilterChip(
        label: Text(label),
        selected: _filter == label,
        onSelected: (selected) {
            if (selected) setState(() => _filter = label);
        },
    );
  }

  String _formatRecurrence(Task task) {
    if (task.targetCompletions != null) {
      if (task.isFinished == 1) return 'Goal Completed (${task.targetCompletions} days)';
      return 'Target Goal: ${task.targetCompletions} completions';
    }

    if (task.recurrenceType == RecurrenceType.daily) {
      // Check if effectively one-time
      if (task.endDate != null &&
          task.startDate.year == task.endDate!.year && 
          task.startDate.month == task.endDate!.month &&
          task.startDate.day == task.endDate!.day) {
        return 'One-time';
      }
      return 'Daily';
    }
    if (task.recurrenceType == RecurrenceType.weekly) {
        // e.g. "Weekly (Mon, Wed)"
        // This requires mapping int to String.
        // Assuming WeekStart is handled elsewhere or standard, 1=Mon, 7=Sun.
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        if (task.weeklyDays == null || task.weeklyDays!.isEmpty) return 'Weekly';
        
        // Sort days
        final sorted = List<int>.from(task.weeklyDays!)..sort();
        final labels = sorted.map((d) => days[(d - 1) % 7]).join(', ');
        return 'Weekly ($labels)';
    }
    return '';
  }
}

// Helper for Color
extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
