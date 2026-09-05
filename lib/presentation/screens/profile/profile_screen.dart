
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/services/image_picker_service.dart';

import '../auth/welcome_screen.dart';
import '../checkpoint/checkpoint_screen.dart';
import 'achievement_screen.dart';

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
// IMAGE PICKER SERVICE
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
// STATES
// ============================================================

bool _isLoading = true;
bool _isSaving = false;

// ============================================================
// PROFILE DATA
// ============================================================

String _fullName = '';
String _email = '';
String _phoneNumber = '';

String? _profilePictureUrl;

int _explorationPoints = 0;

// Connect actual tables later.
int _missionsCompleted = 0;
int _leaderboardRank = 0;

// ============================================================
// NEW SELECTED IMAGE
// ============================================================

XFile? _selectedImage;
Uint8List? _selectedImageBytes;

// ============================================================
// PHONE EDIT STATE
// ============================================================

String _selectedCountryCode = 'MY';
String _selectedDialCode = '+60';
String? _phoneError;

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
_fullName =
profile['full_name']?.toString() ??
'';

// Login email comes ONLY from Supabase Authentication.
// Do not read or duplicate it in public.profiles.
_email = user.email ?? '';

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
} catch (error) {
if (!mounted) return;

setState(() {
_isLoading = false;
});

_showMessage(
'Unable to load profile: $error',
);
}
}

// ============================================================
// NUMBER CONVERTER
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
// CHOOSE PHOTO SOURCE
//
// CAMERA OR GALLERY
// ============================================================

Future<void> _chooseProfilePhoto(
StateSetter setDialogState,
) async {
final ImageSource? source =
await showModalBottomSheet<ImageSource>(
context: context,
backgroundColor: Colors.transparent,
builder: (bottomSheetContext) {
return SafeArea(
child: Container(
margin: const EdgeInsets.all(16),
padding: const EdgeInsets.fromLTRB(
20,
14,
20,
20,
),
decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(24),
boxShadow: const [
BoxShadow(
color: Color(0x330F172A),
blurRadius: 25,
offset: Offset(0, 10),
),
],
),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment:
CrossAxisAlignment.stretch,
children: [
Center(
child: Container(
width: 42,
height: 4,
decoration: BoxDecoration(
color:
const Color(0xFFCBD5E1),
borderRadius:
BorderRadius.circular(99),
),
),
),

const SizedBox(height: 20),

const Text(
'Choose Profile Photo',
textAlign: TextAlign.center,
style: TextStyle(
color: darkText,
fontSize: 21,
fontWeight:
FontWeight.w900,
fontFamily: 'serif',
),
),

const SizedBox(height: 6),

const Text(
'Take a new photo or choose one from your gallery.',
textAlign: TextAlign.center,
style: TextStyle(
color: greyText,
fontSize: 12,
),
),

const SizedBox(height: 22),

// ==============================================
// CAMERA
// ==============================================

InkWell(
borderRadius:
BorderRadius.circular(16),
onTap: () {
Navigator.pop(
bottomSheetContext,
ImageSource.camera,
);
},
child: Container(
padding:
const EdgeInsets.all(16),
decoration: BoxDecoration(
color:
const Color(0xFFF0F9FF),
borderRadius:
BorderRadius.circular(16),
border: Border.all(
color:
const Color(0xFFBAE6FD),
),
),
child: const Row(
children: [
CircleAvatar(
radius: 23,
backgroundColor:
Color(0xFFE0F2FE),
child: Icon(
Icons.camera_alt_rounded,
color: primaryBlue,
),
),

SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Take Photo',
style: TextStyle(
color: darkText,
fontSize: 15,
fontWeight:
FontWeight.w800,
),
),
SizedBox(height: 3),
Text(
'Use your phone camera to take a new photo.',
style: TextStyle(
color: greyText,
fontSize: 11,
),
),
],
),
),

Icon(
Icons.chevron_right_rounded,
color: greyText,
),
],
),
),
),

const SizedBox(height: 12),

// ==============================================
// GALLERY
// ==============================================

InkWell(
borderRadius:
BorderRadius.circular(16),
onTap: () {
Navigator.pop(
bottomSheetContext,
ImageSource.gallery,
);
},
child: Container(
padding:
const EdgeInsets.all(16),
decoration: BoxDecoration(
color:
const Color(0xFFF0FDFA),
borderRadius:
BorderRadius.circular(16),
border: Border.all(
color:
const Color(0xFF99F6E4),
),
),
child: const Row(
children: [
CircleAvatar(
radius: 23,
backgroundColor:
Color(0xFFCCFBF1),
child: Icon(
Icons.photo_library_rounded,
color: teal,
),
),

SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Choose from Gallery',
style: TextStyle(
color: darkText,
fontSize: 15,
fontWeight:
FontWeight.w800,
),
),
SizedBox(height: 3),
Text(
'Choose an existing image from your phone.',
style: TextStyle(
color: greyText,
fontSize: 11,
),
),
],
),
),

Icon(
Icons.chevron_right_rounded,
color: greyText,
),
],
),
),
),

