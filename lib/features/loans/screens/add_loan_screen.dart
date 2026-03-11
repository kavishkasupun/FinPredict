import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/widgets/custom_text_field.dart';

class AddLoanScreen extends StatefulWidget {
  final String? initialBorrowerName;

  const AddLoanScreen({super.key, this.initialBorrowerName});

  @override
  _AddLoanScreenState createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final TextEditingController _borrowerController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  DateTime? _selectedDate;

  // Suggest existing borrowers
  List<String> _existingBorrowers = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBorrowerName != null) {
      _borrowerController.text = widget.initialBorrowerName!;
    }
    _loadExistingBorrowers();
  }

  Future<void> _loadExistingBorrowers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('loans')
          .get();

      final borrowers = snapshot.docs
          .map((doc) => doc.data()['borrower'] as String)
          .toSet()
          .toList();

      setState(() {
        _existingBorrowers = borrowers;
      });
    } catch (e) {
      print('Error loading borrowers: $e');
    }
  }

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
        'borrower': _borrowerController.text.trim(),
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

      CustomDialog.dismiss(context);
      CustomDialog.showSuccess(context, 'Loan added successfully!');

      // Check if this is an existing borrower
      final isExistingBorrower =
          _existingBorrowers.contains(_borrowerController.text.trim());

      if (isExistingBorrower) {
        // Show option to add another loan for same borrower
        _showAddAnotherForSameBorrower();
      } else {
        // Clear fields and go back
        _clearFields();
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context);
        });
      }
    } catch (e) {
      CustomDialog.dismiss(context);
      CustomDialog.showError(context, 'Error adding loan: $e');
    }
  }

  void _showAddAnotherForSameBorrower() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Success!',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loan added successfully!',
              style: TextStyle(color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            Text(
              'Do you want to add another loan for ${_borrowerController.text.trim()}?',
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearFields();
              Navigator.pop(context); // Go back to list
            },
            child: const Text(
              'No, Go Back',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearFields();
              // Keep the borrower name
              setState(() {
                _borrowerController.text = widget.initialBorrowerName ?? '';
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

  void _clearFields() {
    _amountController.clear();
    _descriptionController.clear();
    _dateController.clear();
    setState(() {
      _selectedDate = null;
    });
  }

  List<String> _getBorrowerSuggestions(String query) {
    if (query.isEmpty) return [];
    return _existingBorrowers
        .where(
            (borrower) => borrower.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Add New Loan',
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
        child: GlassCard(
          width: double.infinity,
          borderRadius: 25,
          blur: 20,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Loan Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Borrower field with suggestions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(
                      controller: _borrowerController,
                      label: 'Borrower Name',
                      hintText: 'Enter borrower name',
                      prefixIcon: Icons.person,
                      onChanged: (value) {
                        setState(() {
                          _showSuggestions = value.isNotEmpty;
                        });
                      },
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) {
                          Future.delayed(const Duration(milliseconds: 200), () {
                            setState(() {
                              _showSuggestions = false;
                            });
                          });
                        }
                      },
                    ),
                    if (_showSuggestions && _borrowerController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          children:
                              _getBorrowerSuggestions(_borrowerController.text)
                                  .map((suggestion) => ListTile(
                                        dense: true,
                                        title: Text(
                                          suggestion,
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        leading: const Icon(
                                          Icons.person_outline,
                                          color: Color(0xFFFBA002),
                                          size: 20,
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _borrowerController.text =
                                                suggestion;
                                            _showSuggestions = false;
                                          });
                                        },
                                      ))
                                  .toList(),
                        ),
                      ),
                  ],
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
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Add Loan',
                  onPressed: _addLoan,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
