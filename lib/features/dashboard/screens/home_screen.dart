import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

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
import 'package:finpredict/features/loans/screens/loan_list_screen.dart';
import 'package:finpredict/features/chat/screens/chat_screen.dart';
import 'package:finpredict/features/prediction/screens/prediction_summary_screen.dart';

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
  bool _hasTransactions = false;
  String _selectedTimeRange = 'This Month';
  String _userType = 'General User';
  bool _notificationsEnabled = true;

  // Track last shown notification level to avoid spamming
  String _lastShownWarningLevel = '';
  DateTime _lastNotificationTime =
      DateTime.now().subtract(const Duration(hours: 1));

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
    await _mlService.loadModel();
    await _notificationService.init();
    await _loadUserData();

    // Check notification settings
    final settings = await _notificationService.checkNotificationSettings();
    setState(() {
      _notificationsEnabled = settings;
    });
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUser = FirebaseAuth.instance.currentUser;

      if (_currentUser != null) {
        final userData = await _firebaseService.getUserData(_currentUser!.uid);

        if (userData != null) {
          // Ensure all numeric values are double
          final processedData = Map<String, dynamic>.from(userData);
          processedData.forEach((key, value) {
            if (value is int) {
              processedData[key] = value.toDouble();
            }
          });

          setState(() {
            _userData = processedData;

            // Safely get budget with proper type conversion
            final budgetValue = processedData['monthlyBudget'];
            if (budgetValue != null) {
              if (budgetValue is int) {
                _budgetLimit = budgetValue.toDouble();
              } else if (budgetValue is double) {
                _budgetLimit = budgetValue;
              } else {
                _budgetLimit = 60000.0;
              }
            } else {
              _budgetLimit = 60000.0;
            }

            // Get user type with proper fallback
            _userType = _getUserTypeFromData(processedData);
          });

          await _loadCurrentMonthData();
          await _loadRecentTransactions();

          _hasTransactions =
              await _firebaseService.hasAnyTransactions(_currentUser!.uid);

          if (_hasTransactions) {
            await _runAIPrediction();
          } else {
            setState(() {
              _aiPrediction = {
                'hasData': false,
                'alert': false,
                'warningLevel': 'no_data',
                'userType': _userType,
                'userTypeDisplay': _userType,
                'message':
                    '👋 Welcome! Add your first income or expense to see AI insights',
                'detailedMessage': 'Start by adding your first transaction',
                'shortMessage': 'Welcome! Start tracking your finances',
                'expense_percentage': 0,
                'predicted_monthly_expense': 0.0,
              };
              _forecast = {
                'hasData': false,
                'message': 'Add transactions to see predictions',
                'monthlyProjection': 0.0,
              };
            });
          }
        } else {
          // User exists in Auth but not in Firestore - create basic profile
          await _createBasicUserProfile();
        }
      } else {
        // User not logged in - still initialize for notifications
        await _initializeWithoutUser();
      }
    } catch (e) {
      print('Error loading user data: $e');
      _setDefaultUserData();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createBasicUserProfile() async {
    try {
      final user = _currentUser!;
      final basicUserData = {
        'name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'email': user.email,
        'userType': 'General User',
        'employmentType': 'employee',
        'monthlyBudget': 60000.0,
        'age': 25.0,
        'dependents': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firebaseService.saveUserData(user.uid, basicUserData);

      setState(() {
        _userData = basicUserData;
        _userType = 'General User';
        _budgetLimit = 60000.0;
      });

      await _loadCurrentMonthData();
      await _loadRecentTransactions();
    } catch (e) {
      print('Error creating basic profile: $e');
      _setDefaultUserData();
    }
  }

  String _getUserTypeFromData(Map<String, dynamic> data) {
    // Check for explicit userType
    if (data.containsKey('userType') && data['userType'] != null) {
      return data['userType'].toString();
    }

    // Check employment type
    if (data.containsKey('employmentType') && data['employmentType'] != null) {
      final empType = data['employmentType'].toString().toLowerCase();
      if (empType.contains('student')) return 'Student';
      if (empType.contains('employee')) return 'Employee';
      if (empType.contains('business') || empType.contains('self'))
        return 'Self-Employed';
      if (empType.contains('unemployed') || empType.contains('other'))
        return 'Non-Employee';
    }

    // Detect from age
    final age = data['age'];
    if (age != null) {
      final ageNum = age is int ? age : (age as num?)?.toInt() ?? 25;
      if (ageNum < 23) return 'Student';
    }

    return 'General User';
  }

  Future<void> _initializeWithoutUser() async {
    // Initialize with default values for non-logged in users
    setState(() {
      _userData = {
        'name': 'Guest User',
        'userType': 'Guest',
        'monthlyBudget': 0.0,
      };
      _userType = 'Guest';
      _hasTransactions = false;
      _aiPrediction = {
        'hasData': false,
        'alert': false,
        'warningLevel': 'no_user',
        'message': '👋 Please login to see your financial insights',
        'detailedMessage': 'Login or create an account to start tracking',
        'shortMessage': 'Login to continue',
      };
    });
  }

  Future<void> _loadCurrentMonthData() async {
    try {
      if (_currentUser != null) {
        final now = DateTime.now();
        final firstDayOfMonth = DateTime(now.year, now.month, 1);
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

        final expensesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('expenses')
            .where('date',
                isGreaterThanOrEqualTo: firstDayOfMonth.toIso8601String())
            .where('date',
                isLessThanOrEqualTo: lastDayOfMonth.toIso8601String())
            .get();

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
          final amount = expense.data()['amount'];
          if (amount is int) {
            totalExpenses += amount.toDouble();
          } else if (amount is double) {
            totalExpenses += amount;
          }
        }

        double totalIncome = 0.0;
        for (var income in incomeSnapshot.docs) {
          final amount = income.data()['amount'];
          if (amount is int) {
            totalIncome += amount.toDouble();
          } else if (amount is double) {
            totalIncome += amount;
          }
        }

        if (mounted) {
          setState(() {
            _currentExpense = totalExpenses;
            _currentIncome = totalIncome;
            _savings = _currentIncome - _currentExpense;
          });
        }
      }
    } catch (e) {
      print('Error loading month data: $e');
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      if (_currentUser != null) {
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

          // Ensure amount is double
          if (data.containsKey('amount')) {
            final amount = data['amount'];
            if (amount is int) {
              data['amount'] = amount.toDouble();
            }
          }

          return data;
        }).toList();

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

          // Ensure amount is double
          if (data.containsKey('amount')) {
            final amount = data['amount'];
            if (amount is int) {
              data['amount'] = amount.toDouble();
            }
          }

          return data;
        }).toList();

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error loading recent transactions: $e');
    }
  }

  Future<void> _runAIPrediction() async {
    try {
      final previousExpenses = await _getPreviousExpenses(6);

      // Ensure all values are double
      final userFeatures = {
        'age': _safeToDouble(_userData?['age'] ?? 30.0),
        'dependents': _safeToDouble(_userData?['dependents'] ?? 0.0),
        'savings': _savings,
        'budget': _budgetLimit,
        'employmentType': _userData?['employmentType']?.toString() ?? _userType,
        'userType': _userType,
        'monthlyIncome': _currentIncome,
      };

      final prediction = await _mlService.predictExpenseAlert(
        monthlyIncome: _currentIncome,
        monthlyExpenses: _currentExpense,
        userFeatures: userFeatures,
      );

      final forecast = await _mlService.predictDailyExpenses(
        monthlyIncome: _currentIncome,
        monthlyExpenses: _currentExpense,
        userFeatures: userFeatures,
      );

      // Calculate expense percentage correctly
      final calculatedExpensePercentage = _currentIncome > 0
          ? ((_currentExpense / _currentIncome) * 100).round()
          : 0;

      // Calculate predicted monthly expense
      double predictedMonthlyExpense = _currentExpense;
      if (forecast.containsKey('monthlyProjection')) {
        final projection = forecast['monthlyProjection'];
        if (projection is int) {
          predictedMonthlyExpense = projection.toDouble();
        } else if (projection is double) {
          predictedMonthlyExpense = projection;
        }
      }

      if (mounted) {
        setState(() {
          _aiPrediction = {
            ...prediction,
            'expense_percentage':
                prediction['expense_percentage'] ?? calculatedExpensePercentage,
            'predicted_monthly_expense': predictedMonthlyExpense,
          };
          _forecast = forecast;

          if (prediction.containsKey('userTypeDisplay')) {
            _userType = prediction['userTypeDisplay'].toString();
          }
        });
      }

      await _checkAndShowNotification(prediction);
    } catch (e) {
      print('Error in AI prediction: $e');
      // Fallback with correct percentage calculation and proper messages
      final fallbackPercentage = _currentIncome > 0
          ? ((_currentExpense / _currentIncome) * 100).round()
          : 0;

      final warningLevel = _getWarningLevelFromPercentage(fallbackPercentage);
      final messages = _getFallbackMessages(fallbackPercentage);

      if (mounted) {
        setState(() {
          _aiPrediction = {
            'hasData': _hasTransactions,
            'alert': warningLevel == 'critical' || warningLevel == 'high',
            'warningLevel': warningLevel,
            'userType': _userType,
            'userTypeDisplay': _userType,
            'message': messages['message'],
            'detailedMessage': messages['detailedMessage'],
            'shortMessage': messages['shortMessage'],
            'expense_percentage': fallbackPercentage,
            'predicted_monthly_expense':
                _currentExpense * 1.1, // Simple fallback prediction
          };
        });
      }

      // Show notification for fallback as well
      await _checkAndShowNotification({
        'warningLevel': warningLevel,
        'expense_percentage': fallbackPercentage,
      });
    }
  }

  // Helper method to safely convert to double
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Future<void> _checkAndShowNotification(
      Map<String, dynamic> prediction) async {
    if (!_notificationsEnabled || _currentUser == null) return;

    final warningLevel = prediction['warningLevel']?.toString() ?? 'good';
    final expensePercentage = prediction['expense_percentage'];
    final percentageDouble = expensePercentage is int
        ? expensePercentage.toDouble()
        : (expensePercentage as num?)?.toDouble() ?? 0.0;

    // Only show for high and critical
    if (warningLevel != 'critical' && warningLevel != 'high') {
      return;
    }

    // Rate limiting - don't show more than once every 30 minutes for same level
    final now = DateTime.now();
    final timeDiff = now.difference(_lastNotificationTime).inMinutes;

    if (warningLevel == _lastShownWarningLevel && timeDiff < 30) {
      debugPrint(
          '⏭️ Skipping duplicate notification (same level within 30 minutes)');
      return;
    }

    // Update last shown
    _lastShownWarningLevel = warningLevel;
    _lastNotificationTime = now;

    // Show notification
    await _notificationService.showExpenseAlert(
      currentExpense: _currentExpense,
      monthlyIncome: _currentIncome,
      percentage: percentageDouble,
      aiMessage: prediction['message']?.toString() ?? '',
      warningLevel: warningLevel,
    );
  }

  String _getWarningLevelFromPercentage(int percentage) {
    if (percentage >= 90) return 'critical';
    if (percentage >= 80) return 'high';
    if (percentage >= 70) return 'moderate';
    return 'good';
  }

  Map<String, String> _getFallbackMessages(int percentage) {
    if (percentage >= 90) {
      return {
        'message': '⚠️ CRITICAL: You\'ve spent $percentage% of your income!',
        'detailedMessage':
            'Your expenses are dangerously high. Immediate action required!',
        'shortMessage': 'Critical spending alert!',
      };
    } else if (percentage >= 80) {
      return {
        'message':
            '⚠️ HIGH SPENDING: You\'ve spent $percentage% of your income',
        'detailedMessage':
            'Your spending is very high. Consider reducing expenses.',
        'shortMessage': 'High spending detected.',
      };
    } else if (percentage >= 70) {
      return {
        'message': 'ℹ️ MODERATE: You\'ve spent $percentage% of your income',
        'detailedMessage': 'You\'re spending moderately. Keep monitoring.',
        'shortMessage': 'Moderate spending.',
      };
    } else {
      return {
        'message': '✅ GOOD JOB! You\'ve spent only $percentage% of your income',
        'detailedMessage':
            'You\'re saving ${100 - percentage}% of your income. Great work!',
        'shortMessage': 'Keep up the good work!',
      };
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
          final amount = doc.data()['amount'];
          if (amount is int) {
            total += amount.toDouble();
          } else if (amount is double) {
            total += amount;
          }
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
        'userType': 'General User',
        'employmentType': 'employee',
        'monthlyBudget': 60000.0,
        'currentExpense': 0.0,
      };
      _userType = 'General User';
      _budgetLimit = 60000.0;
      _currentExpense = 0.0;
      _currentIncome = 0.0;
      _savings = 0.0;
      _hasTransactions = false;
    });
  }

  Future<void> _refreshData() async {
    await _loadUserData();
  }

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
      MaterialPageRoute(builder: (context) => const LoanListScreen()),
    );
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
  }

  void _navigateToPredictionSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PredictionSummaryScreen(
          userData: _userData,
          currentIncome: _currentIncome,
          currentExpense: _currentExpense,
          savings: _savings,
          aiPrediction: _aiPrediction,
          forecast: _forecast,
          userId: _currentUser?.uid ?? '',
        ),
      ),
    ).then((_) => _refreshData());
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
              Container(
                width: 200,
                height: 200,
                child: Lottie.asset(
                  'assets/animations/Finpredict.json',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Loading AI Model & Your Data...',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate expense percentage correctly for display with safe conversion
    final double expensePercentage = _safeToDouble(
        _currentIncome > 0 ? (_currentExpense / _currentIncome) * 100 : 0.0);

    final double savingsRate = _safeToDouble(
        (_currentIncome > 0) ? (_savings / _currentIncome) * 100 : 0.0);

    final userName = _userData?['name']?.toString() ??
        _currentUser?.displayName ??
        _currentUser?.email?.split('@').first ??
        'Guest';

    // Get expense percentage from aiPrediction or use calculated value with safe conversion
    final dynamic aiExpensePercentage =
        _aiPrediction?['expense_percentage'] ?? expensePercentage;
    final int displayExpensePercentage;
    if (aiExpensePercentage is int) {
      displayExpensePercentage = aiExpensePercentage;
    } else if (aiExpensePercentage is double) {
      displayExpensePercentage = aiExpensePercentage.round();
    } else {
      displayExpensePercentage = expensePercentage.round();
    }

    // Get predicted monthly expense with safe conversion
    final dynamic predictedValue =
        _aiPrediction?['predicted_monthly_expense'] ?? _currentExpense;
    final double predictedMonthlyExpense = _safeToDouble(predictedValue);

    final bool hasData = _aiPrediction?['hasData'] ?? false;
    final String warningLevel =
        _aiPrediction?['warningLevel']?.toString() ?? 'good';

    Color getAlertColor() {
      switch (warningLevel) {
        case 'critical':
          return const Color(0xFFEF4444); // Red
        case 'high':
          return const Color(0xFFF59E0B); // Orange
        case 'moderate':
          return const Color(0xFFFBA002); // Yellow
        case 'good':
          return const Color(0xFF10B981); // Green
        default:
          return const Color(0xFF3B82F6); // Blue
      }
    }

    IconData getAlertIcon() {
      switch (warningLevel) {
        case 'critical':
          return Icons.warning_amber_rounded;
        case 'high':
          return Icons.warning;
        case 'moderate':
          return Icons.info_outline;
        case 'good':
          return Icons.check_circle_outline;
        default:
          return Icons.auto_graph;
      }
    }

    String getDisplayMessage() {
      if (!hasData) {
        return _aiPrediction?['message']?.toString() ??
            '👋 Welcome! Add your first transaction';
      }

      switch (warningLevel) {
        case 'critical':
          return '⚠️ CRITICAL: You\'ve spent $displayExpensePercentage% of your income!';
        case 'high':
          return '⚠️ HIGH SPENDING: You\'ve spent $displayExpensePercentage% of your income';
        case 'moderate':
          return 'ℹ️ MODERATE: You\'ve spent $displayExpensePercentage% of your income';
        case 'good':
          return '✅ GOOD JOB! You\'ve spent only $displayExpensePercentage% of your income';
        default:
          return _aiPrediction?['message']?.toString() ??
              '✅ Your finances look good!';
      }
    }

    String getDetailedMessage() {
      if (!hasData) {
        return 'Start by adding your first income or expense';
      }

      switch (warningLevel) {
        case 'critical':
          return 'Your expenses are dangerously high. You have only ${100 - displayExpensePercentage}% of income remaining. Immediate action required!';
        case 'high':
          return 'Your spending is very high. Consider reducing discretionary expenses like dining out and entertainment.';
        case 'moderate':
          return 'You\'re spending moderately. Try to keep expenses under 70% to maintain healthy savings.';
        case 'good':
          return 'You\'re saving ${100 - displayExpensePercentage}% of your income. Great financial discipline!';
        default:
          return _aiPrediction?['detailedMessage']?.toString() ??
              'Keep tracking your expenses';
      }
    }

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
                                Row(
                                  children: [
                                    Text(
                                      _currentUser != null
                                          ? 'Welcome Back,'
                                          : 'Welcome,',
                                      style: TextStyle(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_currentUser != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              getAlertColor().withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: getAlertColor()
                                                .withOpacity(0.5),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              color: getAlertColor(),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _userType,
                                              style: TextStyle(
                                                color: getAlertColor(),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
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
                          Row(
                            children: [
                              if (_currentUser != null) ...[
                                IconButton(
                                  onPressed: _navigateToPredictionSummary,
                                  icon: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF3B82F6)
                                              .withOpacity(0.2),
                                          const Color(0xFF8B5CF6)
                                              .withOpacity(0.2),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.analytics,
                                      color: Color(0xFF3B82F6),
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              IconButton(
                                onPressed: () {
                                  if (_currentUser != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const ProfileScreen()),
                                    );
                                  } else {
                                    // Navigate to login screen
                                    Navigator.pushNamed(context, '/login');
                                  }
                                },
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFBA002)
                                            .withOpacity(0.2),
                                        const Color(0xFFFFD166)
                                            .withOpacity(0.2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _currentUser != null
                                        ? Icons.person
                                        : Icons.login,
                                    color: const Color(0xFFFBA002),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // AI Status Card with monthly prediction
                      if (_aiPrediction != null) ...[
                        GlassCard(
                          width: double.infinity,
                          borderRadius: 20,
                          blur: 15,
                          gradient: LinearGradient(
                            colors: [
                              getAlertColor().withOpacity(0.2),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: getAlertColor().withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        getAlertIcon(),
                                        color: getAlertColor(),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                !hasData
                                                    ? '👋 Welcome!'
                                                    : 'AI Analysis',
                                                style: TextStyle(
                                                  color:
                                                      const Color(0xFF94A3B8),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: getAlertColor()
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  warningLevel.toUpperCase(),
                                                  style: TextStyle(
                                                    color: getAlertColor(),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            getDisplayMessage(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            getDetailedMessage(),
                                            style: TextStyle(
                                              color: const Color(0xFF94A3B8),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Expense percentage bar
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Current Expense Level',
                                            style: TextStyle(
                                              color: const Color(0xFF94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '$displayExpensePercentage%',
                                            style: TextStyle(
                                              color: getAlertColor(),
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
                                          value: displayExpensePercentage / 100,
                                          backgroundColor:
                                              const Color(0xFF334155),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            getAlertColor(),
                                          ),
                                          minHeight: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Monthly Prediction Card
                                if (hasData) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF3B82F6)
                                              .withOpacity(0.1),
                                          const Color(0xFF8B5CF6)
                                              .withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF3B82F6)
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3B82F6)
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.trending_up,
                                                color: Color(0xFF3B82F6),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Predicted Monthly Expense',
                                                  style: TextStyle(
                                                    color: Color(0xFF94A3B8),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Rs. ${predictedMonthlyExpense.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: predictedMonthlyExpense >
                                                    _currentIncome * 0.8
                                                ? const Color(0xFFEF4444)
                                                    .withOpacity(0.2)
                                                : const Color(0xFF10B981)
                                                    .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            predictedMonthlyExpense >
                                                    _currentIncome * 0.8
                                                ? 'High'
                                                : 'Normal',
                                            style: TextStyle(
                                              color: predictedMonthlyExpense >
                                                      _currentIncome * 0.8
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF10B981),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                if (!hasData) ...[
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomButton(
                                          text: 'Add Income',
                                          onPressed: _navigateToAddIncome,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: CustomButton(
                                          text: 'Add Expense',
                                          onPressed: _navigateToAddExpense,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Financial Overview Card - Only show if logged in
                      if (_currentUser != null) ...[
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
                                                expensePercentage > 80
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFFFBA002),
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
                                                    MainAxisAlignment
                                                        .spaceAround,
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
                                                    expensePercentage > 80
                                                        ? const Color(
                                                            0xFFEF4444)
                                                        : const Color(
                                                            0xFFFBA002),
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

                                // Expense Gauge
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
                                            value: displayExpensePercentage
                                                .toDouble(),
                                            width: 0.2,
                                            cornerStyle: CornerStyle.bothCurve,
                                            gradient: SweepGradient(
                                              colors: <Color>[
                                                const Color(0xFF10B981),
                                                const Color(0xFFFBA002),
                                                const Color(0xFFEF4444),
                                              ],
                                              stops: const [0.0, 0.7, 1.0],
                                            ),
                                          ),
                                          MarkerPointer(
                                            value: displayExpensePercentage
                                                .toDouble(),
                                            markerType: MarkerType.circle,
                                            color: Colors.white,
                                            borderWidth: 3,
                                            borderColor:
                                                const Color(0xFFFBA002),
                                            markerHeight: 15,
                                            markerWidth: 15,
                                          ),
                                        ],
                                        annotations: <GaugeAnnotation>[
                                          GaugeAnnotation(
                                            positionFactor: 0.1,
                                            widget: Text(
                                              '$displayExpensePercentage%',
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
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap + to add your first transaction',
                                            style: TextStyle(
                                              color: const Color(0xFFFBA002),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else ...[
                                  ..._getCombinedTransactions()
                                      .take(5)
                                      .map((transaction) {
                                    final isExpense =
                                        transaction['type'] == 'expense';
                                    final date =
                                        DateTime.parse(transaction['date']);
                                    final amount =
                                        _safeToDouble(transaction['amount']);

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
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
                                                  : Icons
                                                      .account_balance_wallet,
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
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Show login prompt for non-logged in users
                        const SizedBox(height: 40),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_circle,
                                size: 80,
                                color: const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Please login to access',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'financial features',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 30),
                              CustomButton(
                                text: 'Login / Register',
                                onPressed: () {
                                  Navigator.pushNamed(context, '/login');
                                },
                                width: 200,
                              ),
                            ],
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
          style: const TextStyle(
            color: Color(0xFF94A3B8),
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
      borderRadius: 16,
      blur: 15,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 90,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: const Color(0xFFFBA002),
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
