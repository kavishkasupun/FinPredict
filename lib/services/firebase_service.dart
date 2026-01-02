import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;
  late FirebaseStorage _storage;

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;
  FirebaseStorage get storage => _storage;

  Future<void> init() async {
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _storage = FirebaseStorage.instance;
  }

  // Save user data to Firestore
  Future<void> saveUserData(
      String userId, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(userId).set(
        {
          ...userData,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(), // Added lastLogin
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error saving user data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  Future<void> addExpense(String userId, Map<String, dynamic> expense) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .add({
      ...expense,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getExpensesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> addIncome(String userId, Map<String, dynamic> income) async {
    await _firestore.collection('users').doc(userId).collection('income').add({
      ...income,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addTask(String userId, Map<String, dynamic> task) async {
    await _firestore.collection('users').doc(userId).collection('tasks').add({
      ...task,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getTasksStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> saveMood(String userId, Map<String, dynamic> moodData) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('mood_history')
        .add({
      ...moodData,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveChatMessage(
      String userId, Map<String, dynamic> message) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_history')
        .add({
      ...message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> profileData) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...profileData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  Future<bool> checkUserExists(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists;
  }

  // Additional method to update last login time
  Future<void> updateLastLogin(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastLogin': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  // Method to get user's monthly budget
  Future<double> getUserMonthlyBudget(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      if (data != null && data.containsKey('monthlyBudget')) {
        return (data['monthlyBudget'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Error getting monthly budget: $e');
      return 0.0;
    }
  }

  // Method to update monthly budget
  Future<void> updateMonthlyBudget(String userId, double budget) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'monthlyBudget': budget,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating monthly budget: $e');
      rethrow;
    }
  }

  // Method to get total expenses for current month
  Future<double> getCurrentMonthExpenses(String userId) async {
    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: firstDayOfMonth)
          .where('date', isLessThan: now)
          .get();

      double total = 0.0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('amount')) {
          total += (data['amount'] as num).toDouble();
        }
      }
      return total;
    } catch (e) {
      print('Error getting current month expenses: $e');
      return 0.0;
    }
  }
}
