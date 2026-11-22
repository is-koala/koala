import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/product/constants/upload_limits.dart';
import 'package:koala/product/services/picked_file_probe.dart';

enum IdentityPhotoSource {
  /// Yüz kareleri için ön kamera.
  camera,

  gallery,
}

/// Kabul edilen biçimler, **içerik imzasıyla**: Android seçicisi HEIC'i JPEG'e
/// çevirip adı `.heic` bırakıyor. Parça adı ve tip de buradan yazılıyor.
enum IdentityImageFormat {
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png');

  const IdentityImageFormat(this.extension, this.mimeType);

  /// Sunucunun `UploadValidator`'ı `originalFilename` uzantısına bakıyor.
  final String extension;

  final String mimeType;

  static const int signatureLength = PickedFileProbe.headLength;

  /// JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`. WEBP yok: sunucu
  /// okuyamıyor.
  static IdentityImageFormat? detect(List<int> head) {
    if (_startsWith(head, const [0xFF, 0xD8, 0xFF])) return jpeg;
    if (_startsWith(head, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ])) {
      return png;
    }
    return null;
  }

  /// ISO-BMFF `ftyp` kutusu ve HEIF markası; sunucu açamıyor.
  static bool isHeif(List<int> head) {
    if (head.length < 12) return false;
    if (String.fromCharCodes(head.sublist(4, 8)) != 'ftyp') return false;
    final brand = String.fromCharCodes(head.sublist(8, 12)).toLowerCase();
    return const {
      'heic',
      'heix',
      'hevc',
      'hevx',
      'heif',
      'mif1',
      'msf1',
    }.contains(brand);
  }

  static bool _startsWith(List<int> head, List<int> prefix) {
    if (head.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (head[i] != prefix[i]) return false;
    }
    return true;
  }
}

/// Seçiciden gelen ham dosya; [IdentityPhotoPolicy.accept] karar verir.
class IdentityPhotoCandidate {
  const IdentityPhotoCandidate({
    required this.slot,
    required this.path,
    required this.bytes,
    required this.head,
  });

  final IdentityPhotoSlot slot;

  final String path;

  final int bytes;

  final List<int> head;
}

/// Kabul edilmiş kare: yalnız yol, boyut ve biçim. Kare belleğe alınmıyor;
/// boyut seçimde ölçülüyor ki toplam için dosyalar yeniden açılmasın.
class IdentityPhoto {
  const IdentityPhoto({
    required this.slot,
    required this.path,
    required this.bytes,
    required this.format,
  });

  final IdentityPhotoSlot slot;

  final String path;

  final int bytes;

  final IdentityImageFormat format;

  /// Uzantı gerçek içerikten.
  String get uploadName => '${slot.fieldName}.${format.extension}';
}

/// Karenin neden kabul edilmediği; kullanıcı dört dosyalık yüklemeyi bekleyip
/// reddedilmesin. Metinler ne yapılacağını söylüyor.
enum IdentityPhotoRejection {
  /// iPhone'un varsayılan biçimi; sunucu açamıyor.
  heic(
    'Bu fotoğraf HEIC biçiminde; sunucu bu biçimi kabul etmiyor. Telefonun '
    'kamera ayarlarından "En Uyumlu" biçimini seç ya da fotoğrafı JPEG '
    'olarak kaydedip yeniden seç.',
  ),

  unsupportedType('PNG, JPG veya JPEG biçiminde bir fotoğraf seç.'),

  tooLarge(
    'Fotoğraf en fazla 10 MB olabilir. Daha düşük çözünürlükte yeniden çek '
    'ya da galeriden daha küçük bir kopya seç.',
  ),

  totalTooLarge(
    'Dört fotoğrafın toplam boyutu en fazla 40 MB olabilir. Büyük kareleri '
    'daha düşük çözünürlükte yeniden çek.',
  );

  const IdentityPhotoRejection(this.message);

  final String message;
}

/// Kimlik fotoğrafı sınırları; web ve sunucuyla aynı: dosya başına 10 MiB,
/// toplam 40 MiB, PNG / JPG / JPEG.
abstract final class IdentityPhotoPolicy {
  static const int maxPhotoBytes = UploadLimits.maxImageBytes;

  /// Sunucu `MAX_REQUEST_SIZE=42MB`; 2 MB JSON parçası ve sınır dizgeleri için.
  /// Sabit ifadede enum uzunluğu okunamadığı için sayı yazılı, testi kare
  /// sayısına bağlı.
  static const int photoCount = 4;

  static const int maxTotalBytes = photoCount * maxPhotoBytes;

  static const Set<String> allowedExtensions = UploadLimits.imageExtensions;

  /// Seçiciden istenen en uzun kenar: sunucu sınırlarının altında kalır ve
  /// seçiciyi HEIC'i JPEG'e çevirmeye zorlar. 2560 px kart okunacak kadar net.
  static const double maxDimension = 2560;

  /// 100'de Android seçicisi yeniden kodlamayı atlıyor ve HEIC geliyor.
  static const int quality = 90;

  /// Biçim **içerikten**; HEIF kendi mesajını alır.
  static ({IdentityPhoto? photo, IdentityPhotoRejection? rejection}) accept(
    IdentityPhotoCandidate candidate,
  ) {
    if (IdentityImageFormat.isHeif(candidate.head)) {
      return (photo: null, rejection: IdentityPhotoRejection.heic);
    }
    final format = IdentityImageFormat.detect(candidate.head);
    if (format == null) {
      return (photo: null, rejection: IdentityPhotoRejection.unsupportedType);
    }
    if (candidate.bytes > maxPhotoBytes) {
      return (photo: null, rejection: IdentityPhotoRejection.tooLarge);
    }
    return (
      photo: IdentityPhoto(
        slot: candidate.slot,
        path: candidate.path,
        bytes: candidate.bytes,
        format: format,
      ),
      rejection: null,
    );
  }

  static IdentityPhotoRejection? checkTotal(Iterable<IdentityPhoto> photos) {
    var total = 0;
    for (final photo in photos) {
      total += photo.bytes;
    }
    return total > maxTotalBytes ? IdentityPhotoRejection.totalTooLarge : null;
  }
}
