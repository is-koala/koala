import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/product/constants/upload_limits.dart';
import 'package:koala/product/services/picked_file_probe.dart';

/// Kanıt biçimleri, **içerik imzasıyla** tanınmış: Android seçicisi HEIC'i
/// JPEG'e çevirip adı `.heic` bırakabiliyor. Görsel imzaları kimlik
/// fotoğraflarıyla aynı koddan ([IdentityImageFormat]). WEBP yok: sunucu
/// okuyamıyor.
enum EvidenceFormat {
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png'),
  pdf('pdf', 'application/pdf');

  const EvidenceFormat(this.extension, this.mimeType);

  /// Sunucu `originalFilename` uzantısına bakıyor.
  final String extension;

  final String mimeType;

  bool get isImage => this != pdf;

  static const int signatureLength = PickedFileProbe.headLength;

  static EvidenceFormat? detect(List<int> head) {
    if (head.length >= 4 &&
        head[0] == 0x25 &&
        head[1] == 0x50 &&
        head[2] == 0x44 &&
        head[3] == 0x46) {
      return pdf;
    }

    return switch (IdentityImageFormat.detect(head)) {
      IdentityImageFormat.jpeg => jpeg,
      IdentityImageFormat.png => png,
      null => null,
    };
  }
}

class EvidenceCandidate {
  const EvidenceCandidate({
    required this.path,
    required this.bytes,
    required this.head,
    this.displayName,
  });

  /// Seçicinin verdiği geçici kopya.
  final String path;

  final int bytes;

  final List<int> head;

  /// Kullanıcının verdiği ad (PDF'in adı); `null` ise yükleme anında üretilir.
  /// Kamera/galeri karelerinde `null`: seçicinin geçici adı bir şey söylemiyor,
  /// çekim anı yazmak da personeli yanıltır.
  final String? displayName;
}

class EvidenceFile {
  const EvidenceFile({
    required this.path,
    required this.bytes,
    required this.format,
    required this.uploadName,
  });

  final String path;
  final int bytes;
  final EvidenceFormat format;

  /// Uzantısı **gerçek içerikten**.
  final String uploadName;
}

/// Dosyanın neden kabul edilmediği; kullanıcı yüklemeyi bekleyip reddedilmesin.
/// Metinler ne yapılacağını söylüyor.
enum EvidenceRejection {
  empty('Dosya boş. İçeriği olan bir dosya seçin.'),

  /// iPhone'un varsayılan biçimi; sunucu açamıyor.
  heic(
    'Bu fotoğraf HEIC biçiminde; sunucu bu biçimi kabul etmiyor. '
    'Telefonunuzun kamera ayarlarından "En Uyumlu" biçimini seçin ya da '
    'fotoğrafı JPEG olarak kaydedip yeniden seçin.',
  ),

  unsupportedType('PDF, PNG veya JPG biçiminde bir dosya seçin.'),

  tooLarge('Dosya en fazla 10 MB olabilir. Daha küçük bir dosya seçin.');

  const EvidenceRejection(this.message);

  final String message;
}

/// Kanıt sınırları (#215), backend `UploadProperties` ile aynı: 10 MiB,
/// uyuşmazlık başına 5, `pdf, png, jpg, jpeg`. WEBP sunucuda listede ama
/// okunamıyor, vaat edilmiyor.
abstract final class DisputeEvidencePolicy {
  static const int maxFileBytes = 10 * 1024 * 1024;

  /// İki tarafın toplamı.
  static const int maxPerDispute = 5;

  static const Set<String> allowedExtensions = {
    'pdf',
    ...UploadLimits.imageExtensions,
  };

  /// Kimlik fotoğraflarıyla aynı değerler: sunucu sınırının altında kalmak ve
  /// seçiciyi HEIC'i JPEG'e çevirmeye zorlamak.
  static const double maxDimension = IdentityPhotoPolicy.maxDimension;
  static const int quality = IdentityPhotoPolicy.quality;

  static const int maxBaseNameLength = 80;

  /// Biçim ve boyut sınırından geçirir. Biçim içerikten; HEIF kendi mesajını
  /// alır. Adı olmayan dosya `kanit-<yyyyMMdd-HHmmss>` olur ([now] yükleme
  /// anı).
  static ({EvidenceFile? file, EvidenceRejection? rejection}) accept(
    EvidenceCandidate candidate, {
    required DateTime now,
  }) {
    if (candidate.bytes <= 0) {
      return (file: null, rejection: EvidenceRejection.empty);
    }
    if (IdentityImageFormat.isHeif(candidate.head)) {
      return (file: null, rejection: EvidenceRejection.heic);
    }
    final format = EvidenceFormat.detect(candidate.head);
    if (format == null) {
      return (file: null, rejection: EvidenceRejection.unsupportedType);
    }
    if (candidate.bytes > maxFileBytes) {
      return (file: null, rejection: EvidenceRejection.tooLarge);
    }

    return (
      file: EvidenceFile(
        path: candidate.path,
        bytes: candidate.bytes,
        format: format,
        uploadName: uploadNameFor(
          candidate.displayName ?? generatedBaseName(now),
          format,
        ),
      ),
      rejection: null,
    );
  }

  /// Yükleme anı, yerel saat; çekim zamanı değil.
  static String generatedBaseName(DateTime moment) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'kanit-${moment.year}${two(moment.month)}${two(moment.day)}'
        '-${two(moment.hour)}${two(moment.minute)}${two(moment.second)}';
  }

  /// Temizlenmiş ad + **gerçek biçimin** uzantısı. Tehlikeli karakterler `_`
  /// olur; `.heic` adlı JPEG `.jpg` gider.
  static String uploadNameFor(String displayName, EvidenceFormat format) {
    var base = displayName.split(RegExp(r'[\\/]')).last.trim();
    final dot = base.lastIndexOf('.');
    if (dot > 0) base = base.substring(0, dot);

    base = base
        .replaceAll(RegExp(r'[\x00-\x1F\x7F<>:"|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Baştaki nokta dosyayı gizli yapar.
    base = base.replaceFirst(RegExp(r'^\.+'), '').trim();
    if (base.length > maxBaseNameLength) {
      base = base.substring(0, maxBaseNameLength).trim();
    }
    if (base.isEmpty || RegExp(r'^[._ ]+$').hasMatch(base)) base = 'kanit';

    return '$base.${format.extension}';
  }

  /// Kanıt eklenebilir mi: açık ve sınırın altında. Bayat olabilir; karar yine
  /// sunucunun, bu yalnız düğmeyi boşuna açmamak için.
  static bool canAttach({required bool isOpen, required int count}) =>
      isOpen && count < maxPerDispute;
}
