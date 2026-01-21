import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Simple notification service without flutter_local_notifications
  Future<void> showTaskNotification(
      BuildContext context, String title, String body) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          body,
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFFFBA002)),
            ),
          ),
        ],
      ),
    );
  }

  // Show snackbar notification
  void showSnackBarNotification(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Initialize - empty for now
  Future<void> init() async {
    // No initialization needed
  }

  // Schedule task notification (simulated with delayed dialog)
  Future<void> scheduleTaskNotification({
    required BuildContext context,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final now = DateTime.now();
    final delay = scheduledDate.difference(now);

    if (delay.inSeconds > 0) {
      Future.delayed(delay, () {
        if (context.mounted) {
          showSnackBarNotification(context, '$title: $body');
        }
      });
    }
  }
}
