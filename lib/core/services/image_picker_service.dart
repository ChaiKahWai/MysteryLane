import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImageFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
    } catch (e) {
      throw Exception(
        'Unable to open camera: $e',
      );
    }
  }

  Future<XFile?> pickImageFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (e) {
      throw Exception(
        'Unable to open gallery: $e',
      );
    }
  }
}