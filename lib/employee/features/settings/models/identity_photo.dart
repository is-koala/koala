import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/product/constants/upload_limits.dart';

/// Karenin nereden alındığı.
enum IdentityPhotoSource {
  /// Cihaz kamerası; yüz kareleri için ön kamera tercih ediliyor.
  camera,

  /// Galeri / sistem fotoğraf seçicisi.
  gallery,
}

/// Bir kare için seçilmiş dosya.
///
/// Yalnız yol ve boyut taşıyor: kare belleğe alınmıyor, önizleme dosyadan
/// çiziliyor ve gönderim dosyadan akıtılıyor. Boyut seçim anında ölçülüp
/// burada saklanıyor ki toplam sınırı hesaplamak için dört dosyayı yeniden
/// açmak gerekmesin. Sınırlardan geçip geçmediğine [IdentityPhotoPolicy]
/// karar veriyor; seçici bu nesneyi ham hâliyle veriyor.
class IdentityPhoto {
  const IdentityPhoto({
    required this.slot,
    required this.path,
    required this.bytes,
  });

  final IdentityPhotoSlot slot;

  /// Cihazdaki dosya yolu; `image_picker`'ın verdiği geçici kopya.
  final String path;

  /// Dosyanın boyutu.
  final int bytes;
}

/// Seçilen karenin neden kabul edilmediği.
///
/// Sunucu aynı kuralları uyguluyor (`UploadValidator`); burada bakılmasının
/// sebebi kullanıcıyı dört dosyalık bir yüklemenin bitmesini bekleyip
/// reddedilmekten kurtarmak. Metinler **ne yapılacağını** söylüyor.
enum IdentityPhotoRejection {
  /// iPhone'un varsayılan biçimi. Sunucu ImageIO ile açamıyor ve
  /// `STORAGE_UNSUPPORTED_TYPE` ile reddediyor; seçici JPEG'e çeviremediyse
  /// kullanıcıya söylemek gerekiyor.
  heic(
    'Bu fotoğraf HEIC biçiminde; sunucu bu biçimi kabul etmiyor. Telefonun '
    'kamera ayarlarından "En Uyumlu" biçimini seç ya da fotoğrafı JPEG '
    'olarak kaydedip yeniden seç.',
  ),

  /// PNG, JPG, JPEG ve WEBP dışında bir uzantı.
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

  /// Kabul edilen uzantılar (`upload.image-extensions`).
  static const Set<String> allowedExtensions = UploadLimits.imageExtensions;

  /// iPhone'un HEIF ailesi. Seçici JPEG'e çevirmeden verdiyse sunucu
  /// açamayacak; kullanıcıya bunun için ayrı bir açıklama gösteriliyor.
  static const Set<String> heicExtensions = {'heic', 'heif'};

  /// Seçiciden istenen en uzun kenar. İki işi var: 50 megapiksellik sunucu
  /// tavanının ve 10 MB'lik dosya sınırının çok altında kalmak, **ve**
  /// seçiciyi yeniden kodlamaya zorlamak — hem iOS hem Android seçicisi
  /// ölçekleme istendiğinde HEIC'i JPEG olarak yazıyor. Bir kimlik kartı
  /// 2560 piksellik kenarda personelin okuyabileceği kadar net.
  static const double maxDimension = 2560;

  /// JPEG kalitesi. 100 verilirse Android seçicisi yeniden kodlamayı
  /// atlıyor ve HEIC olduğu gibi geliyor; 90'da kart yazıları okunur kalıyor.
  static const int quality = 90;

  /// [path] uzantısı; nokta yoksa boş.
  static String extensionOf(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// Tek kare sınırların içinde mi; değilse neden değil.
  static IdentityPhotoRejection? check({
    required String path,
    required int bytes,
  }) {
    final extension = extensionOf(path);
    if (heicExtensions.contains(extension)) return IdentityPhotoRejection.heic;
    if (!allowedExtensions.contains(extension)) {
      return IdentityPhotoRejection.unsupportedType;
    }
    if (bytes > maxPhotoBytes) return IdentityPhotoRejection.tooLarge;
    return null;
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
