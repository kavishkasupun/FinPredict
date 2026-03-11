import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  OrtSession? _session;
  Map<String, dynamic>? _config;
  bool _isModelLoaded = false;
  List<String>? _featureOrder;
  Map<String, dynamic>? _categoryMappings;

  // User type detection with more accurate classification
  String _detectUserType(Map<String, dynamic> userFeatures) {
    // Check if user type is explicitly provided from registration
    if (userFeatures.containsKey('userType') &&
        userFeatures['userType'] != null &&
        userFeatures['userType'].toString().isNotEmpty) {
      final userType = userFeatures['userType'].toString().toLowerCase();
      if (userType.contains('student')) return 'Student';
      if (userType.contains('employee')) return 'Employee';
      if (userType.contains('business') ||
          userType.contains('self') ||
          userType.contains('freelance')) return 'Self-Employed';
      if (userType.contains('non') || userType.contains('unemployed'))
        return 'Non-Employee';
    }

    // Check employment type as fallback
    if (userFeatures.containsKey('employmentType')) {
      final empType = userFeatures['employmentType'].toString().toLowerCase();
      if (empType.contains('student')) return 'Student';
      if (empType.contains('employee')) return 'Employee';
      if (empType.contains('business') || empType.contains('self'))
        return 'Self-Employed';
      if (empType.contains('unemployed') || empType.contains('other'))
        return 'Non-Employee';
    }

    // Fallback detection based on income and age
    final income = userFeatures['monthlyIncome'] ?? 0;
    final age = userFeatures['age'] ?? 25;

    if (age < 23 && income < 20000) return 'Student';
    if (income > 50000) return 'Employee';
    return 'General User';
  }

  // Get user type specific spending patterns with better descriptions
  Map<String, dynamic> _getUserTypePatterns(String userType) {
    switch (userType.toLowerCase()) {
      case 'student':
        return {
          'dailyAvg': 500.0,
          'weeklyAvg': 3500.0,
          'monthlyAvg': 15000.0,
          'weekendMultiplier': 1.5,
          'savingRate': 0.1,
          'description':
              'Students typically spend more on education, food, and entertainment',
          'advice':
              'Try using student discounts and cook at home to save money',
        };
      case 'employee':
        return {
          'dailyAvg': 1500.0,
          'weeklyAvg': 10500.0,
          'monthlyAvg': 45000.0,
          'weekendMultiplier': 2.0,
          'savingRate': 0.2,
          'description':
              'Employees have regular income with expenses on commuting, meals, and lifestyle',
          'advice': 'Consider 50/30/20 rule: 50% needs, 30% wants, 20% savings',
        };
      case 'self-employed':
        return {
          'dailyAvg': 2000.0,
          'weeklyAvg': 14000.0,
          'monthlyAvg': 60000.0,
          'weekendMultiplier': 1.3,
          'savingRate': 0.25,
          'description':
              'Self-employed individuals have variable income with business-related expenses',
          'advice': 'Set aside 30% for taxes and maintain an emergency fund',
        };
      default: // general user / non-employee
        return {
          'dailyAvg': 800.0,
          'weeklyAvg': 5600.0,
          'monthlyAvg': 24000.0,
          'weekendMultiplier': 1.2,
          'savingRate': 0.15,
          'description':
              'Track your expenses regularly to understand your spending patterns',
          'advice': 'Start with small savings goals and build up gradually',
        };
    }
  }

  // Load model and config
  Future<void> loadModel() async {
    try {
      print('📱 Loading ML Model...');

      // Load config JSON
      final configString =
          await rootBundle.loadString('assets/ml/finpredict_config.json');
      _config = json.decode(configString);
      _featureOrder = List<String>.from(_config!['feature_order']);
      _categoryMappings = _config!['categorical_encodings'];

      print('📱 Config loaded. Features: ${_featureOrder?.length}');

      // Load ONNX model
      final modelData =
          await rootBundle.load('assets/ml/finpredict_model.onnx');
      final buffer = modelData.buffer.asUint8List();

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/finpredict_model.onnx';
      await File(tempPath).writeAsBytes(buffer);

      // Initialize ONNX Runtime environment
      OrtEnv.instance.init();

      // Create session with options
      final sessionOptions = OrtSessionOptions()..setIntraOpNumThreads(1);

      _session = OrtSession.fromFile(
        File(tempPath),
        sessionOptions,
      );

      _isModelLoaded = true;
      print('✅ ML Model loaded successfully');
    } catch (e, stackTrace) {
      print('❌ Error loading ML model: $e');
      print('Stack trace: $stackTrace');
      _isModelLoaded = false;
    }
  }

  // Check if user has data for predictions
  bool _hasUserData(double monthlyIncome, double monthlyExpenses) {
    return monthlyIncome > 0 && monthlyExpenses > 0;
  }

  // ============================================
  // FIXED: Get warning level based on expense percentage
  // ============================================
  String _getWarningLevel(double expensePercentage) {
    if (expensePercentage >= 90) return 'critical';
    if (expensePercentage >= 80) return 'high';
    if (expensePercentage >= 70) return 'moderate';
    return 'good';
  }

  // ============================================
  // FIXED: Get message based on warning level
  // ============================================
  Map<String, String> _getWarningMessages(
      double expensePercentage, double expenseRatio) {
    final warningLevel = _getWarningLevel(expensePercentage);

    switch (warningLevel) {
      case 'critical':
        return {
          'message':
              '⚠️ CRITICAL: You\'ve spent ${expensePercentage.round()}% of your income!',
          'detailedMessage':
              'Your expenses are dangerously high. You have only ${(100 - expensePercentage).round()}% of income remaining for the month. Immediate action required!',
          'shortMessage': 'Spending too much! Reduce expenses immediately.',
        };
      case 'high':
        return {
          'message':
              '⚠️ HIGH SPENDING: You\'ve spent ${expensePercentage.round()}% of your income',
          'detailedMessage':
              'Your spending is very high. Consider reducing discretionary expenses like dining out, entertainment, and shopping.',
          'shortMessage': 'High spending detected. Review your expenses.',
        };
      case 'moderate':
        return {
          'message':
              'ℹ️ MODERATE: You\'ve spent ${expensePercentage.round()}% of your income',
          'detailedMessage':
              'You\'re spending moderately. Try to keep expenses under 70% to maintain healthy savings.',
          'shortMessage': 'Spending is moderate. Keep monitoring.',
        };
      case 'good':
      default:
        return {
          'message':
              '✅ GOOD JOB! You\'ve spent only ${expensePercentage.round()}% of your income',
          'detailedMessage':
              'You\'re saving ${(100 - expensePercentage).round()}% of your income. Great financial discipline! Keep it up!',
          'shortMessage': 'Keep up the good work!',
        };
    }
  }

  // ============================================
  // ENHANCED: Predict with proper alert messages based on expense level
  // ============================================
  Future<Map<String, dynamic>> predictExpenseAlert({
    required double monthlyIncome,
    required double monthlyExpenses,
    required Map<String, dynamic> userFeatures,
  }) async {
    final userType = _detectUserType(userFeatures);
    final patterns = _getUserTypePatterns(userType);
    final hasData = _hasUserData(monthlyIncome, monthlyExpenses);

    // If no data, return friendly message
    if (!hasData) {
      return {
        'hasData': false,
        'alert': false,
        'warningLevel': 'no_data',
        'confidence': 0,
        'probability': 0,
        'userType': userType,
        'userTypeDisplay': userType,
        'message':
            '👋 Welcome! Add your income and expenses to get AI insights',
        'detailedMessage':
            'Start by adding your first income or expense transaction',
        'shortMessage': 'Start tracking your finances',
        'advice': patterns['advice'],
      };
    }

    // Calculate expense ratio
    final expenseRatio = monthlyExpenses / monthlyIncome;
    final expensePercentage = (expenseRatio * 100);

    // Get warning level and messages
    final warningLevel = _getWarningLevel(expensePercentage);
    final messages = _getWarningMessages(expensePercentage, expenseRatio);

    // Determine if should alert (only for critical and high)
    final shouldAlert = warningLevel == 'critical' || warningLevel == 'high';

    // Calculate savings and projected savings
    final currentSavings = monthlyIncome - monthlyExpenses;
    final projectedYearlySavings = currentSavings * 12;
    final savingsRate =
        monthlyIncome > 0 ? (currentSavings / monthlyIncome * 100) : 0;

    // Try ML model prediction if available
    if (_isModelLoaded && _session != null) {
      try {
        // Prepare features
        final features =
            _prepareFeatures(userFeatures, monthlyIncome, monthlyExpenses);

        if (features.isNotEmpty && features.first.isNotEmpty) {
          final inputShape = [1, features.first.length];
          final floatList = Float32List.fromList(features.first);
          final inputTensor = OrtValueTensor.createTensorWithDataList(
            floatList,
            inputShape,
          );

          final Map<String, OrtValue> inputMap = {'float_input': inputTensor};
          final runOptions = OrtRunOptions();
          final List<OrtValue?> outputs =
              await _session!.run(runOptions, inputMap);

          if (outputs.isNotEmpty && outputs.first != null) {
            final outputTensor = outputs.first!;
            final outputData = outputTensor.value as List;

            double probability;
            if (outputData is List<List>) {
              probability = outputData.first.first.toDouble();
            } else if (outputData is List<double>) {
              probability = outputData.first;
            } else {
              probability = outputData.first.toDouble();
            }

            // Release tensors
            inputTensor.release();
            for (final output in outputs) {
              output?.release();
            }
            runOptions.release();

            // Return with ML prediction but use our proper messages
            return {
              'hasData': true,
              'alert': shouldAlert,
              'warningLevel': warningLevel,
              'prediction': probability > 0.5 ? 1 : 0,
              'probability': probability,
              'expense_ratio': expenseRatio,
              'expense_percentage': expensePercentage.round(),
              'userType': userType,
              'userTypeDisplay': userType,
              'userTypePatterns': patterns,
              'confidence': probability,
              'message': messages['message'],
              'detailedMessage': messages['detailedMessage'],
              'shortMessage': messages['shortMessage'],
              'advice': patterns['advice'],
              'savings': currentSavings,
              'savingsRate': savingsRate,
              'projectedYearlySavings': projectedYearlySavings,
            };
          }
        }
      } catch (e) {
        print('Error in ML prediction: $e');
      }
    }

    // ============================================
    // FIXED: Fallback response with proper messages based on warning level
    // ============================================
    return {
      'hasData': true,
      'alert': shouldAlert,
      'warningLevel': warningLevel,
      'confidence': 0.7,
      'probability': expenseRatio,
      'expense_ratio': expenseRatio,
      'expense_percentage': expensePercentage.round(),
      'userType': userType,
      'userTypeDisplay': userType,
      'userTypePatterns': patterns,
      'message': messages['message'],
      'detailedMessage': messages['detailedMessage'],
      'shortMessage': messages['shortMessage'],
      'advice': patterns['advice'],
      'savings': currentSavings,
      'savingsRate': savingsRate,
      'projectedYearlySavings': projectedYearlySavings,
    };
  }

  // Predict daily expenses
  Future<Map<String, dynamic>> predictDailyExpenses({
    required double monthlyIncome,
    required double monthlyExpenses,
    required Map<String, dynamic> userFeatures,
    DateTime? targetDate,
  }) async {
    final now = targetDate ?? DateTime.now();
    final userType = _detectUserType(userFeatures);
    final patterns = _getUserTypePatterns(userType);
    final hasData = _hasUserData(monthlyIncome, monthlyExpenses);

    if (!hasData) {
      return {
        'hasData': false,
        'userType': userType,
        'userTypeDisplay': userType,
        'message': 'Add your income and expenses to see AI predictions',
      };
    }

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final actualDailyAvg = monthlyExpenses / daysInMonth;
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final dayMultiplier = isWeekend ? patterns['weekendMultiplier']! : 1.0;
    final predictedDaily = actualDailyAvg * dayMultiplier;

    // Generate weekly predictions
    List<Map<String, dynamic>> weeklyPredictions = [];
    double weeklyTotal = 0.0;

    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final isWeekend =
          date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      final multiplier = isWeekend ? patterns['weekendMultiplier']! : 1.0;
      final dailyPrediction = actualDailyAvg * multiplier;
      weeklyTotal += dailyPrediction;

      weeklyPredictions.add({
        'date': date,
        'predicted': dailyPrediction,
        'dayName': DateFormat('EEEE').format(date),
        'isWeekend': isWeekend,
      });
    }

    final monthlyProjection = weeklyTotal * 4.33;
    final projectedSavings = monthlyIncome - monthlyProjection;
    final warning = monthlyProjection > monthlyIncome * 0.8;

    // FIXED: Get proper warning messages for forecast
    final expenseRatio = monthlyExpenses / monthlyIncome;
    final expensePercentage = expenseRatio * 100;
    final messages = _getWarningMessages(expensePercentage, expenseRatio);

    return {
      'hasData': true,
      'userType': userType,
      'userTypeDisplay': userType,
      'patterns': patterns,
      'today': {
        'date': now,
        'predicted': predictedDaily,
        'actual': actualDailyAvg,
        'isWeekend': isWeekend,
        'message': isWeekend
            ? 'Weekend spending may be higher (${patterns['weekendMultiplier']}x)'
            : 'Normal spending day',
      },
      'weekly': weeklyPredictions,
      'weeklyTotal': weeklyTotal,
      'monthlyProjection': monthlyProjection,
      'projectedSavings': projectedSavings,
      'warning': warning,
      'message': warning
          ? '⚠️ Your projected monthly expenses may exceed 80% of income!'
          : messages['shortMessage'],
      'dailyAverage': actualDailyAvg,
      'savings': monthlyIncome - monthlyExpenses,
      'savingsRate': monthlyIncome > 0
          ? ((monthlyIncome - monthlyExpenses) / monthlyIncome * 100)
          : 0,
    };
  }

  // New method: Get complete financial summary with predictions
  Future<Map<String, dynamic>> getFinancialSummary({
    required double monthlyIncome,
    required double monthlyExpenses,
    required Map<String, dynamic> userFeatures,
    required List<double> previousExpenses,
  }) async {
    final alert = await predictExpenseAlert(
      monthlyIncome: monthlyIncome,
      monthlyExpenses: monthlyExpenses,
      userFeatures: userFeatures,
    );

    final daily = await predictDailyExpenses(
      monthlyIncome: monthlyIncome,
      monthlyExpenses: monthlyExpenses,
      userFeatures: userFeatures,
    );

    final userType = _detectUserType(userFeatures);
    final patterns = _getUserTypePatterns(userType);
    final expenseRatio =
        monthlyIncome > 0 ? monthlyExpenses / monthlyIncome : 0;
    final expensePercentage = (expenseRatio * 100).round();
    final savings = monthlyIncome - monthlyExpenses;
    final savingsRate = monthlyIncome > 0 ? (savings / monthlyIncome * 100) : 0;

    // Calculate trend from previous expenses
    String trend = 'stable';
    double trendFactor = 1.0;
    if (previousExpenses.length >= 2) {
      final recentAvg = previousExpenses.length >= 3
          ? previousExpenses.sublist(0, 3).reduce((a, b) => a + b) / 3
          : previousExpenses.first;
      final olderAvg = previousExpenses.length > 3
          ? previousExpenses.sublist(3).reduce((a, b) => a + b) /
              (previousExpenses.length - 3)
          : previousExpenses.last;

      if (olderAvg > 0) {
        trendFactor = recentAvg / olderAvg;
        if (trendFactor > 1.1)
          trend = 'increasing';
        else if (trendFactor < 0.9) trend = 'decreasing';
      }
    }

    return {
      'hasData': monthlyIncome > 0,
      'userType': userType,
      'userTypeDisplay': userType,
      'userTypePatterns': patterns,
      'monthlyIncome': monthlyIncome,
      'monthlyExpenses': monthlyExpenses,
      'savings': savings,
      'savingsRate': savingsRate,
      'expensePercentage': expensePercentage,
      'expenseRatio': expenseRatio,
      'trend': trend,
      'trendFactor': trendFactor,
      'alert': alert,
      'daily': daily,
      'previousExpenses': previousExpenses,
      'message': alert['message'],
      'detailedMessage': alert['detailedMessage'],
      'shortMessage': alert['shortMessage'],
      'advice': patterns['advice'],
      'warningLevel': alert['warningLevel'] ?? 'good',
    };
  }

  List<List<double>> _prepareFeatures(
    Map<String, dynamic> userFeatures,
    double monthlyIncome,
    double monthlyExpenses,
  ) {
    if (_featureOrder == null || _featureOrder!.isEmpty) {
      return [
        [
          monthlyIncome,
          monthlyExpenses,
          userFeatures['age']?.toDouble() ?? 30.0,
          userFeatures['dependents']?.toDouble() ?? 0.0,
          userFeatures['savings']?.toDouble() ?? 0.0,
        ]
      ];
    }

    final featureList = <double>[];
    for (final feature in _featureOrder!) {
      if (feature == 'monthly_income_rs') {
        featureList.add(monthlyIncome);
      } else if (feature == 'monthly_expenses_rs') {
        featureList.add(monthlyExpenses);
      } else if (userFeatures.containsKey(feature)) {
        if (_categoryMappings != null &&
            _categoryMappings!.containsKey(feature)) {
          final mapping = _categoryMappings![feature];
          final value = userFeatures[feature];
          if (mapping is Map && mapping.containsKey(value.toString())) {
            featureList.add(mapping[value.toString()]!.toDouble());
          } else {
            featureList.add(userFeatures[feature]?.toDouble() ?? 0.0);
          }
        } else {
          featureList.add(userFeatures[feature]?.toDouble() ?? 0.0);
        }
      } else {
        featureList.add(0.0);
      }
    }

    return [featureList];
  }

  void dispose() {
    _session?.release();
    _session = null;
    OrtEnv.instance.release();
  }
}
