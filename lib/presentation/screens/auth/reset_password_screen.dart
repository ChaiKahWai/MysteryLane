import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _passwordController =
  TextEditingController();

  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _isLoading = false;

  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // ==========================================
  // PASSWORD REQUIREMENTS
  // Same as Register Screen
  // ==========================================

  bool get _hasMinLength =>
      _passwordController.text.length >= 8;

  bool get _hasUppercase =>
      RegExp(r'[A-Z]').hasMatch(
        _passwordController.text,
      );

  bool get _hasLowercase =>
      RegExp(r'[a-z]').hasMatch(
        _passwordController.text,
      );

  bool get _hasNumber =>
      RegExp(r'[0-9]').hasMatch(
        _passwordController.text,
      );

  bool get _hasSpecialCharacter =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(
        _passwordController.text,
      );

  bool get _isStrongPassword =>
      _hasMinLength &&
          _hasUppercase &&
          _hasLowercase &&
          _hasNumber &&
          _hasSpecialCharacter;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _updatePassword() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Password updated successfully. '
                  'Please log in with your new password.',
            ),
            backgroundColor: Colors.green,
          ),
        );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
          const LoginScreen(),
        ),
            (route) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.message,
            ),
            backgroundColor:
            Colors.redAccent,
          ),
        );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'An unexpected error occurred: $error',
            ),
            backgroundColor:
            Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue =
    Color(0xFF0284C7);

    const darkText =
    Color(0xFF0F172A);

    return Scaffold(
      backgroundColor:
      const Color(0xFFF8FAFC),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(24),

          child: Column(
            children: [
              const SizedBox(
                height: 40,
              ),

              const Text(
                'SET NEW PASSWORD',
                style: TextStyle(
                  fontSize: 9,
                  color: primaryBlue,
                  fontWeight:
                  FontWeight.bold,
                  letterSpacing: 1.8,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              const Text(
                'Create New Password',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                  FontWeight.bold,
                  fontFamily: 'serif',
                  color: darkText,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              const Text(
                'Please enter a strong password '
                    'to secure your account.',
                textAlign:
                TextAlign.center,
                style: TextStyle(
                  color:
                  Color(0xFF64748B),
                ),
              ),

              const SizedBox(
                height: 32,
              ),

              Form(
                key: _formKey,

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'NEW PASSWORD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        Color(
                          0xFF475569,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    TextFormField(
                      controller:
                      _passwordController,

                      obscureText:
                      !_showPassword,

                      onChanged: (_) {
                        setState(() {});
                      },

                      decoration:
                      InputDecoration(
                        hintText:
                        '••••••••',

                        prefixIcon:
                        const Icon(
                          Icons.lock_outline,
                        ),

                        suffixIcon:
                        IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons
                                .visibility_off
                                : Icons
                                .visibility,
                          ),

                          onPressed: () {
                            setState(() {
                              _showPassword =
                              !_showPassword;
                            });
                          },
                        ),

                        filled: true,
                        fillColor:
                        Colors.white,

                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return 'Password must contain at least 8 characters, '
                              'including at least one uppercase letter, '
                              'one lowercase letter, one number, '
                              'and one special character.';
                        }

                        if (!_isStrongPassword) {
                          return 'Password must contain at least 8 characters, '
                              'including at least one uppercase letter, '
                              'one lowercase letter, one number, '
                              'and one special character.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _buildPasswordRule(
                      'At least 8 characters',
                      _hasMinLength,
                    ),

                    _buildPasswordRule(
                      'At least one uppercase letter',
                      _hasUppercase,
                    ),

                    _buildPasswordRule(
                      'At least one lowercase letter',
                      _hasLowercase,
                    ),

                    _buildPasswordRule(
                      'At least one number',
                      _hasNumber,
                    ),

                    _buildPasswordRule(
                      'At least one special character',
                      _hasSpecialCharacter,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    const Text(
                      'CONFIRM NEW PASSWORD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        Color(
                          0xFF475569,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    TextFormField(
                      controller:
                      _confirmPasswordController,

                      obscureText:
                      !_showConfirmPassword,

                      decoration:
                      InputDecoration(
                        hintText:
                        '••••••••',

                        prefixIcon:
                        const Icon(
                          Icons.lock_outline,
                        ),

                        suffixIcon:
                        IconButton(
                          icon: Icon(
                            _showConfirmPassword
                                ? Icons
                                .visibility_off
                                : Icons
                                .visibility,
                          ),

                          onPressed: () {
                            setState(() {
                              _showConfirmPassword =
                              !_showConfirmPassword;
                            });
                          },
                        ),

                        filled: true,
                        fillColor:
                        Colors.white,

                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return 'Password and confirmation password do not match.';
                        }

                        if (value !=
                            _passwordController
                                .text) {
                          return 'Password and confirmation password do not match.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 32,
                    ),

                    SizedBox(
                      width:
                      double.infinity,
                      height: 54,

                      child:
                      ElevatedButton(
                        onPressed:
                        _isLoading
                            ? null
                            : _updatePassword,

                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          primaryBlue,

                          foregroundColor:
                          Colors.white,

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),

                        child:
                        _isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,
                            color:
                            Colors.white,
                          ),
                        )
                            : const Text(
                          'UPDATE PASSWORD',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRule(
      String text,
      bool completed,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 5,
      ),

      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle
                : Icons
                .circle_outlined,

            size: 15,

            color:
            completed
                ? const Color(
              0xFF0284C7,
            )
                : const Color(
              0xFFCBD5E1,
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Text(
            text,
            style:
            const TextStyle(
              fontSize: 11,
              color:
              Color(
                0xFF64748B,
              ),
            ),
          ),
        ],
      ),
    );
  }
}