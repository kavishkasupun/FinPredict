import 'package:flutter/material.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_text_field.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/features/auth/screens/signup_screen.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/services/firebase_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finpredict/features/dashboard/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _isGoogleLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user != null) {
        print('Google User UID: ${user.uid}');
        print('Google User Email: ${user.email}');
        print('Google User Display Name: ${user.displayName}');

        final userExists = await _firebaseService.checkUserExists(user.uid);

        if (!userExists) {
          print('Creating new Google user in Firestore...');
          final userData = {
            'uid': user.uid,
            'name': user.displayName ?? 'Google User',
            'email': user.email,
            'photoUrl': user.photoURL,
            'userType': 'Google User',
            'createdAt': DateTime.now().toIso8601String(),
            'monthlyBudget': 60000.0,
            'totalSavings': 0.0,
            'isGoogleUser': true,
          };

          await _firebaseService.saveUserData(user.uid, userData);
          print('Google user created in Firestore successfully');
        } else {
          print('Google user already exists in Firestore');
        }

        CustomDialog.showSuccess(
          context,
          'Successfully logged in with Google!\n\nWelcome ${user.displayName ?? user.email}',
        );

        await Future.delayed(const Duration(milliseconds: 1500));

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Google Sign In Error: $e');

      String errorMessage = 'Google sign in failed';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'account-exists-with-different-credential':
            errorMessage = 'Account already exists with different credentials';
            break;
          case 'invalid-credential':
            errorMessage = 'Invalid credentials';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Google sign in is not enabled';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled';
            break;
          case 'user-not-found':
            errorMessage = 'No user found';
            break;
          default:
            errorMessage = 'Google sign in failed: ${e.message}';
        }
      }

      CustomDialog.showError(context, errorMessage);
    } finally {
      setState(() {
        _isGoogleLoading = false;
      });
    }
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final User? user = userCredential.user;

      if (user != null) {
        print('Email User UID: ${user.uid}');
        print('Email User Email: ${user.email}');

        // Check if user exists in Firestore
        final userExists = await _firebaseService.checkUserExists(user.uid);

        if (!userExists) {
          print('Creating new email user in Firestore...');
          // If user doesn't exist in Firestore, create them
          final userData = {
            'uid': user.uid,
            'name': user.email?.split('@').first ?? 'New User',
            'email': user.email,
            'userType': 'Regular User',
            'createdAt': DateTime.now().toIso8601String(),
            'monthlyBudget': 60000.0,
            'totalSavings': 0.0,
            'isGoogleUser': false,
          };

          await _firebaseService.saveUserData(user.uid, userData);
          print('Email user created in Firestore successfully');
        } else {
          print('Email user already exists in Firestore');
        }

        CustomDialog.showSuccess(
          context,
          'Successfully logged in!\n\nWelcome ${user.email}',
        );

        await Future.delayed(const Duration(milliseconds: 1500));

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        case 'too-many-requests':
          message = 'Too many login attempts. Try again later';
          break;
        default:
          message = 'Login failed: ${e.message}';
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

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      CustomDialog.showError(context, 'Please enter your email address first');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      CustomDialog.showError(context, 'Please enter a valid email address');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      CustomDialog.showSuccess(
        context,
        'Password reset email sent to $email\nPlease check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        default:
          message = 'Failed to send reset email: ${e.message}';
      }
      CustomDialog.showError(context, message);
    } catch (e) {
      CustomDialog.showError(context, 'An error occurred: $e');
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
                const SizedBox(height: 80),
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
                          Icons.auto_graph,
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
                            'Welcome Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Sign in to continue',
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
                GlassCard(
                  width: double.infinity,
                  borderRadius: 25,
                  blur: 20,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Login to Your Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 30),
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
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hintText: 'Enter your password',
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _sendPasswordReset,
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: const Color(0xFFFBA002),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        CustomButton(
                          text: 'Sign In',
                          onPressed: _loginWithEmail,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: const Color(0xFF334155),
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Or continue with',
                                style: TextStyle(
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: const Color(0xFF334155),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        CustomButton(
                          text: 'Sign in with Google',
                          onPressed: _loginWithGoogle,
                          isLoading: _isGoogleLoading,
                          backgroundColor: Colors.white,
                          textColor: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign Up',
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
