
import 'package:uuid/uuid.dart';
import 'sync_entity_mixin.dart';

class TaskCompletion with SyncEntity {
  final int? id;
  final int taskId;
  final String date; // YYYY-MM-DD
  final bool isCompleted;
  
  @override
  String uuid;
  @override
  DateTime createdAt;
  @override
  DateTime updatedAt;

  TaskCompletion({
    this.id,
    required this.taskId,
    required this.date,
    required this.isCompleted,
    String? uuid,
    DateTime? createdAt,
    DateTime? updatedAt,
    int isDeleted = 0,
  }) : uuid = uuid ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now().toUtc(),
       updatedAt = updatedAt ?? DateTime.now().toUtc() {
    this.isDeleted = isDeleted;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'date': date,
      'isCompleted': isCompleted ? 1 : 0,
      ...toMapSync(),
    };
  }

  factory TaskCompletion.fromMap(Map<String, dynamic> map) {
    return TaskCompletion(
      id: map['id'],
      taskId: map['taskId'],
      date: map['date'],
      isCompleted: map['isCompleted'] == 1,
      uuid: map['uuid'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      isDeleted: map['isDeleted'] ?? 0,
    );
  }
}
