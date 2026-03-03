import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/services/firebase_service.dart';
import 'package:finpredict/services/ml_service.dart';
import 'package:finpredict/services/notification_service.dart';
import 'package:finpredict/features/profile/screens/profile_screen.dart';
import 'package:finpredict/features/expenses/screens/add_expense_screen.dart';
import 'package:finpredict/features/expenses/screens/expense_list_screen.dart';
import 'package:finpredict/features/income/screens/add_income_screen.dart';
import 'package:finpredict/features/income/screens/income_list_screen.dart';
import 'package:finpredict/features/tasks/screens/task_screen.dart' as tasks;
import 'package:finpredict/features/loans/screens/loan_screen.dart' as loans;
import 'package:finpredict/features/chat/screens/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseService _firebaseService = FirebaseService();
  final MLService _mlService = MLService();
  final NotificationService _notificationService = NotificationService();

  User? _currentUser;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _recentExpenses = [];
  List<Map<String, dynamic>> _recentIncome = [];

  double _currentExpense = 0.0;
  double _currentIncome = 0.0;
  double _budgetLimit = 0.0;
  double _savings = 0.0;

  Map<String, dynamic>? _aiPrediction;
  Map<String, dynamic>? _forecast;

  bool _isLoading = true;
  bool _showExpenseWarning = false;
  String _selectedTimeRange = 'This Month';

  final List<String> _timeRanges = [
    'This Week',
    'This Month',
    'Last Month',
    'This Year'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mlService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  Future<void> _initializeApp() async {
    // Initialize ML Model
    await _mlService.loadModel();

    // Initialize Notifications
    await _notificationService.init();

    // Load user data
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUser = FirebaseAuth.instance.currentUser;

      if (_currentUser != null) {
        // Load user data from Firebase
        final userData = await _firebaseService.getUserData(_currentUser!.uid);

        if (userData != null) {
          setState(() {
            _userData = userData;
            _budgetLimit =
                (userData['monthlyBudget'] as num?)?.toDouble() ?? 60000.0;
          });

          // Load actual data
          await _loadCurrentMonthData();
          await _loadRecentTransactions();

          // Run AI prediction
          await _runAIPrediction();

          // Check expense alert
          _checkExpenseAlert();
        } else {
          _setDefaultUserData();
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      _setDefaultUserData();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadCurrentMonthData() async {
    try {
      if (_currentUser != null) {
        final now = DateTime.now();
        final firstDayOfMonth = DateTime(now.year, now.month, 1);
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

        // Get expenses for current month
        final expensesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('expenses')
            .where('date',
                isGreaterThanOrEqualTo: firstDayOfMonth.toIso8601String())
            .where('date',
                isLessThanOrEqualTo: lastDayOfMonth.toIso8601String())
            .get();

        // Get income for current month
        final incomeSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('income')
            .where('date',
                isGreaterThanOrEqualTo: firstDayOfMonth.toIso8601String())
            .where('date',
                isLessThanOrEqualTo: lastDayOfMonth.toIso8601String())
            .get();

        double totalExpenses = 0.0;
        for (var expense in expensesSnapshot.docs) {
          totalExpenses += (expense.data()['amount'] as num).toDouble();
        }

        double totalIncome = 0.0;
        for (var income in incomeSnapshot.docs) {
          totalIncome += (income.data()['amount'] as num).toDouble();
        }

        setState(() {
          _currentExpense = totalExpenses;
          _currentIncome = totalIncome;
          _savings = _currentIncome - _currentExpense;
        });
      }
    } catch (e) {
      print('Error loading month data: $e');
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      if (_currentUser != null) {
        // Load recent expenses
        final expensesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('expenses')
            .orderBy('date', descending: true)
            .limit(5)
            .get();

        _recentExpenses = expensesSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          data['type'] = 'expense';
          return data;
        }).toList();

        // Load recent income
        final incomeSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('income')
            .orderBy('date', descending: true)
            .limit(5)
            .get();

        _recentIncome = incomeSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          data['type'] = 'income';
          return data;
        }).toList();
      }
    } catch (e) {
      print('Error loading recent transactions: $e');
    }
  }

  Future<void> _runAIPrediction() async {
    try {
      // Get previous expenses for forecasting
      final previousExpenses = await _getPreviousExpenses(6); // Last 6 months

      // Prepare user features for ML model
      final userFeatures = {
        'age': _userData?['age'] ?? 30,
        'dependents': _userData?['dependents'] ?? 0,
        'savings': _savings,
        'budget': _budgetLimit,
        'employment_type': _userData?['employmentType'] ?? 'employee',
      };

      // Get AI prediction
      final prediction = await _mlService.predictExpenseAlert(
        monthlyIncome: _currentIncome,
        monthlyExpenses: _currentExpense,
        userFeatures: userFeatures,
      );

      // Get forecast
      final forecast = await _mlService.forecastNextMonth(
        monthlyIncome: _currentIncome,
        monthlyExpenses: _currentExpense,
        previousExpenses: previousExpenses,
      );

      setState(() {
        _aiPrediction = prediction;
        _forecast = forecast;
      });

      // Show notification if alert is triggered
      if (prediction['alert'] == true) {
        await _notificationService.showExpenseAlert(
          currentExpense: _currentExpense,
          monthlyIncome: _currentIncome,
          percentage: (_currentExpense / _currentIncome) * 100,
          aiMessage: prediction['message'],
        );
      }
    } catch (e) {
      print('Error in AI prediction: $e');
    }
  }

  Future<List<double>> _getPreviousExpenses(int months) async {
    final List<double> expenses = [];
    try {
      final now = DateTime.now();

      for (int i = 1; i <= months; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final firstDay = DateTime(month.year, month.month, 1);
        final lastDay = DateTime(month.year, month.month + 1, 0);

        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('expenses')
            .where('date', isGreaterThanOrEqualTo: firstDay.toIso8601String())
            .where('date', isLessThanOrEqualTo: lastDay.toIso8601String())
            .get();

        double total = 0.0;
        for (var doc in snapshot.docs) {
          total += (doc.data()['amount'] as num).toDouble();
        }
        expenses.add(total);
      }
    } catch (e) {
      print('Error getting previous expenses: $e');
    }
    return expenses;
  }

  void _setDefaultUserData() {
    setState(() {
      _userData = {
        'name': _currentUser?.displayName ??
            _currentUser?.email?.split('@').first ??
            'User',
        'monthlyBudget': 60000.0,
        'currentExpense': 0.0,
      };
      _budgetLimit = 60000.0;
      _currentExpense = 0.0;
      _currentIncome = 0.0;
      _savings = 0.0;
    });
  }

  void _checkExpenseAlert() {
    if (_currentIncome <= 0) return;

    final expensePercentage = (_currentExpense / _currentIncome) * 100;
    setState(() {
      _showExpenseWarning =
          expensePercentage > 80 || (_aiPrediction?['alert'] == true);
    });

    if (_showExpenseWarning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomDialog.showWarning(
          context,
          _aiPrediction?['message'] ??
              '⚠️ Warning: Your expenses have reached ${expensePercentage.round()}% of your income! Consider reducing unnecessary spending.',
        );
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadUserData();
  }

  // Navigation methods
  void _navigateToAddExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
    ).then((_) => _refreshData());
  }

  void _navigateToAddIncome() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddIncomeScreen()),
    ).then((_) => _refreshData());
  }

  void _navigateToExpenseList() {
    if (_currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExpenseListScreen(userId: _currentUser!.uid),
        ),
      );
    }
  }

  void _navigateToIncomeList() {
    if (_currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncomeListScreen(userId: _currentUser!.uid),
        ),
      );
    }
  }

  void _navigateToTasks() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const tasks.TaskScreen()),
    ).then((_) => _refreshData());
  }

  void _navigateToLoans() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const loans.LoanScreen()),
    );
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFFFBA002),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading AI Model & Your Data...',
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // FIXED: Explicitly convert to double
    final double expensePercentage =
        (_currentIncome > 0) ? (_currentExpense / _currentIncome) * 100 : 0.0;

    final double savingsRate =
        (_currentIncome > 0) ? (_savings / _currentIncome) * 100 : 0.0;

    final userName = _userData?['name'] ??
        _currentUser?.displayName ??
        _currentUser?.email?.split('@').first ??
        'User';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            color: const Color(0xFFFBA002),
            backgroundColor: const Color(0xFF0F172A),
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 600 ? 24.0 : 16.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome Back,',
                                  style: TextStyle(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ProfileScreen()),
                              );
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF3B82F6).withOpacity(0.2),
                                    const Color(0xFF313B2F).withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF3B82F6),
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // AI Status Card
                      if (_aiPrediction != null) ...[
                        GlassCard(
                          width: double.infinity,
                          borderRadius: 20,
                          blur: 15,
                          gradient: LinearGradient(
                            colors: [
                              _aiPrediction!['alert'] == true
                                  ? const Color(0xFFEF4444).withOpacity(0.2)
                                  : const Color(0xFF10B981).withOpacity(0.2),
                              const Color(0xFF1E293B),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _aiPrediction!['alert'] == true
                                        ? const Color(0xFFEF4444)
                                            .withOpacity(0.2)
                                        : const Color(0xFF10B981)
                                            .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _aiPrediction!['alert'] == true
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle,
                                    color: _aiPrediction!['alert'] == true
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AI Analysis',
                                        style: TextStyle(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _aiPrediction!['message'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (_forecast != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _forecast!['message'],
                                          style: TextStyle(
                                            color: _forecast!['trend'] ==
                                                    'increasing'
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFF10B981),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Financial Overview Card
                      GlassCard(
                        width: double.infinity,
                        borderRadius: 25,
                        blur: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Financial Overview',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: DropdownButton<String>(
                                      value: _selectedTimeRange,
                                      dropdownColor: const Color(0xFF1E293B),
                                      underline: const SizedBox(),
                                      icon: const Icon(Icons.arrow_drop_down,
                                          color: Color(0xFFFBA002), size: 20),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                      items: _timeRanges.map((range) {
                                        return DropdownMenuItem(
                                          value: range,
                                          child: Text(range),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedTimeRange = value!;
                                        });
                                        _loadCurrentMonthData();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Stats Row
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 400;
                                  return isWide
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildStatCard(
                                              'Income',
                                              'Rs. ${_currentIncome.toStringAsFixed(0)}',
                                              Icons.trending_up,
                                              const Color(0xFF10B981),
                                            ),
                                            _buildStatCard(
                                              'Expenses',
                                              'Rs. ${_currentExpense.toStringAsFixed(0)}',
                                              Icons.trending_down,
                                              const Color(0xFFEF4444),
                                            ),
                                            _buildStatCard(
                                              'Savings',
                                              'Rs. ${_savings.toStringAsFixed(0)}',
                                              Icons.savings,
                                              _savings >= 0
                                                  ? const Color(0xFF3B82F6)
                                                  : const Color(0xFFEF4444),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                _buildStatCard(
                                                  'Income',
                                                  'Rs. ${_currentIncome.toStringAsFixed(0)}',
                                                  Icons.trending_up,
                                                  const Color(0xFF10B981),
                                                ),
                                                _buildStatCard(
                                                  'Expenses',
                                                  'Rs. ${_currentExpense.toStringAsFixed(0)}',
                                                  Icons.trending_down,
                                                  const Color(0xFFEF4444),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            _buildStatCard(
                                              'Savings',
                                              'Rs. ${_savings.toStringAsFixed(0)}',
                                              Icons.savings,
                                              _savings >= 0
                                                  ? const Color(0xFF3B82F6)
                                                  : const Color(0xFFEF4444),
                                            ),
                                          ],
                                        );
                                },
                              ),

                              const SizedBox(height: 20),

                              // Expense Gauge (now based on income)
                              SizedBox(
                                height: 180,
                                child: SfRadialGauge(
                                  axes: <RadialAxis>[
                                    RadialAxis(
                                      minimum: 0,
                                      maximum: 100,
                                      showLabels: false,
                                      showTicks: false,
                                      axisLineStyle: const AxisLineStyle(
                                        thickness: 0.1,
                                        cornerStyle: CornerStyle.bothCurve,
                                        color: Color(0xFF334155),
                                      ),
                                      pointers: <GaugePointer>[
                                        RangePointer(
                                          value:
                                              expensePercentage, // Now this is double
                                          width: 0.2,
                                          cornerStyle: CornerStyle.bothCurve,
                                          gradient: const SweepGradient(
                                            colors: <Color>[
                                              Color(0xFF10B981),
                                              Color(0xFFFBA002),
                                              Color(0xFFEF4444),
                                            ],
                                          ),
                                        ),
                                        MarkerPointer(
                                          value:
                                              expensePercentage, // Now this is double
                                          markerType: MarkerType.circle,
                                          color: Colors.white,
                                          borderWidth: 3,
                                          borderColor: const Color(0xFFFBA002),
                                          markerHeight: 15,
                                          markerWidth: 15,
                                        ),
                                      ],
                                      annotations: <GaugeAnnotation>[
                                        GaugeAnnotation(
                                          positionFactor: 0.1,
                                          widget: Text(
                                            '${expensePercentage.round()}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        GaugeAnnotation(
                                          positionFactor: 0.3,
                                          widget: Text(
                                            'of Income',
                                            style: TextStyle(
                                              color: const Color(0xFF94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Savings Rate
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: (_savings >= 0
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444))
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _savings >= 0
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                                child: Text(
                                  'Savings Rate: ${savingsRate.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: _savings >= 0
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickAction(
                              Icons.add_chart,
                              'Add Expense',
                              onTap: _navigateToAddExpense,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickAction(
                              Icons.account_balance_wallet,
                              'Add Income',
                              onTap: _navigateToAddIncome,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickAction(
                              Icons.list_alt,
                              'Expenses',
                              onTap: _navigateToExpenseList,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickAction(
                              Icons.analytics,
                              'Income',
                              onTap: _navigateToIncomeList,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickAction(
                              Icons.task,
                              'Tasks',
                              onTap: _navigateToTasks,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickAction(
                              Icons.money,
                              'Loans',
                              onTap: _navigateToLoans,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickAction(
                              Icons.chat,
                              'AI Chat',
                              onTap: _navigateToChat,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Recent Transactions
                      GlassCard(
                        width: double.infinity,
                        borderRadius: 25,
                        blur: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recent Transactions',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_recentExpenses.isEmpty &&
                                  _recentIncome.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.receipt,
                                          color: const Color(0xFF94A3B8),
                                          size: 48,
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'No transactions yet',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else ...[
                                // Combine and sort recent transactions
                                ..._getCombinedTransactions()
                                    .map((transaction) {
                                  final isExpense =
                                      transaction['type'] == 'expense';
                                  final date =
                                      DateTime.parse(transaction['date']);
                                  final amount =
                                      (transaction['amount'] as num).toDouble();

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: (isExpense
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF10B981))
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            isExpense
                                                ? Icons.shopping_cart
                                                : Icons.account_balance_wallet,
                                            color: isExpense
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF10B981),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                transaction['description'] ??
                                                    (isExpense
                                                        ? 'Expense'
                                                        : 'Income'),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateFormat('MMM dd, yyyy')
                                                    .format(date),
                                                style: TextStyle(
                                                  color:
                                                      const Color(0xFF94A3B8),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${isExpense ? '-' : '+'} Rs. ${amount.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: isExpense
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF10B981),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).take(5),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // AI Recommendations/Warning
                      if (_showExpenseWarning) ...[
                        GlassCard(
                          width: double.infinity,
                          borderRadius: 25,
                          blur: 20,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.warning,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Expense Alert!',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'You\'ve spent ${expensePercentage.round()}% of your income',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                CustomButton(
                                  text: 'View Tips to Save',
                                  onPressed: () {
                                    CustomDialog.showInfo(
                                      context,
                                      '💡 Money Saving Tips:\n\n'
                                      '• Track all expenses daily\n'
                                      '• Cook at home more often\n'
                                      '• Cancel unused subscriptions\n'
                                      '• Use public transport\n'
                                      '• Set a daily spending limit\n'
                                      '• Save 20% of your income first',
                                    );
                                  },
                                  backgroundColor: Colors.white,
                                  textColor: const Color(0xFFEF4444),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getCombinedTransactions() {
    final List<Map<String, dynamic>> all = [];
    all.addAll(_recentExpenses);
    all.addAll(_recentIncome);
    all.sort((a, b) => b['date'].compareTo(a['date']));
    return all;
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF94A3B8),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String title, {VoidCallback? onTap}) {
    return GlassCard(
      height: 90,
      borderRadius: 16,
      blur: 15,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color(0xFFFBA002),
              size: 28,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
