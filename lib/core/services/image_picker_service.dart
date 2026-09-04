import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  // ============================================================
  // PICK IMAGE FROM GALLERY
  // ============================================================

  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      return image;
    } catch (error) {
      throw Exception(
        'Unable to select image from gallery: $error',
      );
    }
  }

  // ============================================================
  // TAKE IMAGE USING CAMERA
  // ============================================================

  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      return image;
    } catch (error) {
      throw Exception(
        'Unable to capture image using camera: $error',
      );
    }
  }

  // ============================================================
  // GENERAL IMAGE PICKER
  // ============================================================

  Future<XFile?> pickImage({
    required ImageSource source,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      return image;
    } catch (error) {
      throw Exception(
        'Unable to select image: $error',
      );
    }
  }
}