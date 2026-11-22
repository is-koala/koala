import 'package:image_picker/image_picker.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/product/services/picked_file_probe.dart';

/// Kimlik fotoğrafını kamera ya da galeriden alır; testler sahtesiyle
/// değiştirsin diye sınıf. Ölçek ve kalite her zaman veriliyor: sınırın altında
/// kalır ve HEIC JPEG'e çevrilir.
class IdentityPhotoPicker {
  const IdentityPhotoPicker();

  /// Vazgeçilirse `null`. Boyut ve baş baytlar burada okunur ki sayfa dosyayı
  /// bir daha açmasın.
  Future<IdentityPhotoCandidate?> pick(
    IdentityPhotoSlot slot,
    IdentityPhotoSource source,
  ) async {
    final picked = await ImagePicker().pickImage(
      source: switch (source) {
        IdentityPhotoSource.camera => ImageSource.camera,
        IdentityPhotoSource.gallery => ImageSource.gallery,
      },
      maxWidth: IdentityPhotoPolicy.maxDimension,
      maxHeight: IdentityPhotoPolicy.maxDimension,
      imageQuality: IdentityPhotoPolicy.quality,
      preferredCameraDevice: slot.usesFrontCamera
          ? CameraDevice.front
          : CameraDevice.rear,
    );
    if (picked == null) return null;

    return candidateFor(slot, picked.path);
  }

  static IdentityPhotoCandidate candidateFor(
    IdentityPhotoSlot slot,
    String path,
  ) {
    final probe = PickedFileProbe.read(path);
    return IdentityPhotoCandidate(
      slot: slot,
      path: path,
      bytes: probe.bytes,
      head: probe.head,
    );
  }
}
