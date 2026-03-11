import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _notificationsEnabled = true;
  final Set<int> _shownNotificationIds = {};

  // Channel IDs
  static const String _expenseAlertChannelId = 'expense_alerts';
  static const String _expenseAlertChannelName = 'Expense Alerts';
  static const String _expenseAlertChannelDescription =
      'Notifications for expense alerts and warnings';

  static const String _taskReminderChannelId = 'task_reminders';
  static const String _taskReminderChannelName = 'Task Reminders';
  static const String _taskReminderChannelDescription =
      'Notifications for task reminders';

  static const String _generalChannelId = 'general_notifications';
  static const String _generalChannelName = 'General Notifications';
  static const String _generalChannelDescription = 'General app notifications';

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz_data.initializeTimeZones();

      // Load notification settings
      await _loadNotificationSettings();

      // Android settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS settings
      final DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        onDidReceiveLocalNotification: (id, title, body, payload) async {
          debugPrint('iOS notification received: $title');
        },
      );

      final InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification tapped: ${details.payload}');
          _handleNotificationTap(details.payload);
        },
      );

      // Create notification channels
      await _createNotificationChannels();

      // Request permissions for Android 13+
      await _requestAndroidPermissions();

      _isInitialized = true;
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      try {
        // Expense Alert Channel
        const AndroidNotificationChannel expenseChannel =
            AndroidNotificationChannel(
          _expenseAlertChannelId,
          _expenseAlertChannelName,
          description: _expenseAlertChannelDescription,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );
        await androidImplementation.createNotificationChannel(expenseChannel);

        // Task Reminder Channel
        const AndroidNotificationChannel taskChannel =
            AndroidNotificationChannel(
          _taskReminderChannelId,
          _taskReminderChannelName,
          description: _taskReminderChannelDescription,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );
        await androidImplementation.createNotificationChannel(taskChannel);

        // General Channel
        const AndroidNotificationChannel generalChannel =
            AndroidNotificationChannel(
          _generalChannelId,
          _generalChannelName,
          description: _generalChannelDescription,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );
        await androidImplementation.createNotificationChannel(generalChannel);

        debugPrint('✅ Notification channels created');
      } catch (e) {
        debugPrint('❌ Error creating notification channels: $e');
      }
    }
  }

  Future<void> _requestAndroidPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      try {
        final bool? granted =
            await androidImplementation.requestNotificationsPermission();
        debugPrint('Notification permission granted: $granted');

        // Request exact alarm permission for Android 12+
        await androidImplementation.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Error requesting permissions: $e');
      }
    }
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  Future<void> saveNotificationSettings(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
      _notificationsEnabled = enabled;
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  Future<bool> checkNotificationSettings() async {
    await _loadNotificationSettings();
    return _notificationsEnabled;
  }

  void _handleNotificationTap(String? payload) {
    debugPrint('Notification tapped with payload: $payload');
  }

  // ============================================
  // FIXED: Schedule notification - Works even when app is closed
  // ============================================
  Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    String channelId = _taskReminderChannelId,
  }) async {
    if (!_isInitialized) await init();
    if (!_notificationsEnabled) return;

    try {
      // Don't schedule if time is in the past
      if (scheduledTime.isBefore(DateTime.now())) {
        debugPrint(
            '⏭️ Cannot schedule notification in the past: $scheduledTime');
        return;
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        channelId == _expenseAlertChannelId
            ? _expenseAlertChannelName
            : channelId == _taskReminderChannelId
                ? _taskReminderChannelName
                : _generalChannelName,
        channelDescription: channelId == _expenseAlertChannelId
            ? _expenseAlertChannelDescription
            : channelId == _taskReminderChannelId
                ? _taskReminderChannelDescription
                : _generalChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        color: const Color(0xFFFBA002),
        ledColor: const Color(0xFFFBA002),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Convert to TZDateTime for scheduling
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      await _notificationsPlugin.zonedSchedule(
        id.hashCode,
        title,
        body,
        tzScheduledTime,
        details,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      debugPrint('✅ Notification scheduled: $title at $scheduledTime');
    } catch (e) {
      debugPrint('❌ Error scheduling notification: $e');
    }
  }

  // ============================================
  // NEW: Schedule task reminder with multiple times
  // ============================================
  Future<void> scheduleTaskReminders({
    required String taskId,
    required String taskTitle,
    required DateTime dueDateTime,
  }) async {
    final now = DateTime.now();

    // Don't schedule if task is already past due
    if (dueDateTime.isBefore(now)) return;

    // Cancel any existing reminders for this task
    await cancelTaskReminders(taskId);

    // 1. Schedule 24 hour reminder
    final reminder24h = dueDateTime.subtract(const Duration(hours: 24));
    if (reminder24h.isAfter(now)) {
      await scheduleNotification(
        id: '${taskId}_24h',
        title: '⏰ Task Due Tomorrow',
        body: 'Task "$taskTitle" is due in 24 hours',
        scheduledTime: reminder24h,
        payload: 'task_reminder_24h|$taskId|$taskTitle',
        channelId: _taskReminderChannelId,
      );
    }

    // 2. Schedule 1 hour reminder
    final reminder1h = dueDateTime.subtract(const Duration(hours: 1));
    if (reminder1h.isAfter(now)) {
      await scheduleNotification(
        id: '${taskId}_1h',
        title: '⚠️ Task Due Soon',
        body: 'Task "$taskTitle" is due in 1 hour',
        scheduledTime: reminder1h,
        payload: 'task_reminder_1h|$taskId|$taskTitle',
        channelId: _taskReminderChannelId,
      );
    }

    // 3. Schedule at due time reminder
    await scheduleNotification(
      id: '${taskId}_now',
      title: '🔔 Task Due Now',
      body: 'Task "$taskTitle" is due now',
      scheduledTime: dueDateTime,
      payload: 'task_reminder_now|$taskId|$taskTitle',
      channelId: _taskReminderChannelId,
    );

    debugPrint('✅ All reminders scheduled for task: $taskTitle');
  }

  // ============================================
  // NEW: Cancel all reminders for a task
  // ============================================
  Future<void> cancelTaskReminders(String taskId) async {
    await cancelNotification('${taskId}_24h');
    await cancelNotification('${taskId}_1h');
    await cancelNotification('${taskId}_now');
    debugPrint('✅ Cancelled reminders for task: $taskId');
  }

  // Show instant notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _generalChannelId,
    int? id,
  }) async {
    if (!_isInitialized) await init();
    if (!_notificationsEnabled) return;

    try {
      final notificationId =
          id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (_shownNotificationIds.contains(notificationId)) {
        debugPrint('⏭️ Skipping duplicate notification: $notificationId');
        return;
      }

      _shownNotificationIds.add(notificationId);
      Future.delayed(const Duration(minutes: 5), () {
        _shownNotificationIds.remove(notificationId);
      });

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        channelId == _expenseAlertChannelId
            ? _expenseAlertChannelName
            : channelId == _taskReminderChannelId
                ? _taskReminderChannelName
                : _generalChannelName,
        channelDescription: channelId == _expenseAlertChannelId
            ? _expenseAlertChannelDescription
            : channelId == _taskReminderChannelId
                ? _taskReminderChannelDescription
                : _generalChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFFBA002),
        ledColor: const Color(0xFFFBA002),
        ledOnMs: 1000,
        ledOffMs: 500,
        enableVibration: true,
        playSound: true,
        styleInformation: const BigTextStyleInformation(''),
        ticker: 'ticker',
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Notification shown: $title (ID: $notificationId)');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  // Show expense alert notification
  Future<void> showExpenseAlert({
    required double currentExpense,
    required double monthlyIncome,
    required double percentage,
    required String aiMessage,
    String? warningLevel,
  }) async {
    if (!_notificationsEnabled) {
      debugPrint('🔕 Notifications are disabled');
      return;
    }

    final int percentageInt = percentage.round();
    final int hourOfDay = DateTime.now().hour;
    final int uniqueId = (percentageInt * 1000 + hourOfDay).abs() % 10000;

    String title;
    String body;
    String channelId;

    if (warningLevel == 'critical' || percentage >= 90) {
      title = '🔴 CRITICAL: Expense Alert!';
      body =
          'You\'ve spent ${percentage.round()}% of your income! Take action now!';
      channelId = _expenseAlertChannelId;
    } else if (warningLevel == 'high' || percentage >= 80) {
      title = '🟠 HIGH SPENDING Alert!';
      body =
          'You\'ve spent ${percentage.round()}% of your income. Review your expenses.';
      channelId = _expenseAlertChannelId;
    } else if (warningLevel == 'moderate' || percentage >= 70) {
      title = '🟡 Moderate Spending';
      body =
          'You\'ve spent ${percentage.round()}% of your income. Keep monitoring.';
      channelId = _generalChannelId;
    } else {
      return;
    }

    await showNotification(
      id: uniqueId,
      title: title,
      body: body,
      payload: 'expense_alert|$percentage|$warningLevel',
      channelId: channelId,
    );
  }

  // Show AI recommendation notification
  Future<void> showAIRecommendation(String message) async {
    await showNotification(
      title: '🤖 AI Financial Tip',
      body: message,
      payload: 'ai_tip',
      channelId: _expenseAlertChannelId,
    );
  }

  // Show daily financial tip
  Future<void> showDailyTip(String tip) async {
    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day + 1, 9, 0);

    await scheduleNotification(
      id: 'daily_tip_${now.day}',
      title: '💡 Daily Financial Tip',
      body: tip,
      scheduledTime: scheduledTime,
      payload: 'daily_tip',
      channelId: _generalChannelId,
    );
  }

  // Show welcome notification
  Future<void> showWelcomeNotification(String userName) async {
    await showNotification(
      title: '👋 Welcome to FinPredict!',
      body: 'Start tracking your expenses to get AI-powered insights.',
      payload: 'welcome',
      channelId: _generalChannelId,
    );
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
    _shownNotificationIds.clear();
    debugPrint('✅ All notifications cancelled');
  }

  // Cancel specific notification
  Future<void> cancelNotification(String id) async {
    await _notificationsPlugin.cancel(id.hashCode);
    _shownNotificationIds.remove(id.hashCode);
    debugPrint('✅ Notification cancelled: $id');
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    return _notificationsEnabled;
  }
}
