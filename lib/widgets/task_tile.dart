
import 'package:flutter/material.dart';

class TaskTile extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final String? comment;
  final VoidCallback? onCommentTap;

  const TaskTile({
    Key? key,
    required this.title,
    required this.isCompleted,
    required this.onToggle,
    this.onEdit,
    this.comment,
    this.onCommentTap,
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
        subtitle: GestureDetector(
          onTap: onCommentTap,
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
            child: comment != null && comment!.isNotEmpty
                ? Text(
                    comment!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  )
                : Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Add comment',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
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
