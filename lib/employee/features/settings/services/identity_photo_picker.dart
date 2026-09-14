import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';

/// Kimlik fotoğrafını kameradan ya da galeriden alan sınır.
///
/// `image_picker` zaten pubspec'te (şirket logosu ve profil fotoğrafı için
/// eklenmişti); kamera desteği aynı eklentide, yeni paket gerekmiyor. Sınıf
/// olarak duruyor ki testler yerli eklenti olmadan bir sahteyle değiştirsin.
///
/// Seçiciye ölçek ve kalite **her zaman** veriliyor ([IdentityPhotoPolicy]):
/// hem dosya boyutunu sunucu sınırının altında tutuyor hem de iPhone'un
/// HEIC karesini JPEG'e çevirtiyor — iki platformun seçicisi de ölçekleme
/// istendiğinde yeniden kodlayarak yazıyor. Sunucu HEIC açamıyor.
class IdentityPhotoPicker {
  const IdentityPhotoPicker();

  /// Kareyi alır; kullanıcı vazgeçtiyse `null`.
  ///
  /// Dönen dosya henüz sınırlardan geçmedi; boyut ve uzantı kontrolü
  /// çağıranın işi. Boyut burada ölçülüyor ki sayfa dosyayı bir daha
  /// açmasın.
  Future<IdentityPhoto?> pick(
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

    final bytes = await File(picked.path).length();
    return IdentityPhoto(slot: slot, path: picked.path, bytes: bytes);
  }
}
