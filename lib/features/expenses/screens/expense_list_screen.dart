import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_dialog.dart';

class ExpenseListScreen extends StatefulWidget {
  final String userId;

  const ExpenseListScreen({super.key, required this.userId});

  @override
  _ExpenseListScreenState createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  double _totalExpenses = 0.0;
  Map<String, double> _categoryTotals = {};

  Future<void> _loadExpenses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('expenses')
          .orderBy('date', descending: true)
          .get();

      double total = 0.0;
      final Map<String, double> categoryTotals = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num).toDouble();
        final category = data['category'] as String;

        total += amount;
        categoryTotals.update(
          category,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      }

      setState(() {
        _totalExpenses = total;
        _categoryTotals = categoryTotals;
      });
    } catch (e) {
      CustomDialog.showError(context, 'Error loading expenses: $e');
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirmed = await CustomDialog.showConfirmation(
      context,
      'Delete Expense',
      'Are you sure you want to delete this expense?',
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('expenses')
            .doc(expenseId)
            .delete();

        await _loadExpenses();
        CustomDialog.showSuccess(context, 'Expense deleted successfully');
      } catch (e) {
        CustomDialog.showError(context, 'Error deleting expense: $e');
      }
    }
  }

  Widget _buildExpenseItem(DocumentSnapshot expenseDoc) {
    final expense = expenseDoc.data() as Map<String, dynamic>;
    final date = DateTime.parse(expense['date']);
    final amount = (expense['amount'] as num).toDouble();
    final category = expense['category'] as String;

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
                    expense['description'] ?? 'No description',
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
                    if (value == 'delete') {
                      _deleteExpense(expenseDoc.id);
                    }
                  },
                  itemBuilder: (context) => [
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
                    color: _getCategoryColor(category).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getCategoryColor(category)),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: _getCategoryColor(category),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_today,
                  color: const Color(0xFF94A3B8),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Amount:',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Rs. ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Food': const Color(0xFF10B981),
      'Transportation': const Color(0xFF3B82F6),
      'Utilities': const Color(0xFF8B5CF6),
      'Entertainment': const Color(0xFFEC4899),
      'Shopping': const Color(0xFFF59E0B),
      'Healthcare': const Color(0xFFEF4444),
      'Education': const Color(0xFF06B6D4),
      'Other': const Color(0xFF94A3B8),
    };
    return colors[category] ?? const Color(0xFF94A3B8);
  }

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Expense History',
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
            // Summary Card
            GlassCard(
              width: double.infinity,
              borderRadius: 25,
              blur: 20,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Expense Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rs. ${_totalExpenses.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Total Expenses',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Category Breakdown
                    if (_categoryTotals.isNotEmpty) ...[
                      const Text(
                        'By Category',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._categoryTotals.entries.map((entry) {
                        final percentage = _totalExpenses > 0
                            ? (entry.value / _totalExpenses) * 100
                            : 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(entry.key),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Expense List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userId)
                    .collection('expenses')
                    .orderBy('date', descending: true)
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

                  final expenses = snapshot.data!.docs;

                  if (expenses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt,
                            color: const Color(0xFF94A3B8),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No expenses recorded',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your first expense from home screen!',
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
                    itemCount: expenses.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildExpenseItem(expenses[index]);
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
