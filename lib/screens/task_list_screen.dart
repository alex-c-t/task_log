import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/preferences_provider.dart';
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
  String? _categoryFilter;

  static const List<String> _categories = [
    'Personal',
    'Work',
    'Health',
    'Home',
    'Finance',
    'Social',
    'Hobby',
  ];

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.addListener(_onDbChanged);
  }

  @override
  void dispose() {
    DatabaseService.instance.removeListener(_onDbChanged);
    super.dispose();
  }

  void _onDbChanged() {
    if (mounted) {
      setState(() {});
    }
  }

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

      // 3. Category Filter
      if (_categoryFilter != null && task.category != _categoryFilter) {
        return false;
      }

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
    final isPro = Provider.of<PreferencesProvider>(context).isProMode;
    return Column(
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              _buildFilterChip('Active'),
              const SizedBox(width: 8),
              _buildFilterChip('Completed'),
              const SizedBox(width: 8),
              _buildFilterChip('All'),
              if (isPro) ...[
                const SizedBox(width: 16),
                const VerticalDivider(width: 1),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('All Categories'),
                  selected: _categoryFilter == null,
                  onSelected: (selected) {
                    if (selected) setState(() => _categoryFilter = null);
                  },
                ),
                ..._categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: _categoryFilter == cat,
                    onSelected: (selected) {
                      setState(() => _categoryFilter = selected ? cat : null);
                    },
                  ),
                )),
              ],
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
              
              final allTasks = snapshot.data ?? [];
              final scheduledTasks = allTasks.where((t) => t.targetCompletions == null).toList();

              return _buildTaskList(scheduledTasks, isPro);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList(List<Task> tasks, bool isPro) {
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
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      decoration: isExpiredOrFinished ? TextDecoration.lineThrough : null,
                      decorationColor: isExpiredOrFinished ? Colors.grey[800] : null,
                      decorationThickness: 2.0,
                      color: isExpiredOrFinished ? Colors.grey : null,
                    ),
                  ),
                ),
                FutureBuilder<int>(
                  future: DatabaseService.instance.getTaskStreak(task),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data! > 0) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 2),
                          Text(
                            '${snapshot.data}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
            subtitle: Text(
              '${(isPro && task.category != null) ? "[${task.category}] " : ""}${_formatRecurrence(task)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
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

    final n = task.recurrenceInterval;

    if (task.recurrenceType == RecurrenceType.daily) {
      if (task.endDate != null &&
          task.startDate.year == task.endDate!.year && 
          task.startDate.month == task.endDate!.month &&
          task.startDate.day == task.endDate!.day) {
        return 'One-time';
      }
      return n > 1 ? 'Every $n days' : 'Daily';
    }

    if (task.recurrenceType == RecurrenceType.weekly) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        if (task.weeklyDays == null || task.weeklyDays!.isEmpty) {
          return n > 1 ? 'Every $n weeks' : 'Weekly';
        }
        
        final sorted = List<int>.from(task.weeklyDays!)..sort();
        final labels = sorted.map((d) => days[(d - 1) % 7]).join(', ');
        final prefix = n > 1 ? 'Every $n weeks' : 'Weekly';
        return '$prefix ($labels)';
    }

    if (task.recurrenceType == RecurrenceType.monthly) {
      return n > 1 ? 'Every $n months' : 'Monthly';
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
