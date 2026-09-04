import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/services/image_picker_service.dart';

import '../auth/welcome_screen.dart';
import '../checkpoint/checkpoint_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryBlue = Color(0xFF0284C7);
  static const Color teal = Color(0xFF0D9488);
  static const Color darkText = Color(0xFF0F172A);
  static const Color greyText = Color(0xFF64748B);
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color lightBlue = Color(0xFFE0F2FE);
  static const Color borderColor = Color(0xFFE2E8F0);

  // ============================================================
  // SERVICES
  // ============================================================

  final ImagePickerService _imagePickerService =
  ImagePickerService();

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController _phoneController =
  TextEditingController();

  // ============================================================
  // PAGE STATE
  // ============================================================

  bool _isLoading = true;
  bool _isSaving = false;

  // ============================================================
  // REAL PROFILE DATA FROM SUPABASE
  // ============================================================

  String _fullName = '';
  String _email = '';
  String _phoneNumber = '';

  String? _profilePictureUrl;

  int _explorationPoints = 0;

  // ============================================================
  // THESE WILL BE CONNECTED TO REAL TABLES LATER
  // ============================================================

  int _missionsCompleted = 0;
  int _leaderboardRank = 0;

  // ============================================================
  // TEMP SELECTED IMAGE
  // ============================================================

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD PROFILE FROM SUPABASE
  // ============================================================

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final User? user =
          SupabaseConfig.client.auth.currentUser;

      if (user == null) {
        throw Exception(
          'No authenticated traveller was found.',
        );
      }

      final Map<String, dynamic>? profile =
      await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        throw Exception(
          'Traveller profile could not be found.',
        );
      }

      if (!mounted) return;

      final String? picture =
      profile['profile_picture_url']?.toString();

      setState(() {
        // Your current Supabase screenshot uses full_Name.
        // Fallback names are included just in case.
        _fullName =
            profile['full_Name']?.toString() ??
                profile['fullName']?.toString() ??
                profile['full_name']?.toString() ??
                '';

        // Authentication email is preferred.
        _email =
            user.email ??
                profile['email']?.toString() ??
                '';

        _phoneNumber =
            profile['phone_number']?.toString() ??
                '';

        if (picture != null &&
            picture.trim().isNotEmpty) {
          _profilePictureUrl = picture;
        } else {
          _profilePictureUrl = null;
        }

        _explorationPoints =
            _convertToInt(
              profile['exploration_points'],
            );

        // Not hardcoded.
        // Will connect real tables later.
        _missionsCompleted = 0;
        _leaderboardRank = 0;

        _nameController.text =
            _fullName;

        _phoneController.text =
            _phoneNumber;

        _selectedImage = null;
        _selectedImageBytes = null;

        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Unable to load profile: ${error.message}',
      );

      debugPrint(
        'PROFILE DATABASE ERROR: ${error.message}',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Unable to load profile: $error',
      );

      debugPrint(
        'PROFILE LOAD ERROR: $error',
      );
    }
  }

  // ============================================================
  // CONVERT DATABASE NUMBER
  // ============================================================

  int _convertToInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    ) ??
        0;
  }

  // ============================================================
  // OPEN EDIT PROFILE
  // ============================================================

  Future<void> _openEditProfile() async {
    _nameController.text =
        _fullName;

    _phoneController.text =
        _phoneNumber;

    _selectedImage = null;
    _selectedImageBytes = null;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            // ==================================================
            // SELECT PROFILE PICTURE
            // ==================================================

            Future<void> selectPicture() async {
              try {
                final XFile? image =
                await _imagePickerService
                    .pickImageFromGallery();

                if (image == null) {
                  return;
                }

                final String fileName =
                image.name.toLowerCase();

                final bool validFormat =
                    fileName.endsWith('.jpg') ||
                        fileName.endsWith('.jpeg') ||
                        fileName.endsWith('.png') ||
                        fileName.endsWith('.webp');

                if (!validFormat) {
                  _showMessage(
                    'Profile picture must be JPG, PNG or WEBP.',
                  );

                  return;
                }

                final Uint8List bytes =
                await image.readAsBytes();

                const int maximumSize =
                    5 * 1024 * 1024;

                if (bytes.length >
                    maximumSize) {
                  _showMessage(
                    'Profile picture must be 5MB or smaller.',
                  );

                  return;
                }

                setDialogState(() {
                  _selectedImage =
                      image;

                  _selectedImageBytes =
                      bytes;
                });
              } catch (error) {
                _showMessage(
                  'Unable to select image: $error',
                );
              }
            }

            return Dialog(
              backgroundColor:
              pageBackground,
              insetPadding:
              const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  24,
                ),
              ),
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets.all(
                  22,
                ),
                child:
                Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    // ==========================================
                    // TITLE
                    // ==========================================

                    Row(
                      children: [
                        const Expanded(
                          child:
                          Text(
                            'Edit Profile Information',
                            style:
                            TextStyle(
                              color:
                              darkText,
                              fontSize:
                              20,
                              fontWeight:
                              FontWeight.w900,
                              fontFamily:
                              'serif',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed:
                          _isSaving
                              ? null
                              : () {
                            _selectedImage =
                            null;

                            _selectedImageBytes =
                            null;

                            Navigator.pop(
                              dialogContext,
                            );
                          },
                          icon:
                          const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),

                    const Divider(),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==========================================
                    // PROFILE PICTURE
                    // ==========================================

                    Row(
                      children: [
                        _buildEditAvatar(),

                        const SizedBox(
                          width: 16,
                        ),

                        Expanded(
                          child:
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width:
                                double.infinity,
                                child:
                                FilledButton.icon(
                                  onPressed:
                                  _isSaving
                                      ? null
                                      : selectPicture,
                                  style:
                                  FilledButton.styleFrom(
                                    backgroundColor:
                                    primaryBlue,
                                  ),
                                  icon:
                                  const Icon(
                                    Icons.upload_rounded,
                                    size: 18,
                                  ),
                                  label:
                                  const Text(
                                    'UPLOAD NEW PHOTO',
                                    style:
                                    TextStyle(
                                      fontSize: 10,
                                      fontWeight:
                                      FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              const Text(
                                'JPG, PNG or WEBP • max 5MB',
                                style:
                                TextStyle(
                                  color:
                                  greyText,
                                  fontSize:
                                  10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // ==========================================
                    // NAME
                    // ==========================================

                    const Text(
                      'FULL NAME *',
                      style:
                      TextStyle(
                        color:
                        greyText,
                        fontSize:
                        11,
                        fontWeight:
                        FontWeight.w900,
                        letterSpacing:
                        1,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    TextField(
                      controller:
                      _nameController,
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      _editInputDecoration(
                        hint:
                        'Full Name',
                        icon:
                        Icons.person_outline,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ==========================================
                    // EMAIL READ-ONLY
                    // ==========================================

                    const Text(
                      'EMAIL ADDRESS',
                      style:
                      TextStyle(
                        color:
                        greyText,
                        fontSize:
                        11,
                        fontWeight:
                        FontWeight.w900,
                        letterSpacing:
                        1,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    TextFormField(
                      initialValue:
                      _email,
                      readOnly:
                      true,
                      decoration:
                      _editInputDecoration(
                        hint:
                        'Email Address',
                        icon:
                        Icons.email_outlined,
                      ).copyWith(
                        fillColor:
                        const Color(
                          0xFFF1F5F9,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ==========================================
                    // PHONE
                    // ==========================================

                    const Text(
                      'PHONE NUMBER *',
                      style:
                      TextStyle(
                        color:
                        greyText,
                        fontSize:
                        11,
                        fontWeight:
                        FontWeight.w900,
                        letterSpacing:
                        1,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    TextField(
                      controller:
                      _phoneController,
                      keyboardType:
                      TextInputType.phone,
                      decoration:
                      _editInputDecoration(
                        hint:
                        'Phone Number',
                        icon:
                        Icons.phone_outlined,
                      ),
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    // ==========================================
                    // SAVE + CANCEL
                    // ==========================================

                    Row(
                      children: [
                        Expanded(
                          child:
                          SizedBox(
                            height: 50,
                            child:
                            FilledButton(
                              onPressed:
                              _isSaving
                                  ? null
                                  : () async {
                                final bool saved =
                                await _saveProfile();

                                if (saved &&
                                    dialogContext.mounted) {
                                  Navigator.pop(
                                    dialogContext,
                                  );
                                }
                              },
                              style:
                              FilledButton.styleFrom(
                                backgroundColor:
                                primaryBlue,
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    13,
                                  ),
                                ),
                              ),
                              child:
                              _isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                CircularProgressIndicator(
                                  color:
                                  Colors.white,
                                  strokeWidth:
                                  2,
                                ),
                              )
                                  : const Text(
                                'SAVE CHANGES',
                                style:
                                TextStyle(
                                  fontWeight:
                                  FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        OutlinedButton(
                          onPressed:
                          _isSaving
                              ? null
                              : () {
                            _selectedImage =
                            null;

                            _selectedImageBytes =
                            null;

                            Navigator.pop(
                              dialogContext,
                            );
                          },
                          child:
                          const Text(
                            'CANCEL',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<bool> _saveProfile() async {
    final User? user =
        SupabaseConfig.client.auth.currentUser;

    if (user == null) {
      _showMessage(
        'Your session has expired. Please log in again.',
      );

      return false;
    }

    final String newName =
    _nameController.text.trim();

    final String newPhone =
    _phoneController.text.trim();

    if (newName.isEmpty) {
      _showMessage(
        'Please enter your full name.',
      );

      return false;
    }

    if (newName.length < 2 ||
        newName.length > 50) {
      _showMessage(
        'Full name must contain 2 to 50 characters.',
      );

      return false;
    }

    if (newPhone.isEmpty) {
      _showMessage(
        'Please enter your phone number.',
      );

      return false;
    }

    final RegExp phoneRegex =
    RegExp(
      r'^\+?[0-9 ()-]{8,20}$',
    );

    if (!phoneRegex.hasMatch(
      newPhone,
    )) {
      _showMessage(
        'Please enter a valid phone number.',
      );

      return false;
    }

    final bool nameChanged =
        newName !=
            _fullName;

    final bool phoneChanged =
        newPhone !=
            _phoneNumber;

    final bool pictureChanged =
        _selectedImage != null &&
            _selectedImageBytes != null;

    if (!nameChanged &&
        !phoneChanged &&
        !pictureChanged) {
      _showMessage(
        'No changes were detected.',
      );

      return true;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? newPictureUrl =
          _profilePictureUrl;

      if (pictureChanged) {
        newPictureUrl =
        await _uploadProfilePicture(
          userId:
          user.id,
          image:
          _selectedImage!,
          bytes:
          _selectedImageBytes!,
        );
      }

      await SupabaseConfig.client
          .from('profiles')
          .update({
        'full_Name':
        newName,
        'phone_number':
        newPhone,
        'profile_picture_url':
        newPictureUrl,
        'updated_at':
        DateTime.now()
            .toIso8601String(),
      })
          .eq(
        'id',
        user.id,
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        _fullName =
            newName;

        _phoneNumber =
            newPhone;

        _profilePictureUrl =
            newPictureUrl;

        _selectedImage =
        null;

        _selectedImageBytes =
        null;
      });

      _showMessage(
        'Profile updated successfully.',
      );

      return true;
    } on StorageException catch (error) {
      _showMessage(
        'Unable to upload profile picture: ${error.message}',
      );

      return false;
    } on PostgrestException catch (error) {
      _showMessage(
        'Unable to update profile: ${error.message}',
      );

      return false;
    } catch (error) {
      _showMessage(
        'Unable to update profile: $error',
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // UPLOAD PROFILE PICTURE
  // ============================================================

  Future<String> _uploadProfilePicture({
    required String userId,
    required XFile image,
    required Uint8List bytes,
  }) async {
    String extension =
    image.name
        .split('.')
        .last
        .toLowerCase();

    if (extension ==
        'jpeg') {
      extension =
      'jpg';
    }

    String contentType;

    switch (extension) {
      case 'png':
        contentType =
        'image/png';
        break;

      case 'webp':
        contentType =
        'image/webp';
        break;

      default:
        contentType =
        'image/jpeg';
        break;
    }

    final String path =
        '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await SupabaseConfig.client.storage
        .from(
      'profile-pictures',
    )
        .uploadBinary(
      path,
      bytes,
      fileOptions:
      FileOptions(
        contentType:
        contentType,
        upsert:
        true,
      ),
    );

    final String publicUrl =
    SupabaseConfig.client.storage
        .from(
      'profile-pictures',
    )
        .getPublicUrl(
      path,
    );

    return publicUrl;
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> _openChangePassword() async {
    final TextEditingController passwordController =
    TextEditingController();

    final TextEditingController confirmController =
    TextEditingController();

    bool showPassword =
    false;

    bool showConfirm =
    false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  22,
                ),
              ),
              title:
              const Row(
                children: [
                  Icon(
                    Icons.key_rounded,
                    color:
                    primaryBlue,
                  ),
                  SizedBox(
                    width: 9,
                  ),
                  Text(
                    'Change Password',
                    style:
                    TextStyle(
                      color:
                      darkText,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                ],
              ),
              content:
              SingleChildScrollView(
                child:
                Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                      passwordController,
                      obscureText:
                      !showPassword,
                      decoration:
                      InputDecoration(
                        labelText:
                        'New Password',
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            13,
                          ),
                        ),
                        suffixIcon:
                        IconButton(
                          onPressed:
                              () {
                            setDialogState(
                                  () {
                                showPassword =
                                !showPassword;
                              },
                            );
                          },
                          icon:
                          Icon(
                            showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    TextField(
                      controller:
                      confirmController,
                      obscureText:
                      !showConfirm,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Confirm Password',
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            13,
                          ),
                        ),
                        suffixIcon:
                        IconButton(
                          onPressed:
                              () {
                            setDialogState(
                                  () {
                                showConfirm =
                                !showConfirm;
                              },
                            );
                          },
                          icon:
                          Icon(
                            showConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    const Text(
                      'Password must contain at least 8 characters, '
                          'including uppercase, lowercase, number and special character.',
                      style:
                      TextStyle(
                        color:
                        greyText,
                        fontSize:
                        11,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                  const Text(
                    'CANCEL',
                  ),
                ),

                FilledButton(
                  style:
                  FilledButton.styleFrom(
                    backgroundColor:
                    primaryBlue,
                  ),
                  onPressed:
                      () async {
                    final String password =
                        passwordController.text;

                    final String confirm =
                        confirmController.text;

                    final bool validPassword =
                        password.length >= 8 &&
                            RegExp(
                              r'[A-Z]',
                            ).hasMatch(
                              password,
                            ) &&
                            RegExp(
                              r'[a-z]',
                            ).hasMatch(
                              password,
                            ) &&
                            RegExp(
                              r'[0-9]',
                            ).hasMatch(
                              password,
                            ) &&
                            RegExp(
                              r'[^A-Za-z0-9]',
                            ).hasMatch(
                              password,
                            );

                    if (!validPassword) {
                      _showMessage(
                        'Password does not meet the password requirements.',
                      );

                      return;
                    }

                    if (password !=
                        confirm) {
                      _showMessage(
                        'Passwords do not match.',
                      );

                      return;
                    }

                    try {
                      await SupabaseConfig
                          .client
                          .auth
                          .updateUser(
                        UserAttributes(
                          password:
                          password,
                        ),
                      );

                      if (!mounted) return;

                      if (dialogContext.mounted) {
                        Navigator.pop(
                          dialogContext,
                        );
                      }

                      _showMessage(
                        'Password changed successfully.',
                      );
                    } on AuthException catch (error) {
                      _showMessage(
                        error.message,
                      );
                    }
                  },
                  child:
                  const Text(
                    'CHANGE',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    confirmController.dispose();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              22,
            ),
          ),
          title:
          const Text(
            'Confirm Log Out',
            style:
            TextStyle(
              fontWeight:
              FontWeight.w900,
            ),
          ),
          content:
          const Text(
            'Are you sure you want to log out of MYsteryLane?',
          ),
          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
              const Text(
                'CANCEL',
              ),
            ),

            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFFE11D48,
                ),
              ),
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
              const Text(
                'LOG OUT',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed !=
        true) {
      return;
    }

    try {
      await SupabaseConfig
          .client
          .auth
          .signOut();

      if (!mounted) return;

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (context) =>
          const WelcomeScreen(),
        ),
            (route) =>
        false,
      );
    } catch (error) {
      _showMessage(
        'Unable to log out: $error',
      );
    }
  }

  // ============================================================
  // MAIN BUILD
  // NO TOP APP BAR
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      pageBackground,

      extendBody:
      true,

      // ========================================================
      // NO appBar HERE
      // ========================================================

      body:
      SafeArea(
        child:
        _isLoading
            ? const Center(
          child:
          CircularProgressIndicator(
            color:
            primaryBlue,
          ),
        )
            : RefreshIndicator(
          color:
          primaryBlue,
          onRefresh:
          _loadProfile,
          child:
          SingleChildScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            padding:
            const EdgeInsets.fromLTRB(
              16,
              28,
              16,
              130,
            ),

            child:
            Center(
              child:
              ConstrainedBox(
                constraints:
                const BoxConstraints(
                  maxWidth:
                  650,
                ),
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    // ==================================
                    // PROFILE HEADER
                    // ==================================

                    _buildProfileHeader(),

                    const SizedBox(
                      height: 24,
                    ),

                    // ==================================
                    // EXPLORATION POINTS
                    // ==================================

                    _buildExplorationPoints(),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==================================
                    // STATS
                    // ==================================

                    _buildStats(),

                    const SizedBox(
                      height: 24,
                    ),

                    // ==================================
                    // USER INFORMATION
                    // ==================================

                    _buildProfileInformation(),

                    const SizedBox(
                      height: 24,
                    ),

                    // ==================================
                    // SECURITY
                    // ==================================

                    _buildSecuritySection(),

                    const SizedBox(
                      height: 34,
                    ),

                    // ==================================
                    // ACHIEVEMENTS
                    // ==================================

                    _buildAchievementSection(),

                    const SizedBox(
                      height: 34,
                    ),

                    // ==================================
                    // IN PROGRESS
                    // ==================================

                    _buildInProgressSection(),

                    const SizedBox(
                      height: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      // ========================================================
      // SAME HOME BUTTON AS HOMEPAGE
      // ========================================================

      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerDocked,

      floatingActionButton:
      _buildHomeButton(),

      // ========================================================
      // SAME BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar:
      _buildBottomBar(),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          clipBehavior:
          Clip.none,
          children: [
            Container(
              width: 112,
              height: 112,
              padding:
              const EdgeInsets.all(
                4,
              ),
              decoration:
              BoxDecoration(
                shape:
                BoxShape.circle,
                border:
                Border.all(
                  color:
                  primaryBlue,
                  width:
                  4,
                ),
                boxShadow:
                const [
                  BoxShadow(
                    color:
                    Color(
                      0x220F172A,
                    ),
                    blurRadius:
                    16,
                    offset:
                    Offset(
                      0,
                      7,
                    ),
                  ),
                ],
              ),
              child:
              CircleAvatar(
                backgroundColor:
                lightBlue,
                backgroundImage:
                _profilePictureUrl != null
                    ? NetworkImage(
                  _profilePictureUrl!,
                )
                    : null,
                child:
                _profilePictureUrl == null
                    ? Text(
                  _getInitial(),
                  style:
                  const TextStyle(
                    color:
                    primaryBlue,
                    fontSize:
                    40,
                    fontWeight:
                    FontWeight.w900,
                  ),
                )
                    : null,
              ),
            ),

            Positioned(
              right: -2,
              bottom: 3,
              child:
              InkWell(
                customBorder:
                const CircleBorder(),
                onTap:
                _openEditProfile,
                child:
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                  BoxDecoration(
                    color:
                    primaryBlue,
                    shape:
                    BoxShape.circle,
                    border:
                    Border.all(
                      color:
                      Colors.white,
                      width:
                      3,
                    ),
                    boxShadow:
                    const [
                      BoxShadow(
                        color:
                        Color(
                          0x33000000,
                        ),
                        blurRadius:
                        7,
                      ),
                    ],
                  ),
                  child:
                  const Icon(
                    Icons.camera_alt_rounded,
                    color:
                    Colors.white,
                    size:
                    19,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 14,
        ),

        const Text(
          'FIELD EXPLORER',
          style:
          TextStyle(
            color:
            primaryBlue,
            fontSize:
            9,
            fontWeight:
            FontWeight.w900,
            letterSpacing:
            2,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        Text(
          _fullName.isEmpty
              ? 'Traveller'
              : _fullName,
          textAlign:
          TextAlign.center,
          style:
          const TextStyle(
            color:
            darkText,
            fontSize:
            31,
            fontWeight:
            FontWeight.w900,
            fontFamily:
            'serif',
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        const Text(
          'Urban Explorer',
          style:
          TextStyle(
            color:
            greyText,
            fontSize:
            13,
          ),
        ),
      ],
    );
  }

  String _getInitial() {
    if (_fullName.trim().isEmpty) {
      return '?';
    }

    return _fullName
        .trim()
        .substring(
      0,
      1,
    )
        .toUpperCase();
  }

  // ============================================================
  // EXPLORATION POINTS
  // ============================================================

  Widget _buildExplorationPoints() {
    return Container(
      height: 145,
      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            primaryBlue,
            teal,
          ],
          begin:
          Alignment.centerLeft,
          end:
          Alignment.centerRight,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        boxShadow:
        const [
          BoxShadow(
            color:
            Color(
              0x300284C7,
            ),
            blurRadius:
            18,
            offset:
            Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child:
      Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration:
            BoxDecoration(
              color:
              Colors.white.withOpacity(
                0.15,
              ),
              shape:
              BoxShape.circle,
            ),
            child:
            const Icon(
              Icons.workspace_premium_outlined,
              color:
              Color(
                0xFFFACC15,
              ),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            _formatNumber(
              _explorationPoints,
            ),
            style:
            const TextStyle(
              color:
              Colors.white,
              fontSize:
              35,
              fontWeight:
              FontWeight.w900,
              fontFamily:
              'serif',
            ),
          ),

          const Text(
            'EXPLORATION POINTS',
            style:
            TextStyle(
              color:
              Colors.white,
              fontSize:
              11,
              fontWeight:
              FontWeight.w900,
              letterSpacing:
              2.2,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child:
          _statCard(
            value:
            _missionsCompleted.toString(),
            label:
            'MISSIONS COMPLETED',
            icon:
            Icons.check_circle_outline,
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child:
          _statCard(
            value:
            _leaderboardRank > 0
                ? '#$_leaderboardRank'
                : '-',
            label:
            'LEADERBOARD RANK',
            icon:
            Icons.bar_chart_rounded,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(
        18,
      ),
      decoration:
      _whiteCardDecoration(),
      child:
      Row(
        children: [
          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style:
                  const TextStyle(
                    color:
                    darkText,
                    fontSize:
                    24,
                    fontWeight:
                    FontWeight.w900,
                    fontFamily:
                    'serif',
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  label,
                  style:
                  const TextStyle(
                    color:
                    greyText,
                    fontSize:
                    8,
                    fontWeight:
                    FontWeight.w800,
                    letterSpacing:
                    1,
                  ),
                ),
              ],
            ),
          ),

          CircleAvatar(
            backgroundColor:
            lightBlue,
            child:
            Icon(
              icon,
              color:
              primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE INFORMATION
  // ============================================================

  Widget _buildProfileInformation() {
    return Container(
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      _whiteCardDecoration(),
      child:
      Column(
        children: [
          _buildInfoRow(
            icon:
            Icons.person_outline_rounded,
            title:
            'FULL NAME',
            value:
            _fullName.isEmpty
                ? '-'
                : _fullName,
          ),

          const Divider(
            height: 28,
          ),

          _buildInfoRow(
            icon:
            Icons.email_outlined,
            title:
            'EMAIL ADDRESS',
            value:
            _email.isEmpty
                ? '-'
                : _email,
            readOnly:
            true,
          ),

          const Divider(
            height: 28,
          ),

          _buildInfoRow(
            icon:
            Icons.phone_outlined,
            title:
            'PHONE NUMBER',
            value:
            _phoneNumber.isEmpty
                ? '-'
                : _phoneNumber,
          ),

          const SizedBox(
            height: 20,
          ),

          SizedBox(
            width:
            double.infinity,
            height: 50,
            child:
            DecoratedBox(
              decoration:
              BoxDecoration(
                gradient:
                const LinearGradient(
                  colors: [
                    primaryBlue,
                    teal,
                  ],
                ),
                borderRadius:
                BorderRadius.circular(
                  13,
                ),
              ),
              child:
              Material(
                color:
                Colors.transparent,
                child:
                InkWell(
                  onTap:
                  _openEditProfile,
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                  child:
                  const Center(
                    child:
                    Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color:
                          Colors.white,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'EDIT PROFILE & PHOTO',
                          style:
                          TextStyle(
                            color:
                            Colors.white,
                            fontSize:
                            11,
                            fontWeight:
                            FontWeight.w900,
                            letterSpacing:
                            1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    bool readOnly = false,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration:
          const BoxDecoration(
            color:
            lightBlue,
            shape:
            BoxShape.circle,
          ),
          child:
          Icon(
            icon,
            color:
            primaryBlue,
          ),
        ),

        const SizedBox(
          width: 14,
        ),

        Expanded(
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style:
                    const TextStyle(
                      color:
                      primaryBlue,
                      fontSize:
                      9,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                  if (readOnly) ...[
                    const SizedBox(
                      width: 7,
                    ),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal:
                        6,
                        vertical:
                        2,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        lightBlue,
                        borderRadius:
                        BorderRadius.circular(
                          4,
                        ),
                      ),
                      child:
                      const Text(
                        'READ-ONLY',
                        style:
                        TextStyle(
                          color:
                          primaryBlue,
                          fontSize:
                          7,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                value,
                style:
                const TextStyle(
                  color:
                  darkText,
                  fontSize:
                  14,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECURITY
  // ============================================================

  Widget _buildSecuritySection() {
    return Container(
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      _whiteCardDecoration(),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color:
                primaryBlue,
              ),
              SizedBox(
                width: 9,
              ),
              Text(
                'Account Security & Session',
                style:
                TextStyle(
                  color:
                  darkText,
                  fontSize:
                  19,
                  fontWeight:
                  FontWeight.w900,
                  fontFamily:
                  'serif',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          Row(
            children: [
              Expanded(
                child:
                OutlinedButton.icon(
                  onPressed:
                  _openChangePassword,
                  icon:
                  const Icon(
                    Icons.key_rounded,
                  ),
                  label:
                  const FittedBox(
                    child:
                    Text(
                      'CHANGE PASSWORD',
                    ),
                  ),
                  style:
                  OutlinedButton.styleFrom(
                    foregroundColor:
                    primaryBlue,
                    backgroundColor:
                    const Color(
                      0xFFF0F9FF,
                    ),
                    minimumSize:
                    const Size(
                      0,
                      48,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child:
                OutlinedButton.icon(
                  onPressed:
                  _logout,
                  icon:
                  const Icon(
                    Icons.logout_rounded,
                  ),
                  label:
                  const Text(
                    'LOG OUT',
                  ),
                  style:
                  OutlinedButton.styleFrom(
                    foregroundColor:
                    const Color(
                      0xFFE11D48,
                    ),
                    backgroundColor:
                    const Color(
                      0xFFFFF1F2,
                    ),
                    minimumSize:
                    const Size(
                      0,
                      48,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACHIEVEMENTS
  // ============================================================

  Widget _buildAchievementSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Explorer Achievements',
          style:
          TextStyle(
            color:
            darkText,
            fontSize:
            23,
            fontWeight:
            FontWeight.w900,
            fontFamily:
            'serif',
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        const Text(
          'YOUR UNLOCKED AND LOCKED ACHIEVEMENTS WILL APPEAR HERE',
          style:
          TextStyle(
            color:
            primaryBlue,
            fontSize:
            8,
            fontWeight:
            FontWeight.w900,
            letterSpacing:
            1,
          ),
        ),

        const SizedBox(
          height: 15,
        ),

        Container(
          width:
          double.infinity,
          padding:
          const EdgeInsets.all(
            25,
          ),
          decoration:
          _whiteCardDecoration(),
          child:
          const Column(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                color:
                primaryBlue,
                size: 40,
              ),

              SizedBox(
                height: 10,
              ),

              Text(
                'No achievement records available yet.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  darkText,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),

              SizedBox(
                height: 5,
              ),

              Text(
                'Achievements will appear here after the achievement database is connected.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  greyText,
                  fontSize:
                  11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // IN PROGRESS
  // ============================================================

  Widget _buildInProgressSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'In Progress',
          style:
          TextStyle(
            color:
            darkText,
            fontSize:
            23,
            fontWeight:
            FontWeight.w900,
            fontFamily:
            'serif',
          ),
        ),

        const SizedBox(
          height: 15,
        ),

        Container(
          width:
          double.infinity,
          padding:
          const EdgeInsets.all(
            25,
          ),
          decoration:
          _whiteCardDecoration(),
          child:
          const Column(
            children: [
              Icon(
                Icons.track_changes_rounded,
                color:
                primaryBlue,
                size: 38,
              ),

              SizedBox(
                height: 10,
              ),

              Text(
                'No achievement progress available yet.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  darkText,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EDIT AVATAR
  // ============================================================

  Widget _buildEditAvatar() {
    ImageProvider? image;

    if (_selectedImageBytes !=
        null) {
      image =
          MemoryImage(
            _selectedImageBytes!,
          );
    } else if (_profilePictureUrl !=
        null) {
      image =
          NetworkImage(
            _profilePictureUrl!,
          );
    }

    return Container(
      width: 70,
      height: 70,
      padding:
      const EdgeInsets.all(
        3,
      ),
      decoration:
      const BoxDecoration(
        color:
        primaryBlue,
        shape:
        BoxShape.circle,
      ),
      child:
      CircleAvatar(
        backgroundColor:
        lightBlue,
        backgroundImage:
        image,
        child:
        image == null
            ? Text(
          _getInitial(),
          style:
          const TextStyle(
            color:
            primaryBlue,
            fontSize:
            26,
            fontWeight:
            FontWeight.w900,
          ),
        )
            : null,
      ),
    );
  }

  // ============================================================
  // HOME BUTTON
  // ============================================================

  Widget _buildHomeButton() {
    return Padding(
      padding:
      const EdgeInsets.only(
        top: 10,
      ),
      child:
      InkWell(
        customBorder:
        const CircleBorder(),
        onTap:
            () {
          Navigator.pop(
            context,
          );
        },
        child:
        Container(
          width: 66,
          height: 66,
          decoration:
          BoxDecoration(
            shape:
            BoxShape.circle,
            gradient:
            const LinearGradient(
              colors: [
                primaryBlue,
                teal,
              ],
              begin:
              Alignment.topLeft,
              end:
              Alignment.bottomRight,
            ),
            border:
            Border.all(
              color:
              Colors.white,
              width:
              4,
            ),
            boxShadow:
            const [
              BoxShadow(
                color:
                Color(
                  0x3D0284C7,
                ),
                blurRadius:
                16,
                offset:
                Offset(
                  0,
                  7,
                ),
              ),
            ],
          ),
          child:
          const Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_rounded,
                color:
                Color(
                  0xFFFDE68A,
                ),
                size:
                27,
              ),
              Text(
                'HOME',
                style:
                TextStyle(
                  color:
                  Colors.white,
                  fontSize:
                  8,
                  fontWeight:
                  FontWeight.w900,
                  letterSpacing:
                  0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomBar() {
    return BottomAppBar(
      height: 78,
      padding:
      EdgeInsets.zero,
      color:
      Colors.white.withOpacity(
        0.98,
      ),
      elevation: 18,
      shadowColor:
      const Color(
        0x330284C7,
      ),
      shape:
      const CircularNotchedRectangle(),
      notchMargin: 8,
      child:
      SafeArea(
        top: false,
        child:
        Row(
          children: [
            Expanded(
              child:
              _ProfileBottomItem(
                icon:
                Icons.inventory_2_outlined,
                label:
                'BLIND BOX',
                onTap:
                    () {
                  _showMessage(
                    'Blind Box will be connected later.',
                  );
                },
              ),
            ),

            Expanded(
              child:
              _ProfileBottomItem(
                icon:
                Icons.assignment_outlined,
                label:
                'MISSIONS',
                onTap:
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                      const CheckpointScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(
              width: 74,
            ),

            Expanded(
              child:
              _ProfileBottomItem(
                icon:
                Icons.map_outlined,
                label:
                'PLAN',
                onTap:
                    () {
                  _showMessage(
                    'Plan will be connected later.',
                  );
                },
              ),
            ),

            Expanded(
              child:
              _ProfileBottomItem(
                icon:
                Icons.groups_2_outlined,
                label:
                'TEAMS',
                onTap:
                    () {
                  _showMessage(
                    'Teams will be connected later.',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatNumber(
      int number,
      ) {
    final String text =
    number.toString();

    if (text.length <=
        3) {
      return text;
    }

    final StringBuffer buffer =
    StringBuffer();

    for (int index = 0;
    index < text.length;
    index++) {
      if (index > 0 &&
          (text.length - index) %
              3 ==
              0) {
        buffer.write(
          ',',
        );
      }

      buffer.write(
        text[index],
      );
    }

    return buffer.toString();
  }

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
          SnackBarBehavior.floating,
          margin:
          const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            92,
          ),
          content:
          Text(
            message,
          ),
        ),
      );
  }

  InputDecoration _editInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText:
      hint,
      prefixIcon:
      Icon(
        icon,
      ),
      filled:
      true,
      fillColor:
      Colors.white,
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
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

  BoxDecoration _whiteCardDecoration() {
    return BoxDecoration(
      color:
      Colors.white,
      borderRadius:
      BorderRadius.circular(
        18,
      ),
      border:
      Border.all(
        color:
        borderColor,
      ),
      boxShadow:
      const [
        BoxShadow(
          color:
          Color(
            0x100F172A,
          ),
          blurRadius:
          10,
          offset:
          Offset(
            0,
            4,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// BOTTOM NAVIGATION ITEM
// ============================================================

class _ProfileBottomItem
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileBottomItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    const Color iconColor =
    Color(
      0xFF64748B,
    );

    return InkWell(
      onTap:
      onTap,
      child:
      Padding(
        padding:
        const EdgeInsets.only(
          top: 10,
          bottom: 4,
        ),
        child:
        Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 42,
              height: 29,
              child:
              Icon(
                icon,
                size: 21,
                color:
                iconColor,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              label,
              maxLines: 1,
              overflow:
              TextOverflow.clip,
              style:
              const TextStyle(
                color:
                iconColor,
                fontSize:
                8,
                fontWeight:
                FontWeight.w800,
                letterSpacing:
                0.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}