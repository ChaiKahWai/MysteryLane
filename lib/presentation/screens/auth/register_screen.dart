import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import '../../../core/config/supabase_config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController =
  TextEditingController();

  final TextEditingController _emailController =
  TextEditingController();

  final TextEditingController _phoneController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  PhoneNumber _selectedPhoneNumber =
  PhoneNumber(isoCode: 'MY', dialCode: '+60');

  bool _isPhoneNumberValid = false;
  String _e164PhoneNumber = '';

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
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final fullName =
    _fullNameController.text.trim();

    final email =
    _emailController.text.trim().toLowerCase();

    final localPhoneNumber =
    _phoneController.text.trim();

    final password =
        _passwordController.text;

    final confirmPassword =
        _confirmPasswordController.text;

// [A6][M6][C6] Mandatory fields.
    if (fullName.isEmpty ||
        email.isEmpty ||
        localPhoneNumber.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _formKey.currentState!.validate();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Please complete all required fields.',
            ),
          ),
        );
      return;
    }

// [A1-A5][M1-M5][C1-C5]
    if (!_formKey.currentState!.validate()) {
      return;
    }

// [A3][M3][C3] The international phone widget validates
// the number against the selected country's numbering rules.
    if (!_isPhoneNumberValid ||
        _e164PhoneNumber.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter a valid phone number for the selected country.',
            ),
          ),
        );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse response =
      await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,

// [C7][C12]
// Supabase Authentication manages email/password.
// Full name and the normalized E.164 phone number are stored
// temporarily in Auth metadata. main.dart creates the profile
// only after successful email verification.
        data: {
          'full_name': fullName,
          'phone_number': _e164PhoneNumber,
        },

        emailRedirectTo:
        'mysterylane://login-callback',
      );

      final User? user = response.user;

      if (user == null) {
        throw Exception(
          'Unable to create traveller account.',
        );
      }

      if (!mounted) return;

// [M9][C8]
      await showDialog(
        context: context,
        barrierDismissible: false,
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
                  child: Text('Verify Your Email'),
                ),
              ],
            ),
            content: Text(
              'A verification link has been sent to your email address. '
                  'Please verify your email to complete the registration.\n\n'
                  'Email: $email',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      final String errorText =
      error.message.toLowerCase();

// [A7][M7]
      if (errorText.contains('already registered') ||
          errorText.contains('already exists') ||
          errorText.contains('user already registered')) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'This email address has already been registered.',
              ),
            ),
          );
        return;
      }

// [A10][M10]
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to complete the registration request. Please try again.',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;