const SizedBox(height: 14),

TextButton(
onPressed: () {
Navigator.pop(
bottomSheetContext,
);
},
child: const Text(
'CANCEL',
style: TextStyle(
color: greyText,
fontWeight:
FontWeight.w800,
),
),
),
],
),
),
);
},
);

if (source == null) {
return;
}

try {
XFile? image;

if (source ==
ImageSource.camera) {
image =
await _imagePickerService
    .pickImageFromCamera();
}

if (source ==
ImageSource.gallery) {
image =
await _imagePickerService
    .pickImageFromGallery();
}

if (image == null) {
return;
}

final Uint8List bytes =
await image.readAsBytes();

const int maxFileSize =
5 * 1024 * 1024;

if (bytes.length > maxFileSize) {
_showMessage(
'Please select a valid Profile Picture in JPG, JPEG, PNG, or WEBP format with a file size of 5 MB or smaller.',
);
return;
}

final String fileName =
image.name.toLowerCase();

final bool validFile =
fileName.endsWith('.jpg') ||
fileName.endsWith('.jpeg') ||
fileName.endsWith('.png') ||
fileName.endsWith('.webp');

if (!validFile) {
_showMessage(
'Please select a valid Profile Picture in JPG, JPEG, PNG, or WEBP format with a file size of 5 MB or smaller.',
);
return;
}

setDialogState(() {
_selectedImage = image;
_selectedImageBytes = bytes;
});

_showMessage(
'Profile picture selected. Save your profile to apply the change.',
);
} catch (error) {
debugPrint(
'IMAGE PICKER ERROR: $error',
);

_showMessage(
'Unable to select profile picture: $error',
);
}
}

// ============================================================
// EDIT PROFILE DIALOG
// ============================================================

