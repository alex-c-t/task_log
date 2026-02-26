
import 'package:flutter/material.dart';

class TaskTile extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final String? comment;
  final VoidCallback? onCommentTap;
  final bool isHighlighted;

  const TaskTile({
    super.key,
    required this.title,
    required this.isCompleted,
    required this.onToggle,
    this.onEdit,
    this.onTap,
    this.comment,
    this.onCommentTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: isHighlighted ? theme.colorScheme.primaryContainer : null,
      margin: isHighlighted ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8) : const EdgeInsets.all(4),
      elevation: isHighlighted ? 4 : 1,
      shape: isHighlighted
        ? RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.primary, width: 3),
            borderRadius: BorderRadius.circular(12),
          )
        : null,
      child: ListTile(
        leading: Checkbox(
          value: isCompleted,
          onChanged: (_) => onToggle(),
        ),
        title: InkWell(
          onTap: onTap,
          child: Text(
            title,
            style: TextStyle(
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: isCompleted ? Colors.grey[800] : null,
              decorationThickness: 2.0,
              color: isCompleted ? Colors.grey : null,
            ),
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
        trailing: onEdit != null
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
