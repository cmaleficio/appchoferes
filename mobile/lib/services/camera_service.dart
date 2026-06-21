import 'package:image_picker/image_picker.dart';

class CameraService {
  static final CameraService _instance = CameraService._();
  static CameraService get instance => _instance;
  CameraService._();

  final ImagePicker _picker = ImagePicker();

  /// Opens the camera, takes a photo, and returns the file path.
  /// Returns `null` if the user cancels.
  Future<String?> takeReceiptPhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    return photo?.path;
  }

  /// Opens the gallery to pick an existing receipt image.
  Future<String?> pickReceiptFromGallery() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    return photo?.path;
  }
}