Future<void> _openEditProfile() async {
_nameController.text = _fullName;
_selectedImage = null;
_selectedImageBytes = null;

PhoneNumber initialPhone = PhoneNumber(
isoCode: 'MY',
dialCode: '+60',
phoneNumber: _phoneNumber,
);

try {
if (_phoneNumber.trim().isNotEmpty) {
initialPhone =
await PhoneNumber.getRegionInfoFromPhoneNumber(
_phoneNumber,
);
}
} catch (_) {
// Keep Malaysia as a safe selector default if an older stored
// number cannot be parsed by libphonenumber.
}

bool phoneIsValid = false;
String normalizedPhone = _phoneNumber.trim();

await showDialog<void>(
context: context,
barrierDismissible: false,
builder: (dialogContext) {
return StatefulBuilder(
builder: (context, setDialogState) {
return Dialog(
backgroundColor: pageBackground,
insetPadding: const EdgeInsets.symmetric(
horizontal: 18,
vertical: 20,
),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(22),
),
child: SingleChildScrollView(
padding: const EdgeInsets.all(22),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment:
CrossAxisAlignment.stretch,
children: [
Row(
children: [
const Expanded(
child: Text(
'Edit Profile Information',
style: TextStyle(
color: darkText,
fontSize: 20,
fontWeight: FontWeight.w900,
fontFamily: 'serif',
),
),
),
IconButton(
onPressed: _isSaving
? null
    : () {
_nameController.text =
_fullName;
_phoneController.text =
_phoneNumber;
_selectedImage = null;
_selectedImageBytes = null;
Navigator.pop(
dialogContext,
);
},
icon: const Icon(
Icons.close_rounded,
),
),
],
),
const Divider(),
const SizedBox(height: 14),

Container(
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: const Color(0xFFF0F9FF),
borderRadius:
BorderRadius.circular(14),
border: Border.all(
color: const Color(0xFFBAE6FD),
),
),
child: Row(
children: [
_buildEditAvatar(),
const SizedBox(width: 15),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
SizedBox(
height: 40,
child: FilledButton.icon(
onPressed: _isSaving
? null
    : () =>
_chooseProfilePhoto(
setDialogState,
),
style:
FilledButton.styleFrom(
backgroundColor:
primaryBlue,
foregroundColor:
Colors.white,
),
icon: const Icon(
Icons.add_a_photo_rounded,
size: 17,
),
label: const Text(
'CHANGE PHOTO',
style: TextStyle(
fontSize: 10,
fontWeight:
FontWeight.w900,
),
),
),
),
const SizedBox(height: 6),
const Text(
'JPG, JPEG, PNG or WEBP • max 5MB',
style: TextStyle(
color: greyText,
fontSize: 9,
),
),
],
),
),
],
),
),

const SizedBox(height: 22),
const Text(
'FULL NAME *',
style: TextStyle(
color: greyText,
fontSize: 10,
fontWeight: FontWeight.w900,
),
),
const SizedBox(height: 7),
TextField(
controller: _nameController,
decoration:
_inputDecoration(hint: 'Full Name'),
),

const SizedBox(height: 20),
const Text(
'PHONE NUMBER *',
style: TextStyle(
color: greyText,
fontSize: 10,
fontWeight: FontWeight.w900,
),
),
const SizedBox(height: 7),

InternationalPhoneNumberInput(
textFieldController: _phoneController,
initialValue: initialPhone,
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
final value =
number.phoneNumber?.trim() ?? '';
normalizedPhone =
value.startsWith('+')
? value
    : '';
},
onInputValidated: (bool valid) {
phoneIsValid = valid;
},
inputDecoration: _inputDecoration(
hint: 'Phone Number',
),
),

const SizedBox(height: 25),
SizedBox(
height: 48,
child: FilledButton(
onPressed: _isSaving
? null
    : () async {
final bool saved =
await _saveProfile(
normalizedPhone:
normalizedPhone,
phoneIsValid:
phoneIsValid,
);

if (saved &&
dialogContext.mounted) {
Navigator.pop(
dialogContext,
);
} else if (mounted) {
setDialogState(() {});
}
},
child: _isSaving
? const CircularProgressIndicator(
color: Colors.white,
strokeWidth: 2,
)
    : const Text(
'SAVE CHANGES',
style: TextStyle(
fontWeight:
FontWeight.w900,
),
),
),
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

Future<bool> _saveProfile({
required String normalizedPhone,
required bool phoneIsValid,
}) async {
final User? user =
SupabaseConfig.client.auth.currentUser;

if (user == null) {
_showMessage(
'Unable to update the profile. Please try again.',
);
return false;
}

final String newName =
_nameController.text.trim();

// [A2][M1][C1]
if (newName.isEmpty ||
_phoneController.text.trim().isEmpty) {
_showMessage(
'Please complete all required fields before saving your profile.',
);
return false;
}

// [A3][M2][C2]
if (newName.length < 2 ||
newName.length > 50) {
_showMessage(
'Please enter a valid full name (2–50 characters).',
);
return false;
}

// [A4][M3][C3][C4]
if (!phoneIsValid ||
normalizedPhone.isEmpty ||
!normalizedPhone.startsWith('+')) {
_showMessage(
'Please enter a valid phone number for the selected country.',
);
return false;
}

final bool nameChanged =
newName != _fullName;

final bool phoneChanged =
normalizedPhone != _phoneNumber;

final bool pictureChanged =
_selectedImage != null &&
_selectedImageBytes != null;

// [A5][M4][C5]
if (!nameChanged &&
!phoneChanged &&
!pictureChanged) {
_showMessage(
'No changes were detected in your profile information.',
);
return true;
}

if (mounted) {
setState(() {
_isSaving = true;
});
}

try {
final Map<String, dynamic> updates = {};

// [C6] Update only changed fields.
if (nameChanged) {
updates['full_name'] = newName;
}

if (phoneChanged) {
updates['phone_number'] =
normalizedPhone;
}

String? newPhotoUrl =
_profilePictureUrl;

if (pictureChanged) {
newPhotoUrl =
await _uploadProfilePicture(
userId: user.id,
image: _selectedImage!,
bytes: _selectedImageBytes!,
);

updates['profile_picture_url'] =
newPhotoUrl;
}

updates['updated_at'] =
DateTime.now().toIso8601String();

await SupabaseConfig.client
    .from('profiles')
    .update(updates)
    .eq('id', user.id);

if (!mounted) return false;

setState(() {
if (nameChanged) {
_fullName = newName;
}

if (phoneChanged) {
_phoneNumber =
normalizedPhone;
}

if (pictureChanged) {
_profilePictureUrl =
newPhotoUrl;
}

_selectedImage = null;
_selectedImageBytes = null;
_isSaving = false;
});

// [M5]
_showMessage(
'Your profile has been updated successfully.',
);

return true;
} catch (_) {
if (mounted) {
setState(() {
_isSaving = false;
});
}

_showMessage(
'Unable to update the profile. Please try again.',
);

return false;
}
}

// ============================================================
// UPLOAD PROFILE PICTURE TO SUPABASE STORAGE
// ============================================================

Future<String> _uploadProfilePicture({
required String userId,
required XFile image,
required Uint8List bytes,
}) async {
String extension = image.name.split('.').last.toLowerCase();

if (extension == 'jpeg') {
extension = 'jpg';
}

String contentType = 'image/jpeg';

if (extension == 'png') {
contentType = 'image/png';
}

if (extension == 'webp') {
contentType = 'image/webp';
}

// One stable path is reused for every retry. upsert=true is
// important because the first request may actually reach
// Supabase even when the phone loses the response connection.
final String path =
'$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';

Object? lastError;

for (int attempt = 1; attempt <= 3; attempt++) {
try {
await SupabaseConfig.client.storage
    .from('profile-pictures')
    .uploadBinary(
path,
bytes,
fileOptions: FileOptions(
contentType: contentType,
upsert: true,
),
)
    .timeout(
const Duration(seconds: 45),
);

return SupabaseConfig.client.storage
    .from('profile-pictures')
    .getPublicUrl(path);
} catch (error) {
lastError = error;

debugPrint(
'PROFILE PHOTO UPLOAD ATTEMPT $attempt FAILED: $error',
);

if (attempt < 3) {
await Future<void>.delayed(
Duration(seconds: attempt * 2),
);
}
}
}

throw Exception(
'Profile photo upload failed after 3 attempts. $lastError',
);
}

// ============================================================
// CHANGE PASSWORD
// ============================================================

Future<void> _openChangePassword() async {
final currentController =
TextEditingController();
final newController =
TextEditingController();
final confirmController =
TextEditingController();

bool showCurrent = false;
bool showNew = false;
bool showConfirm = false;
bool changing = false;

await showDialog<void>(
context: context,
barrierDismissible: false,
builder: (dialogContext) {
return StatefulBuilder(
builder: (context, setDialogState) {
return AlertDialog(
title: const Text('Change Password'),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
TextField(
controller: currentController,
obscureText: !showCurrent,
decoration: InputDecoration(
labelText: 'Current Password',
suffixIcon: IconButton(
onPressed: () {
setDialogState(() {
showCurrent =
!showCurrent;
});
},
icon: Icon(
showCurrent
? Icons.visibility_off
    : Icons.visibility,
),
),
),
),
const SizedBox(height: 14),
TextField(
controller: newController,
obscureText: !showNew,
decoration: InputDecoration(
labelText: 'New Password',
suffixIcon: IconButton(
onPressed: () {
setDialogState(() {
showNew = !showNew;
});
},
icon: Icon(
showNew
? Icons.visibility_off
    : Icons.visibility,
),
),
),
),
const SizedBox(height: 14),
TextField(
controller: confirmController,
obscureText: !showConfirm,
decoration: InputDecoration(
labelText: 'Confirm Password',
suffixIcon: IconButton(
onPressed: () {
setDialogState(() {
showConfirm =
!showConfirm;
});
},
icon: Icon(
showConfirm
? Icons.visibility_off
    : Icons.visibility,
),
),
),
),
],
),
),
actions: [
TextButton(
onPressed: changing
? null
    : () =>
Navigator.pop(dialogContext),
child: const Text('CANCEL'),
),
FilledButton(
onPressed: changing
? null
    : () async {
final String currentPassword =
currentController.text;
final String newPassword =
newController.text;
final String confirmPassword =
confirmController.text;

// [A6d][M13][C12]
if (currentPassword.isEmpty ||
newPassword.isEmpty ||
confirmPassword.isEmpty) {
_showMessage(
'Please complete all required password fields.',
);
return;
}

final User? user =
SupabaseConfig
    .client.auth.currentUser;

final String email =
user?.email ?? '';

if (user == null ||
email.isEmpty) {
_showMessage(
'Unable to change the password. Please try again.',
);
return;
}

setDialogState(() {
changing = true;
});

try {
// [A6a][M8][C8]
try {
await SupabaseConfig
    .client.auth
    .signInWithPassword(
email: email,
password:
currentPassword,
);
} on AuthException {
if (dialogContext.mounted) {
setDialogState(() {
changing = false;
});
}

_showMessage(
'The current password is incorrect. Please try again.',
);
return;
}

final bool strongPassword =
newPassword.length >= 8 &&
RegExp(r'[A-Z]')
    .hasMatch(
newPassword) &&
RegExp(r'[a-z]')
    .hasMatch(
newPassword) &&
RegExp(r'[0-9]')
    .hasMatch(
newPassword) &&
RegExp(
r'[^A-Za-z0-9]',
).hasMatch(
newPassword,
);

// [A6b][M9][C9]
if (!strongPassword) {
if (dialogContext.mounted) {
setDialogState(() {
changing = false;
});
}

_showMessage(
'Please enter a password that meets the password requirements.',
);
return;
}

// [A6e][M14][C13]
if (newPassword ==
currentPassword) {
if (dialogContext.mounted) {
setDialogState(() {
changing = false;
});
}

_showMessage(
'The new password must be different from your current password.',
);
return;
}

// [A6c][M10][C10]
if (newPassword !=
confirmPassword) {
if (dialogContext.mounted) {
setDialogState(() {
changing = false;
});
}

_showMessage(
'The new password and confirmation password do not match.',
);
return;
}

await SupabaseConfig.client.auth
    .updateUser(
UserAttributes(
password: newPassword,
),
);

if (!mounted) return;

// [M11]
_showMessage(
'Your password has been changed successfully.',
);

if (dialogContext.mounted) {
Navigator.pop(
dialogContext,
);
}
} catch (_) {
if (dialogContext.mounted) {
setDialogState(() {
changing = false;
});
}

_showMessage(
'Unable to change the password. Please try again.',
);
}
},
child: changing
? const SizedBox(
width: 18,
height: 18,
child:
CircularProgressIndicator(
strokeWidth: 2,
color: Colors.white,
),
)
    : const Text(
'CHANGE PASSWORD',
),
),
],
);
},
);
},
);

currentController.dispose();
newController.dispose();
confirmController.dispose();
}

