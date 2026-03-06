import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../utils/recurrence_helper.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLoading = true;
  int _totalCompletions = 0;
  Map<DateTime, int> _heatmapData = {};
  Map<String, int> _categoryStats = {};
  Map<DateTime, double> _dailyScores = {};
  int _bestStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);

    final allTasks = await DatabaseService.instance.getAllTasks();
    final now = DateTime.now();
    
    int completionsCount = 0;
    Map<DateTime, int> heatmap = {};
    Map<String, int> catStats = {};
    Map<DateTime, double> scores = {};

    // 1. Heatmap & Daily Scores (Last 30 days for heatmap, last 7 for scores)
    for (int i = 0; i < 30; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayCompletions = await DatabaseService.instance.getCompletionsForDate(date);
      
      final completedThisDay = dayCompletions.where((c) => c.isCompleted).length;
      completionsCount += completedThisDay;
      heatmap[date] = completedThisDay;

      if (i < 7) {
        // Calculate potential active tasks for score
        int activeOnDay = 0;
        for (var task in allTasks) {
          final isCompleted = dayCompletions.any((c) => c.taskId == task.id && c.isCompleted);
          if (RecurrenceHelper.isTaskActiveOnDate(task, date, isCompletedOnDate: isCompleted)) {
            activeOnDay++;
          }
        }
        scores[date] = activeOnDay > 0 ? (completedThisDay / activeOnDay) : 0.0;
      }
    }

    // 2. Max Streak
    int maxStreak = 0;
    for (var task in allTasks) {
      final s = await DatabaseService.instance.getTaskStreak(task);
      if (s > maxStreak) maxStreak = s;
    }

    // 3. Category Stats
    for (var task in allTasks) {
      if (task.category != null) {
        catStats[task.category!] = (catStats[task.category!] ?? 0) + 1;
      }
    }

    if (mounted) {
      setState(() {
        _totalCompletions = completionsCount;
        _heatmapData = heatmap;
        _categoryStats = catStats;
        _dailyScores = scores;
        _bestStreak = maxStreak;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 24),
              const Text('Productivity Score (Last 7 Days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildScoreChart(),
              const SizedBox(height: 24),
              const Text('Activity Heatmap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildHeatmap(),
              const SizedBox(height: 24),
              const Text('Category Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildCategoryStats(),
              const SizedBox(height: 24),
              const Text('Achievements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildAchievements(),
            ],
          ),
    );
  }

  Widget _buildAchievements() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (_bestStreak >= 3) _achievementBadge('Consistent 3', Icons.bolt, Colors.amber),
        if (_bestStreak >= 7) _achievementBadge('Streak Master 7', Icons.local_fire_department, Colors.orange),
        if (_totalCompletions >= 10) _achievementBadge('Power User', Icons.star, Colors.blue),
        if (_totalCompletions >= 50) _achievementBadge('Elite', Icons.emoji_events, Colors.purple),
        if (_categoryStats.length >= 3) _achievementBadge('Balanced', Icons.pie_chart, Colors.teal),
        if (_totalCompletions == 0) _achievementBadge('Fresh Start', Icons.child_care, Colors.green),
      ],
    );
  }

  Widget _achievementBadge(String label, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            label, 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Last 30 Days', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('Completions', '$_totalCompletions'),
                _statItem('Best Streak', '🔥 $_bestStreak'),
                _statItem('Tasks', '${_categoryStats.values.isNotEmpty ? _categoryStats.values.reduce((a, b) => a + b) : 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildScoreChart() {
    final sortedDates = _dailyScores.keys.toList()..sort();
    
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: sortedDates.map((date) {
          final score = _dailyScores[date] ?? 0.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 25,
                height: 50 * score + 5, // At least 5px height
                decoration: BoxDecoration(
                  color: score > 0.8 ? Colors.green : (score > 0.4 ? Colors.orange : Colors.red),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(DateFormat.E().format(date).substring(0, 1), style: const TextStyle(fontSize: 10)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeatmap() {
    // A simple 7x5 or similar grid
    final dates = _heatmapData.keys.toList()..sort((a, b) => b.compareTo(a));
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: 28, // Last 4 weeks
        itemBuilder: (context, index) {
          if (index >= dates.length) return const SizedBox();
          final date = dates[index];
          final count = _heatmapData[date] ?? 0;
          
          Color color = Colors.grey[300]!;
          if (count > 0) color = Colors.green[200]!;
          if (count > 2) color = Colors.green[400]!;
          if (count > 4) color = Colors.green[700]!;

          return Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${date.day}', 
                style: TextStyle(
                  fontSize: 10, 
                  color: count > 3 ? Colors.white : Colors.black54
                )
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryStats() {
    if (_categoryStats.isEmpty) {
      return const Text('No data yet.', style: TextStyle(color: Colors.grey));
    }

    return Column(
      children: _categoryStats.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(width: 80, child: Text(entry.key, style: const TextStyle(fontSize: 14))),
              Expanded(
                child: LinearProgressIndicator(
                  value: entry.value / _categoryStats.values.reduce((a, b) => a > b ? a : b),
                  backgroundColor: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 12,
                ),
              ),
              const SizedBox(width: 12),
              Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
