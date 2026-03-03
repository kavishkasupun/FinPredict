import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  OrtSession? _session;
  Map<String, dynamic>? _config;
  bool _isModelLoaded = false;
  List<String>? _featureOrder;
  Map<String, dynamic>? _categoryMappings;

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

  // Predict if expenses will exceed income
  Future<Map<String, dynamic>> predictExpenseAlert({
    required double monthlyIncome,
    required double monthlyExpenses,
    required Map<String, dynamic> userFeatures,
  }) async {
    if (!_isModelLoaded || _session == null) {
      // Fallback logic if model not loaded
      final expenseRatio = monthlyExpenses / monthlyIncome;
      return {
        'alert': expenseRatio > 0.8,
        'confidence': 0.5,
        'probability': expenseRatio > 0.8 ? 0.9 : 0.1,
        'message': expenseRatio > 0.8
            ? '⚠️ Warning: Your expenses are high!'
            : '✅ Your expenses are within limit',
      };
    }

    try {
      // Prepare features in correct order
      final features =
          _prepareFeatures(userFeatures, monthlyIncome, monthlyExpenses);

      // Get input shape from config or use default [1, numFeatures]
      final inputShape = [1, features.first.length];

      // Create input tensor using Float32List for better compatibility
      final floatList = Float32List.fromList(features.first);

      // FIXED: Use createTensorWithDataList instead of fromList
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        floatList,
        inputShape,
      );

      // Create input map with correct typing
      final Map<String, OrtValue> inputMap = {'float_input': inputTensor};

      // Create run options
      final runOptions = OrtRunOptions();

      // FIXED: Pass runOptions as first parameter, inputMap as second
      final List<OrtValue?> outputs = await _session!.run(runOptions, inputMap);

      // Process outputs
      if (outputs.isNotEmpty && outputs.first != null) {
        final outputTensor = outputs.first!;
        final outputData = outputTensor.value as List;

        // Handle different output formats
        double probability;
        if (outputData is List<List>) {
          probability = outputData.first.first.toDouble();
        } else if (outputData is List<double>) {
          probability = outputData.first;
        } else {
          probability = outputData.first.toDouble();
        }

        final prediction = probability > 0.5 ? 1 : 0;

        // Calculate alert threshold
        final expenseRatio = monthlyExpenses / monthlyIncome;
        final shouldAlert = prediction == 1 || expenseRatio > 0.8;

        // Release tensors to free memory
        inputTensor.release();
        for (final output in outputs) {
          output?.release();
        }
        runOptions.release();

        return {
          'alert': shouldAlert,
          'prediction': prediction,
          'probability': probability,
          'expense_ratio': expenseRatio,
          'confidence': prediction == 1 ? probability : 1 - probability,
          'message': shouldAlert
              ? '⚠️ AI Alert: Your expenses may exceed income! Consider reducing spending.'
              : '✅ AI says: Your finances look good!',
        };
      } else {
        throw Exception('No output from model');
      }
    } catch (e, stackTrace) {
      print('Error in prediction: $e');
      print('Stack trace: $stackTrace');

      // Fallback to simple threshold
      final expenseRatio = monthlyExpenses / monthlyIncome;
      return {
        'alert': expenseRatio > 0.8,
        'confidence': 0.5,
        'probability': expenseRatio > 0.8 ? 0.9 : 0.1,
        'message': expenseRatio > 0.8
            ? '⚠️ Warning: Expenses are high!'
            : '✅ You are within budget',
      };
    }
  }

  // Next month spending forecast
  Future<Map<String, dynamic>> forecastNextMonth({
    required double monthlyIncome,
    required double monthlyExpenses,
    required List<double> previousExpenses,
  }) async {
    // Simple forecasting based on trend
    if (previousExpenses.isEmpty) {
      return {
        'forecast': monthlyExpenses * 1.05, // Assume 5% increase
        'confidence': 0.6,
        'trend': 'stable',
        'message':
            'Next month forecast: Rs. ${(monthlyExpenses * 1.05).toStringAsFixed(2)}',
      };
    }

    // Calculate trend
    final avgExpense =
        previousExpenses.reduce((a, b) => a + b) / previousExpenses.length;
    final recentAvg = previousExpenses.length > 3
        ? previousExpenses
                .sublist(previousExpenses.length - 3)
                .reduce((a, b) => a + b) /
            3
        : avgExpense;

    final trend = recentAvg > avgExpense ? 'increasing' : 'decreasing';
    final forecast = recentAvg * 1.02; // 2% adjustment

    return {
      'forecast': forecast,
      'confidence': 0.75,
      'trend': trend,
      'message': trend == 'increasing'
          ? '📈 Next month expenses may increase to Rs. ${forecast.toStringAsFixed(2)}'
          : '📉 Next month expenses may decrease to Rs. ${forecast.toStringAsFixed(2)}',
    };
  }

  List<List<double>> _prepareFeatures(
    Map<String, dynamic> userFeatures,
    double monthlyIncome,
    double monthlyExpenses,
  ) {
    if (_featureOrder == null || _featureOrder!.isEmpty) {
      // Default features if config not available
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

    // Prepare features in correct order
    final featureList = <double>[];
    for (final feature in _featureOrder!) {
      if (feature == 'monthly_income_rs') {
        featureList.add(monthlyIncome);
      } else if (feature == 'monthly_expenses_rs') {
        featureList.add(monthlyExpenses);
      } else if (userFeatures.containsKey(feature)) {
        // Handle categorical encodings if needed
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