// ============================================================
// LOGOUT
// ============================================================

Future<void> _logout() async {
// [A7][A7a][M12]
final bool? confirmed =
await showDialog<bool>(
context: context,
builder: (dialogContext) {
return AlertDialog(
title: const Text('Log Out'),
content: const Text(
'Are you sure you want to log out?',
),
actions: [
TextButton(
onPressed: () =>
Navigator.pop(
dialogContext,
false,
),
child: const Text('CANCEL'),
),
FilledButton(
onPressed: () =>
Navigator.pop(
dialogContext,
true,
),
child: const Text('LOG OUT'),
),
],
);
},
);

if (confirmed != true) {
return;
}

try {
// [C11]
await SupabaseConfig.client.auth.signOut();

if (!mounted) return;

Navigator.of(context).pushAndRemoveUntil(
MaterialPageRoute(
builder: (context) =>
const WelcomeScreen(),
),
(route) => false,
);
} catch (_) {
_showMessage(
'Unable to log out. Please try again.',
);
}
}

// ============================================================
// PAGE UI
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
_buildProfileBackButton(),

const SizedBox(
height:
18,
),

_buildProfileHeader(),

const SizedBox(
height:
24,
),

_buildExplorationPoints(),

const SizedBox(
height:
16,
),

_buildStats(),

