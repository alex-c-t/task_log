
class SubTask {
  final int? id;
  final int taskId;
  final String title;
  final bool isDeleted;

  SubTask({
    this.id,
    required this.taskId,
    required this.title,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'title': title,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'],
      taskId: map['taskId'],
      title: map['title'],
      isDeleted: map['isDeleted'] == 1,
    );
  }
}

class SubTaskCompletion {
  final int? id;
  final int subtaskId;
  final String date; // YYYY-MM-DD
  final bool isCompleted;
  final bool isDeleted;

  SubTaskCompletion({
    this.id,
    required this.subtaskId,
    required this.date,
    this.isCompleted = false,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subtaskId': subtaskId,
      'date': date,
      'isCompleted': isCompleted ? 1 : 0,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory SubTaskCompletion.fromMap(Map<String, dynamic> map) {
    return SubTaskCompletion(
      id: map['id'],
      subtaskId: map['subtaskId'],
      date: map['date'],
      isCompleted: map['isCompleted'] == 1,
      isDeleted: map['isDeleted'] == 1,
    );
  }
}
