import 'package:finpredict/core/theme/app_theme.dart';
import 'package:finpredict/features/auth/screens/login_screen.dart';
import 'package:finpredict/features/auth/screens/splash_screen.dart';
import 'package:finpredict/features/dashboard/screens/home_screen.dart';
import 'package:finpredict/services/firebase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Add other providers here
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinPredict',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: Provider.of<ThemeProvider>(context).themeMode,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Wait for Firebase to initialize completely
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if user is already logged in via Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;

      print('📱 Current User in AuthWrapper: ${currentUser?.uid}');
      print('📱 Current User Email: ${currentUser?.email}');
      print('📱 User Logged In: ${currentUser != null}');

      if (currentUser != null) {
        // For Google users or verified email users
        final isGoogleUser = currentUser.providerData
            .any((userInfo) => userInfo.providerId == 'google.com');
        final isEmailVerified = currentUser.emailVerified;

        if (isGoogleUser || isEmailVerified) {
          // Check if user exists in Firestore
          final userExists =
              await FirebaseService().checkUserExists(currentUser.uid);

          print('📱 User exists in Firestore: $userExists');

          if (!userExists) {
            print(
                '⚠️ User exists in Auth but not in Firestore. Creating user in Firestore...');
            // Create user in Firestore if they don't exist
            final userData = {
              'uid': currentUser.uid,
              'name': currentUser.displayName ??
                  currentUser.email?.split('@').first ??
                  'User',
              'email': currentUser.email,
              'userType': isGoogleUser ? 'Google User' : 'Regular User',
              'emailVerified': isEmailVerified,
              'accountStatus': 'active',
              'createdAt': DateTime.now().toIso8601String(),
              'monthlyBudget': 60000.0,
              'totalSavings': 0.0,
              'isGoogleUser': isGoogleUser,
              'lastLogin': DateTime.now().toIso8601String(),
            };

            await FirebaseService().saveUserData(currentUser.uid, userData);
          } else {
            // Update last login time
            await FirebaseService().updateLastLogin(currentUser.uid);
          }

          setState(() {
            _isLoggedIn = true;
            _isLoading = false;
          });
          return;
        } else {
          // Email not verified - show login screen
          print('⚠️ Email not verified, showing login screen');
          // Sign out the user so they can verify email
          await FirebaseAuth.instance.signOut();
        }
      }
    } catch (e) {
      print('❌ Error checking auth status: $e');
    }

    // If we reach here, user is not logged in or there was an error
    setState(() {
      _isLoggedIn = false;
      _isLoading = false;
    });
  }

  void _handleSplashComplete() {
    // This is called when splash screen animation completes
    // Auth check is already done in initState, so we don't need to do anything here
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SplashScreen(onAnimationComplete: _handleSplashComplete);
    }

    return _isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
