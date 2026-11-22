import 'dart:io';

import 'package:koala/product/constants/upload_limits.dart';

/// Galeri yüklemesinin ön kontrolü; kullanıcı yükleme bekleyip reddedilmesin.
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
