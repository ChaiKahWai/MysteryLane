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

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _newPasswordController =
  TextEditingController();

  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _isSaving = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  static const Color primaryBlue = Color(0xFF0284C7);
  static const Color darkText = Color(0xFF0F172A);
  static const Color mutedText = Color(0xFF64748B);

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // PASSWORD VALIDATION
  // ============================================================

  bool _isPasswordValid(String password) {
    final bool hasMinimumLength =
        password.length >= 8;

    final bool hasUppercase =
    RegExp(r'[A-Z]').hasMatch(password);

    final bool hasLowercase =
    RegExp(r'[a-z]').hasMatch(password);

    final bool hasNumber =
    RegExp(r'[0-9]').hasMatch(password);

    // "_" is EXPLICITLY accepted as a special character.
    final bool hasSpecialCharacter =
        password.contains('_') ||
            RegExp(r'[^A-Za-z0-9\s_]').hasMatch(password);

    return hasMinimumLength &&
        hasUppercase &&
        hasLowercase &&
        hasNumber &&
        hasSpecialCharacter;
  }

  // ============================================================
  // CHECK SAME AS CURRENT PASSWORD
  // ============================================================

  Future<bool> _isSameAsCurrentPassword(
      String proposedPassword,
      ) async {
    final dynamic result =
    await SupabaseConfig.client.rpc(
      'is_current_password',
      params: {
        'p_password': proposedPassword,
      },
    );

    return result == true;
  }

  // ============================================================
  // GO TO LOGIN
  // ============================================================

  Future<void> _goToLogin() async {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  // ============================================================
  // CANCEL RESET
  // ============================================================

  Future<void>
  _cancelResetAndReturnToLogin() async {
    try {
      await SupabaseConfig.client.auth.signOut(
        scope: SignOutScope.local,
      );
    } catch (_) {
      // Continue navigation.
    }

    if (!mounted) return;

    await _goToLogin();
  }

  // ============================================================
  // INVALID / EXPIRED RECOVERY SESSION
  // ============================================================

  Future<void>
  _handleUnavailableRecoverySession() async {
    _showMessage(
      'This password-reset session is invalid or has expired. '
          'Please request a new password-reset link.',
      isError: true,
    );

    await Future<void>.delayed(
      const Duration(
        milliseconds: 1200,
      ),
    );

    try {
      await SupabaseConfig.client.auth.signOut(
        scope: SignOutScope.local,
      );
    } catch (_) {}

    if (!mounted) return;

    await _goToLogin();
  }

  // ============================================================
  // RESET PASSWORD
  // ============================================================

  Future<void> _updatePassword() async {
    FocusScope.of(context).unfocus();

    // DO NOT trim password.
    final String newPassword =
        _newPasswordController.text;

    final String confirmPassword =
        _confirmPasswordController.text;

    // ==========================================================
    // 1. REQUIRED FIELDS
    // ==========================================================

    if (newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showMessage(
        'Please fill both password fields.',
        isError: true,
      );

      return;
    }

    // ==========================================================
    // 2. PASSWORD STRENGTH
    // ==========================================================

    if (!_isPasswordValid(newPassword)) {
      _showMessage(
        'Password must contain at least 8 characters, '
            'including at least one uppercase letter, '
            'one lowercase letter, one number, '
            'and one special character. '
            'Underscore (_) is accepted.',
        isError: true,
      );

      return;
    }

    // ==========================================================
    // 3. CONFIRM PASSWORD
    // ==========================================================

    if (newPassword != confirmPassword) {
      _showMessage(
        'The passwords do not match. Please try again.',
        isError: true,
      );

      return;
    }

    // ==========================================================
    // 4. CHECK PASSWORD RECOVERY SESSION
    // ==========================================================

    final Session? recoverySession =
        SupabaseConfig.client.auth.currentSession;

    final User? recoveryUser =
        SupabaseConfig.client.auth.currentUser;

    if (recoverySession == null ||
        recoveryUser == null) {
      await _handleUnavailableRecoverySession();
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // ========================================================
      // 5. CHECK SAME AS CURRENT PASSWORD
      // ========================================================

      final bool sameAsCurrent =
      await _isSameAsCurrentPassword(
        newPassword,
      );

      if (sameAsCurrent) {
        if (!mounted) return;

        _showMessage(
          'The new password cannot be the same as your current '
              'password. Please choose another password.',
          isError: true,
        );

        return;
      }

      // ========================================================
      // 6. UPDATE PASSWORD
      // ========================================================

      final UserResponse response =
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (response.user == null) {
        if (!mounted) return;

        _showMessage(
          'Unable to complete the request. Please try again.',
          isError: true,
        );

        return;
      }

      if (!mounted) return;

      // ========================================================
      // 7. SUCCESS
      // ========================================================

      _showMessage(
        'Your password has been reset successfully. '
            'Please log in using your new password.',
        isError: false,
      );

      await Future<void>.delayed(
        const Duration(
          milliseconds: 1000,
        ),
      );

      // ========================================================
      // 8. END RECOVERY SESSION
      // ========================================================

      try {
        await SupabaseConfig.client.auth.signOut(
          scope: SignOutScope.local,
        );
      } catch (_) {}

      if (!mounted) return;

      await _goToLogin();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      debugPrint(
        'RESET PASSWORD RPC ERROR: '
            'message=${error.message}, '
            'code=${error.code}',
      );

      _showMessage(
        'Unable to verify the current password. '
            'Please make sure the Supabase password-check function '
            'has been created, then try again.',
        isError: true,
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      debugPrint(
        'RESET PASSWORD AUTH ERROR: '
            'message=${error.message}, '
            'code=${error.code}',
      );

      final String errorText =
      error.message.toLowerCase();

      if ((errorText.contains('password') &&
          errorText.contains('same')) ||
          errorText.contains(
            'different from the old',
          ) ||
          errorText.contains(
            'different from your old',
          )) {
        _showMessage(
          'The new password cannot be the same as your current '
              'password. Please choose another password.',
          isError: true,
        );

        return;
      }

      // Show real Supabase message.
      _showMessage(
        error.message,
        isError: true,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'RESET PASSWORD ERROR: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      _showMessage(
        'Unable to verify or update the password. '
            'Please try again.',
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

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message, {
        bool isError = true,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
          backgroundColor:
          isError
              ? Colors.redAccent
              : Colors.green,
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return WillPopScope(
      onWillPop: () async {
        await _cancelResetAndReturnToLogin();

        return false;
      },
      child: Scaffold(
        backgroundColor:
        const Color(
          0xFFF8FAFC,
        ),

        appBar: AppBar(
          backgroundColor:
          Colors.white,
          foregroundColor:
          primaryBlue,
          elevation:
          0,
          automaticallyImplyLeading:
          false,

          leading:
          IconButton(
            onPressed:
            _isSaving
                ? null
                : _cancelResetAndReturnToLogin,
            icon:
            const Icon(
              Icons.arrow_back,
            ),
          ),

          title:
          const Text(
            'Reset Password',
          ),
        ),

        body: SafeArea(
          child:
          SingleChildScrollView(
            padding:
            const EdgeInsets.all(
              22,
            ),

            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                const Icon(
                  Icons.lock_reset_rounded,
                  size:
                  52,
                  color:
                  primaryBlue,
                ),

                const SizedBox(
                  height:
                  18,
                ),

                const Text(
                  'Create New Password',
                  style:
                  TextStyle(
                    fontSize:
                    26,
                    fontWeight:
                    FontWeight.bold,
                    fontFamily:
                    'serif',
                    color:
                    darkText,
                  ),
                ),

                const SizedBox(
                  height:
                  10,
                ),

                const Text(
                  'The new password must contain at least '
                      '8 characters, including at least one '
                      'uppercase letter, one lowercase letter, '
                      'one number, and one special character. '
                      'Underscore (_) is accepted.',
                  style:
                  TextStyle(
                    fontSize:
                    13,
                    color:
                    mutedText,
                    height:
                    1.45,
                  ),
                ),

                const SizedBox(
                  height:
                  28,
                ),

                // ==================================================
                // NEW PASSWORD
                // ==================================================

                TextField(
                  controller:
                  _newPasswordController,

                  obscureText:
                  !_showNewPassword,

                  enabled:
                  !_isSaving,

                  enableSuggestions:
                  false,

                  autocorrect:
                  false,

                  textInputAction:
                  TextInputAction.next,

                  decoration:
                  InputDecoration(
                    labelText:
                    'NEW PASSWORD',

                    hintText:
                    'Enter new password',

                    prefixIcon:
                    const Icon(
                      Icons.lock_outline,
                    ),

                    suffixIcon:
                    IconButton(
                      onPressed:
                          () {
                        setState(
                              () {
                            _showNewPassword =
                            !_showNewPassword;
                          },
                        );
                      },

                      icon:
                      Icon(
                        _showNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),

                    border:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(
                        13,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                  20,
                ),

                // ==================================================
                // CONFIRM PASSWORD
                // ==================================================

                TextField(
                  controller:
                  _confirmPasswordController,

                  obscureText:
                  !_showConfirmPassword,

                  enabled:
                  !_isSaving,

                  enableSuggestions:
                  false,

                  autocorrect:
                  false,

                  textInputAction:
                  TextInputAction.done,

                  decoration:
                  InputDecoration(
                    labelText:
                    'CONFIRM NEW PASSWORD',

                    hintText:
                    'Re-enter new password',

                    prefixIcon:
                    const Icon(
                      Icons.lock_outline,
                    ),

                    suffixIcon:
                    IconButton(
                      onPressed:
                          () {
                        setState(
                              () {
                            _showConfirmPassword =
                            !_showConfirmPassword;
                          },
                        );
                      },

                      icon:
                      Icon(
                        _showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),

                    border:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(
                        13,
                      ),
                    ),
                  ),

                  onSubmitted:
                      (_) {
                    if (!_isSaving) {
                      _updatePassword();
                    }
                  },
                ),

                const SizedBox(
                  height:
                  30,
                ),

                // ==================================================
                // RESET PASSWORD BUTTON
                // ==================================================

                SizedBox(
                  width:
                  double.infinity,

                  height:
                  54,

                  child:
                  ElevatedButton(
                    onPressed:
                    _isSaving
                        ? null
                        : _updatePassword,

                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      primaryBlue,

                      foregroundColor:
                      Colors.white,

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),

                    child:
                    _isSaving
                        ? const SizedBox(
                      width:
                      22,
                      height:
                      22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2.5,
                        color:
                        Colors.white,
                      ),
                    )
                        : const Text(
                      'RESET PASSWORD',
                      style:
                      TextStyle(
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

//test