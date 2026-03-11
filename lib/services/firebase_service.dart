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

  // Save user data to Firestore with user type
  Future<void> saveUserData(
      String userId, Map<String, dynamic> userData) async {
    try {
      // Remove any existing 'lastLogin' from userData to avoid conflicts
      final dataToSave = Map<String, dynamic>.from(userData);
      dataToSave.remove('lastLogin'); // Remove if exists

      await _firestore.collection('users').doc(userId).set(
        {
          ...dataToSave,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(), // Add server timestamp
        },
        SetOptions(merge: true),
      );
      print('✅ User data saved successfully for user: $userId');
    } catch (e) {
      print('❌ Error saving user data: $e');
      rethrow;
    }
  }

  // Detect user type based on registration data
  String detectUserTypeFromSignUp(Map<String, dynamic> userData) {
    if (userData.containsKey('employmentType')) {
      final empType = userData['employmentType'].toString().toLowerCase();
      if (empType.contains('student')) return 'student';
      if (empType.contains('employee')) return 'employee';
      if (empType.contains('business') || empType.contains('self'))
        return 'self-employed';
      if (empType.contains('unemployed') || empType.contains('other'))
        return 'non-employee';
    }

    // Default based on age if provided
    final age = userData['age'] ?? 25;
    if (age < 23) return 'student';
    return 'employee'; // Default
  }

  // Check if email is verified
  Future<bool> isEmailVerified(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.uid == userId) {
        await user.reload(); // Reload to get latest status
        return user.emailVerified;
      }

      // Fallback to Firestore data
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['emailVerified'] ?? false;
    } catch (e) {
      print('Error checking email verification: $e');
      return false;
    }
  }

  // Resend verification email
  Future<void> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      print('Error resending verification email: $e');
      rethrow;
    }
  }

  // Update email verification status
  Future<void> updateEmailVerificationStatus(
      String userId, bool isVerified) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'emailVerified': isVerified,
        'accountStatus': isVerified ? 'active' : 'pending_verification',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating email verification status: $e');
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

  Future<void> addLoan(String userId, Map<String, dynamic> loanData) async {
    await _firestore.collection('users').doc(userId).collection('loans').add({
      ...loanData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getLoansStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('loans')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateLoan(
      String userId, String loanId, Map<String, dynamic> updates) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('loans')
        .doc(loanId)
        .update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Check if user has any transactions
  Future<bool> hasAnyTransactions(String userId) async {
    try {
      // Check expenses
      final expensesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .limit(1)
          .get();

      if (expensesSnapshot.docs.isNotEmpty) return true;

      // Check income
      final incomeSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('income')
          .limit(1)
          .get();

      return incomeSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking transactions: $e');
      return false;
    }
  }

  // NEW: Get all unique borrowers
  Future<List<String>> getAllBorrowers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('loans')
          .get();

      final borrowers = snapshot.docs
          .map((doc) => doc.data()['borrower'] as String)
          .toSet()
          .toList();

      return borrowers;
    } catch (e) {
      print('Error getting borrowers: $e');
      return [];
    }
  }

  // NEW: Get loan summary by borrower
  Future<Map<String, dynamic>> getLoanSummaryByBorrower(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('loans')
          .get();

      Map<String, dynamic> summary = {};

      for (var doc in snapshot.docs) {
        final loan = doc.data();
        final borrower = loan['borrower'] as String;
        final amount = (loan['amount'] as num).toDouble();
        final remaining = (loan['remaining'] as num).toDouble();

        if (!summary.containsKey(borrower)) {
          summary[borrower] = {
            'totalLoaned': 0.0,
            'totalRemaining': 0.0,
            'loanCount': 0,
            'activeLoans': 0,
          };
        }

        summary[borrower]['totalLoaned'] += amount;
        summary[borrower]['totalRemaining'] += remaining;
        summary[borrower]['loanCount'] += 1;
        if (remaining > 0) {
          summary[borrower]['activeLoans'] += 1;
        }
      }

      return summary;
    } catch (e) {
      print('Error getting loan summary: $e');
      return {};
    }
  }
}
