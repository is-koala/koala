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
  /// Dönen aday henüz sınırlardan geçmedi; biçim ve boyut kararı
  /// [IdentityPhotoPolicy.accept]'in işi. Boyut ve baş baytlar burada
  /// okunuyor ki sayfa dosyayı bir daha açmasın.
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

  /// Diskteki dosyadan aday kurar: boyut ve içerik imzası için baş baytlar.
  ///
  /// Eşzamanlı okuma: dosyanın tamamı değil ilk on iki baytı; sahte saatli
  /// widget testlerinde de eşzamansız IO gibi takılmıyor.
  static IdentityPhotoCandidate candidateFor(
    IdentityPhotoSlot slot,
    String path,
  ) {
    final file = File(path);
    final handle = file.openSync();
    try {
      return IdentityPhotoCandidate(
        slot: slot,
        path: path,
        bytes: handle.lengthSync(),
        head: handle.readSync(IdentityImageFormat.signatureLength),
      );
    } finally {
      handle.closeSync();
    }
  }
}
