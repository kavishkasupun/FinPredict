import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_dialog.dart';

class IncomeListScreen extends StatefulWidget {
  final String userId;

  const IncomeListScreen({super.key, required this.userId});

  @override
  State<IncomeListScreen> createState() => _IncomeListScreenState();
}

class _IncomeListScreenState extends State<IncomeListScreen> {
  double _totalIncome = 0.0;
  Map<String, double> _incomeTypeTotals = {};
  String _selectedPeriod = 'This Month';
  final List<String> _periods = [
    'This Month',
    'Last Month',
    'This Year',
    'All Time'
  ];

  Future<void> _loadIncomeSummary() async {
    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      switch (_selectedPeriod) {
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Last Month':
          startDate = DateTime(now.year, now.month - 1, 1);
          endDate = DateTime(now.year, now.month, 0);
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          break;
        case 'All Time':
          startDate = DateTime(2000, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('income')
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date', descending: true)
          .get();

      double total = 0.0;
      final Map<String, double> typeTotals = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num).toDouble();
        final type = data['incomeType'] as String;

        total += amount;
        typeTotals.update(
          type,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      }

      setState(() {
        _totalIncome = total;
        _incomeTypeTotals = typeTotals;
      });
    } catch (e) {
      CustomDialog.showError(context, 'Error loading income: $e');
    }
  }

  Future<void> _deleteIncome(String incomeId) async {
    final confirmed = await CustomDialog.showConfirmation(
      context,
      'Delete Income',
      'Are you sure you want to delete this income record?',
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('income')
            .doc(incomeId)
            .delete();

        await _loadIncomeSummary();
        CustomDialog.showSuccess(context, 'Income deleted successfully');
      } catch (e) {
        CustomDialog.showError(context, 'Error deleting income: $e');
      }
    }
  }

  Color _getIncomeTypeColor(String type) {
    final colors = {
      'Salary': const Color(0xFF10B981),
      'Business': const Color(0xFF3B82F6),
      'Investment': const Color(0xFF8B5CF6),
      'Freelance': const Color(0xFFEC4899),
      'Rental': const Color(0xFFF59E0B),
      'Pension': const Color(0xFF06B6D4),
      'Other': const Color(0xFF94A3B8),
    };
    return colors[type] ?? const Color(0xFF94A3B8);
  }

  @override
  void initState() {
    super.initState();
    _loadIncomeSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Income History',
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
      body: Column(
        children: [
          // Period Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _periods.map((period) {
                  final isSelected = period == _selectedPeriod;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPeriod = period;
                        });
                        _loadIncomeSummary();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFBA002),
                                    Color(0xFFF59E0B)
                                  ],
                                )
                              : null,
                          color: isSelected ? null : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Text(
                          period,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GlassCard(
              width: double.infinity,
              borderRadius: 25,
              blur: 20,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Income Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rs. ${_totalIncome.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Income ($_selectedPeriod)',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                    if (_incomeTypeTotals.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFF334155)),
                      const SizedBox(height: 12),
                      const Text(
                        'By Type',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._incomeTypeTotals.entries.map((entry) {
                        final percentage = _totalIncome > 0
                            ? (entry.value / _totalIncome) * 100
                            : 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getIncomeTypeColor(entry.key),
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
                                'Rs. ${entry.value.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Color(0xFFF1F5F9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.right,
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
          ),
          const SizedBox(height: 20),

          // Income List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('income')
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
                    child: CircularProgressIndicator(color: Color(0xFFFBA002)),
                  );
                }

                final incomes = snapshot.data!.docs;

                if (incomes.isEmpty) {
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
                          'No income recorded',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add your first income from home screen!',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: incomes.length,
                  itemBuilder: (context, index) {
                    final income =
                        incomes[index].data() as Map<String, dynamic>;
                    final date = DateTime.parse(income['date']);
                    final amount = (income['amount'] as num).toDouble();
                    final type = income['incomeType'] as String;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        width: double.infinity,
                        borderRadius: 20,
                        blur: 10,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      income['source'] ?? type,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert,
                                        color: const Color(0xFF94A3B8)),
                                    color: const Color(0xFF1E293B),
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteIncome(incomes[index].id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete,
                                                color: const Color(0xFFEF4444),
                                                size: 20),
                                            const SizedBox(width: 8),
                                            const Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.white)),
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getIncomeTypeColor(type)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: _getIncomeTypeColor(type)),
                                    ),
                                    child: Text(
                                      type,
                                      style: TextStyle(
                                        color: _getIncomeTypeColor(type),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFF3B82F6)),
                                    ),
                                    child: Text(
                                      income['frequency'] ?? 'One-time',
                                      style: const TextStyle(
                                        color: Color(0xFF3B82F6),
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
                              if (income['description'] != null &&
                                  income['description'].isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  income['description'],
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      color: Color(0xFF10B981),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
