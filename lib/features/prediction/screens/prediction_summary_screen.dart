// lib/features/prediction/screens/prediction_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:lottie/lottie.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/services/ml_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PredictionSummaryScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final double currentIncome;
  final double currentExpense;
  final double savings;
  final Map<String, dynamic>? aiPrediction;
  final Map<String, dynamic>? forecast;
  final String userId;

  const PredictionSummaryScreen({
    super.key,
    this.userData,
    required this.currentIncome,
    required this.currentExpense,
    required this.savings,
    this.aiPrediction,
    this.forecast,
    required this.userId,
  });

  @override
  State<PredictionSummaryScreen> createState() =>
      _PredictionSummaryScreenState();
}

class _PredictionSummaryScreenState extends State<PredictionSummaryScreen> {
  final MLService _mlService = MLService();
  Map<String, dynamic>? _detailedSummary;
  bool _isLoading = false;
  List<double> _previousExpenses = [];
  String _selectedPeriod = 'weekly'; // 'daily' or 'weekly'

  // Colors based on expense level
  Color _getExpenseColor(double percentage) {
    if (percentage >= 90) return const Color(0xFFEF4444); // Red
    if (percentage >= 80) return const Color(0xFFF59E0B); // Orange
    if (percentage >= 70) return const Color(0xFFFBA002); // Yellow
    return const Color(0xFF10B981); // Green
  }

  // ============================================
  // FIXED: Use the same prediction as home screen
  // ============================================
  double _getPredictedMonthlyExpense() {
    // First try from detailed summary
    if (_detailedSummary != null &&
        _detailedSummary!.containsKey('predicted_monthly_expense')) {
      return _detailedSummary!['predicted_monthly_expense'];
    }

    // Then try from aiPrediction
    if (widget.aiPrediction != null &&
        widget.aiPrediction!.containsKey('predicted_monthly_expense')) {
      return widget.aiPrediction!['predicted_monthly_expense'];
    }

    // Try from forecast
    if (widget.forecast != null &&
        widget.forecast!.containsKey('monthlyProjection')) {
      return widget.forecast!['monthlyProjection'];
    }

    // Fallback to current expense + 10%
    return widget.currentExpense * 1.1;
  }

  // ============================================
  // FIXED: Get AI insight message based on warning level
  // ============================================
  String _getAIInsightMessage() {
    final warningLevel = _detailedSummary?['warningLevel'] ??
        widget.aiPrediction?['warningLevel'] ??
        'good';
    final expensePercentage = widget.currentIncome > 0
        ? (widget.currentExpense / widget.currentIncome * 100).round()
        : 0;
    final predictedExpense = _getPredictedMonthlyExpense();

    switch (warningLevel) {
      case 'critical':
        return '⚠️ CRITICAL: You\'ve spent $expensePercentage% of your income! Projected to reach ${(predictedExpense / widget.currentIncome * 100).round()}% by month end.';
      case 'high':
        return '⚠️ HIGH SPENDING: You\'ve spent $expensePercentage% of your income. Projected to reach ${(predictedExpense / widget.currentIncome * 100).round()}% by month end.';
      case 'moderate':
        return 'ℹ️ MODERATE: You\'ve spent $expensePercentage% of your income. Projected to reach ${(predictedExpense / widget.currentIncome * 100).round()}% by month end.';
      case 'good':
        return '✅ GOOD JOB! You\'ve spent only $expensePercentage% of your income. Projected to reach ${(predictedExpense / widget.currentIncome * 100).round()}% by month end.';
      default:
        return _detailedSummary?['detailedMessage'] ??
            widget.aiPrediction?['detailedMessage'] ??
            'No insights available';
    }
  }

