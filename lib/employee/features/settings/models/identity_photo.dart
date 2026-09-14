import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/product/constants/upload_limits.dart';

/// Karenin nereden alındığı.
enum IdentityPhotoSource {
  /// Cihaz kamerası; yüz kareleri için ön kamera tercih ediliyor.
  camera,

  /// Galeri / sistem fotoğraf seçicisi.
  gallery,
}

/// Sunucunun kabul ettiği görsel biçimleri, **içerik imzasıyla** tanınmış.
///
/// Uzantıya güvenilmiyor: Android galerisinden HEIC seçildiğinde
/// `image_picker` kareyi JPEG olarak yeniden kodluyor ama dosya adını
/// `.heic` bırakıyor; uzantıya bakan bir denetim doğru bir JPEG'i
/// reddederdi. Dosyanın ilk baytları ne olduğunu söylüyor, gönderilen parça
/// adı ve içerik tipi de buradan yazılıyor.
enum IdentityImageFormat {
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png'),
  webp('webp', 'image/webp');

  const IdentityImageFormat(this.extension, this.mimeType);

  /// Multipart parça adına yazılan uzantı; sunucunun `UploadValidator`'ı
  /// `originalFilename` uzantısına bakıyor.
  final String extension;

  /// Multipart parçasının `Content-Type`'ı.
  final String mimeType;

  /// Dosya başındaki imzayı okumak için yeten bayt sayısı: WEBP'nin
  /// `RIFF....WEBP` başlığı ve HEIF'in `....ftyp` kutusu 12 bayt.
  static const int signatureLength = 12;

  /// Baş baytlardan biçimi bulur; tanımıyorsa `null`.
  ///
  /// JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`, WEBP `RIFF` + 4 bayt
  /// boyut + `WEBP`.
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
    if (_startsWith(head, 'RIFF'.codeUnits) &&
        head.length >= 12 &&
        String.fromCharCodes(head.sublist(8, 12)) == 'WEBP') {
      return webp;
    }
    return null;
  }

  /// HEIF ailesi mi: ISO-BMFF `ftyp` kutusu ve `heic` / `heix` / `hevc` /
  /// `mif1` / `msf1` / `heif` markası. Sunucu bunu açamıyor.
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

/// Seçiciden gelen ham dosya: yol, boyut ve baş baytlar.
///
/// Henüz kabul edilmedi; [IdentityPhotoPolicy.accept] biçimi ve sınırları
/// bakıp ya [IdentityPhoto] üretir ya [IdentityPhotoRejection] söyler.
class IdentityPhotoCandidate {
  const IdentityPhotoCandidate({
    required this.slot,
    required this.path,
    required this.bytes,
    required this.head,
  });

  final IdentityPhotoSlot slot;

  /// Cihazdaki dosya yolu; `image_picker`'ın verdiği geçici kopya.
  final String path;

  /// Dosyanın boyutu.
  final int bytes;

  /// Dosyanın ilk [IdentityImageFormat.signatureLength] baytı; biçim
  /// buradan tanınıyor.
  final List<int> head;
}

/// Bir kare için kabul edilmiş dosya.
///
/// Yalnız yol, boyut ve biçim taşıyor: kare belleğe alınmıyor, önizleme
/// dosyadan çiziliyor ve gönderim dosyadan akıtılıyor. Boyut seçim anında
/// ölçülüp burada saklanıyor ki toplam sınırı hesaplamak için dört dosyayı
/// yeniden açmak gerekmesin. [format] içerik imzasından; gönderilen parçanın
/// adı ve içerik tipi bundan yazılıyor, dosyanın uzantısından değil.
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

  /// Sunucuya giden parça adı: `front.jpg` gibi. Uzantı gerçek içerikten.
  String get uploadName => '${slot.fieldName}.${format.extension}';
}

/// Seçilen karenin neden kabul edilmediği.
///
/// Sunucu aynı kuralları uyguluyor (`UploadValidator`); burada bakılmasının
/// sebebi kullanıcıyı dört dosyalık bir yüklemenin bitmesini bekleyip
/// reddedilmekten kurtarmak. Metinler **ne yapılacağını** söylüyor.
enum IdentityPhotoRejection {
  /// iPhone'un varsayılan biçimi (içerik imzasından tanınıyor). Sunucu
  /// ImageIO ile açamıyor ve `STORAGE_UNSUPPORTED_TYPE` ile reddediyor;
  /// seçici JPEG'e çeviremediyse kullanıcıya söylemek gerekiyor.
  heic(
    'Bu fotoğraf HEIC biçiminde; sunucu bu biçimi kabul etmiyor. Telefonun '
    'kamera ayarlarından "En Uyumlu" biçimini seç ya da fotoğrafı JPEG '
    'olarak kaydedip yeniden seç.',
  ),

