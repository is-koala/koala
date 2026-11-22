import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Değerlendirme formu ve "az önce gönderdim" belleği. Kaynak **sunucu**
/// (`myReview`); provider yalnız iki fetch arasındaki boşluğu kapatıyor ki
/// düğme hemen kaybolsun. Disk önbelleği yok; eski sürümlerin anahtarları
/// [purgeLegacyCache] ile silinir.
class ReviewProvider extends ChangeNotifier {
  ReviewProvider({ReviewService? service})
    : _service = service ?? ReviewService();

  /// "Zaten değerlendirdin" kodu. Bu ve "iş tamamlanmadı" aynı `409
  /// DATA_CONFLICT`; ayıran tek alan `errorCode`. Eski sunucunun tek
  /// "değerlendirilmiş" sinyali.
  static const String _alreadyReviewedErrorCode = 'REVIEW_ALREADY_REVIEWED';

  /// Kullanıcı kimlikli anahtarlar da aynı önekle başlıyor.
  static const List<String> _legacyPrefsPrefixes = [
    'reviewed_assignments',
    'reviewed_assignment_details',
  ];

  final ReviewService _service;

  final Map<String, Review> _submitted = {};

  /// Yalnız eski sunucuya karşı; içerik yok.
  final Set<String> _knownReviewed = {};

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

  /// Önce [Assignment.myReview], yoksa bu oturumda gönderilen. `null`
  /// "değerlendirilmedi" demek değil; [hasReviewed]'a bak.
  Review? ownReviewFor(Assignment? assignment) {
    if (assignment == null) return null;
    return assignment.myReview ?? _submitted[assignment.id];
  }

  bool hasReviewed(Assignment? assignment) {
    if (assignment == null) return false;
    return assignment.myReview != null ||
        _submitted.containsKey(assignment.id) ||
        _knownReviewed.contains(assignment.id);
  }

  /// Başarılıysa `true`. `409 REVIEW_ALREADY_REVIEWED`'de atama içeriksiz
  /// işaretlenir; diğer redlerde işaret yok, fazladan düğme yanlış kilitten
  /// iyi.
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
      // `dataConflict` iki durumu aynı torbaya koyuyor; koda bakılıyor.
      if (error.errorCode == _alreadyReviewedErrorCode) {
        _knownReviewed.add(assignmentId);
      }
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clear() {
    _submitted.clear();
    _knownReviewed.clear();
    _errorMessage = null;
    notifyListeners();
  }

  /// Eski disk önbelleğini siler; ilk temizlikten sonra boş döngü. Ayrı
  /// "temizlendi" bayrağı kalıcı bir anahtar bırakırdı. Disk okunamazsa sessiz.
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