const SizedBox(
height:
24,
),

_buildAchievements(),

const SizedBox(
height:
24,
),

_buildProfileInformation(),

const SizedBox(
height:
24,
),

_buildSecurity(),

const SizedBox(
height:
30,
),
],
),
),
),
),
),
),

floatingActionButtonLocation:
FloatingActionButtonLocation.centerDocked,

floatingActionButton:
_buildHomeButton(),

bottomNavigationBar:
_buildBottomBar(),
);
}

// ============================================================
// PROFILE HEADER
// ============================================================

Widget _buildProfileBackButton() {
return Align(
alignment: Alignment.centerLeft,
child: OutlinedButton.icon(
onPressed: () => Navigator.of(context).maybePop(),
icon: const Icon(Icons.arrow_back_rounded, size: 20),
label: const Text('Back'),
style: OutlinedButton.styleFrom(
foregroundColor: darkText,
backgroundColor: Colors.white,
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
side: const BorderSide(color: borderColor),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
),
),
);
}

Widget _buildProfileHeader() {
return Column(
children: [
Stack(
clipBehavior:
Clip.none,
children: [
Container(
width:
112,
height:
112,
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
right:
-2,
bottom:
3,
child:
InkWell(
customBorder:
const CircleBorder(),

onTap:
_openEditProfile,

child:
Container(
width:
38,
height:
38,
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
height:
14,
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
height:
7,
),

Text(
_fullName.isEmpty
? 'Traveller'
    : _fullName,
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
height:
4,
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

// ============================================================
// EDIT AVATAR PREVIEW
// ============================================================

Widget _buildEditAvatar() {
ImageProvider? provider;

if (_selectedImageBytes !=
null) {
provider =
MemoryImage(
_selectedImageBytes!,
);
} else if (_profilePictureUrl !=
null) {
provider =
NetworkImage(
_profilePictureUrl!,
);
}

return Container(
width:
66,
height:
66,
padding:
const EdgeInsets.all(
2,
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
provider,

child:
provider == null
? Text(
_getInitial(),
style:
const TextStyle(
color:
primaryBlue,
fontSize:
25,
fontWeight:
FontWeight.w900,
),
)
    : null,
),
);
}

// ============================================================
// EXPLORATION POINTS
// ============================================================

Widget _buildExplorationPoints() {
return Container(
height:
145,
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
20,
),
),

child:
Column(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
const Icon(
Icons.workspace_premium_outlined,
color:
Color(
0xFFFACC15,
),
size:
30,
),

const SizedBox(
height:
7,
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
2,
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
text:
'MISSIONS COMPLETED',
),
),

const SizedBox(
width:
12,
),

Expanded(
child:
_statCard(
value:
_leaderboardRank == 0
? '-'
    : '#$_leaderboardRank',
text:
'LEADERBOARD RANK',
),
),
],
);
}

Widget _statCard({
required String value,
required String text,
}) {
return Container(
padding:
const EdgeInsets.all(
18,
),

decoration:
_whiteCardDecoration(),

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
23,
fontWeight:
FontWeight.w900,
),
),

Text(
text,
style:
const TextStyle(
color:
greyText,
fontSize:
8,
fontWeight:
FontWeight.w800,
),
),
],
),
);
}

// ============================================================
// ACHIEVEMENTS
// ============================================================

Widget _buildAchievements() {
return Material(
color: Colors.white,
borderRadius: BorderRadius.circular(18),
child: InkWell(
borderRadius: BorderRadius.circular(18),
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const AchievementScreen(),
),
);
},
child: Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(18),
border: Border.all(color: borderColor),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 46,
height: 46,
decoration: BoxDecoration(
color: const Color(0xFFFFFBEB),
borderRadius: BorderRadius.circular(14),
),
child: const Icon(
Icons.emoji_events_rounded,
color: Color(0xFFD97706),
size: 26,
),
),
const SizedBox(width: 13),
const Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Achievements',
style: TextStyle(
color: darkText,
fontSize: 18,
fontWeight: FontWeight.w900,
),
),
SizedBox(height: 3),
Text(
'View unlocked, in-progress and locked achievements.',
style: TextStyle(
color: greyText,
fontSize: 10,
height: 1.35,
),
),
],
),
),
const Icon(
Icons.chevron_right_rounded,
color: greyText,
),
],
),
const SizedBox(height: 16),
const Divider(height: 1),
const SizedBox(height: 14),
const Row(
children: [
Icon(
Icons.touch_app_outlined,
color: primaryBlue,
size: 16,
),
SizedBox(width: 6),
Expanded(
child: Text(
'Tap to see achievement progress and unlock requirements.',
style: TextStyle(
color: primaryBlue,
fontSize: 10,
fontWeight: FontWeight.w800,
),
),
),
],
),
],
),
),
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
_infoRow(
'FULL NAME',
_fullName,
),

