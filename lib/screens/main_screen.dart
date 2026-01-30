import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'day_detail_screen.dart';
import 'task_list_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';

/// The main container screen for the app.
/// Implements Hybrid Navigation:
/// - **BottomNavigationBar**: For primary filtered views (Calendar, Today, Tasks).
/// - **Drawer**: For utility views (Settings, About).
class MainScreen extends StatefulWidget {
  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Primary Tab Views
  final List<Widget> _pages = [
    const CalendarScreen(),
    // "Today" is a DayDetailScreen for DateTime.now()
    DayDetailScreen(selectedDate: DateTime.now()),
    const TaskListScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
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
    // Note: DayDetailScreen has its own Scaffold/AppBar, so we might need to be careful.
    // However, usually putting a Scaffold inside a Scaffold body works but the inner appbar stays.
    // For CalendarScreen, it also has a Scaffold.
    // Ideally, top-level Scaffold handles the bottom bar, and children are just the body content.
    // But our existing screens have Scaffolds.
    // For this generic navigation wrapper, we can rely on the fact that existing screens
    // are self-contained. The BottomNavigationBar remains visible only if we are at this level.
    //
    // WAIT: If we navigate to CalendarScreen which returns a Scaffold, the BottomBar from THIS Scaffold
    // might be obscured or the nesting might be weird.
    // A common pattern with existing self-contained screens is to use an IndexedStack.
    // BUT since our children have Scaffolds, we should probably strip them or wrap them differently.
    //
    // GIVEN the existing codebase constraint (minimizing refactor of existing screens),
    // we will adopt the approach where `MainScreen` is the persistent parent.
    // If child screens have AppBars, they will show up.
    
    return Scaffold(
      key: MainScreen.scaffoldKey,
      // We do NOT provide an AppBar here because each child page (Calendar, DayDetail) provides one.
      // This allows "Today" to show "Today, Oct 12" and Calendar to show "October 2023" in the header.
      
      // Drawer is available at this root level. 
      // To access it from Child screens that have their own AppBar, 
      // the child AppBar should conceptually have a Menu icon if we want consistent access.
      // 
      // However, Child screens like `CalendarScreen` rely on `Scaffold`. If we nest them, 
      // the `Scaffold.drawer` of the PARENT is not automagically accessible via the child's hamburger 
      // unless we pass the drawer down or use a global key.
      //
      // SIMPLIFICATION FOR PHASE 2.7:
      // We will add the Drawer to THIS Scaffold.
      // Accessing it: 
      // 1. Edge Swipe (Built-in).
      // 2. We can modify child screens to show a Menu button, OR we add a small floating button?
      // No, let's stick to standard behavior. Detailed pages might just use back buttons.
      // But CalendarScreen is a root view.
      //
      // Let's implement the Drawer here.
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
                   // App Logo Placeholder if needed
                   const Icon(Icons.task_alt, size: 48),
                   const SizedBox(height: 12),
                   Text(
                    'Task Log',
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
        children: _pages,
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
