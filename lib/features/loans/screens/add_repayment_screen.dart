import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/widgets/custom_text_field.dart';

class AddRepaymentScreen extends StatefulWidget {
  final String loanId;
  final double remaining;

  const AddRepaymentScreen({
    super.key,
    required this.loanId,
    required this.remaining,
  });

  @override
  _AddRepaymentScreenState createState() => _AddRepaymentScreenState();
}

class _AddRepaymentScreenState extends State<AddRepaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  DateTime? _selectedDate;

  // Quick amount suggestions
  final List<double> _quickAmounts = [1000, 5000, 10000, 20000, 50000];

  Future<void> _addRepayment() async {
    final repaymentAmount = double.tryParse(_amountController.text);
    if (repaymentAmount == null || repaymentAmount <= 0) {
      CustomDialog.showError(context, 'Please enter valid amount');
      return;
    }

    if (repaymentAmount > widget.remaining) {
      CustomDialog.showError(
          context, 'Repayment cannot exceed remaining amount');
      return;
    }

    try {
      CustomDialog.showLoading(context, 'Recording repayment...');

      // Get current loan data
      final loanDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('loans')
          .doc(widget.loanId)
          .get();

      final loanData = loanDoc.data() as Map<String, dynamic>;
      final currentTotalRepaid = (loanData['totalRepaid'] as num).toDouble();
      final currentRemaining = (loanData['remaining'] as num).toDouble();

      final newTotalRepaid = currentTotalRepaid + repaymentAmount;
      final newRemaining = currentRemaining - repaymentAmount;
      final newStatus = newRemaining <= 0 ? 'completed' : 'partially_paid';

      final repaymentRecord = {
        'amount': repaymentAmount,
        'date': (_selectedDate ?? DateTime.now()).toIso8601String(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Get existing repayments and add new one
      final List<dynamic> existingRepayments = loanData['repayments'] ?? [];
      final List<dynamic> updatedRepayments = [
        ...existingRepayments,
        repaymentRecord
      ];

      // Update loan document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('loans')
          .doc(widget.loanId)
          .update({
        'totalRepaid': newTotalRepaid,
        'remaining': newRemaining,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'repayments': updatedRepayments,
      });

      CustomDialog.dismiss(context);

      // Show success message with option to add another repayment
      if (newRemaining > 0) {
        _showAddAnotherRepaymentDialog(newRemaining);
      } else {
        CustomDialog.showSuccess(
          context,
          'Loan fully repaid! 🎉',
        );
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context);
        });
      }
    } catch (e) {
      CustomDialog.dismiss(context);
      CustomDialog.showError(context, 'Error recording repayment: $e');
    }
  }

  void _showAddAnotherRepaymentDialog(double newRemaining) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Repayment Recorded!',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remaining: Rs. ${newRemaining.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Do you want to add another repayment?',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back
            },
            child: const Text(
              'Done',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _amountController.clear();
              _dateController.clear();
              setState(() {
                _selectedDate = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBA002),
            ),
            child: const Text('Add Another'),
          ),
        ],
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
        title: const Text(
          'Add Repayment',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Remaining Amount Card
            GlassCard(
              width: double.infinity,
              borderRadius: 20,
              blur: 10,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Remaining Balance',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs. ${widget.remaining.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Quick Amount Suggestions
            if (widget.remaining > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Amounts',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickAmounts.map((amount) {
                          final isEnabled = amount <= widget.remaining;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                'Rs. ${amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: isEnabled
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              selected: false,
                              onSelected: isEnabled
                                  ? (selected) {
                                      setState(() {
                                        _amountController.text =
                                            amount.toStringAsFixed(2);
                                      });
                                    }
                                  : null,
                              backgroundColor: const Color(0xFF1E293B),
                              selectedColor: const Color(0xFFFBA002),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isEnabled
                                      ? const Color(0xFFFBA002)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            // Repayment Form
            GlassCard(
              width: double.infinity,
              borderRadius: 20,
              blur: 10,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Repayment Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      controller: _amountController,
                      label: 'Repayment Amount',
                      hintText: 'Enter amount',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.money,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
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
                            _dateController.text =
                                DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _dateController,
                          label: 'Repayment Date',
                          hintText: 'Select date (optional)',
                          prefixIcon: Icons.calendar_today,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Add Repayment',
                      onPressed: _addRepayment,
                      width: double.infinity,
                      backgroundColor: const Color(0xFF10B981),
                    ),
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
