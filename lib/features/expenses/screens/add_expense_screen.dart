import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/widgets/custom_text_field.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  DateTime? _selectedDate;
  String _selectedCategory = 'Food';
  final List<String> _categories = [
    'Food',
    'Transportation',
    'Utilities',
    'Entertainment',
    'Shopping',
    'Healthcare',
    'Education',
    'Other'
  ];

  Future<void> _addExpense() async {
    if (_amountController.text.isEmpty) {
      CustomDialog.showError(context, 'Please enter amount');
      return;
    }

    try {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        CustomDialog.showError(context, 'Please enter valid amount');
        return;
      }

      CustomDialog.showLoading(context, 'Adding expense...');

      final expenseData = {
        'amount': amount,
        'description': _descriptionController.text,
        'category': _selectedCategory,
        'date': _selectedDate?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'userId': _currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('expenses')
          .add(expenseData);

      // Clear fields
      _amountController.clear();
      _descriptionController.clear();
      _categoryController.clear();
      _dateController.clear();
      setState(() {
        _selectedDate = null;
        _selectedCategory = 'Food';
      });

      CustomDialog.dismiss(context);
      CustomDialog.showSuccess(context, 'Expense added successfully!');
    } catch (e) {
      CustomDialog.dismiss(context);
      CustomDialog.showError(context, 'Error adding expense: $e');
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
          'Add Expense',
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
        child: SingleChildScrollView(
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
                        'Enter Expense Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _amountController,
                        label: 'Amount',
                        hintText: 'Enter amount',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.money,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _descriptionController,
                        label: 'Description (Optional)',
                        hintText: 'Enter description',
                        prefixIcon: Icons.description,
                      ),
                      const SizedBox(height: 16),
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
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            dropdownColor: const Color(0xFF1E293B),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor:
                                  const Color(0xFF1E293B).withOpacity(0.7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                            items: _categories
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(
                                        category,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value!;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                      CustomButton(
                        text: 'Add Expense',
                        onPressed: _addExpense,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
