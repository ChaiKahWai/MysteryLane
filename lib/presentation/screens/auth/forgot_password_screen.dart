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
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController =
  TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return emailRegex.hasMatch(email);
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email =
    _emailController.text.trim().toLowerCase();

    setState(() {
      _isLoading = true;
    });

    try {
      // =========================================================
      // SEND PASSWORD RESET EMAIL
      // =========================================================

      await SupabaseConfig.client.auth.resetPasswordForEmail(
        email,

        // User clicks email link
        // → return to MYsteryLane
        redirectTo:
        'mysterylane://reset-password-callback',
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  color: Color(0xFF0284C7),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reset Link Sent',
                  ),
                ),
              ],
            ),
            content: Text(
              'A password-reset link has been sent to:\n\n'
                  '$email\n\n'
                  'Please check your email and click the link '
                  'to reset your password.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'OK',
                ),
              ),
            ],
          );
        },
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      String message = error.message;

      final errorText =
      error.message.toLowerCase();

      if (errorText.contains('rate limit')) {
        message =
        'Too many reset emails were requested. '
            'Please wait and try again later.';
      } else if (errorText.contains('email')) {
        message =
        'Unable to send the reset email. '
            'Please check the email address.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );

      debugPrint(
        'FORGOT PASSWORD ERROR: ${error.message}',
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to send reset link: $error',
          ),
        ),
      );

      debugPrint(
        'FORGOT PASSWORD ERROR: $error',
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
          const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            32,
          ),

          child: Column(
            children: [
              // =====================================================
              // HEADER
              // =====================================================
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    borderRadius:
                    BorderRadius.circular(50),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                        const Color(
                          0xFFF0F9FF,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                          const Color(
                            0xFFBAE6FD,
                          ),
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
                          fontWeight:
                          FontWeight.bold,
                          letterSpacing: 1.8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'MysteryLane',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight:
                          FontWeight.bold,
                          fontFamily: 'serif',
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // =====================================================
              // CARD
              // =====================================================
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(24),
                  border: Border.all(
                    color:
                    const Color(
                      0xFFE2E8F0,
                    ),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(
                        15,
                        23,
                        42,
                        0.08,
                      ),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),

                child: Form(
                  key: _formKey,

                  child: Column(
                    children: [
                      // =================================================
                      // ICON
                      // =================================================
                      Container(
                        width: 70,
                        height: 70,
                        decoration:
                        BoxDecoration(
                          color:
                          const Color(
                            0xFFE0F2FE,
                          ),
                          shape:
                          BoxShape.circle,
                          border: Border.all(
                            color:
                            const Color(
                              0xFFBAE6FD,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.key_outlined,
                          size: 34,
                          color: primaryBlue,
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Reset Password',
                        textAlign:
                        TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight:
                          FontWeight.bold,
                          fontFamily: 'serif',
                          color: darkText,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Enter your registered email address '
                            'and we will send you a secure link '
                            'to reset your password.',
                        textAlign:
                        TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Color(
                            0xFF64748B,
                          ),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // =================================================
                      // EMAIL
                      // =================================================
                      const Align(
                        alignment:
                        Alignment.centerLeft,
                        child: Text(
                          'EMAIL ADDRESS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                            FontWeight.bold,
                            color:
                            Color(
                              0xFF475569,
                            ),
                            letterSpacing:
                            1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 7),

                      TextFormField(
                        controller:
                        _emailController,
                        keyboardType:
                        TextInputType
                            .emailAddress,
                        textInputAction:
                        TextInputAction.done,

                        decoration:
                        InputDecoration(
                          hintText:
                          'explorer@mysterylane.app',

                          prefixIcon:
                          const Icon(
                            Icons.email_outlined,
                            color:
                            Color(
                              0xFF94A3B8,
                            ),
                          ),

                          filled: true,
                          fillColor:
                          const Color(
                            0xFFF8FAFC,
                          ),

                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              13,
                            ),
                          ),

                          enabledBorder:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              13,
                            ),
                            borderSide:
                            const BorderSide(
                              color:
                              Color(
                                0xFFE2E8F0,
                              ),
                            ),
                          ),

                          focusedBorder:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              13,
                            ),
                            borderSide:
                            const BorderSide(
                              color:
                              primaryBlue,
                              width: 2,
                            ),
                          ),

                          errorBorder:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              13,
                            ),
                            borderSide:
                            const BorderSide(
                              color:
                              Colors.red,
                            ),
                          ),
                        ),

                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Please fill in your registered email address.';
                          }

                          if (!_isValidEmail(
                            value.trim(),
                          )) {
                            return 'Please enter a valid email address.';
                          }

                          return null;
                        },

                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            _sendResetLink();
                          }
                        },
                      ),

                      const SizedBox(height: 24),

                      // =================================================
                      // SEND LINK
                      // =================================================
                      SizedBox(
                        width: double.infinity,
                        height: 54,

                        child:
                        ElevatedButton.icon(
                          onPressed:
                          _isLoading
                              ? null
                              : _sendResetLink,

                          icon: _isLoading
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                              Colors.white,
                            ),
                          )
                              : const Icon(
                            Icons
                                .send_outlined,
                            size: 18,
                          ),

                          label: Text(
                            _isLoading
                                ? 'SENDING...'
                                : 'SEND RESET LINK',

                            style:
                            const TextStyle(
                              fontSize: 12,
                              fontWeight:
                              FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),

                          style:
                          ElevatedButton
                              .styleFrom(
                            backgroundColor:
                            primaryBlue,
                            foregroundColor:
                            Colors.white,
                            elevation: 4,

                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 16,
                        ),
                        label: const Text(
                          'RETURN TO LOGIN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                            FontWeight.bold,
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