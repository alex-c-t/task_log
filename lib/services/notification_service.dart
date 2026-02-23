
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/task.dart';
import '../services/database_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationService._();

  Future<void> init() async {
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'task_category',
          actions: [
            DarwinNotificationAction.plain('mark_done', 'Mark as Done'),
          ],
        ),
      ],
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  static void _onNotificationResponse(NotificationResponse response) async {
    if (response.actionId == 'mark_done') {
      final payload = response.payload;
      if (payload != null) {
        final taskId = int.tryParse(payload);
        if (taskId != null) {
          try {
            await DatabaseService.instance.toggleTaskCompletion(taskId, DateTime.now());
          } catch (e) {
            // Log or handle error
          }
        }
      }
    }
  }

  /// Updates the reminder state based on whether the task is completed today.
  Future<void> updateTaskReminderState(Task task) async {
    if (task.reminderTime == null || task.id == null) {
      await cancelReminder(task.id ?? -1);
      return;
    }

    // Check if task is completed today
    final completions = await DatabaseService.instance.getCompletionsForDate(DateTime.now());
    final isCompletedToday = completions.any((c) => c.taskId == task.id && c.isCompleted);

    if (isCompletedToday) {
      // If completed today, cancel today's notification.
      // We schedule the next one for tomorrow to ensure it doesn't fire again today.
      await _scheduleForNextOccurrence(task, forceTomorrow: true);
    } else {
      // If not completed, schedule for today (if time not passed) or tomorrow.
      await _scheduleForNextOccurrence(task, forceTomorrow: false);
    }
  }

  Future<void> _scheduleForNextOccurrence(Task task, {required bool forceTomorrow}) async {
    final parts = task.reminderTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (forceTomorrow || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    print('NOTIFICATION_DEBUG: Scheduling "${task.title}" for $scheduledDate (Local Now: $now)');

    await _notificationsPlugin.zonedSchedule(
      task.id!,
      'Task Reminder',
      'It\'s time for: ${task.title}',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Notifications for task reminders',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              'mark_done',
              'Mark as Done',
              showsUserInterface: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'task_category',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: task.id.toString(),
    );
  }

  Future<void> scheduleTaskReminder(Task task) async {
    await updateTaskReminderState(task);
  }

  Future<void> cancelReminder(int taskId) async {
    await _notificationsPlugin.cancel(taskId);
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  if (response.actionId == 'mark_done') {
    final payload = response.payload;
    if (payload != null) {
      final taskId = int.tryParse(payload);
      if (taskId != null) {
        try {
          await DatabaseService.instance.toggleTaskCompletion(taskId, DateTime.now());
        } catch (e) {
          // Handle or log error
        }
      }
    }
  }
}