  // ============================================
  // FIXED: Get advice based on warning level
  // ============================================
  String _getAdviceMessage() {
    final warningLevel = _detailedSummary?['warningLevel'] ??
        widget.aiPrediction?['warningLevel'] ??
        'good';
    final userType = _detailedSummary?['userTypeDisplay'] ??
        widget.aiPrediction?['userTypeDisplay'] ??
        widget.userData?['userType'] ??
        'General User';
    final savings = widget.savings;
    final predictedExpense = _getPredictedMonthlyExpense();
    final willOverspend = predictedExpense > widget.currentIncome;

    if (willOverspend) {
      return '⚠️ You may overspend this month. Current expenses: Rs. ${widget.currentExpense.toStringAsFixed(0)}, Projected: Rs. ${predictedExpense.toStringAsFixed(0)}. Reduce spending now!';
    }

    switch (warningLevel) {
      case 'critical':
        if (userType.toLowerCase().contains('self-employed')) {
          return 'Critical alert! Create an emergency budget, cut all non-essential expenses, and set aside money for taxes.';
        } else if (userType.toLowerCase().contains('student')) {
          return 'Critical! Look for student discounts, reduce eating out, and consider part-time work if possible.';
        } else {
          return 'Urgent! Create a strict budget, cancel unused subscriptions, and find ways to increase income.';
        }
      case 'high':
        if (userType.toLowerCase().contains('self-employed')) {
          return 'Your spending is high. Track business vs personal expenses and build a 3-month emergency fund.';
        } else {
          return 'High spending detected. Review your monthly subscriptions and dining out expenses.';
        }
      case 'moderate':
        if (savings < 0) {
          return 'You\'re in negative savings. Focus on reducing expenses to get back to positive savings.';
        } else {
          return 'You\'re doing okay but aim to save at least 20% of your income for long-term goals.';
        }
      case 'good':
        if (savings > widget.currentIncome * 0.3) {
          return 'Excellent savings rate! Consider investing your extra savings for better returns.';
        } else {
          return 'Great job! You\'re on track. Consider automating your savings each month.';
        }
      default:
        return _detailedSummary?['advice'] ??
            widget.aiPrediction?['advice'] ??
            'Track your expenses regularly to get better insights';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDetailedSummary();
  }

  Future<void> _loadDetailedSummary() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get previous expenses (last 6 months)
      await _loadPreviousExpenses();

      // Prepare user features
      final userFeatures = {
        'age': widget.userData?['age'] ?? 30,
        'dependents': widget.userData?['dependents'] ?? 0,
        'savings': widget.savings,
        'budget': widget.userData?['monthlyBudget'] ?? 60000,
        'employmentType': widget.userData?['employmentType'] ??
            widget.userData?['userType'] ??
            'employee',
        'userType': widget.userData?['userType'] ?? 'General User',
        'monthlyIncome': widget.currentIncome,
      };

      // Get comprehensive financial summary
      final summary = await _mlService.getFinancialSummary(
        monthlyIncome: widget.currentIncome,
        monthlyExpenses: widget.currentExpense,
        userFeatures: userFeatures,
        previousExpenses: _previousExpenses,
      );

      setState(() {
        _detailedSummary = summary;
      });
    } catch (e) {
      print('Error loading detailed summary: $e');
      // Fallback to passed predictions
      setState(() {
        _detailedSummary = {
          'hasData': widget.currentIncome > 0,
          'userType': widget.aiPrediction?['userTypeDisplay'] ?? 'General User',
          'userTypeDisplay':
              widget.aiPrediction?['userTypeDisplay'] ?? 'General User',
          'monthlyIncome': widget.currentIncome,
          'monthlyExpenses': widget.currentExpense,
          'savings': widget.savings,
          'savingsRate': widget.currentIncome > 0
              ? (widget.savings / widget.currentIncome * 100)
              : 0,
          'expensePercentage': widget.currentIncome > 0
              ? (widget.currentExpense / widget.currentIncome * 100).round()
              : 0,
          'alert': widget.aiPrediction,
          'daily': widget.forecast,
          'message': widget.aiPrediction?['message'] ?? 'No data',
          'detailedMessage': widget.aiPrediction?['detailedMessage'] ??
              'Add transactions to see insights',
          'shortMessage': widget.aiPrediction?['shortMessage'] ?? 'Welcome!',
          'advice':
              widget.aiPrediction?['advice'] ?? 'Start tracking your expenses',
          'warningLevel': widget.aiPrediction?['warningLevel'] ?? 'good',
          'predicted_monthly_expense': _getPredictedMonthlyExpense(),
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPreviousExpenses() async {
    try {
      final now = DateTime.now();
      _previousExpenses = [];

      for (int i = 1; i <= 6; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final firstDay = DateTime(month.year, month.month, 1);
        final lastDay = DateTime(month.year, month.month + 1, 0);

        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('expenses')
            .where('date', isGreaterThanOrEqualTo: firstDay.toIso8601String())
            .where('date', isLessThanOrEqualTo: lastDay.toIso8601String())
            .get();

        double total = 0.0;
        for (var doc in snapshot.docs) {
          total += (doc.data()['amount'] as num).toDouble();
        }
        _previousExpenses.add(total);
      }
    } catch (e) {
      print('Error loading previous expenses: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensePercentage = widget.currentIncome > 0
        ? (widget.currentExpense / widget.currentIncome * 100)
        : 0.0;
    final expenseColor = _getExpenseColor(expensePercentage);

    final hasData = widget.currentIncome > 0 || widget.currentExpense > 0;
    final warningLevel = _detailedSummary?['warningLevel'] ??
        widget.aiPrediction?['warningLevel'] ??
        'good';
    final userType = _detailedSummary?['userTypeDisplay'] ??
        widget.aiPrediction?['userTypeDisplay'] ??
        widget.userData?['userType'] ??
        'General User';

    final predictedMonthlyExpense = _getPredictedMonthlyExpense();
    final projectedStatus = predictedMonthlyExpense > widget.currentIncome
        ? '⚠️ May Overspend'
        : '✅ On Track';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AI Financial Summary',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ============================================
                  // UPDATED: Finpredict.json animation for loading
                  // ============================================
                  Container(
                    width: 200,
                    height: 200,
                    child: Lottie.asset(
                      'assets/animations/Finpredict.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Analyzing your finances...',
                    style: TextStyle(
                      color: const Color(0xFF94A3B8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // User Type Card
                  GlassCard(
                    width: double.infinity,
                    borderRadius: 20,
                    blur: 15,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: expenseColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_outline,
                              color: expenseColor,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Profile',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userType,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _detailedSummary?['userTypePatterns']
                                          ?['description'] ??
                                      'Track your expenses to get personalized insights',
                                  style: TextStyle(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Current Status Card with Projection
                  GlassCard(
                    width: double.infinity,
                    borderRadius: 20,
                    blur: 15,
                    gradient: LinearGradient(
                      colors: [
                        expenseColor.withOpacity(0.2),
                        const Color(0xFF1E293B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Current Month Status',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: expenseColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  warningLevel.toUpperCase(),
                                  style: TextStyle(
                                    color: expenseColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatusItem(
                                  'Income',
                                  'Rs. ${widget.currentIncome.toStringAsFixed(0)}',
                                  Icons.arrow_upward,
                                  const Color(0xFF10B981),
                                ),
                              ),
                              Expanded(
                                child: _buildStatusItem(
                                  'Expenses',
                                  'Rs. ${widget.currentExpense.toStringAsFixed(0)}',
                                  Icons.arrow_downward,
                                  expenseColor,
                                ),
                              ),
                              Expanded(
                                child: _buildStatusItem(
                                  'Savings',
                                  'Rs. ${widget.savings.toStringAsFixed(0)}',
                                  Icons.savings,
                                  widget.savings >= 0
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ============================================
                          // FIXED: Monthly Projection Card
                          // ============================================
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: predictedMonthlyExpense >
                                        widget.currentIncome
                                    ? const Color(0xFFEF4444).withOpacity(0.5)
                                    : const Color(0xFF10B981).withOpacity(0.5),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Projected Month End',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: predictedMonthlyExpense >
                                                widget.currentIncome
                                            ? const Color(0xFFEF4444)
                                                .withOpacity(0.2)
                                            : const Color(0xFF10B981)
                                                .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        projectedStatus,
                                        style: TextStyle(
                                          color: predictedMonthlyExpense >
                                                  widget.currentIncome
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF10B981),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Current',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          'Rs. ${widget.currentExpense.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: const Color(0xFFFBA002),
                                      size: 20,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Projected',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          'Rs. ${predictedMonthlyExpense.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: predictedMonthlyExpense >
                                                    widget.currentIncome
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF10B981),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Expense percentage bar
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Current Expense Ratio',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${expensePercentage.round()}%',
                                    style: TextStyle(
                                      color: expenseColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: expensePercentage / 100,
                                  backgroundColor: const Color(0xFF334155),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    expenseColor,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Projected Ratio',
                                    style: TextStyle(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    '${(predictedMonthlyExpense / widget.currentIncome * 100).round()}%',
                                    style: TextStyle(
                                      color: predictedMonthlyExpense >
                                              widget.currentIncome
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF10B981),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ============================================
                  // FIXED: AI Insights Card with consistent message
                  // ============================================
                  GlassCard(
                    width: double.infinity,
                    borderRadius: 20,
                    blur: 15,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: expenseColor,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'AI Insights',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      warningLevel == 'critical' ||
                                              warningLevel == 'high'
                                          ? Icons.warning
                                          : Icons.check_circle,
                                      color: expenseColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _getAIInsightMessage(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: Color(0xFF334155)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lightbulb,
                                      color: const Color(0xFFFBA002),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _getAdviceMessage(),
                                        style: TextStyle(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Prediction Period Selector
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPeriod = 'daily';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedPeriod == 'daily'
                                  ? const Color(0xFFFBA002).withOpacity(0.2)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedPeriod == 'daily'
                                    ? const Color(0xFFFBA002)
                                    : Colors.transparent,
                              ),
                            ),
                            child: const Text(
                              'Daily',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPeriod = 'weekly';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedPeriod == 'weekly'
                                  ? const Color(0xFFFBA002).withOpacity(0.2)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedPeriod == 'weekly'
                                    ? const Color(0xFFFBA002)
                                    : Colors.transparent,
                              ),
                            ),
                            child: const Text(
                              'Weekly',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Prediction Chart
                  GlassCard(
                    width: double.infinity,
                    borderRadius: 20,
                    blur: 15,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPeriod == 'daily'
                                ? 'Daily Expense Prediction'
                                : 'Weekly Expense Prediction',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_detailedSummary != null &&
                              _detailedSummary!['hasData'] == true)
                            _buildPredictionChart()
                          else
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.show_chart,
                                      color: const Color(0xFF94A3B8),
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Add more data to see predictions',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Savings Projection Card
                  GlassCard(
                    width: double.infinity,
                    borderRadius: 20,
                    blur: 15,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Savings Projection',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildProjectionItem(
                                  'Monthly',
                                  'Rs. ${widget.savings.toStringAsFixed(0)}',
                                  widget.savings >= 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                              Expanded(
                                child: _buildProjectionItem(
                                  'Yearly',
                                  'Rs. ${(widget.savings * 12).toStringAsFixed(0)}',
                                  widget.savings >= 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                              Expanded(
                                child: _buildProjectionItem(
                                  '5 Years',
                                  'Rs. ${(widget.savings * 12 * 5).toStringAsFixed(0)}',
                                  widget.savings >= 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: const Color(0xFFFBA002),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Based on your current savings rate of '
                                    '${_detailedSummary?['savingsRate']?.round() ?? 0}%',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ============================================
                  // FIXED: Recommendations Card
                  // ============================================
                  GlassCard(
                    width: double.infinity,
                    borderRadius: 20,
                    blur: 15,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF3B82F6).withOpacity(0.2),
                        const Color(0xFF1E293B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.recommend,
                                color: const Color(0xFF3B82F6),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Personalized Recommendations',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Dynamic recommendations based on warning level and projection
                          if (predictedMonthlyExpense >
                              widget.currentIncome) ...[
                            _buildRecommendationItem(
                              'Reduce Spending Now',
                              'You may overspend this month. Cut discretionary expenses immediately.',
                              Icons.warning,
                              isUrgent: true,
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (warningLevel == 'critical') ...[
                            _buildRecommendationItem(
                              'Emergency Budget Needed',
                              'Create a strict budget and cut all non-essential spending immediately',
                              Icons.warning,
                              isUrgent: true,
                            ),
                            const SizedBox(height: 12),
                            _buildRecommendationItem(
                              'Review All Expenses',
                              'List every expense and identify what can be eliminated',
                              Icons.receipt_long,
                            ),
                          ] else if (warningLevel == 'high') ...[
                            _buildRecommendationItem(
                              'Reduce Discretionary Spending',
                              'Cut back on dining out, entertainment, and non-essential shopping',
                              Icons.restaurant,
                              isUrgent: true,
                            ),
                            const SizedBox(height: 12),
                            _buildRecommendationItem(
                              'Review Subscriptions',
                              'Cancel unused subscriptions like streaming services or gym memberships',
                              Icons.subscriptions,
                            ),
                          ] else if (warningLevel == 'moderate') ...[
                            _buildRecommendationItem(
                              'Set Savings Goals',
                              'Aim to save at least 20% of your income each month',
                              Icons.flag,
                            ),
                            const SizedBox(height: 12),
                            _buildRecommendationItem(
                              'Build Emergency Fund',
                              'Save 3-6 months of expenses for emergencies',
                              Icons.savings,
                            ),
                          ] else if (warningLevel == 'good') ...[
                            _buildRecommendationItem(
                              'Invest Your Savings',
                              'Consider investing extra savings for long-term growth',
                              Icons.trending_up,
                            ),
                            const SizedBox(height: 12),
                            _buildRecommendationItem(
                              'Automate Savings',
                              'Set up automatic transfers to savings each month',
                              Icons.auto_awesome,
                            ),
                          ],

                          const SizedBox(height: 12),
                          _buildRecommendationItem(
                            'Track Daily Expenses',
                            'Log expenses immediately to avoid forgetting',
                            Icons.today,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Add Expense',
                          onPressed: () {
                            Navigator.pop(context);
                            // Navigate to add expense
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Add Income',
                          onPressed: () {
                            Navigator.pop(context);
                            // Navigate to add income
                          },
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildProjectionItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildRecommendationItem(
      String title, String description, IconData icon,
      {bool isUrgent = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color:
                (isUrgent ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
                    .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
            size: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionChart() {
    if (_selectedPeriod == 'daily') {
      final dailyDataRaw = _detailedSummary?['daily']?['weekly'] as List?;

      if (dailyDataRaw == null || dailyDataRaw.isEmpty) {
        return const Center(
          child: Text(
            'No daily predictions available',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        );
      }

      // Cast List<dynamic> to List<Map<String, dynamic>>
      final List<Map<String, dynamic>> dailyData =
          dailyDataRaw.map((item) => item as Map<String, dynamic>).toList();

      return SizedBox(
        height: 200,
        child: SfCartesianChart(
          backgroundColor: Colors.transparent,
          primaryXAxis: CategoryAxis(
            majorGridLines: const MajorGridLines(width: 0),
            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          ),
          primaryYAxis: NumericAxis(
            majorGridLines: MajorGridLines(
              color: const Color(0xFF334155).withOpacity(0.3),
            ),
            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          ),
          series: <CartesianSeries>[
            ColumnSeries<Map<String, dynamic>, String>(
              dataSource: dailyData.take(7).toList(),
              xValueMapper: (data, _) => DateFormat('E').format(data['date']),
              yValueMapper: (data, _) => data['predicted'],
              color: const Color(0xFFFBA002),
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else {
      // Weekly predictions
      return Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'This Week',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${_detailedSummary?['daily']?['weeklyTotal']?.toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              height: 40,
              width: 1,
              color: const Color(0xFF334155),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Monthly Projection',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${_getPredictedMonthlyExpense().toStringAsFixed(0)}',
                  style: TextStyle(
                    color: _getPredictedMonthlyExpense() > widget.currentIncome
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
}
