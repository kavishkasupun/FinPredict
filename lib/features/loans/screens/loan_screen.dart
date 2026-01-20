import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/widgets/custom_text_field.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  _LoanScreenState createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  final TextEditingController _borrowerController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  DateTime? _selectedDate;

  Future<void> _addLoan() async {
    if (_borrowerController.text.isEmpty) {
      CustomDialog.showError(context, 'Please enter borrower name');
      return;
    }

    if (_amountController.text.isEmpty) {
      CustomDialog.showError(context, 'Please enter loan amount');
      return;
    }

    try {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        CustomDialog.showError(context, 'Please enter valid amount');
        return;
      }

      CustomDialog.showLoading(context, 'Adding loan record...');

      final loanData = {
        'borrower': _borrowerController.text,
        'amount': amount,
        'description': _descriptionController.text,
        'date': _selectedDate?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'status': 'pending',
        'repayments': [],
        'totalRepaid': 0.0,
        'remaining': amount,
        'userId': _currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('loans')
          .add(loanData);

      // Clear fields
      _borrowerController.clear();
      _amountController.clear();
      _descriptionController.clear();
      _dateController.clear();
      setState(() {
        _selectedDate = null;
      });

      CustomDialog.dismiss(context);
      CustomDialog.showSuccess(context, 'Loan added successfully!');
    } catch (e) {
      CustomDialog.dismiss(context);
      CustomDialog.showError(context, 'Error adding loan: $e');
    }
  }

  Future<void> _addRepayment(String loanId, double remaining) async {
    final amountController = TextEditingController();
    final dateController = TextEditingController();
    DateTime? repaymentDate;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Add Repayment',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: amountController,
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
                    repaymentDate = picked;
                    dateController.text =
                        DateFormat('yyyy-MM-dd').format(picked);
                  }
                },
                child: AbsorbPointer(
                  child: CustomTextField(
                    controller: dateController,
                    label: 'Repayment Date',
                    hintText: 'Select date',
                    prefixIcon: Icons.calendar_today,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () async {
                final repaymentAmount = double.tryParse(amountController.text);
                if (repaymentAmount == null || repaymentAmount <= 0) {
                  CustomDialog.showError(context, 'Please enter valid amount');
                  return;
                }

                if (repaymentAmount > remaining) {
                  CustomDialog.showError(
                      context, 'Repayment cannot exceed remaining amount');
                  return;
                }

                try {
                  // Get current loan data
                  final loanDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .collection('loans')
                      .doc(loanId)
                      .get();

                  final loanData = loanDoc.data() as Map<String, dynamic>;
                  final currentTotalRepaid =
                      (loanData['totalRepaid'] as num).toDouble();
                  final currentRemaining =
                      (loanData['remaining'] as num).toDouble();

                  final newTotalRepaid = currentTotalRepaid + repaymentAmount;
                  final newRemaining = currentRemaining - repaymentAmount;
                  final newStatus =
                      newRemaining <= 0 ? 'completed' : 'partially_paid';

                  final repaymentRecord = {
                    'amount': repaymentAmount,
                    'date': (repaymentDate ?? DateTime.now()).toIso8601String(),
                    'timestamp': FieldValue.serverTimestamp(),
                  };

                  // Update loan document
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .collection('loans')
                      .doc(loanId)
                      .update({
                    'totalRepaid': newTotalRepaid,
                    'remaining': newRemaining,
                    'status': newStatus,
                    'updatedAt': FieldValue.serverTimestamp(),
                    'repayments': FieldValue.arrayUnion([repaymentRecord]),
                  });

                  Navigator.pop(context);
                  CustomDialog.showSuccess(
                    context,
                    'Repayment recorded!\nRemaining: Rs. ${newRemaining.toStringAsFixed(2)}',
                  );
                } catch (e) {
                  CustomDialog.showError(
                      context, 'Error recording repayment: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              child: const Text('Add Repayment'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoanItem(DocumentSnapshot loanDoc) {
    final loan = loanDoc.data() as Map<String, dynamic>;
    final loanDate = DateTime.parse(loan['date']);
    final repayments =
        (loan['repayments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final remaining = (loan['remaining'] as num).toDouble();
    final totalRepaid = (loan['totalRepaid'] as num).toDouble();
    final totalAmount = remaining + totalRepaid;
    final repaymentPercentage =
        totalAmount > 0 ? (totalRepaid / totalAmount) * 100 : 0;

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
                    loan['borrower'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(loan['status']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(loan['status'])),
                  ),
                  child: Text(
                    loan['status']
                        .toString()
                        .replaceAll('_', ' ')
                        .toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(loan['status']),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loan['description'] ?? 'No description',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loan Date',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(loanDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Rs. ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Repayment Progress',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${repaymentPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: repaymentPercentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Repaid',
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Rs. ${totalRepaid.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Remaining',
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Rs. ${remaining.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: remaining > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (remaining > 0)
              CustomButton(
                text: 'Add Repayment',
                onPressed: () => _addRepayment(loanDoc.id, remaining),
                width: double.infinity,
                backgroundColor: const Color(0xFF3B82F6),
              ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Loan Tracking',
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
            // Add Loan Form
            GlassCard(
              width: double.infinity,
              borderRadius: 25,
              blur: 20,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Add New Loan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      controller: _borrowerController,
                      label: 'Borrower Name',
                      hintText: 'Enter borrower name',
                      prefixIcon: Icons.person,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _amountController,
                      label: 'Loan Amount',
                      hintText: 'Enter amount',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.money,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _descriptionController,
                      label: 'Description (Optional)',
                      hintText: 'Enter loan purpose',
                      prefixIcon: Icons.description,
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
                          label: 'Loan Date',
                          hintText: 'Select date',
                          prefixIcon: Icons.calendar_today,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      text: 'Add Loan',
                      onPressed: _addLoan,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Loan List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('loans')
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

                  final loans = snapshot.data!.docs;

                  if (loans.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: const Color(0xFF94A3B8),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No loans recorded',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your first loan above!',
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
                    itemCount: loans.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildLoanItem(loans[index]);
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
