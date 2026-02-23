import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey<CalendarScreenState>();
  final GlobalKey<TaskListScreenState> _taskListKey = GlobalKey<TaskListScreenState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      // Handle double-tap
      if (index == 0) {
        _calendarKey.currentState?.resetToToday();
        _calendarKey.currentState?.refresh();
      } else if (index == 1) {
        setState(() {
          _selectedDate = DateTime.now();
        });
      } else if (index == 2) {
        _taskListKey.currentState?.resetToToday();
      }
    } else {
      setState(() {
        _currentIndex = index;
        // If user taps "Today" tab for the first time, sync to today
        if (index == 1) {
          _selectedDate = DateTime.now();
        }
      });
      // Refresh calendar when switching to it to show new changes
      if (index == 0) {
        _calendarKey.currentState?.refresh();
      }
    }
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
      CalendarScreen(key: _calendarKey, onDateSelected: _onDaySelected),
      DayDetailScreen(
        selectedDate: _selectedDate,
        onDateChanged: (date) => setState(() => _selectedDate = date),
      ),
      TaskListScreen(key: _taskListKey),
    ];

    String title = 'Tasklet';
    if (_currentIndex == 1) {
      title = DateFormat.yMMMd().format(_selectedDate);
    } else if (_currentIndex == 2) {
      title = 'Tasks';
    }

    return PopScope(
      canPop: false, // Handle pop manually for better tab/drawer control
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. Close drawer if open
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }

        // 2. Switch to Home Tab if not already there
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // 3. Finally allow exit if on Home Tab
        if (_currentIndex == 0) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(title),
          leading: _currentIndex != 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _onTabTapped(0),
                )
              : null, // Shows hamburger menu if null and drawer exists
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final date = _currentIndex == 1 ? _selectedDate : DateTime.now();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AddTaskScreen(initialStartDate: date)),
                );
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
      ),
    );
  }
}
