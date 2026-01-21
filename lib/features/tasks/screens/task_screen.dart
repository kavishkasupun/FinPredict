import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/widgets/custom_text_field.dart';
import 'package:finpredict/services/firebase_service.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  _TaskScreenState createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  DateTime? _selectedDate;
  String _selectedPriority = 'Medium';

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    // This would be where you set up local notifications
    // For now, we'll just simulate with a timer
  }

  Future<void> _addTask() async {
    if (_taskController.text.isEmpty) {
      CustomDialog.showError(context, 'Please enter a task description');
      return;
    }

    if (_selectedDate == null) {
      CustomDialog.showError(context, 'Please select a due date');
      return;
    }

    try {
      CustomDialog.showLoading(context, 'Adding task...');

      final taskData = {
        'title': _taskController.text,
        'description': '',
        'dueDate': _selectedDate!.toIso8601String(),
        'priority': _selectedPriority,
        'category': 'General',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reminderSent': false,
        'userId': _currentUser!.uid,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('tasks')
          .add(taskData);

      // Send notification for task
      _sendTaskNotification(_taskController.text, _selectedDate!);

      // Clear fields
      _taskController.clear();
      _dueDateController.clear();
      setState(() {
        _selectedDate = null;
        _selectedPriority = 'Medium';
      });

      CustomDialog.dismiss(context);
      CustomDialog.showSuccess(context, 'Task added successfully!');
    } catch (e) {
      CustomDialog.dismiss(context);
      CustomDialog.showError(context, 'Error adding task: $e');
    }
  }

  void _sendTaskNotification(String taskTitle, DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.inHours <= 24) {
      // Show snackbar notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task Reminder: "$taskTitle" is due within 24 hours!'),
          backgroundColor: const Color(0xFFF59E0B),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
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
    }
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
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

      if (newStatus == 'completed') {
        CustomDialog.showSuccess(context, 'Task marked as completed! 🎉');
      }
    } catch (e) {
      CustomDialog.showError(context, 'Error updating task: $e');
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
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('tasks')
            .doc(taskId)
            .delete();

        CustomDialog.showSuccess(context, 'Task deleted successfully');
      } catch (e) {
        CustomDialog.showError(context, 'Error deleting task: $e');
      }
    }
  }

  Widget _buildTaskItem(DocumentSnapshot taskDoc) {
    final task = taskDoc.data() as Map<String, dynamic>;
    final dueDate = DateTime.parse(task['dueDate']);
    final isOverdue =
        dueDate.isBefore(DateTime.now()) && task['status'] != 'completed';
    final priorityColor = _getPriorityColor(task['priority']);

    return GlassCard(
      width: double.infinity,
      borderRadius: 20,
      blur: 10,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: const Color(0xFF94A3B8)),
                  color: const Color(0xFF1E293B),
                  onSelected: (value) {
                    if (value == 'edit') {
                      // Implement edit functionality
                    } else if (value == 'delete') {
                      _deleteTask(taskDoc.id);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit,
                              color: const Color(0xFFFBA002), size: 20),
                          const SizedBox(width: 8),
                          const Text('Edit',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete,
                              color: const Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 8),
                          const Text('Delete',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: priorityColor),
                  ),
                  child: Text(
                    task['priority'],
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.calendar_today,
                  color: const Color(0xFF94A3B8),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(dueDate),
                  style: TextStyle(
                    color: isOverdue
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF94A3B8),
                    fontSize: 14,
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: task['status'] == 'completed'
                        ? 'Completed ✅'
                        : 'Mark Complete',
                    onPressed: task['status'] == 'completed'
                        ? () {} // Changed from null to empty function
                        : () => _updateTaskStatus(taskDoc.id, 'completed'),
                    backgroundColor: task['status'] == 'completed'
                        ? const Color(0xFF10B981)
                        : null,
                  ),
                ),
                if (task['status'] != 'completed') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomButton(
                      text: 'In Progress',
                      onPressed: () =>
                          _updateTaskStatus(taskDoc.id, 'in_progress'),
                      backgroundColor: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Daily Tasks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Add Task Form
            GlassCard(
              width: double.infinity,
              borderRadius: 25,
              blur: 20,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Add New Task',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      controller: _taskController,
                      label: 'Task Description',
                      hintText: 'Enter your task here...',
                      prefixIcon: Icons.task,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _dueDateController,
                          label: 'Due Date',
                          hintText: 'Select due date',
                          prefixIcon: Icons.calendar_today,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        DropdownButtonFormField<String>(
                          value: _selectedPriority,
                          dropdownColor: const Color(0xFF1E293B),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1E293B).withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          items: ['High', 'Medium', 'Low']
                              .map((priority) => DropdownMenuItem(
                                    value: priority,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color: _getPriorityColor(priority),
                                          size: 12,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          priority,
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPriority = value!;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      text: 'Add Task',
                      onPressed: _addTask,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Task List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('tasks')
                    .orderBy('createdAt', descending: true)
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
                      child:
                          CircularProgressIndicator(color: Color(0xFFFBA002)),
                    );
                  }

                  final tasks = snapshot.data!.docs;

                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt,
                            color: const Color(0xFF94A3B8),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No tasks yet',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your first task above!',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildTaskItem(tasks[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