  /// İçeriği JPEG, PNG ya da WEBP olarak tanınmayan dosya.
  unsupportedType('PNG, JPG, JPEG veya WEBP biçiminde bir fotoğraf seç.'),

  /// Tek dosya sunucunun dosya başına sınırını aşıyor.
  tooLarge(
    'Fotoğraf en fazla 10 MB olabilir. Daha düşük çözünürlükte yeniden çek '
    'ya da galeriden daha küçük bir kopya seç.',
  ),

  /// Dört dosyanın toplamı istek gövdesi sınırını aşıyor.
  totalTooLarge(
    'Dört fotoğrafın toplam boyutu en fazla 40 MB olabilir. Büyük kareleri '
    'daha düşük çözünürlükte yeniden çek.',
  );

  const IdentityPhotoRejection(this.message);

  /// Kullanıcıya gösterilen açıklama.
  final String message;
}

/// Kimlik fotoğrafları için istemci tarafı sınırlar.
///
/// Değerler web'deki `document-upload-policy.ts` ile ve sunucunun
/// `UploadProperties` / `spring.servlet.multipart` ayarlarıyla aynı:
/// dosya başına 10 MiB, dört dosya toplamı 40 MiB (sunucunun 42 MB'lik
/// istek sınırı JSON parçası ve multipart başlıkları için pay bırakıyor),
/// uzantı PNG / JPG / JPEG / WEBP.
abstract final class IdentityPhotoPolicy {
  /// Tek karenin en büyük boyutu; şirket logosuyla aynı sunucu sınırı.
  static const int maxPhotoBytes = UploadLimits.maxImageBytes;

  /// Dört karenin toplamı. Sunucu `MAX_REQUEST_SIZE=42MB`; aradaki 2 MB
  /// `identity` JSON parçası ve multipart sınır dizgeleri için. Çarpan
  /// [IdentityPhotoSlot] sayısı; enum uzunluğu sabit ifadede okunamadığı
  /// için sayı yazılıyor ve testi kare sayısına bağlı.
  static const int photoCount = 4;

  static const int maxTotalBytes = photoCount * maxPhotoBytes;

  /// Sunucunun kabul ettiği uzantılar (`upload.image-extensions`);
  /// [IdentityImageFormat] bu kümenin içerik karşılığı ve gönderilen parça
  /// adı hep bu kümeden bir uzantı taşıyor.
  static const Set<String> allowedExtensions = UploadLimits.imageExtensions;

  /// Seçiciden istenen en uzun kenar. İki işi var: 50 megapiksellik sunucu
  /// tavanının ve 10 MB'lik dosya sınırının çok altında kalmak, **ve**
  /// seçiciyi yeniden kodlamaya zorlamak — hem iOS hem Android seçicisi
  /// ölçekleme istendiğinde HEIC'i JPEG olarak yazıyor. Bir kimlik kartı
  /// 2560 piksellik kenarda personelin okuyabileceği kadar net.
  static const double maxDimension = 2560;

  /// JPEG kalitesi. 100 verilirse Android seçicisi yeniden kodlamayı
  /// atlıyor ve HEIC olduğu gibi geliyor; 90'da kart yazıları okunur kalıyor.
  static const int quality = 90;

  /// Adayı biçim ve boyut sınırlarından geçirir.
  ///
  /// Biçim **içerikten**: JPEG/PNG/WEBP imzası yoksa reddediliyor, HEIF
  /// imzası kendi mesajını alıyor. Kabulde [IdentityPhoto] biçimiyle birlikte
  /// dönüyor; ikisi birden dolu ya da boş olamaz.
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

  /// Seçilen karelerin toplamı istek sınırının içinde mi.
  static IdentityPhotoRejection? checkTotal(Iterable<IdentityPhoto> photos) {
    var total = 0;
    for (final photo in photos) {
      total += photo.bytes;
    }
    return total > maxTotalBytes ? IdentityPhotoRejection.totalTooLarge : null;
  }
}
