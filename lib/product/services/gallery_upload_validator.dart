import 'dart:io';

import 'package:koala/product/constants/upload_limits.dart';

/// Galeri yüklemesinin dosya sistemi sınırı.
///
/// Şirket ve ilan galerileri aynı tür/boyut kurallarına tabidir. Sunucu da
/// doğrular; bu ön kontrol kullanıcıyı gereksiz yükleme bekleyişinden korur.
abstract final class GalleryUploadValidator {
  static Future<String?> errorFor(String path) async {
    if (!UploadLimits.hasAllowedImageExtension(path)) {
      return 'Yalnızca PNG, JPG veya WEBP yükleyebilirsiniz';
    }

    final int length;
    try {
      length = await File(path).length();
    } on FileSystemException {
      return 'Seçilen görsel okunamadı';
    }

    if (length > UploadLimits.maxImageBytes) {
      return 'Görsel en fazla 10 MB olabilir';
    }
    return null;
  }
}
