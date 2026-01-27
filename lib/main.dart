
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

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
        colorSchemeSeed: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}
