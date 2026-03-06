
import 'package:flutter_test/flutter_test.dart';
import 'package:task_log/models/task.dart';
import 'package:task_log/utils/recurrence_helper.dart';

void main() {
  group('RecurrenceHelper Interval Tests', () {
    final baseDate = DateTime(2024, 1, 1); // Monday

    test('Daily recurrence with interval 2', () {
      final task = Task(
        title: 'Gym',
        startDate: baseDate,
        endDate: baseDate.add(const Duration(days: 10)),
        recurrenceType: RecurrenceType.daily,
        recurrenceInterval: 2,
        colorHex: '#000000',
        uuid: '1',
        createdAt: baseDate,
        updatedAt: baseDate,
      );

      // Jan 1: Active
      expect(RecurrenceHelper.isTaskActiveOnDate(task, baseDate), isTrue);
      // Jan 2: Inactive (interval 2)
      expect(RecurrenceHelper.isTaskActiveOnDate(task, baseDate.add(const Duration(days: 1))), isFalse);
      // Jan 3: Active
      expect(RecurrenceHelper.isTaskActiveOnDate(task, baseDate.add(const Duration(days: 2))), isTrue);
    });

    test('Weekly recurrence with interval 2 (Mon, Wed)', () {
      final task = Task(
        title: 'Course',
        startDate: baseDate,
        endDate: baseDate.add(const Duration(days: 30)),
        recurrenceType: RecurrenceType.weekly,
        recurrenceInterval: 2,
        weeklyDays: [1, 3], // Mon, Wed
        colorHex: '#000000',
        uuid: '2',
        createdAt: baseDate,
        updatedAt: baseDate,
      );

      // Week 1 Mon (Jan 1): Active
      expect(RecurrenceHelper.isTaskActiveOnDate(task, baseDate), isTrue);
      // Week 1 Wed (Jan 3): Active
      expect(RecurrenceHelper.isTaskActiveOnDate(task, baseDate.add(const Duration(days: 2))), isTrue);
      
      // Week 2 Mon (Jan 8): Inactive (Every 2 weeks)
      expect(RecurrenceHelper.isTaskActiveOnDate(task, baseDate.add(const Duration(days: 7))), isFalse);
      
      // Week 3 Mon (Jan 15): Active
      expect(RecurrenceHelper.isTaskActiveOnDate(task, baseDate.add(const Duration(days: 14))), isTrue);
    });

    test('Monthly recurrence with interval 3', () {
      final task = Task(
        title: 'Rent',
        startDate: baseDate,
        endDate: baseDate.add(const Duration(days: 200)),
        recurrenceType: RecurrenceType.monthly,
        recurrenceInterval: 3,
        colorHex: '#000000',
        uuid: '3',
        createdAt: baseDate,
        updatedAt: baseDate,
      );

      // Month 1 (Jan 1): Active
      expect(RecurrenceHelper.isTaskActiveOnDate(task, baseDate), isTrue);
      // Month 2 (Feb 1): Inactive
      expect(RecurrenceHelper.isTaskActiveOnDate(task, DateTime(2024, 2, 1)), isFalse);
      // Month 4 (Apr 1): Active (Jan -> Apr is 3 months)
      expect(RecurrenceHelper.isTaskActiveOnDate(task, DateTime(2024, 4, 1)), isTrue);
    });
  });

  group('Task Model Serialization', () {
    test('toMap and fromMap should preserve new fields', () {
      final now = DateTime.now();
      final task = Task(
        title: 'Test Task',
        startDate: now,
        recurrenceType: RecurrenceType.daily,
        recurrenceInterval: 5,
        category: 'Work',
        colorHex: '#FF5733',
        uuid: 'unique-id',
        createdAt: now,
        updatedAt: now,
      );

      final map = task.toMap();
      expect(map['category'], 'Work');
      expect(map['recurrenceInterval'], 5);

      final restored = Task.fromMap(map);
      expect(restored.category, 'Work');
      expect(restored.recurrenceInterval, 5);
      expect(restored.title, 'Test Task');
    });
  });
}
