import 'dart:io';

import 'package:koala/product/constants/upload_limits.dart';

/// İşveren galeri yüklemelerinin dosya sistemi ön kontrolü.
///
/// Şirket ve ilan galerileri aynı tür/boyut kurallarına tabidir. Sunucu da
/// doğrular; bu kontrol kullanıcıyı gereksiz yükleme bekleyişinden korur.
abstract final class BGalleryUploadValidator {
  static Future<String?> errorFor(String path) async {
    if (!UploadLimits.hasAllowedImageExtension(path)) {
      return 'Yalnızca PNG veya JPG yükleyebilirsiniz';
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
