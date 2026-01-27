
class TaskCompletion {
  final int? id;
  final int taskId;
  final String date; // YYYY-MM-DD
  final bool isCompleted;

  TaskCompletion({
    this.id,
    required this.taskId,
    required this.date,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'date': date,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory TaskCompletion.fromMap(Map<String, dynamic> map) {
    return TaskCompletion(
      id: map['id'],
      taskId: map['taskId'],
      date: map['date'],
      isCompleted: map['isCompleted'] == 1,
    );
  }
}
