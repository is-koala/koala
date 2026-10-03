import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/product/constants/upload_limits.dart';
import 'package:koala/product/services/picked_file_probe.dart';

/// Kanıt olarak gönderilebilen biçimler, **içerik imzasıyla** tanınmış.
///
/// Sunucu uzantıya bakıyor ama içeriği de denetliyor (`pdf` için `%PDF`,
/// görsel için ImageIO). Uzantıya güvenilmiyor: Android seçicisi HEIC'i JPEG
/// olarak yeniden kodlayıp dosya adını `.heic` bırakabiliyor. Görsel imzaları
/// kimlik fotoğraflarıyla **aynı** koddan okunuyor ([IdentityImageFormat]) —
/// iki yerde yazılmış bir imza tablosu zamanla ayrışırdı.
///
/// **WEBP yok:** sunucu listesinde duruyor ama WebP okuyan bir ImageIO
/// eklentisi olmadığı için gerçek bir WebP hep `STORAGE_UNSUPPORTED_TYPE` ile
/// düşüyor (koala-backend#348).
enum EvidenceFormat {
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png'),
  pdf('pdf', 'application/pdf');

  const EvidenceFormat(this.extension, this.mimeType);

  /// Multipart parça adına yazılan uzantı; sunucu `originalFilename`
  /// uzantısına bakıyor.
  final String extension;

  /// Multipart parçasının `Content-Type`'ı.
  final String mimeType;

  bool get isImage => this != pdf;

  /// İmzayı okumak için yeten bayt sayısı ([PickedFileProbe] okuyor).
  static const int signatureLength = PickedFileProbe.headLength;

  /// Baş baytlardan biçimi bulur; tanımıyorsa `null`.
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

/// Kullanıcının seçtiği, henüz kabul edilmemiş dosya.
class EvidenceCandidate {
  const EvidenceCandidate({
    required this.path,
    required this.bytes,
    required this.head,
    this.displayName,
  });

  /// Cihazdaki dosya yolu; seçicinin verdiği geçici kopya.
  final String path;

  final int bytes;

  /// Dosyanın ilk [EvidenceFormat.signatureLength] baytı.
  final List<int> head;

  /// Kullanıcının verdiği ad (PDF'in kendi adı); `null` ise ad **yükleme
  /// anında** üretiliyor ([DisputeEvidencePolicy.accept]).
  ///
  /// Kamera ve galeriden gelen karelerde `null`: seçicinin geçici adı
  /// (`image_picker_8F2A….jpg`) kimseye bir şey söylemiyor. Ad olarak çekim ya
  /// da seçim anı da yazılmıyor — personel onu çekim zamanı sanabilir; yazılan
  /// tek zaman yüklemenin zamanı.
  final String? displayName;
}

/// Gönderilmeye hazır dosya: yol, boyut, biçim ve parça adı.
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

  /// Sunucuya giden dosya adı; uzantısı **gerçek içerikten**.
  final String uploadName;
}

/// Seçilen dosyanın neden kabul edilmediği. Sunucu aynı kuralları uyguluyor;
/// burada bakılmasının sebebi kullanıcıyı yüklemenin bitmesini bekleyip
/// reddedilmekten kurtarmak. Metinler **ne yapılacağını** söylüyor.
enum EvidenceRejection {
  /// Dosya boş (`DISPUTE_EVIDENCE_EMPTY`).
  empty('Dosya boş. İçeriği olan bir dosya seçin.'),

  /// iPhone'un varsayılan biçimi; sunucu açamıyor. Seçici JPEG'e çeviremediyse
  /// kullanıcıya söylemek gerekiyor.
  heic(
    'Bu fotoğraf HEIC biçiminde; sunucu bu biçimi kabul etmiyor. '
    'Telefonunuzun kamera ayarlarından "En Uyumlu" biçimini seçin ya da '
    'fotoğrafı JPEG olarak kaydedip yeniden seçin.',
  ),

  /// İçeriği PDF, JPEG ya da PNG olarak tanınmayan dosya.
  unsupportedType('PDF, PNG veya JPG biçiminde bir dosya seçin.'),

  /// Dosya sunucunun dosya başına sınırını aşıyor.
  tooLarge('Dosya en fazla 10 MB olabilir. Daha küçük bir dosya seçin.');

  const EvidenceRejection(this.message);

  final String message;
}