const Divider(
height:
28,
),

_infoRow(
'EMAIL ADDRESS',
_email,
),

const Divider(
height:
28,
),

_infoRow(
'PHONE NUMBER',
_phoneNumber,
),

const SizedBox(
height:
20,
),

SizedBox(
width:
double.infinity,

height:
50,

child:
FilledButton.icon(
onPressed:
_openEditProfile,

style:
FilledButton.styleFrom(
backgroundColor:
primaryBlue,
),

icon:
const Icon(
Icons.edit_outlined,
),

label:
const Text(
'EDIT PROFILE & PHOTO',
),
),
),
],
),
);
}

Widget _infoRow(
String label,
String value,
) {
return Align(
alignment:
Alignment.centerLeft,

child:
Column(
crossAxisAlignment:
CrossAxisAlignment.start,

children: [
Text(
label,
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

const SizedBox(
height:
5,
),

Text(
value.isEmpty
? '-'
    : value,
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
);
}

// ============================================================
// SECURITY
// ============================================================

Widget _buildSecurity() {
return Container(
decoration: _whiteCardDecoration(),
clipBehavior: Clip.antiAlias,
child: Column(
crossAxisAlignment:
CrossAxisAlignment.stretch,
children: [
// ------------------------------------------------------
// SECURITY HEADER
// ------------------------------------------------------
Padding(
padding: const EdgeInsets.fromLTRB(
18,
18,
18,
16,
),
child: Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Container(
width: 46,
height: 46,
decoration: BoxDecoration(
color: const Color(
0xFFE0F2FE,
),
borderRadius:
BorderRadius.circular(
14,
),
),
child: const Icon(
Icons.shield_outlined,
color: primaryBlue,
size: 24,
),
),

const SizedBox(width: 13),

const Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Account Security & Session',
style: TextStyle(
color: darkText,
fontSize: 17,
fontWeight:
FontWeight.w900,
),
),
SizedBox(height: 5),
Text(
'Manage your password and account session.',
style: TextStyle(
color: greyText,
fontSize: 11,
height: 1.4,
),
),
],
),
),
],
),
),

const Divider(
height: 1,
thickness: 1,
color: borderColor,
),

// ------------------------------------------------------
// CHANGE PASSWORD
// ------------------------------------------------------
Material(
color: Colors.transparent,
child: InkWell(
onTap: _openChangePassword,
child: Padding(
padding: const EdgeInsets.symmetric(
horizontal: 18,
vertical: 15,
),
child: Row(
children: [
Container(
width: 40,
height: 40,
decoration: BoxDecoration(
color: const Color(
0xFFF0F9FF,
),
borderRadius:
BorderRadius.circular(
12,
),
),
child: const Icon(
Icons.lock_reset_rounded,
color: primaryBlue,
size: 22,
),
),

const SizedBox(width: 13),

const Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Change Password',
style: TextStyle(
color: darkText,
fontSize: 14,
fontWeight:
FontWeight.w800,
),
),
SizedBox(height: 4),
Text(
'Verify your current password and set a new password.',
style: TextStyle(
color: greyText,
fontSize: 10,
height: 1.35,
),
),
],
),
),

const SizedBox(width: 8),

const Icon(
Icons.chevron_right_rounded,
color: Color(
0xFF94A3B8,
),
size: 23,
),
],
),
),
),
),

