
import 'package:flutter/material.dart';
import 'screens/calendar_screen.dart';

/// The root widget of the Task Log application.
///
/// This widget initializes the [MaterialApp] and defines the theme
/// and the initial screen of the app, which is the [CalendarScreen].
void main() {
  runApp(const TaskLogApp());
}

class TaskLogApp extends StatelessWidget {
  const TaskLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Log',
      theme: ThemeData(
        useMaterial3: true,
        // Using a soft color scheme as per Phase 1 standards.
        colorSchemeSeed: Colors.blue,
      ),
      // The CalendarScreen is now the entry point as per Phase 2A requirements.
      home: const CalendarScreen(),
    );
  }
}