// [A10][M10]
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to complete the registration request. Please try again.',
            ),
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
          const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            32,
          ),

          child: Column(
            children: [
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
                          color: darkText,
                          fontWeight:
                          FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Container(
                width: double.infinity,

                padding:
                const EdgeInsets.all(
                  22,
                ),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                  BorderRadius.circular(
                    24,
                  ),

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
                      offset: Offset(
                        0,
                        8,
                      ),
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
                        'FIELD REGISTRATION',

                        style: TextStyle(
                          fontSize: 9,
                          color: primaryBlue,
                          fontWeight:
                          FontWeight.bold,
                          letterSpacing: 1.8,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      const Text(
                        'Begin Your Journey',

                        style: TextStyle(
                          fontSize: 26,
                          fontWeight:
                          FontWeight.bold,
                          fontFamily: 'serif',
                          color: darkText,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      const Text(
                        'Register to unlock exclusive urban exploration '
                            'missions and blind boxes.',

                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Color(
                            0xFF64748B,
                          ),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      _buildLabel(
                        'FULL NAME',
                      ),

                      _buildTextField(
                        controller:
                        _fullNameController,
                        hintText:
                        'e.g. Indiana Jones',
                        icon:
                        Icons.person_outline,

                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Please enter a valid full name (2–50 characters).';
                          }

                          if (value.trim().length < 2 ||
                              value.trim().length > 50) {
                            return 'Please enter a valid full name (2–50 characters).';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      _buildLabel(
                        'EMAIL ADDRESS',
                      ),

                      _buildTextField(
                        controller:
                        _emailController,
                        hintText:
                        'explorer@mysterylane.app',
                        icon:
                        Icons.email_outlined,
                        keyboardType:
                        TextInputType.emailAddress,

                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Please enter a valid email address.';
                          }

                          final emailRegex =
                          RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          );

                          if (!emailRegex.hasMatch(
                            value.trim(),
                          )) {
                            return 'Please enter a valid email address.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      _buildLabel(
                        'PHONE NUMBER',
                      ),

                      InternationalPhoneNumberInput(
                        textFieldController:
                        _phoneController,

                        initialValue:
                        _selectedPhoneNumber,

                        selectorConfig:
                        const SelectorConfig(
                          selectorType:
                          PhoneInputSelectorType.BOTTOM_SHEET,
                          useEmoji: true,
                          setSelectorButtonAsPrefixIcon: true,
                          leadingPadding: 12,
                        ),

                        formatInput: true,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: false,
                        ),

                        autoValidateMode:
                        AutovalidateMode.onUserInteraction,

                        errorMessage:
                        'Please enter a valid phone number for the selected country.',

                        onInputChanged:
                            (PhoneNumber number) {
                          _selectedPhoneNumber = number;

                          final String normalized =
                              number.phoneNumber?.trim() ?? '';

                          _e164PhoneNumber =
                          normalized.startsWith('+')
                              ? normalized
                              : '';
                        },

                        onInputValidated:
                            (bool isValid) {
                          setState(() {
                            _isPhoneNumberValid =
                                isValid;
                          });
                        },

                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Please enter a valid phone number for the selected country.';
                          }

                          if (!_isPhoneNumberValid) {
                            return 'Please enter a valid phone number for the selected country.';
                          }

                          return null;
                        },

                        inputDecoration:
                        InputDecoration(
                          hintText:
                          'Enter phone number',

                          filled: true,
                          fillColor:
                          const Color(
                            0xFFF8FAFC,
                          ),

                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(
                              13,
                            ),
                          ),

                          enabledBorder:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(
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
                            BorderRadius.circular(
                              13,
                            ),
                            borderSide:
                            const BorderSide(
                              color:
                              Color(
                                0xFF0284C7,
                              ),
                              width: 2,
                            ),
                          ),

                          errorBorder:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(
                              13,
                            ),
                            borderSide:
                            const BorderSide(
                              color:
                              Colors.red,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 18,
                      ),

                      _buildLabel(
                        'PASSWORD',
                      ),

                      _buildTextField(
                        controller:
                        _passwordController,
                        hintText:
                        'Create a secure password',
                        icon:
                        Icons.lock_outline,
                        obscureText:
                        !_showPassword,

                        suffixIcon:
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showPassword =
                              !_showPassword;
                            });
                          },

                          icon: Icon(
                            _showPassword
                                ? Icons
                                .visibility_off_outlined
                                : Icons
                                .visibility_outlined,

                            color:
                            const Color(
                              0xFF94A3B8,
                            ),
                          ),
                        ),

                        onChanged: (_) {
                          setState(() {});
                        },

                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'Password must contain at least 8 characters, including at least one uppercase letter, one lowercase letter, one number, and one special character.';
                          }

                          if (!_isStrongPassword) {
                            return 'Password must contain at least 8 characters, including at least one uppercase letter, one lowercase letter, one number, and one special character.';
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
                        height: 18,
                      ),

                      _buildLabel(
                        'CONFIRM PASSWORD',
                      ),

                      _buildTextField(
                        controller:
                        _confirmPasswordController,
                        hintText:
                        'Repeat your password',
                        icon:
                        Icons.lock_outline,
                        obscureText:
                        !_showConfirmPassword,

                        suffixIcon:
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showConfirmPassword =
                              !_showConfirmPassword;
                            });
                          },

                          icon: Icon(
                            _showConfirmPassword
                                ? Icons
                                .visibility_off_outlined
                                : Icons
                                .visibility_outlined,

                            color:
                            const Color(
                              0xFF94A3B8,
                            ),
                          ),
                        ),

                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'Password and confirmation password do not match.';
                          }

                          if (value !=
                              _passwordController.text) {
                            return 'Password and confirmation password do not match.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      SizedBox(
                        width: double.infinity,
                        height: 54,

                        child:
                        ElevatedButton.icon(
                          onPressed:
                          _isLoading
                              ? null
                              : _register,

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
                                .how_to_reg_outlined,
                            size: 18,
                          ),

                          label: Text(
                            _isLoading
                                ? 'REGISTERING...'
                                : 'REGISTER ACCOUNT',

                            style:
                            const TextStyle(
                              fontSize: 12,
                              fontWeight:
                              FontWeight.bold,
                              letterSpacing: 2.4,
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
                              BorderRadius.circular(
                                16,
                              ),
                            ),
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

  Widget _buildLabel(
      String label,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 6,
      ),

      child: Text(
        label,

        style: const TextStyle(
          fontSize: 11,
          fontWeight:
          FontWeight.bold,
          color:
          Color(
            0xFF475569,
          ),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType =
        TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
      keyboardType,
      obscureText:
      obscureText,
      onChanged:
      onChanged,
      validator:
      validator,

      decoration:
      InputDecoration(
        hintText:
        hintText,

        prefixIcon:
        Icon(
          icon,
        ),

        suffixIcon:
        suffixIcon,

        filled: true,

        fillColor:
        const Color(
          0xFFF8FAFC,
        ),

        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            13,
          ),
        ),

        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
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
          BorderRadius.circular(
            13,
          ),

          borderSide:
          const BorderSide(
            color:
            Color(
              0xFF0284C7,
            ),
            width: 2,
          ),
        ),

        errorBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            13,
          ),

          borderSide:
          const BorderSide(
            color:
            Colors.red,
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
                : Icons.circle_outlined,

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
