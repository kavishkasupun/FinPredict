import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    _isInitialized = true;
  }

  // Show instant notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'expense_alerts',
      'Expense Alerts',
      channelDescription: 'Notifications for expense alerts',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFFBA002),
      ledColor: Color(0xFFFBA002),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Schedule notification
  Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'scheduled_alerts',
      'Scheduled Alerts',
      channelDescription: 'Scheduled notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _notificationsPlugin.zonedSchedule(
      id.hashCode,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // Show expense alert notification
  Future<void> showExpenseAlert({
    required double currentExpense,
    required double monthlyIncome,
    required double percentage,
    required String aiMessage,
  }) async {
    await showNotification(
      title: '⚠️ AI Expense Alert!',
      body: aiMessage,
      payload: 'expense_alert',
    );
  }

  // Show AI recommendation notification
  Future<void> showAIRecommendation(String message) async {
    await showNotification(
      title: '🤖 AI Financial Tip',
      body: message,
      payload: 'ai_tip',
    );
  }

  // Show task reminder notification
  Future<void> showTaskReminder(String taskTitle, DateTime dueDate) async {
    await scheduleNotification(
      id: 'task_$taskTitle',
      title: '📋 Task Reminder',
      body:
          'Task "$taskTitle" is due ${dueDate.day - DateTime.now().day} days from now',
      scheduledTime:
          dueDate.subtract(const Duration(hours: 24)), // 24 hours before
      payload: 'task_reminder',
    );
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
