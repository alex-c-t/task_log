import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../screens/main_screen.dart';
import '../main.dart';

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
            DarwinNotificationAction.plain('mark_completed', 'Mark as Completed'),
            DarwinNotificationAction.plain('snooze', 'Snooze (15m)'),
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
    final payload = response.payload;
    if (payload == null) return;
    final taskId = int.tryParse(payload);
    if (taskId == null) return;

    if (response.actionId == 'snooze') {
      instance.snoozeTask(taskId);
      return;
    }

    if (response.actionId == 'mark_completed') {
      try {
        // 1. Cancel the current notification first (dismisses from shade)
        await instance._notificationsPlugin.cancel(taskId);

        // 2. Mark task as completed. Use skipNotificationUpdate to isolate
        //    the DB write from notification scheduling errors, ensuring
        //    notifyListeners() always fires after a successful DB update.
        await DatabaseService.instance.toggleTaskCompletion(
          taskId, DateTime.now(),
          forceStatus: true,
          skipNotificationUpdate: true,
        );

        // 3. Reschedule notification for tomorrow (separate error boundary)
        try {
          final task = await DatabaseService.instance.getTaskById(taskId);
          if (task != null) {
            await instance.updateTaskReminderState(task);
          }
        } catch (e) {
          debugPrint('NotificationService: Error rescheduling after mark_completed: $e');
        }
      } catch (e) {
        debugPrint('NotificationService: Error handling mark_completed action: $e');
      }
    } else {
      // Tap on body - Navigate to Day Detail for today (by re-rooting to MainScreen on tab 1)
      TaskLogApp.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainScreen(
            initialTab: 1,
            highlightTaskId: taskId,
          ),
        ),
        (route) => false,
      );
    }
  }

  /// Updates the reminder state based on whether the task is completed today.
  Future<void> updateTaskReminderState(Task task) async {
    if (task.reminderTime == null || task.id == null || task.isFinished == 1) {
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

    // Debug log for verification (can be re-enabled if needed)
    // print('NOTIFICATION_DEBUG: Scheduling "${task.title}" for $scheduledDate (Local Now: $now)');

    await _notificationsPlugin.zonedSchedule(
      task.id!,
      task.title,
      'Daily Goal',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Notifications for task reminders',
          importance: Importance.max,
          priority: Priority.high,
          ticker: task.title,
          color: Color(int.parse(task.colorHex.replaceFirst('#', '0xFF'))),
          ledColor: Color(int.parse(task.colorHex.replaceFirst('#', '0xFF'))),
          ledOnMs: 1000,
          ledOffMs: 500,
          showWhen: true,
          category: AndroidNotificationCategory.reminder,
          styleInformation: const BigTextStyleInformation(
            'Scheduled for today',
            contentTitle: null,
            summaryText: 'Tasklet',
          ),
          actions: [
            AndroidNotificationAction(
              'mark_completed',
              'Mark as Completed',
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'snooze',
              'Snooze (15m)',
              showsUserInterface: false,
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

  Future<void> snoozeTask(int taskId, {int minutes = 15}) async {
    try {
      final task = await DatabaseService.instance.getTaskById(taskId);
      if (task == null) return;

      await _notificationsPlugin.cancel(taskId);

      final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));

      await _notificationsPlugin.zonedSchedule(
        task.id!,
        '${task.title} (Snoozed)',
        'Reminding you in $minutes minutes',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(int.parse(task.colorHex.replaceFirst('#', '0xFF'))),
            actions: [
              const AndroidNotificationAction('mark_completed', 'Mark as Completed', showsUserInterface: false),
              const AndroidNotificationAction('snooze', 'Snooze (15m)', showsUserInterface: false),
            ],
          ),
          iOS: const DarwinNotificationDetails(categoryIdentifier: 'task_category'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id.toString(),
      );
    } catch (e) {
      debugPrint('NotificationService: Error snoozing task: $e');
    }
  }

  Future<void> cancelReminder(int taskId) async {
    await _notificationsPlugin.cancel(taskId);
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  if (response.actionId == 'snooze') {
    final payload = response.payload;
    if (payload != null) {
      final taskId = int.tryParse(payload);
      if (taskId != null) {
        try {
          // Initialize background context if needed for snooze scheduling
          tz.initializeTimeZones();
          final FlutterLocalNotificationsPlugin bgPlugin = FlutterLocalNotificationsPlugin();
          final now = tz.TZDateTime.now(tz.local);
          final scheduledDate = now.add(const Duration(minutes: 15));
          
          // Fetch task title for the snoozed notification
          // Note: In background isolate, we might not have all context,
          // but we can try to get it from DB.
          final task = await DatabaseService.instance.getTaskById(taskId);
          if (task != null) {
            await bgPlugin.zonedSchedule(
              taskId,
              '${task.title} (Snoozed)',
              'Reminding you in 15 minutes',
              scheduledDate,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  'task_reminders',
                  'Task Reminders',
                  importance: Importance.max,
                  priority: Priority.high,
                  actions: [
                    const AndroidNotificationAction('mark_completed', 'Mark as Completed', showsUserInterface: false),
                    const AndroidNotificationAction('snooze', 'Snooze (15m)', showsUserInterface: false),
                  ],
                ),
                iOS: const DarwinNotificationDetails(categoryIdentifier: 'task_category'),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              payload: taskId.toString(),
            );
          }
        } catch (e) {
          debugPrint('NotificationService: Error in background snooze: $e');
        }
      }
    }
    return;
  }

  if (response.actionId == 'mark_completed') {
    final payload = response.payload;
    if (payload != null) {
      final taskId = int.tryParse(payload);
      if (taskId != null) {
        try {
          // 1. Dismiss the notification first
          final FlutterLocalNotificationsPlugin bgPlugin = FlutterLocalNotificationsPlugin();
          await bgPlugin.cancel(taskId);

          // 2. Mark as completed in DB.
          //    skipNotificationUpdate: true because NotificationService
          //    cannot be fully initialized in a background isolate.
          //    Rescheduling will happen when the app resumes.
          await DatabaseService.instance.toggleTaskCompletion(
            taskId,
            DateTime.now(),
            skipNotificationUpdate: true,
            forceStatus: true,
          );
        } catch (e) {
          debugPrint('NotificationService: Error in background mark_completed: $e');
        }
      }
    }
  }
}
