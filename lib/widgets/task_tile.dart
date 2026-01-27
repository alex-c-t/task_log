
import 'package:flutter/material.dart';

class TaskTile extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;

  const TaskTile({
    Key? key,
    required this.title,
    required this.isCompleted,
    required this.onToggle,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: CheckboxListTile(
        title: Text(
          title,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        value: isCompleted,
        onChanged: (_) => onToggle(),
        secondary: onEdit != null
            ? IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
                tooltip: 'Edit Task',
              )
            : null,
      ),
    );
  }
}