/// Kanıt dosyaları için istemci tarafı sınırlar (is-koala/koala#215).
///
/// Değerler backend `UploadProperties` ile aynı: dosya başına 10 MiB
/// (`upload.max-evidence-size-mb`), uyuşmazlık başına 5
/// (`upload.max-evidence-per-dispute`), uzantı `pdf, png, jpg, jpeg`
/// (`upload.evidence-extensions` bir de `webp` sayıyor ama onu okuyan bir
/// ImageIO eklentisi yok, koala-backend#348; vaat edilmiyor). Web'deki
/// `disputeEvidenceLimits` WebP'yi hâlâ listeliyor.
abstract final class DisputeEvidencePolicy {
  /// Tek dosyanın en büyük boyutu.
  static const int maxFileBytes = 10 * 1024 * 1024;

  /// Bir uyuşmazlığa eklenebilecek toplam kanıt; **iki tarafın toplamı**.
  static const int maxPerDispute = 5;

  /// Sunucunun kabul ettiği uzantılar; [EvidenceFormat] bu kümenin içerik
  /// karşılığı ve gönderilen ad hep bu kümeden bir uzantı taşıyor.
  static const Set<String> allowedExtensions = {
    'pdf',
    ...UploadLimits.imageExtensions,
  };

  /// Fotoğrafı seçiciden isterken verilen en uzun kenar ve JPEG kalitesi.
  /// Kimlik fotoğraflarıyla **aynı** değerler ve aynı iki gerekçe: sunucu
  /// sınırlarının çok altında kalmak ve seçiciyi yeniden kodlamaya zorlamak
  /// (iki platformun seçicisi de ölçekleme istendiğinde HEIC'i JPEG yazıyor).
  static const double maxDimension = IdentityPhotoPolicy.maxDimension;
  static const int quality = IdentityPhotoPolicy.quality;

  /// Gönderilen adın en uzun hâli (uzantı dahil değil).
  static const int maxBaseNameLength = 80;

  /// Adayı biçim ve boyut sınırlarından geçirir.
  ///
  /// Biçim **içerikten**: PDF/JPEG/PNG imzası yoksa reddediliyor, HEIF imzası
  /// kendi mesajını alıyor. Kabulde [EvidenceFile] içerikten yazılmış adla
  /// dönüyor; ikisi birden dolu ya da boş olamaz. [now] yükleme anı: adı
  /// olmayan dosya `kanit-<yyyyMMdd-HHmmss>` adını alıyor.
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

  /// Adı olmayan dosyanın gövdesi: `kanit-20261003-104231`. **Yükleme anı**,
  /// cihazın yerel saati; çekim zamanı değil (o EXIF'te, varsa).
  static String generatedBaseName(DateTime moment) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'kanit-${moment.year}${two(moment.month)}${two(moment.day)}'
        '-${two(moment.hour)}${two(moment.minute)}${two(moment.second)}';
  }

  /// Gönderilecek ad: [displayName]'in temizlenmiş gövdesi + **gerçek
  /// biçimin** uzantısı.
  ///
  /// Klasör ayracı, kontrol karakteri ve dosya sistemi için tehlikeli
  /// işaretler `_` olur; boş kalırsa `kanit`. Eski uzantı atılıyor: `.heic`
  /// adlı bir JPEG `.jpg` olarak gider.
  static String uploadNameFor(String displayName, EvidenceFormat format) {
    var base = displayName.split(RegExp(r'[\\/]')).last.trim();
    final dot = base.lastIndexOf('.');
    if (dot > 0) base = base.substring(0, dot);

    base = base
        .replaceAll(RegExp(r'[\x00-\x1F\x7F<>:"|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Başında nokta kalırsa dosya sistemlerinde gizli dosya sayılır.
    base = base.replaceFirst(RegExp(r'^\.+'), '').trim();
    if (base.length > maxBaseNameLength) {
      base = base.substring(0, maxBaseNameLength).trim();
    }
    if (base.isEmpty || RegExp(r'^[._ ]+$').hasMatch(base)) base = 'kanit';

    return '$base.${format.extension}';
  }

  /// Bir uyuşmazlığa şu an kanıt eklenebilir mi.
  ///
  /// Sunucunun iki kapısı: uyuşmazlık sonuçlanmamış olmalı ve toplam sayı
  /// sınırın altında kalmalı. Bayat olabilir (karşı taraf bu arada ekledi);
  /// karar yine sunucunun, bu yalnız düğmeyi gereksiz yere açmamak için.
  static bool canAttach({required bool isOpen, required int count}) =>
      isOpen && count < maxPerDispute;
}