const Divider(
height: 1,
thickness: 1,
indent: 71,
color: borderColor,
),

// ------------------------------------------------------
// SESSION STATUS
// ------------------------------------------------------
Padding(
padding: const EdgeInsets.symmetric(
horizontal: 18,
vertical: 14,
),
child: Row(
children: [
Container(
width: 40,
height: 40,
decoration: BoxDecoration(
color: const Color(
0xFFECFDF5,
),
borderRadius:
BorderRadius.circular(
12,
),
),
child: const Icon(
Icons.verified_user_outlined,
color: Color(
0xFF059669,
),
size: 21,
),
),

const SizedBox(width: 13),

const Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Current Session',
style: TextStyle(
color: darkText,
fontSize: 14,
fontWeight:
FontWeight.w800,
),
),
SizedBox(height: 4),
Text(
'You are currently signed in securely.',
style: TextStyle(
color: greyText,
fontSize: 10,
),
),
],
),
),

Container(
padding:
const EdgeInsets.symmetric(
horizontal: 9,
vertical: 5,
),
decoration: BoxDecoration(
color: const Color(
0xFFDCFCE7,
),
borderRadius:
BorderRadius.circular(
99,
),
),
child: const Text(
'ACTIVE',
style: TextStyle(
color: Color(
0xFF15803D,
),
fontSize: 8,
fontWeight:
FontWeight.w900,
letterSpacing: 0.7,
),
),
),
],
),
),

const Divider(
height: 1,
thickness: 1,
color: borderColor,
),

// ------------------------------------------------------
// LOG OUT
// ------------------------------------------------------
Material(
color: Colors.transparent,
child: InkWell(
onTap: _logout,
child: Padding(
padding: const EdgeInsets.symmetric(
horizontal: 18,
vertical: 15,
),
child: Row(
children: [
Container(
width: 40,
height: 40,
decoration: BoxDecoration(
color: const Color(
0xFFFEF2F2,
),
borderRadius:
BorderRadius.circular(
12,
),
),
child: const Icon(
Icons.logout_rounded,
color: Color(
0xFFDC2626,
),
size: 21,
),
),

const SizedBox(width: 13),

const Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Log Out',
style: TextStyle(
color: Color(
0xFFDC2626,
),
fontSize: 14,
fontWeight:
FontWeight.w800,
),
),
SizedBox(height: 4),
Text(
'Sign out from MYsteryLane on this device.',
style: TextStyle(
color: greyText,
fontSize: 10,
),
),
],
),
),

const Icon(
Icons.chevron_right_rounded,
color: Color(
0xFFFCA5A5,
),
size: 23,
),
],
),
),
),
),
],
),
);
}

