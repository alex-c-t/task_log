import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'day_detail_screen.dart';
import 'task_list_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'add_task_screen.dart';

/// The main container screen for the app.
/// Implements Hybrid Navigation:
/// - **BottomNavigationBar**: For primary filtered views (Calendar, Today, Tasks).
/// - **Drawer**: For utility views (Settings, About).
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  DateTime _selectedDate = DateTime.now();

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onDaySelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _currentIndex = 1; // Switch to "Detail" tab
    });
  }

  void _navigateToDrawerItem(Widget screen) {
    Navigator.of(context).pop(); // Close Drawer
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      CalendarScreen(onDateSelected: _onDaySelected),
      DayDetailScreen(selectedDate: _selectedDate),
      const TaskListScreen(),
    ];

    String title = 'Tasklet';
    if (_currentIndex == 1) {
      // Logic for DayDetail title can be here or based on _selectedDate
      title = 'Task Log'; 
    } else if (_currentIndex == 2) {
      title = 'Tasks';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_currentIndex == 1 || _currentIndex == 2)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final date = _currentIndex == 1 ? _selectedDate : DateTime.now();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AddTaskScreen(initialStartDate: date)),
                );
                // After returning, we might need a way to refresh if we weren't using streams
                // Since child widgets load data in initState/didUpdateWidget, 
                // and IndexedStack keeps them alive, we might need to trigger a reload.
                // However, switching tabs or re-building MainScreen might help.
                setState(() {}); 
              },
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.task_alt, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Tasklet',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => _navigateToDrawerItem(const SettingsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () => _navigateToDrawerItem(const AboutScreen()),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Tasks',
          ),
        ],
      ),
    );
  }
}
