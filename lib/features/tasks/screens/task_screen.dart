import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/widgets/custom_text_field.dart';
import 'package:finpredict/services/firebase_service.dart';
import 'package:finpredict/services/notification_service.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  _TaskScreenState createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Controllers
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _dueTimeController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedPriority = 'Medium';
  String _selectedCategory = 'General';
  String? _editingTaskId;

  late AnimationController _animationController;
  final List<String> _priorities = ['High', 'Medium', 'Low'];
  final List<String> _categories = [
    'General',
    'Work',
    'Personal',
    'Health',
    'Finance',
    'Shopping'
  ];

  // Filter state
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Pending', 'In Progress', 'Completed'];

  // Local storage for guest users
  List<Map<String, dynamic>> _localTasks = [];
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkUserStatus();
    _loadLocalTasks();

    // Initialize notification service
    _notificationService.init();
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    _dueTimeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _checkUserStatus() {
    setState(() {
      _isGuest = _currentUser == null;
    });
  }

  Future<void> _loadLocalTasks() async {
    if (!_isGuest) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksString = prefs.getString('local_tasks');
      if (tasksString != null && tasksString.isNotEmpty) {
        final List<dynamic> decodedList = json.decode(tasksString);
        _localTasks = decodedList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _localTasks = [];
      }
    } catch (e) {
      print('Error loading local tasks: $e');
      _localTasks = [];
    }
  }

  Future<void> _saveLocalTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedTasks = json.encode(_localTasks);
      await prefs.setString('local_tasks', encodedTasks);
      debugPrint('✅ Local tasks saved: ${_localTasks.length} tasks');
    } catch (e) {
      print('Error saving local tasks: $e');
    }
  }

  // ============================================
  // FIXED: Add task with proper reminder scheduling
  // ============================================
  Future<void> _addOrUpdateTask() async {
    if (_taskController.text.isEmpty) {
      CustomDialog.showError(context, 'Please enter a task title');
      return;
    }

    if (_selectedDate == null) {
      CustomDialog.showError(context, 'Please select a due date');
      return;
    }

    try {
      CustomDialog.showLoading(context,
          _editingTaskId == null ? 'Adding task...' : 'Updating task...');

      // Combine date and time
      DateTime dueDateTime = _selectedDate!;
      if (_selectedTime != null) {
        dueDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      } else {
        // If no time selected, set to end of day
        dueDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          23,
          59,
          59,
        );
      }

      final String taskId =
          _editingTaskId ?? DateTime.now().millisecondsSinceEpoch.toString();

      final Map<String, dynamic> taskData = {
        'id': taskId,
        'title': _taskController.text,
        'description': _descriptionController.text,
        'dueDate': dueDateTime.toIso8601String(),
        'dueDateTime': dueDateTime.millisecondsSinceEpoch,
        'priority': _selectedPriority,
        'category': _selectedCategory,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'userId': _currentUser?.uid ?? 'guest',
      };

      if (_isGuest) {
        // Handle guest user
        if (_editingTaskId == null) {
          // Add new task
          _localTasks.add(taskData);
          debugPrint('✅ New task added locally');
        } else {
          // Update existing task
          final index =
              _localTasks.indexWhere((t) => t['id'] == _editingTaskId);
          if (index != -1) {
            taskData['createdAt'] = _localTasks[index]['createdAt'];
            _localTasks[index] = taskData;
            debugPrint('✅ Task updated locally');
          }
        }
        await _saveLocalTasks();

        // Schedule notifications for guest user
        await _notificationService.scheduleTaskReminders(
          taskId: taskId,
          taskTitle: _taskController.text,
          dueDateTime: dueDateTime,
        );

        CustomDialog.dismiss(context);
        CustomDialog.showSuccess(
            context,
            _editingTaskId == null
                ? 'Task added successfully! 🎯'
                : 'Task updated successfully! ✨');
      } else {
        // Handle logged in user
        if (_editingTaskId == null) {
          // Add new task
          taskData['createdAt'] = FieldValue.serverTimestamp();

          final docRef = await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .collection('tasks')
              .add(taskData);

          debugPrint('✅ New task added to Firebase with ID: ${docRef.id}');

          // Schedule notifications with the generated Firestore ID
          await _notificationService.scheduleTaskReminders(
            taskId: docRef.id,
            taskTitle: _taskController.text,
            dueDateTime: dueDateTime,
          );
        } else {
          // Update existing task
          final Map<String, dynamic> firestoreData = Map.from(taskData);
          firestoreData.remove('id');
          firestoreData['updatedAt'] = FieldValue.serverTimestamp();

          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .collection('tasks')
              .doc(_editingTaskId)
              .update(firestoreData);

          debugPrint('✅ Task updated in Firebase');

          // Reschedule notifications for updated task
          await _notificationService.cancelTaskReminders(_editingTaskId!);
          await _notificationService.scheduleTaskReminders(
            taskId: _editingTaskId!,
            taskTitle: _taskController.text,
            dueDateTime: dueDateTime,
          );
        }

        CustomDialog.dismiss(context);
        CustomDialog.showSuccess(
            context,
            _editingTaskId == null
                ? 'Task added successfully! 🎯'
                : 'Task updated successfully! ✨');
      }

      _clearForm();
    } catch (e) {
      CustomDialog.dismiss(context);
      CustomDialog.showError(context, 'Error saving task: $e');
      print('❌ Error saving task: $e');
    }
  }

  void _clearForm() {
    setState(() {
      _taskController.clear();
      _descriptionController.clear();
      _dueDateController.clear();
      _dueTimeController.clear();
      _selectedDate = null;
      _selectedTime = null;
      _selectedPriority = 'Medium';
      _selectedCategory = 'General';
      _editingTaskId = null;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFBA002),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });

      // Automatically open time picker after date selection
      _selectTime(context);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFBA002),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _dueTimeController.text = picked.format(context);
      });
    }
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      if (_isGuest) {
        final index = _localTasks.indexWhere((t) => t['id'] == taskId);
        if (index != -1) {
          _localTasks[index]['status'] = newStatus;
          _localTasks[index]['updatedAt'] = DateTime.now().toIso8601String();
          if (newStatus == 'completed') {
            _localTasks[index]['completedAt'] =
                DateTime.now().toIso8601String();
          }
          await _saveLocalTasks();
          debugPrint('✅ Task status updated locally');
        }
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('tasks')
            .doc(taskId)
            .update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          'completedAt':
              newStatus == 'completed' ? FieldValue.serverTimestamp() : null,
        });
        debugPrint('✅ Task status updated in Firebase');
      }

      // Cancel notifications if task is completed
      if (newStatus == 'completed') {
        await _notificationService.cancelTaskReminders(taskId);

        _animationController.forward().then((_) {
          _animationController.reverse();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Great job! Task completed!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      CustomDialog.showError(context, 'Error updating task: $e');
      print('❌ Error updating task status: $e');
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final confirmed = await CustomDialog.showConfirmation(
      context,
      'Delete Task',
      'Are you sure you want to delete this task?',
    );

    if (confirmed == true) {
      try {
        // Cancel all notifications for this task
        await _notificationService.cancelTaskReminders(taskId);

        if (_isGuest) {
          _localTasks.removeWhere((t) => t['id'] == taskId);
          await _saveLocalTasks();
          debugPrint('✅ Task deleted locally');
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .collection('tasks')
              .doc(taskId)
              .delete();
          debugPrint('✅ Task deleted from Firebase');
        }

        CustomDialog.showSuccess(context, 'Task deleted successfully');
      } catch (e) {
        CustomDialog.showError(context, 'Error deleting task: $e');
        print('❌ Error deleting task: $e');
      }
    }
  }

  void _editTask(dynamic taskDoc) {
    Map<String, dynamic> task;
    String taskId;

    if (_isGuest) {
      task = taskDoc as Map<String, dynamic>;
      taskId = task['id'] as String;
    } else {
      final doc = taskDoc as DocumentSnapshot;
      task = doc.data() as Map<String, dynamic>;
      taskId = doc.id;
    }

    final dueDate = DateTime.parse(task['dueDate']);

    setState(() {
      _editingTaskId = taskId;
      _taskController.text = task['title'] ?? '';
      _descriptionController.text = task['description'] ?? '';
      _selectedDate = dueDate;
      _dueDateController.text = DateFormat('yyyy-MM-dd').format(dueDate);
      _selectedPriority = task['priority'] ?? 'Medium';
      _selectedCategory = task['category'] ?? 'General';

      if (dueDate.hour != 23 || dueDate.minute != 59) {
        _selectedTime = TimeOfDay(hour: dueDate.hour, minute: dueDate.minute);
        _dueTimeController.text = _selectedTime!.format(context);
      }
    });

    // Show the form
    _showTaskForm();

    // Scroll to form
    Future.delayed(const Duration(milliseconds: 300), () {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
      );
    });
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFFBA002);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Icons.work;
      case 'personal':
        return Icons.person;
      case 'health':
        return Icons.favorite;
      case 'finance':
        return Icons.attach_money;
      case 'shopping':
        return Icons.shopping_cart;
      default:
        return Icons.task;
    }
  }

  String _getTimeRemaining(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} left';
    } else {
      return 'Due now';
    }
  }

  Widget _buildTaskItem(dynamic taskItem) {
    Map<String, dynamic> task;
    String taskId;

    if (_isGuest) {
      task = taskItem as Map<String, dynamic>;
      taskId = task['id'] as String;
    } else {
      final doc = taskItem as DocumentSnapshot;
      task = doc.data() as Map<String, dynamic>;
      taskId = doc.id;
    }

    final dueDate = DateTime.parse(task['dueDate']);
    final isOverdue =
        dueDate.isBefore(DateTime.now()) && task['status'] != 'completed';
    final priorityColor = _getPriorityColor(task['priority']);
    final categoryIcon = _getCategoryIcon(task['category'] ?? 'General');
    final timeRemaining = _getTimeRemaining(dueDate);

    return GlassCard(
      width: double.infinity,
      borderRadius: 20,
      blur: 10,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: isOverdue
              ? Border.all(color: const Color(0xFFEF4444), width: 1)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with priority and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Priority badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: priorityColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag,
                          color: priorityColor,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task['priority'],
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: task['status'] == 'completed'
                          ? const Color(0xFF10B981).withOpacity(0.2)
                          : task['status'] == 'in_progress'
                              ? const Color(0xFF3B82F6).withOpacity(0.2)
                              : const Color(0xFF94A3B8).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          task['status'] == 'completed'
                              ? Icons.check_circle
                              : task['status'] == 'in_progress'
                                  ? Icons.autorenew
                                  : Icons.schedule,
                          color: task['status'] == 'completed'
                              ? const Color(0xFF10B981)
                              : task['status'] == 'in_progress'
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF94A3B8),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task['status'] == 'in_progress'
                              ? 'In Progress'
                              : task['status'] == 'completed'
                                  ? 'Completed'
                                  : 'Pending',
                          style: TextStyle(
                            color: task['status'] == 'completed'
                                ? const Color(0xFF10B981)
                                : task['status'] == 'in_progress'
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title and category
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      categoryIcon,
                      color: priorityColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['title'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (task['description'] != null &&
                            task['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task['description'],
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Date and time with reminder indicator
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.calendar_today,
                      color: isOverdue
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFFBA002),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMM dd, yyyy').format(dueDate),
                            style: TextStyle(
                              color: isOverdue
                                  ? const Color(0xFFEF4444)
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (dueDate.hour != 23 || dueDate.minute != 59)
                            Text(
                              DateFormat('hh:mm a').format(dueDate),
                              style: TextStyle(
                                color: isOverdue
                                    ? const Color(0xFFEF4444).withOpacity(0.7)
                                    : const Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Reminder indicator
                    if (!isOverdue && task['status'] != 'completed')
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.notifications_active,
                          color: const Color(0xFFFBA002),
                          size: 16,
                        ),
                      ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? const Color(0xFFEF4444).withOpacity(0.2)
                            : const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        timeRemaining,
                        style: TextStyle(
                          color: isOverdue
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        if (task['status'] != 'completed') ...[
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.check,
                              label: 'Done',
                              color: const Color(0xFF10B981),
                              onTap: () =>
                                  _updateTaskStatus(taskId, 'completed'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.autorenew,
                              label: task['status'] == 'in_progress'
                                  ? 'Progress'
                                  : 'Start',
                              color: const Color(0xFF3B82F6),
                              onTap: () => _updateTaskStatus(
                                taskId,
                                'in_progress',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildIconButton(
                    icon: Icons.edit,
                    color: const Color(0xFFFBA002),
                    onTap: () => _editTask(taskItem),
                  ),
                  const SizedBox(width: 6),
                  _buildIconButton(
                    icon: Icons.delete_outline,
                    color: const Color(0xFFEF4444),
                    onTap: () => _deleteTask(taskId),
                  ),
                ],
              ),

              // Completed checkmark
              if (task['status'] == 'completed')
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Completed',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              backgroundColor: const Color(0xFF1E293B),
              selectedColor: const Color(0xFFFBA002),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFFBA002)
                      : const Color(0xFF334155),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isGuest ? 'My Tasks (Guest)' : 'My Tasks',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Color(0xFFFBA002),
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isGuest)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .collection('tasks')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                final total = snapshot.data!.docs.length;
                final completed = snapshot.data!.docs
                    .where((doc) =>
                        (doc.data() as Map<String, dynamic>)['status'] ==
                        'completed')
                    .length;

                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$completed/$total',
                        style: const TextStyle(
                          color: Color(0xFFFBA002),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.task_alt,
                        color: Color(0xFFFBA002),
                        size: 16,
                      ),
                    ],
                  ),
                );
              },
            ),
          if (_isGuest)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(
                    '${_localTasks.where((t) => t['status'] == 'completed').length}/${_localTasks.length}',
                    style: const TextStyle(
                      color: Color(0xFFFBA002),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.task_alt,
                    color: Color(0xFFFBA002),
                    size: 16,
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilterChips(),
          ),
          Expanded(
            child: _isGuest ? _buildGuestTaskList() : _buildFirebaseTaskList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTaskForm,
        backgroundColor: const Color(0xFFFBA002),
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text(
          'Add Task',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFirebaseTaskList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('tasks')
          .orderBy('dueDateTime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFBA002),
            ),
          );
        }

        var tasks = snapshot.data!.docs;

        if (_selectedFilter != 'All') {
          tasks = tasks.where((doc) {
            final task = doc.data() as Map<String, dynamic>;
            return task['status'] == _selectedFilter.toLowerCase();
          }).toList();
        }

        if (tasks.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return _buildTaskItem(tasks[index]);
          },
        );
      },
    );
  }

  Widget _buildGuestTaskList() {
    var tasks = _localTasks;

    if (_selectedFilter != 'All') {
      tasks = tasks.where((task) {
        return task['status'] == _selectedFilter.toLowerCase();
      }).toList();
    }

    tasks.sort(
        (a, b) => (a['dueDateTime'] as int).compareTo(b['dueDateTime'] as int));

    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return _buildTaskItem(tasks[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt,
              color: Color(0xFFFBA002),
              size: 60,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No tasks yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a new task to get started',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 16,
            ),
          ),
          if (_isGuest) ...[
            const SizedBox(height: 16),
            const Text(
              'Working in guest mode - tasks saved locally',
              style: TextStyle(
                color: Color(0xFFFBA002),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showTaskForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editingTaskId == null ? 'Add New Task' : 'Edit Task',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _clearForm();
                      Navigator.pop(context);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _taskController,
                      label: 'Task Title',
                      hintText: 'Enter task title',
                      prefixIcon: Icons.task,
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      controller: _descriptionController,
                      label: 'Description (Optional)',
                      hintText: 'Add more details',
                      prefixIcon: Icons.description,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context),
                            child: AbsorbPointer(
                              child: CustomTextField(
                                controller: _dueDateController,
                                label: 'Due Date',
                                hintText: 'Select date',
                                prefixIcon: Icons.calendar_today,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectTime(context),
                            child: AbsorbPointer(
                              child: CustomTextField(
                                controller: _dueTimeController,
                                label: 'Due Time',
                                hintText: 'Select time',
                                prefixIcon: Icons.access_time,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Priority',
                          style: TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedPriority,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            underline: const SizedBox(),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFFFBA002),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            items: _priorities.map((priority) {
                              return DropdownMenuItem(
                                value: priority,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      color: _getPriorityColor(priority),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(priority),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedPriority = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category',
                          style: TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            underline: const SizedBox(),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFFFBA002),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Row(
                                  children: [
                                    Icon(
                                      _getCategoryIcon(category),
                                      color: const Color(0xFFFBA002),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(category),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    CustomButton(
                      text: _editingTaskId == null ? 'Add Task' : 'Update Task',
                      onPressed: () {
                        _addOrUpdateTask();
                        Navigator.pop(context);
                      },
                    ),
                    if (_editingTaskId != null) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          _clearForm();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                    if (_isGuest) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFFFBA002),
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You are in guest mode. Tasks will be saved locally on this device.',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
