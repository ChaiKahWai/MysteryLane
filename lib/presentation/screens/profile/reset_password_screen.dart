import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../auth/login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  final TextEditingController _newPasswordController =
  TextEditingController();

  final TextEditingController
  _confirmPasswordController =
  TextEditingController();

  bool _isSaving = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // C10
  bool _isPasswordValid(String password) {
    final bool hasMinimumLength =
        password.length >= 8;

    final bool hasUppercase =
    RegExp(r'[A-Z]').hasMatch(password);

    final bool hasLowercase =
    RegExp(r'[a-z]').hasMatch(password);

    final bool hasNumber =
    RegExp(r'[0-9]').hasMatch(password);

    final bool hasSpecialCharacter =
    RegExp(
      r'''[!@#$%^&*(),.?":{}|<>]''',
    ).hasMatch(password);

    return hasMinimumLength &&
        hasUppercase &&
        hasLowercase &&
        hasNumber &&
        hasSpecialCharacter;
  }

  Future<void> _goToLogin() async {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  // A6e
  Future<void> _cancelResetAndReturnToLogin() async {
    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (_) {
      // The navigation still continues.
    }

    if (!mounted) return;

    await _goToLogin();
  }

  // A6b / M9 / C9
  Future<void> _handleUnavailableRecoverySession() async {
    _showMessage(
      'This password-reset session is invalid or has expired. '
          'Please request a new password-reset link.',
      isError: true,
    );

    await Future<void>.delayed(
      const Duration(milliseconds: 1200),
    );

    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (_) {}

    if (!mounted) return;

    await _goToLogin();
  }

  Future<void> _updatePassword() async {
    FocusScope.of(context).unfocus();

    final String newPassword =
        _newPasswordController.text;

    final String confirmPassword =
        _confirmPasswordController.text;

    // A6g / M14 / C13
    if (newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showMessage(
        'Please fill both password fields.',
        isError: true,
      );
      return;
    }

    // A6c / M10 / C10
    if (!_isPasswordValid(newPassword)) {
      _showMessage(
        'Please enter a password that meets '
            'the password requirements.',
        isError: true,
      );
      return;
    }

    // A6d / M11 / C11
    if (newPassword != confirmPassword) {
      _showMessage(
        'The passwords do not match. Please try again.',
        isError: true,
      );
      return;
    }

    // A6 Step 21
    // A6b / M9 / C9
    final Session? recoverySession =
        SupabaseConfig.client.auth.currentSession;

    if (recoverySession == null) {
      await _handleUnavailableRecoverySession();
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // A6 Step 22
      final UserResponse response =
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (response.user == null) {
        if (!mounted) return;

        // A7 / M15
        _showMessage(
          'Unable to complete the request. Please try again.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;

      // A6 Step 23 / M12
      _showMessage(
        'Your password has been reset successfully. '
            'Please log in using your new password.',
        isError: false,
      );

      await Future<void>.delayed(
        const Duration(milliseconds: 1000),
      );

      // A6 Step 24
      await SupabaseConfig.client.auth.signOut();

      if (!mounted) return;

      // A6 Step 25
      await _goToLogin();
    } on AuthException {
      if (!mounted) return;

      // A7 / M15
      _showMessage(
        'Unable to complete the request. Please try again.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;

      // A7 / M15
      _showMessage(
        'Unable to complete the request. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(
      String message, {
        bool isError = true,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          isError ? Colors.redAccent : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0284C7);
    const Color darkText = Color(0xFF0F172A);

    return WillPopScope(
      // A6e
      onWillPop: () async {
        await _cancelResetAndReturnToLogin();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primaryBlue,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            // A6e
            onPressed: _cancelResetAndReturnToLogin,
            icon: const Icon(
              Icons.arrow_back,
            ),
          ),
          title: const Text(
            'Reset Password',
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_reset_rounded,
                  size: 52,
                  color: primaryBlue,
                ),

                const SizedBox(height: 18),

                const Text(
                  'Create New Password',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                    color: darkText,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'The new password must contain at least '
                      '8 characters, including at least one '
                      'uppercase letter, one lowercase letter, '
                      'one number, and one special character.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 28),

                TextField(
                  controller: _newPasswordController,
                  obscureText: !_showNewPassword,
                  decoration: InputDecoration(
                    labelText: 'NEW PASSWORD',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _showNewPassword =
                          !_showNewPassword;
                        });
                      },
                      icon: Icon(
                        _showNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(13),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller:
                  _confirmPasswordController,
                  obscureText:
                  !_showConfirmPassword,
                  decoration: InputDecoration(
                    labelText:
                    'CONFIRM NEW PASSWORD',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _showConfirmPassword =
                          !_showConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(13),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                    _isSaving ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'RESET PASSWORD',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}