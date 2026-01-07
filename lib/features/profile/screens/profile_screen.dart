import 'package:flutter/material.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/widgets/custom_text_field.dart';
import 'package:finpredict/widgets/custom_dialog.dart';
import 'package:finpredict/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finpredict/features/auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isChangingPassword = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    _currentUser = _auth.currentUser;

    if (_currentUser != null) {
      final userData = await _firebaseService.getUserData(_currentUser!.uid);

      if (userData != null) {
        setState(() {
          _userData = userData;
          _nameController.text =
              userData['name'] ?? _currentUser!.displayName ?? '';
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUser != null) {
        final updateData = {
          'name': _nameController.text.trim(),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        await _firebaseService.updateUserProfile(_currentUser!.uid, updateData);

        // Update display name in Firebase Auth
        await _currentUser!.updateDisplayName(_nameController.text.trim());

        setState(() {
          _isEditing = false;
          _userData?['name'] = _nameController.text.trim();
        });

        CustomDialog.showSuccess(context, 'Profile updated successfully!');
      }
    } catch (e) {
      CustomDialog.showError(context, 'Failed to update profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      CustomDialog.showError(context, 'New passwords do not match!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Re-authenticate user before changing password
      final credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: _currentPasswordController.text,
      );

      await _currentUser!.reauthenticateWithCredential(credential);

      // Change password
      await _currentUser!.updatePassword(_newPasswordController.text);

      // Clear password fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _isChangingPassword = false;
      });

      CustomDialog.showSuccess(context, 'Password changed successfully!');
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect';
          break;
        case 'weak-password':
          message = 'New password is too weak';
          break;
        default:
          message = 'Failed to change password: ${e.message}';
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

  Future<void> _sendPasswordResetEmail() async {
    if (_currentUser?.email == null) {
      CustomDialog.showError(context, 'No email associated with this account');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: _currentUser!.email!);
      CustomDialog.showSuccess(
        context,
        'Password reset email sent to ${_currentUser!.email}\nPlease check your inbox.',
      );
    } catch (e) {
      CustomDialog.showError(context, 'Failed to send reset email: $e');
    }
  }

  Future<void> _logout() async {
    final confirmed = await CustomDialog.showConfirmation(
      context,
      'Logout',
      'Are you sure you want to logout?',
    );

    if (confirmed == true) {
      try {
        await _auth.signOut();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        CustomDialog.showError(context, 'Logout failed: $e');
      }
    }
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
                'Loading profile...',
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
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
                    // Profile Header
                    GlassCard(
                      width: double.infinity,
                      borderRadius: 25,
                      blur: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFFFBA002),
                              child: Text(
                                (_userData?['name']?[0] ??
                                        _currentUser?.email?[0] ??
                                        'U')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _userData?['name'] ??
                                  _currentUser?.displayName ??
                                  'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentUser?.email ?? 'No email',
                              style: TextStyle(
                                color: const Color(0xFF94A3B8),
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 20),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 400;
                                return isWide
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: _buildProfileButtons(),
                                      )
                                    : Column(
                                        children: _buildProfileButtons(),
                                      );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Profile Form
                    if (_isEditing)
                      GlassCard(
                        width: double.infinity,
                        borderRadius: 25,
                        blur: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _profileFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Edit Profile Information',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                CustomTextField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  hintText: 'Enter your full name',
                                  prefixIcon: Icons.person,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Password Change Section
                    GlassCard(
                      width: double.infinity,
                      borderRadius: 25,
                      blur: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!_isChangingPassword)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isChangingPassword = true;
                                      });
                                    },
                                    child: const Text(
                                      'Change',
                                      style: TextStyle(
                                        color: Color(0xFFFBA002),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (_isChangingPassword) ...[
                              const SizedBox(height: 20),
                              Form(
                                key: _passwordFormKey,
                                child: Column(
                                  children: [
                                    CustomTextField(
                                      controller: _currentPasswordController,
                                      label: 'Current Password',
                                      hintText: 'Enter current password',
                                      prefixIcon: Icons.lock,
                                      obscureText: true,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter current password';
                                        }
                                        if (value.length < 6) {
                                          return 'Password must be at least 6 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    CustomTextField(
                                      controller: _newPasswordController,
                                      label: 'New Password',
                                      hintText: 'Enter new password',
                                      prefixIcon: Icons.lock_outline,
                                      obscureText: true,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter new password';
                                        }
                                        if (value.length < 6) {
                                          return 'Password must be at least 6 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    CustomTextField(
                                      controller: _confirmPasswordController,
                                      label: 'Confirm New Password',
                                      hintText: 'Confirm new password',
                                      prefixIcon: Icons.lock_outline,
                                      obscureText: true,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please confirm new password';
                                        }
                                        if (value !=
                                            _newPasswordController.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isWide =
                                            constraints.maxWidth > 350;
                                        return isWide
                                            ? Row(
                                                children: [
                                                  CustomButton(
                                                    text: 'Update Password',
                                                    onPressed: _changePassword,
                                                    isLoading: _isLoading,
                                                    width: 160,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  CustomButton(
                                                    text: 'Cancel',
                                                    onPressed: () {
                                                      setState(() {
                                                        _isChangingPassword =
                                                            false;
                                                        _currentPasswordController
                                                            .clear();
                                                        _newPasswordController
                                                            .clear();
                                                        _confirmPasswordController
                                                            .clear();
                                                      });
                                                    },
                                                    backgroundColor:
                                                        const Color(0xFFEF4444),
                                                    width: 100,
                                                  ),
                                                ],
                                              )
                                            : Column(
                                                children: [
                                                  CustomButton(
                                                    text: 'Update Password',
                                                    onPressed: _changePassword,
                                                    isLoading: _isLoading,
                                                    width: double.infinity,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  CustomButton(
                                                    text: 'Cancel',
                                                    onPressed: () {
                                                      setState(() {
                                                        _isChangingPassword =
                                                            false;
                                                        _currentPasswordController
                                                            .clear();
                                                        _newPasswordController
                                                            .clear();
                                                        _confirmPasswordController
                                                            .clear();
                                                      });
                                                    },
                                                    backgroundColor:
                                                        const Color(0xFFEF4444),
                                                    width: double.infinity,
                                                  ),
                                                ],
                                              );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Account Actions
                    GlassCard(
                      width: double.infinity,
                      borderRadius: 25,
                      blur: 20,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'Account Actions',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: Icon(
                                Icons.email,
                                color: const Color(0xFFFBA002),
                              ),
                              title: const Text(
                                'Send Password Reset Email',
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                'Reset via email',
                                style:
                                    TextStyle(color: const Color(0xFF94A3B8)),
                              ),
                              onTap: _sendPasswordResetEmail,
                            ),
                            const Divider(color: Color(0xFF334155)),
                            ListTile(
                              leading: Icon(
                                Icons.logout,
                                color: const Color(0xFFEF4444),
                              ),
                              title: const Text(
                                'Logout',
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                'Sign out from this device',
                                style:
                                    TextStyle(color: const Color(0xFF94A3B8)),
                              ),
                              onTap: _logout,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Account Information
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
                              'Account Information',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Column(
                              children: [
                                _buildInfoItem(
                                    'User ID', _currentUser?.uid ?? 'N/A'),
                                const SizedBox(height: 12),
                                _buildInfoItem(
                                    'Email Verified',
                                    _currentUser?.emailVerified.toString() ??
                                        'false'),
                                const SizedBox(height: 12),
                                _buildInfoItem(
                                    'Account Created',
                                    _currentUser?.metadata.creationTime
                                            ?.toString()
                                            .split('.')
                                            .first ??
                                        'N/A'),
                                const SizedBox(height: 12),
                                _buildInfoItem(
                                    'Last Sign In',
                                    _currentUser?.metadata.lastSignInTime
                                            ?.toString()
                                            .split('.')
                                            .first ??
                                        'N/A'),
                                const SizedBox(height: 12),
                                _buildInfoItem('Account Type',
                                    _userData?['userType'] ?? 'Regular User'),
                              ],
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
          );
        },
      ),
    );
  }

  List<Widget> _buildProfileButtons() {
    final buttons = <Widget>[];

    if (!_isEditing) {
      buttons.add(
        CustomButton(
          text: 'Edit Profile',
          onPressed: () {
            setState(() {
              _isEditing = true;
            });
          },
          width: 150,
        ),
      );
    } else {
      buttons.addAll([
        CustomButton(
          text: 'Save',
          onPressed: _updateProfile,
          isLoading: _isLoading,
          width: 100,
        ),
        const SizedBox(width: 10, height: 10),
        CustomButton(
          text: 'Cancel',
          onPressed: () {
            setState(() {
              _isEditing = false;
              _nameController.text = _userData?['name'] ?? '';
            });
          },
          backgroundColor: const Color(0xFFEF4444),
          width: 100,
        ),
      ]);
    }

    return buttons;
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              if (value.length > 30)
                IconButton(
                  icon: const Icon(Icons.content_copy, size: 18),
                  color: const Color(0xFF94A3B8),
                  onPressed: () {
                    // Copy to clipboard
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
