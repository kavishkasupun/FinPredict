import 'package:flutter/material.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_text_field.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/features/auth/screens/login_screen.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedUserType;
  bool _isLoading = false;
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      CustomDialog.showError(context, 'Passwords do not match');
      return;
    }

    if (_selectedUserType == null) {
      CustomDialog.showError(context, 'Please select user type');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create user in Firebase Authentication
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final User? user = userCredential.user;

      if (user != null) {
        // Save user data to Firestore
        final userData = {
          'uid': user.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'userType': _selectedUserType,
          'createdAt': DateTime.now().toIso8601String(),
          'monthlyBudget': 0.0,
          'totalSavings': 0.0,
        };

        await _firebaseService.saveUserData(user.uid, userData);

        CustomDialog.showSuccess(
          context,
          'Account created successfully!\n\nName: ${_nameController.text}\nEmail: ${_emailController.text}\nUser Type: $_selectedUserType',
        );

        // Navigate to login screen
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Email already in use';
          break;
        case 'weak-password':
          message = 'Password is too weak (min 6 characters)';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled';
          break;
        default:
          message = 'Registration failed: ${e.message}';
      }
      CustomDialog.showError(context, message);
    } catch (e) {
      CustomDialog.showError(context, 'An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Logo and Title
                GlassCard(
                  width: double.infinity,
                  height: 100,
                  borderRadius: 25,
                  blur: 15,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFBA002), Color(0xFFFFD166)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.person_add,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Create Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Join FinPredict today',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Sign Up Form
                GlassCard(
                  width: double.infinity,
                  borderRadius: 25,
                  blur: 20,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 30),
                        CustomTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hintText: 'Enter your full name',
                          prefixIcon: Icons.person,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hintText: 'Enter your email',
                          prefixIcon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _selectedUserType,
                          onChanged: (value) {
                            setState(() {
                              _selectedUserType = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'User Type',
                            labelStyle:
                                const TextStyle(color: Color(0xFFF1F5F9)),
                            filled: true,
                            fillColor: const Color(0xFF1E293B).withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Color(0xFFFBA002), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            prefixIcon: const Icon(
                              Icons.category,
                              color: Color(0xFFFBA002),
                            ),
                          ),
                          dropdownColor: const Color(0xFF1E293B),
                          items: [
                            'Employee',
                            'Student',
                            'Non-Employee',
                            'Business Owner'
                          ]
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      type,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ))
                              .toList(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select user type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hintText: 'Enter your password (min 6 characters)',
                          prefixIcon: Icons.lock,
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          hintText: 'Re-enter your password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),
                        CustomButton(
                          text: 'Create Account',
                          onPressed: _signUp,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Color(0xFFFBA002),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
