import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'main_screen.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import 'add_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  DateTime _focusedMonth = DateTime.now();
  String _filter = 'Active'; // Active, Completed, All

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
      final overlapsMonth = task.startDate.isBefore(monthEnd) && task.endDate.isAfter(monthStart);
      if (!overlapsMonth) return false;

      // 2. Chip Filter using "Lifecycle" logic
      // Active: definition is still valid (endDate >= today)
      // Completed: definition is expired (endDate < today) - Roughly
      // Note: "Completed" usually implies "Done". For recurring tasks, "Expired" is a better term, 
      // but we stick to UI terms.
      
      if (_filter == 'All') return true;

      // Normalize task end date to end of day for comparison
      final taskEnd = DateTime(task.endDate.year, task.endDate.month, task.endDate.day, 23, 59, 59);
      final isExpired = taskEnd.isBefore(today);

      if (_filter == 'Active') return !isExpired;
      if (_filter == 'Completed') return isExpired;

      return true;
    }).toList();
  }

  void _navigateToEdit(Task task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTaskScreen(taskToEdit: task),
      ),
    );
    setState(() {}); // Refresh list on return
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => MainScreen.scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        actions: [
            // Month Pagination Controls in AppBar
            IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
            ),
            Text(DateFormat.yMMM().format(_focusedMonth), style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
            ),
            const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
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
          
          Expanded(
            child: FutureBuilder<List<Task>>(
              future: _loadTasks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No tasks found'));
                }

                final tasks = snapshot.data!;
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
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
                                decoration: _filter == 'Completed' ? TextDecoration.lineThrough : null,
                                color: _filter == 'Completed' ? Colors.grey : null,
                            ),
                        ),
                        subtitle: Text(_formatRecurrence(task)),
                        onTap: () => _navigateToEdit(task),
                        trailing: const Icon(Icons.edit, size: 20),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
            await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddTaskScreen()),
            );
            setState(() {});
        },
        child: const Icon(Icons.add),
      ),
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
    if (task.recurrenceType == RecurrenceType.daily) {
      // Check if effectively one-time
      if (task.startDate.year == task.endDate.year && 
          task.startDate.month == task.endDate.month &&
          task.startDate.day == task.endDate.day) {
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
