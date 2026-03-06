import 'package:flutter/material.dart';
import '../models/subtask.dart';

class TaskTile extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final String? comment;
  final VoidCallback? onCommentTap;
  final bool isHighlighted;
  final int streak;
  final String? category;
  final List<SubTask> subTasks;
  final Map<int, bool> subTaskCompletions;
  final Function(int)? onSubTaskToggle;

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
    this.streak = 0,
    this.category,
    this.subTasks = const [],
    this.subTaskCompletions = const {},
    this.onSubTaskToggle,
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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Checkbox - isolated tap zone
              GestureDetector(
                onTap: onToggle,
                child: Checkbox(
                  value: isCompleted,
                  onChanged: (_) => onToggle(),
                ),
              ),
              const SizedBox(width: 8),
              // Title and subtitle - expands to fill space
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              color: isCompleted ? Colors.grey : null,
                            ),
                          ),
                        ),
                        if (streak > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 2),
                                Text(
                                  '$streak',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (category != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (comment != null && comment!.isNotEmpty)
                      GestureDetector(
                        onTap: onCommentTap,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            comment!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else if (onCommentTap != null)
                      GestureDetector(
                        onTap: onCommentTap,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Row(
                            children: [
                              Icon(Icons.add_comment_outlined, size: 14, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                'Add comment...',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (subTasks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...subTasks.map((sub) {
                        final subDone = subTaskCompletions[sub.id] ?? false;
                        return Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: GestureDetector(
                            onTap: () => onSubTaskToggle?.call(sub.id!),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: subDone,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (_) => onSubTaskToggle?.call(sub.id!),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    sub.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: subDone ? Colors.grey : Colors.grey[800],
                                      decoration: subDone ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              // Edit button - isolated tap zone
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                  tooltip: 'Edit Task',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
