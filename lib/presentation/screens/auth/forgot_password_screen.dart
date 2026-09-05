import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController =
  TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(email);
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();

    final String email =
    _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showMessage(
        'Please fill in your registered email address.',
        isError: true,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dynamic result =
      await SupabaseConfig.client.rpc(
        'is_password_reset_eligible',
        params: {'input_email': email},
      );

      if (result != true) {
        if (!mounted) return;
        _showMessage(
          'Password reset is unavailable for this account. '
              'Please complete your registration and email verification first.',
          isError: true,
        );
        return;
      }

      await SupabaseConfig.client.auth.resetPasswordForEmail(
        email,
        redirectTo:
        'mysterylane://reset-password-callback',
      );

      if (!mounted) return;

      _showMessage(
        'A password-reset email has been sent. '
            'Please check your email.',
        isError: false,
      );
    } on AuthException {
      if (!mounted) return;
      _showMessage(
        'Unable to complete the request. Please try again.',
        isError: true,
      );
    } on PostgrestException {
      if (!mounted) return;
      _showMessage(
        'Unable to complete the request. Please try again.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Unable to complete the request. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(
      String message, {
        bool isError = false,
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFBAE6FD),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: primaryBlue,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AUTHENTICATION LOG',
                        style: TextStyle(
                          fontSize: 9,
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'MysteryLane',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color:
                      Color.fromRGBO(15, 23, 42, 0.08),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACCOUNT RECOVERY',
                        style: TextStyle(
                          fontSize: 9,
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                          color: darkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter your registered email address '
                            'and we will send you a secure link '
                            'to reset your password.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'EMAIL ADDRESS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType:
                        TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText:
                          'explorer@mysterylane.app',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor:
                          const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(13),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(13),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(13),
                            borderSide: const BorderSide(
                              color: primaryBlue,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return null;
                          }

                          if (!_isValidEmail(
                            value.trim(),
                          )) {
                            return 'Please enter a valid email address.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : _sendResetLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
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
                            'SEND RESET LINK',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                              FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 17,
                          ),
                          label: const Text(
                            'BACK TO LOGIN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryBlue,
                          ),
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
    );
  }
}