// ============================================================
// HOME BUTTON
// ============================================================

Widget _buildHomeButton() {
return Padding(
padding: const EdgeInsets.only(
top: 10,
),
child: InkWell(
customBorder: const CircleBorder(),
onTap: () {
Navigator.of(context).pop();
},
child: Container(
width: 66,
height: 66,
decoration: BoxDecoration(
shape: BoxShape.circle,
gradient: const LinearGradient(
colors: [
primaryBlue,
teal,
],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
border: Border.all(
color: Colors.white,
width: 4,
),
boxShadow: const [
BoxShadow(
color: Color(0x3D0284C7),
blurRadius: 16,
offset: Offset(0, 7),
),
],
),
child: const Column(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Icon(
Icons.home_rounded,
color: Color(0xFFFDE68A),
size: 27,
),
Text(
'HOME',
style: TextStyle(
color: Colors.white,
fontSize: 8,
fontWeight: FontWeight.w900,
letterSpacing: 0.8,
),
),
],
),
),
),
);
}

// ============================================================
// BOTTOM BAR
// ============================================================

Widget _buildBottomBar() {
return BottomAppBar(
height: 78,
padding: EdgeInsets.zero,
color: Colors.white.withOpacity(0.98),
elevation: 18,
shadowColor: const Color(
0x330284C7,
),
shape: const CircularNotchedRectangle(),
notchMargin: 8,
child: SafeArea(
top: false,
child: Row(
children: [
Expanded(
child: _buildProfileBottomItem(
icon: Icons.inventory_2_outlined,
label: 'BLIND BOX',
onTap: () {
_showMessage(
'Blind Box is not connected yet.',
);
},
),
),

Expanded(
child: _buildProfileBottomItem(
icon: Icons.assignment_outlined,
label: 'MISSIONS',
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) =>
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
child: _buildProfileBottomItem(
icon: Icons.map_outlined,
label: 'PLAN',
onTap: () {
_showMessage(
'Plan is not connected yet.',
);
},
),
),

Expanded(
child: _buildProfileBottomItem(
icon: Icons.groups_2_outlined,
label: 'TEAMS',
onTap: () {
_showMessage(
'Teams is not connected yet.',
);
},
),
),
],
),
),
);
}

Widget _buildProfileBottomItem({
required IconData icon,
required String label,
required VoidCallback onTap,
}) {
return InkWell(
onTap: onTap,
child: Padding(
padding: const EdgeInsets.only(
top: 10,
bottom: 4,
),
child: Column(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Container(
width: 42,
height: 29,
decoration: BoxDecoration(
color: Colors.transparent,
borderRadius:
BorderRadius.circular(
12,
),
),
child: Icon(
icon,
size: 21,
color: const Color(
0xFF64748B,
),
),
),
const SizedBox(
height: 3,
),
FittedBox(
fit: BoxFit.scaleDown,
child: Text(
label,
maxLines: 1,
style: const TextStyle(
color: Color(
0xFF64748B,
),
fontSize: 8,
fontWeight:
FontWeight.w800,
letterSpacing: 0.45,
),
),
),
],
),
),
);
}

Widget _bottomItem(
IconData icon,
String text,
VoidCallback action,
) {
return InkWell(
onTap:
action,

child:
Column(
mainAxisAlignment:
MainAxisAlignment.center,

children: [
Icon(
icon,
color:
greyText,
),

Text(
text,
style:
const TextStyle(
color:
greyText,
fontSize:
8,
),
),
],
),
);
}

// ============================================================
// HELPERS
// ============================================================

String _getInitial() {
if (_fullName.trim().isEmpty) {
return '?';
}

return _fullName
    .trim()[0]
    .toUpperCase();
}

String _formatNumber(
int number,
) {
return number.toString();
}

InputDecoration _inputDecoration({
required String hint,
}) {
return InputDecoration(
hintText:
hint,

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
);
}

void _showMessage(
String message,
) {
if (!mounted) return;

ScaffoldMessenger.of(context)
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

