import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_text_field.dart';
import 'package:finpredict/widgets/custom_dialog.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  DateTime? _selectedDate;
  String _selectedIncomeType = 'Salary';
  String _selectedFrequency = 'Monthly';

  final List<String> _incomeTypes = [
    'Salary',
    'Business',
    'Investment',
    'Freelance',
    'Rental',
    'Pension',
    'Other'
  ];

  final List<String> _frequencies = [
    'One-time',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _addIncome() async {
    // Validation - show error popup
    if (_amountController.text.isEmpty) {
      CustomDialog.showError(context, 'Please enter amount');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      CustomDialog.showError(context, 'Please enter valid amount');
      return;
    }

    // Show loading popup
    CustomDialog.showLoading(context, 'Adding income...');

    try {
      final incomeData = {
        'amount': amount,
        'source': _sourceController.text,
        'description': _descriptionController.text,
        'incomeType': _selectedIncomeType,
        'frequency': _selectedFrequency,
        'date': _selectedDate?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'userId': _currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('income')
          .add(incomeData);

      // Update user's total income in user document
      await _updateUserTotalIncome(amount);

      // Clear fields
      _amountController.clear();
      _sourceController.clear();
      _descriptionController.clear();

      setState(() {
        _selectedDate = DateTime.now();
        _selectedIncomeType = 'Salary';
        _selectedFrequency = 'Monthly';
        _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      });

      // Dismiss loading popup
      CustomDialog.dismiss(context);

      // Show success popup
      CustomDialog.showSuccess(context, 'Income added successfully!');

      // Wait a bit then navigate back
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        CustomDialog.dismiss(context); // Dismiss success popup
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Dismiss loading popup
      CustomDialog.dismiss(context);

      // Show error popup with details
      CustomDialog.showError(context, 'Error adding income: $e');
    }
  }

  Future<void> _updateUserTotalIncome(double newAmount) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (snapshot.exists) {
          final currentTotal =
              (snapshot.data()?['totalIncome'] as num?)?.toDouble() ?? 0.0;
          final currentMonthlyIncome =
              (snapshot.data()?['monthlyIncome'] as num?)?.toDouble() ?? 0.0;

          transaction.update(userRef, {
            'totalIncome': currentTotal + newAmount,
            'monthlyIncome': _selectedFrequency == 'Monthly'
                ? currentMonthlyIncome + newAmount
                : currentMonthlyIncome,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error updating total income: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
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
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
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
          'Add Income',
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
            GlassCard(
              width: double.infinity,
              borderRadius: 25,
              blur: 20,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Enter Income Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount Field
                    CustomTextField(
                      controller: _amountController,
                      label: 'Amount (Rs.)',
                      hintText: 'Enter amount',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.currency_rupee,
                    ),
                    const SizedBox(height: 16),

                    // Income Type Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Income Type',
                          style: TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButton<String>(
                            value: _selectedIncomeType,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFFFBA002)),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                            items: _incomeTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedIncomeType = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Frequency Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Frequency',
                          style: TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButton<String>(
                            value: _selectedFrequency,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFFFBA002)),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                            items: _frequencies.map((freq) {
                              return DropdownMenuItem(
                                value: freq,
                                child: Text(freq),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedFrequency = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Source Field
                    CustomTextField(
                      controller: _sourceController,
                      label: 'Source (Optional)',
                      hintText: 'e.g., Company Name, Business',
                      prefixIcon: Icons.business_center,
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    CustomTextField(
                      controller: _descriptionController,
                      label: 'Description (Optional)',
                      hintText: 'Additional details',
                      prefixIcon: Icons.description,
                    ),
                    const SizedBox(height: 16),

                    // Date Field
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _dateController,
                          label: 'Date',
                          hintText: 'Select date',
                          prefixIcon: Icons.calendar_today,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Add Button
                    CustomButton(
                      text: 'Add Income',
                      onPressed: _addIncome,
                      width: double.infinity,
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
