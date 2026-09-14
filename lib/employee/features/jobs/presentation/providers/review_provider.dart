import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Değerlendirme formunun durumu ve "az önce gönderdim" belleği.
///
/// "Bu atamayı değerlendirdim mi" sorusunun kaynağı **sunucu**:
/// `MyAssignmentDto.myReview` (koala-backend#293) dolu geliyorsa
/// değerlendirilmiş, içerik de orada. Bu provider yalnız iki fetch arasındaki
/// boşluğu kapatıyor — kullanıcı formu gönderdi, elindeki liste henüz eski;
/// sunucu yanıtı bellekte tutuluyor ki düğme o anda kaybolsun. Sonraki
/// fetch geldiğinde sunucunun alanı esas ([ownReviewFor] önce ona bakıyor).
///
/// Disk önbelleği yok. Önceki sürüm kimlikleri `SharedPreferences`'a
/// yazıyordu (`reviewed_assignments*`, kullanıcı anahtarlı) ve içeriği
/// `GET /users/{id}/reviews` içinden **tahmin ediyordu**; ikisi de kaldırıldı,
/// eski anahtarlar [purgeLegacyCache] ile siliniyor. Bellek oturumluk:
/// [clear] çıkışta sıfırlıyor, uygulama kapanınca zaten gidiyor.
class ReviewProvider extends ChangeNotifier {
  ReviewProvider({ReviewService? service})
    : _service = service ?? ReviewService();

  /// Sunucunun "bu atamayı zaten değerlendirdin" dediği hata kodu.
  ///
  /// `ReviewManager.leaveReview` iki farklı reddi **aynı**
  /// `ConflictException` ile veriyor, yani ikisi de `409` + `DATA_CONFLICT`
  /// olarak geliyor:
  ///
  /// - atama `COMPLETED` değilse `{review.work.not.completed}`
  /// - değerlendirme zaten yazılmışsa `{review.already.reviewed}`
  ///
  /// Kategori bu ikisini ayıramıyor; ayıran tek alan `errorCode`, çünkü
  /// `KoalaException` onu mesaj anahtarından türetiyor
  /// (`{review.already.reviewed}` → `REVIEW_ALREADY_REVIEWED`). Bu kod eski
  /// sunucunun (alan yok) tek "değerlendirilmiş" sinyali; yeni sunucuda
  /// düğme zaten çıkmadığı için nadiren görülür.
  static const String _alreadyReviewedErrorCode = 'REVIEW_ALREADY_REVIEWED';

  /// Önceki sürümlerin disk anahtarları; kullanıcı kimliğiyle eklenmiş
  /// hâlleri de (`reviewed_assignments:<userId>`) aynı önekle başlıyor.
  static const List<String> _legacyPrefsPrefixes = [
    'reviewed_assignments',
    'reviewed_assignment_details',
  ];

  final ReviewService _service;

  /// Bu oturumda gönderilen kayıtlar: atama kimliği → sunucunun yanıtı.
  final Map<String, Review> _submitted = {};

  /// Bu oturumda "zaten değerlendirilmiş" öğrenilen atamalar; içerik yok.
  /// Yalnız eski sunucuya karşı: yeni sunucuda `myReview` doluyken düğme
  /// hiç çizilmiyor, buraya düşen bir istek de olmuyor.
  final Set<String> _knownReviewed = {};

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

  /// Bu atamaya yazılan değerlendirmenin içeriği; bilinmiyorsa `null`.
  ///
  /// Sunucu önce: [Assignment.myReview] doluysa o. Yoksa bu oturumda
  /// gönderilen yanıt — liste henüz tazelenmemişken düğme yerine içerik
  /// yazılsın. `null`, "değerlendirilmedi" demek değil; [hasReviewed] ona
  /// bakar (eski sunucunun `409`u içeriksiz işaretliyor).
  Review? ownReviewFor(Assignment? assignment) {
    if (assignment == null) return null;
    return assignment.myReview ?? _submitted[assignment.id];
  }

  /// Bu atama değerlendirilmiş mi: sunucu söylüyorsa sunucu, yoksa oturum.
  bool hasReviewed(Assignment? assignment) {
    if (assignment == null) return false;
    return assignment.myReview != null ||
        _submitted.containsKey(assignment.id) ||
        _knownReviewed.contains(assignment.id);
  }

  /// Tamamlanmış bir işi değerlendirir. Başarılıysa `true` döner.
  ///
  /// Yanıt, sunucunun söylediği atama kimliğiyle (`ReviewDto.jobAssignmentId`,
  /// yalnız bu yanıtta dolu) anahtarlanıyor; sunucu söylemezse istenen
  /// kimlikle. Sunucu `409 REVIEW_ALREADY_REVIEWED` derse atama içeriksiz
  /// işaretleniyor — kullanıcı açısından sonuç "yazılmış", düğme çıkmasın.
  /// Diğer her redde hiçbir şey işaretlenmiyor: iş henüz tamamlanmamış
  /// olabilir, fazladan bir düğme yanlış bir kilitten iyidir.
  Future<bool> submitReview({
    required String assignmentId,
    required int rating,
    String? comment,
    bool anonymous = false,
  }) async {
    if (_isSubmitting) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final review = await _service.leaveReview(
        assignmentId: assignmentId,
        rating: rating,
        comment: comment,
        anonymous: anonymous,
      );
      _submitted[review.jobAssignmentId ?? assignmentId] = review;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      // Kategoriye değil koda bakılıyor: `dataConflict` "zaten
      // değerlendirilmiş" ile "iş henüz tamamlanmamış"ı aynı torbaya koyuyor.
      if (error.errorCode == _alreadyReviewedErrorCode) {
        _knownReviewed.add(assignmentId);
      }
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Çıkışta önceki kullanıcının oturum belleği kalmasın.
  void clear() {
    _submitted.clear();
    _knownReviewed.clear();
    _errorMessage = null;
    notifyListeners();
  }

  /// Önceki sürümlerin disk önbelleğini siler.
  ///
  /// `main.dart` provider ilk okunduğunda çağırıyor (provider tembel, yani
  /// her açılışta bir kez); ilk temizlikten sonra önekle başlayan anahtar
  /// kalmadığı için sonraki çağrılar boş döngü. Ayrı bir "temizlendi" bayrağı
  /// tutulmadı: kaldırılan önbelleğin yerine kalıcı bir anahtar bırakmak
  /// olurdu. Anahtarlar kullanıcı kimliğiyle ekliydi ve kimlerin olduğu artık
  /// bilinmiyor; önekle başlayan her şey gidiyor. Disk okunamazsa (platform
  /// kanalı yok) sessiz — silinecek bir şey de yok demektir.
  static Future<void> purgeLegacyCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stale = prefs.getKeys().where(
        (key) => _legacyPrefsPrefixes.any(
          (prefix) => key == prefix || key.startsWith('$prefix:'),
        ),
      );
      for (final key in stale.toList()) {
        await prefs.remove(key);
      }
    } on Exception {
      // Yerel önbellek temizliği; başarısızlığı kullanıcıya taşınmaz.
    }
  }
}
