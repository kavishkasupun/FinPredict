import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finpredict/features/profile/screens/profile_screen.dart';
import 'package:finpredict/features/expenses/services/expense_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ExpenseService _expenseService = ExpenseService();
  User? _currentUser;
  Map<String, dynamic>? _userData;
  double _currentExpense = 0.0;
  double _budgetLimit = 0.0;
  String _currentMood = 'neutral';
  List<String> _recommendations = [];
  bool _showExpenseWarning = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

          // Load actual expenses for current month
          await _loadCurrentMonthExpenses();
          _checkExpenseAlert();
          _loadRecommendations();
        } else {
          // If user data doesn't exist, create default
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

  Future<void> _loadCurrentMonthExpenses() async {
    try {
      if (_currentUser != null) {
        final now = DateTime.now();
        final firstDayOfMonth = DateTime(now.year, now.month, 1);
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

        // Get expenses for current month
        final expenses = await _expenseService.getExpensesByDateRange(
          _currentUser!.uid,
          firstDayOfMonth,
          lastDayOfMonth,
        );

        // Calculate total expenses
        double total = 0.0;
        for (var expense in expenses) {
          total += expense['amount'] as double;
        }

        setState(() {
          _currentExpense = total;
        });
      }
    } catch (e) {
      print('Error loading expenses: $e');
      // Fallback to user data if expense calculation fails
      final fallbackExpense =
          (_userData?['currentExpense'] as num?)?.toDouble() ?? 0.0;
      setState(() {
        _currentExpense = fallbackExpense;
      });
    }
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
    });
  }

  void _checkExpenseAlert() {
    if (_budgetLimit <= 0) return;

    final expensePercentage = (_currentExpense / _budgetLimit) * 100;
    setState(() {
      _showExpenseWarning = expensePercentage > 80;
    });

    if (expensePercentage > 80) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomDialog.showWarning(
          context,
          'Warning: Your expenses have reached ${expensePercentage.round()}% of your budget! Consider reducing unnecessary spending.',
        );
      });
    }
  }

  void _loadRecommendations() {
    List<String> recommendations = [];

    if (_budgetLimit > 0) {
      final savingsRate =
          ((_budgetLimit - _currentExpense) / _budgetLimit) * 100;

      if (savingsRate >= 30) {
        recommendations.addAll([
          'Excellent! You\'re saving ${savingsRate.round()}% of your budget',
          'Consider investing in low-risk mutual funds',
          'Build an emergency fund for 6 months of expenses',
        ]);
      } else if (savingsRate >= 20) {
        recommendations.addAll([
          'Good job! You\'re saving ${savingsRate.round()}% of your budget',
          'Try to save 30% next month by reducing dining out',
          'Review your subscription services',
        ]);
      } else if (savingsRate >= 10) {
        recommendations.addAll([
          'You\'re saving ${savingsRate.round()}% of your budget',
          'Save 20% of your income this month',
          'Consider cooking at home to save on food expenses',
        ]);
      } else {
        recommendations.addAll([
          'Try to save at least 10% of your income',
          'Cancel unused subscriptions',
          'Use public transportation to save fuel costs',
          'Set up automatic savings transfer',
        ]);
      }
    }

    // Add general recommendations
    recommendations.addAll([
      'Track your daily expenses in the app',
      'Set specific financial goals for next month',
      'Review your budget at the end of each week',
    ]);

    setState(() {
      _recommendations = recommendations.take(5).toList();
    });
  }

  void _detectMood() {
    final moods = ['happy', 'neutral', 'sad', 'stressed'];
    setState(() {
      _currentMood = moods[DateTime.now().second % 4];
    });
    _showMoodRecommendations();
  }

  void _showMoodRecommendations() {
    Map<String, List<String>> moodTips = {
      'happy': [
        'Great time to review your financial goals!',
        'Consider investing some of your savings',
        'Share your financial success with loved ones'
      ],
      'sad': [
        'Take a walk and review your budget',
        'Listen to uplifting financial podcasts',
        'Small savings add up - focus on progress'
      ],
      'stressed': [
        'Practice deep breathing exercises',
        'Break down financial tasks into smaller steps',
        'Remember financial journeys have ups and downs'
      ],
      'neutral': [
        'Perfect time for financial planning',
        'Review your monthly expenses',
        'Set new financial goals'
      ],
    };

    final tips = moodTips[_currentMood] ?? [];
    CustomDialog.showSuccess(
      context,
      'Mood detected: ${_currentMood.toUpperCase()}\n\n${tips.join('\n')}',
    );
  }

  Future<void> _refreshData() async {
    await _loadUserData();
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
                'Loading your data...',
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

    final expensePercentage =
        (_budgetLimit > 0) ? (_currentExpense / _budgetLimit) * 100 : 0;
    final double expensePercentageDouble = expensePercentage.toDouble();
    final savings = _budgetLimit - _currentExpense;
    final savingsRate = (_budgetLimit > 0) ? (savings / _budgetLimit) * 100 : 0;
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileScreen(),
                                    ),
                                  );
                                },
                                icon: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF3B82F6)
                                            .withOpacity(0.2),
                                        const Color(0xFF313B2F)
                                            .withOpacity(0.2),
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
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _detectMood,
                                icon: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFBA002)
                                            .withOpacity(0.2),
                                        const Color(0xFF313B2F)
                                            .withOpacity(0.2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getMoodIcon(),
                                    color: const Color(0xFFFBA002),
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      // Financial Overview Glass Card
                      GlassCard(
                        width: double.infinity,
                        borderRadius: 25,
                        blur: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text(
                                'Financial Overview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 400;
                                  return isWide
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildStatCard(
                                              'Monthly Budget',
                                              'Rs. ${_budgetLimit.toStringAsFixed(2)}',
                                              Icons.account_balance_wallet,
                                              const Color(0xFF10B981),
                                            ),
                                            _buildStatCard(
                                              'Current Expenses',
                                              'Rs. ${_currentExpense.toStringAsFixed(2)}',
                                              Icons.money_off,
                                              const Color(0xFFEF4444),
                                            ),
                                            _buildStatCard(
                                              'Savings',
                                              'Rs. ${savings.toStringAsFixed(2)}',
                                              Icons.savings,
                                              const Color(0xFF3B82F6),
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
                                                  'Monthly Budget',
                                                  'Rs. ${_budgetLimit.toStringAsFixed(2)}',
                                                  Icons.account_balance_wallet,
                                                  const Color(0xFF10B981),
                                                ),
                                                _buildStatCard(
                                                  'Current Expenses',
                                                  'Rs. ${_currentExpense.toStringAsFixed(2)}',
                                                  Icons.money_off,
                                                  const Color(0xFFEF4444),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            _buildStatCard(
                                              'Savings',
                                              'Rs. ${savings.toStringAsFixed(2)}',
                                              Icons.savings,
                                              const Color(0xFF3B82F6),
                                            ),
                                          ],
                                        );
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Savings Rate: ${savingsRate.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: savingsRate >= 20
                                      ? const Color(0xFF10B981)
                                      : savingsRate >= 10
                                          ? const Color(0xFFFBA002)
                                          : const Color(0xFFEF4444),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 30),
                              // Expense Gauge
                              SizedBox(
                                height: 200,
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
                                          value: expensePercentageDouble,
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
                                          value: expensePercentageDouble,
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
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        GaugeAnnotation(
                                          positionFactor: 0.3,
                                          widget: Text(
                                            'Budget Used',
                                            style: TextStyle(
                                              color: const Color(0xFF94A3B8),
                                              fontSize: 14,
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
                      const SizedBox(height: 20),
                      // AI Recommendations
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
                                'AI Recommendations',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Based on your spending patterns',
                                style: TextStyle(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ..._recommendations
                                  .map((recommendation) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Icon(
                                                Icons.lightbulb,
                                                color: const Color(0xFFFBA002),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                recommendation,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                              const SizedBox(height: 20),
                              CustomButton(
                                text: 'View More Recommendations',
                                onPressed: () {},
                                width: double.infinity,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Quick Actions
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 500;
                          return isWide
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: _buildQuickAction(
                                        Icons.add_chart,
                                        'Add Expense',
                                        onTap: () {
                                          // Navigate to add expense screen
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildQuickAction(
                                        Icons.task,
                                        'Tasks',
                                        onTap: () {
                                          // Navigate to tasks screen
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildQuickAction(
                                        Icons.chat,
                                        'AI Chat',
                                        onTap: () {
                                          // Navigate to AI chat screen
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildQuickAction(
                                            Icons.add_chart,
                                            'Add Expense',
                                            onTap: () {
                                              // Navigate to add expense screen
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildQuickAction(
                                            Icons.task,
                                            'Tasks',
                                            onTap: () {
                                              // Navigate to tasks screen
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildQuickAction(
                                      Icons.chat,
                                      'AI Chat',
                                      onTap: () {
                                        // Navigate to AI chat screen
                                      },
                                    ),
                                  ],
                                );
                        },
                      ),
                      if (_showExpenseWarning) ...[
                        const SizedBox(height: 20),
                        GlassCard(
                          width: double.infinity,
                          borderRadius: 25,
                          blur: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: const Color(0xFFF59E0B),
                                  size: 32,
                                ),
                                const SizedBox(width: 16),
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
                                        'You\'ve used ${expensePercentage.round()}% of your monthly budget',
                                        style: TextStyle(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      // Additional Info
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
                                'Monthly Summary',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 15),
                              _buildSummaryItem(
                                'Days Left in Month:',
                                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryItem(
                                'Daily Budget Available:',
                                'Rs. ${((_budgetLimit - _currentExpense) / DateTime.now().day).toStringAsFixed(2)}',
                                isPositive: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF94A3B8),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String title, {VoidCallback? onTap}) {
    return GlassCard(
      height: 120,
      borderRadius: 20,
      blur: 15,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color(0xFFFBA002),
              size: 32,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value,
      {bool isPositive = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                color: isPositive ? const Color(0xFF10B981) : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getMoodIcon() {
    switch (_currentMood) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'sad':
        return Icons.sentiment_very_dissatisfied;
      case 'stressed':
        return Icons.sentiment_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }
}
