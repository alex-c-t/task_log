import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import 'task_detail_screen.dart';
import 'task_list_screen.dart' show HexColor;

class GoalsListScreen extends StatefulWidget {
  const GoalsListScreen({super.key});

  @override
  State<GoalsListScreen> createState() => GoalsListScreenState();
}

class GoalsListScreenState extends State<GoalsListScreen> {
  String _filter = 'Active'; // Active, Completed, All

  void resetToToday() {
    setState(() {});
  }

  Future<List<Task>> _loadGoals() async {
    final allTasks = await DatabaseService.instance.getAllTasks();
    
    return allTasks.where((task) {
      if (task.targetCompletions == null) return false;

      bool isFinished = task.isFinished == 1;

      if (_filter == 'All') return true;
      if (_filter == 'Active') return !isFinished;
      if (_filter == 'Completed') return isFinished;

      return true;
    }).toList();
  }

  void _navigateToDetail(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(task: task),
      ),
    );
    setState(() {}); // Refresh list on return
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

  @override
  Widget build(BuildContext context) {
    return Column(
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
            future: _loadGoals(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No goals found'));
              }

              final goals = snapshot.data!;
              return ListView.builder(
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];

                  return _GoalCard(
                    goal: goal,
                    onTap: () => _navigateToDetail(goal),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatefulWidget {
  final Task goal;
  final VoidCallback onTap;

  const _GoalCard({required this.goal, required this.onTap});

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void didUpdateWidget(covariant _GoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goal.id != oldWidget.goal.id) {
      _loadProgress();
    }
  }

  Future<void> _loadProgress() async {
    final completions = await DatabaseService.instance.getCompletionsForRange(
      widget.goal.startDate,
      DateTime(2099),
    );
    final count = completions.where((c) => c.taskId == widget.goal.id && c.isCompleted).length;
    if (mounted) {
      setState(() {
        _completedCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    bool isFinished = goal.isFinished == 1;
    final target = goal.targetCompletions!;
    final progress = target > 0 ? _completedCount / target : 0.0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: HexColor.fromHex(goal.colorHex),
                    radius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: isFinished ? TextDecoration.lineThrough : null,
                        color: isFinished ? Colors.grey : null,
                      ),
                    ),
                  ),
                  if (isFinished)
                    const Icon(Icons.check_circle, color: Colors.green)
                  else
                    const Icon(Icons.flag_outlined, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFinished ? 'Goal Completed!' : 'Progress',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$_completedCount / $target',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isFinished ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFinished ? Colors.green : HexColor.fromHex(goal.colorHex)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
