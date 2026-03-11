import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/widgets/custom_text_field.dart';
import 'package:finpredict/features/loans/screens/add_repayment_screen.dart';
import 'package:finpredict/features/loans/screens/add_loan_screen.dart';

class LoanDetailScreen extends StatefulWidget {
  final String loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  @override
  _LoanDetailScreenState createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _deleteLoan() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Delete Loan',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this loan? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        CustomDialog.showLoading(context, 'Deleting loan...');

        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('loans')
            .doc(widget.loanId)
            .delete();

        CustomDialog.dismiss(context);
        CustomDialog.showSuccess(context, 'Loan deleted successfully!');

        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context);
        });
      } catch (e) {
        CustomDialog.dismiss(context);
        CustomDialog.showError(context, 'Error deleting loan: $e');
      }
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
          'Loan Details',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            onPressed: _deleteLoan,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('loans')
            .doc(widget.loanId)
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
              child: CircularProgressIndicator(color: Color(0xFFFBA002)),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Loan not found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final loan = snapshot.data!.data() as Map<String, dynamic>;
          final loanDate = DateTime.parse(loan['date']);
          final repayments =
              (loan['repayments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final remaining = (loan['remaining'] as num).toDouble();
          final totalRepaid = (loan['totalRepaid'] as num).toDouble();
          final totalAmount = (loan['amount'] as num).toDouble();
          final repaymentPercentage =
              totalAmount > 0 ? (totalRepaid / totalAmount) * 100 : 0;
          final borrower = loan['borrower'] as String;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Main Loan Info Card
                GlassCard(
                  width: double.infinity,
                  borderRadius: 20,
                  blur: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                borrower,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(loan['status'])
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _getStatusColor(loan['status'])),
                              ),
                              child: Text(
                                loan['status']
                                    .toString()
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(loan['status']),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loan['description'] ?? 'No description',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 16,
                          ),
                        ),
                        const Divider(height: 32, color: Color(0xFF334155)),
                        // Amount Details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildAmountColumn(
                                'Loan Amount', totalAmount, Colors.white),
                            _buildAmountColumn(
                                'Repaid', totalRepaid, const Color(0xFF10B981)),
                            _buildAmountColumn(
                                'Remaining',
                                remaining,
                                remaining > 0
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Progress Card
                GlassCard(
                  width: double.infinity,
                  borderRadius: 20,
                  blur: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Repayment Progress',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${repaymentPercentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Color(0xFFFBA002),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: repaymentPercentage / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF3B82F6)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Loan Date: ${DateFormat('MMM dd, yyyy').format(loanDate)}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${repayments.length} Repayments',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Action Buttons
                Row(
                  children: [
                    if (remaining > 0)
                      Expanded(
                        child: CustomButton(
                          text: 'Add Repayment',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddRepaymentScreen(
                                  loanId: widget.loanId,
                                  remaining: remaining,
                                ),
                              ),
                            );
                          },
                          backgroundColor: const Color(0xFF3B82F6),
                        ),
                      ),
                    if (remaining > 0) const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'Add Another Loan',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddLoanScreen(
                                initialBorrowerName: borrower,
                              ),
                            ),
                          );
                        },
                        backgroundColor: const Color(0xFFFBA002),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Repayment History
                if (repayments.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Repayment History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...repayments.reversed.map((repayment) {
                    final date = DateTime.parse(repayment['date']);
                    final amount = (repayment['amount'] as num).toDouble();
                    return GlassCard(
                      width: double.infinity,
                      borderRadius: 12,
                      blur: 5,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_downward,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        title: Text(
                          'Rs. ${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy').format(date),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.check_circle,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmountColumn(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Rs. ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'partially_paid':
        return const Color(0xFFFBA002);
      case 'pending':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}
