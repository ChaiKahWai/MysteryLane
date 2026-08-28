import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
  });

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryBlue =
  Color(0xFF0284C7);

  static const Color teal =
  Color(0xFF0D9488);

  static const Color darkText =
  Color(0xFF0F172A);

  static const Color greyText =
  Color(0xFF64748B);

  static const Color pageBackground =
  Color(0xFFF8FAFC);

  static const Color borderColor =
  Color(0xFFE2E8F0);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController
  _newPasswordController =
  TextEditingController();

  final TextEditingController
  _confirmPasswordController =
  TextEditingController();

  // ============================================================
  // STATES
  // ============================================================

  bool _hideNewPassword = true;

  bool _hideConfirmPassword = true;

  bool _isSaving = false;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _newPasswordController.dispose();

    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // UPDATE PASSWORD
  // ============================================================

  Future<void> _updatePassword() async {
    if (_isSaving) {
      return;
    }

    final String newPassword =
    _newPasswordController.text.trim();

    final String confirmPassword =
    _confirmPasswordController.text.trim();

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (newPassword.isEmpty) {
      _showMessage(
        'Please enter your new password.',
      );

      return;
    }

    if (newPassword.length < 8) {
      _showMessage(
        'Password must contain at least 8 characters.',
      );

      return;
    }

    if (confirmPassword.isEmpty) {
      _showMessage(
        'Please confirm your new password.',
      );

      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage(
        'New password and confirm password do not match.',
      );

      return;
    }

    // ==========================================================
    // CHECK RECOVERY SESSION
    // ==========================================================

    final Session? session =
        SupabaseConfig.client.auth.currentSession;

    if (session == null) {
      _showMessage(
        'Your password reset link is invalid or has expired. Please request a new password reset email.',
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // ========================================================
      // UPDATE PASSWORD
      // ========================================================

      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      debugPrint(
        'PASSWORD CHANGED SUCCESSFULLY',
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // SUCCESS DIALOG
      // ========================================================

      await showDialog<void>(
        context: context,
        barrierDismissible: false,

        builder: (
            BuildContext dialogContext,
            ) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 55,
            ),

            title: const Text(
              'Password Changed',
              textAlign: TextAlign.center,
            ),

            content: const Text(
              'Your password has been changed successfully.',
              textAlign: TextAlign.center,
            ),

            actionsAlignment:
            MainAxisAlignment.center,

            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop();
                },

                style:
                FilledButton.styleFrom(
                  backgroundColor:
                  primaryBlue,
                ),

                child: const Text(
                  'DONE',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // RETURN TO PREVIOUS APP SCREEN
      // ========================================================
      //
      // IMPORTANT:
      // NO signOut().
      //
      // User remains logged in.
      // ========================================================

      Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      debugPrint(
        'PASSWORD UPDATE ERROR: $error',
      );

      _showMessage(
        'Unable to change password. Please try again.',
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
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      pageBackground,

      appBar: AppBar(
        backgroundColor:
        Colors.white,

        foregroundColor:
        darkText,

        elevation:
        0,

        title: const Text(
          'Change Password',

          style: TextStyle(
            fontWeight:
            FontWeight.w900,
          ),
        ),
      ),

      body: SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.all(
            22,
          ),

          child: Center(
            child:
            ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth:
                500,
              ),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,

                children: [
                  const SizedBox(
                    height:
                    24,
                  ),

                  // ====================================================
                  // ICON
                  // ====================================================

                  Center(
                    child:
                    Container(
                      width:
                      90,

                      height:
                      90,

                      decoration:
                      const BoxDecoration(
                        shape:
                        BoxShape.circle,

                        gradient:
                        LinearGradient(
                          begin:
                          Alignment.topLeft,

                          end:
                          Alignment.bottomRight,

                          colors: [
                            primaryBlue,
                            teal,
                          ],
                        ),
                      ),

                      child:
                      const Icon(
                        Icons
                            .lock_reset_rounded,

                        color:
                        Colors.white,

                        size:
                        45,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                    25,
                  ),

                  // ====================================================
                  // TITLE
                  // ====================================================

                  const Text(
                    'Create New Password',

                    textAlign:
                    TextAlign.center,

                    style:
                    TextStyle(
                      color:
                      darkText,

                      fontSize:
                      26,

                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height:
                    8,
                  ),

                  const Text(
                    'Enter and confirm your new password below.',

                    textAlign:
                    TextAlign.center,

                    style:
                    TextStyle(
                      color:
                      greyText,

                      fontSize:
                      13,

                      height:
                      1.5,
                    ),
                  ),

                  const SizedBox(
                    height:
                    36,
                  ),

                  // ====================================================
                  // NEW PASSWORD
                  // ====================================================

                  const Text(
                    'NEW PASSWORD *',

                    style:
                    TextStyle(
                      color:
                      greyText,

                      fontSize:
                      10,

                      fontWeight:
                      FontWeight.w900,

                      letterSpacing:
                      1,
                    ),
                  ),

                  const SizedBox(
                    height:
                    8,
                  ),

                  TextField(
                    controller:
                    _newPasswordController,

                    obscureText:
                    _hideNewPassword,

                    textInputAction:
                    TextInputAction.next,

                    autofillHints:
                    const [
                      AutofillHints.newPassword,
                    ],

                    decoration:
                    _passwordDecoration(
                      hint:
                      'Enter new password',

                      hidden:
                      _hideNewPassword,

                      onVisibility:
                          () {
                        setState(
                              () {
                            _hideNewPassword =
                            !_hideNewPassword;
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    height:
                    8,
                  ),

                  const Row(
                    children: [
                      Icon(
                        Icons
                            .info_outline_rounded,

                        color:
                        greyText,

                        size:
                        14,
                      ),

                      SizedBox(
                        width:
                        5,
                      ),

                      Expanded(
                        child:
                        Text(
                          'Password must contain at least 8 characters.',

                          style:
                          TextStyle(
                            color:
                            greyText,

                            fontSize:
                            10,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                    24,
                  ),

                  // ====================================================
                  // CONFIRM PASSWORD
                  // ====================================================

                  const Text(
                    'CONFIRM NEW PASSWORD *',

                    style:
                    TextStyle(
                      color:
                      greyText,

                      fontSize:
                      10,

                      fontWeight:
                      FontWeight.w900,

                      letterSpacing:
                      1,
                    ),
                  ),

                  const SizedBox(
                    height:
                    8,
                  ),

                  TextField(
                    controller:
                    _confirmPasswordController,

                    obscureText:
                    _hideConfirmPassword,

                    textInputAction:
                    TextInputAction.done,

                    autofillHints:
                    const [
                      AutofillHints.newPassword,
                    ],

                    onSubmitted:
                        (_) {
                      if (!_isSaving) {
                        _updatePassword();
                      }
                    },

                    decoration:
                    _passwordDecoration(
                      hint:
                      'Confirm new password',

                      hidden:
                      _hideConfirmPassword,

                      onVisibility:
                          () {
                        setState(
                              () {
                            _hideConfirmPassword =
                            !_hideConfirmPassword;
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    height:
                    34,
                  ),

                  // ====================================================
                  // CHANGE PASSWORD
                  // ====================================================

                  SizedBox(
                    height:
                    54,

                    child:
                    FilledButton(
                      onPressed:
                      _isSaving
                          ? null
                          : _updatePassword,

                      style:
                      FilledButton.styleFrom(
                        backgroundColor:
                        primaryBlue,

                        foregroundColor:
                        Colors.white,

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            14,
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
                          2,

                          color:
                          Colors.white,
                        ),
                      )
                          : const Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,

                        children: [
                          Icon(
                            Icons.lock_reset_rounded,
                          ),

                          SizedBox(
                            width: 8,
                          ),

                          Text(
                            'CHANGE PASSWORD',

                            style:
                            TextStyle(
                              fontWeight:
                              FontWeight.w900,

                              letterSpacing:
                              0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PASSWORD FIELD
  // ============================================================

  InputDecoration _passwordDecoration({
    required String hint,
    required bool hidden,
    required VoidCallback onVisibility,
  }) {
    return InputDecoration(
      hintText: hint,

      filled: true,

      fillColor: Colors.white,

      prefixIcon:
      const Icon(
        Icons.lock_outline_rounded,
      ),

      suffixIcon:
      IconButton(
        onPressed:
        onVisibility,

        icon:
        Icon(
          hidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
      ),

      contentPadding:
      const EdgeInsets.symmetric(
        horizontal:
        14,

        vertical:
        16,
      ),

      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),

        borderSide:
        const BorderSide(
          color:
          borderColor,
        ),
      ),

      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),

        borderSide:
        const BorderSide(
          color:
          borderColor,
        ),
      ),

      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),

        borderSide:
        const BorderSide(
          color:
          primaryBlue,

          width:
          2,
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(
            message,
          ),

          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }
}