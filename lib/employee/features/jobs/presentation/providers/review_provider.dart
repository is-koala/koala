import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının bıraktığı değerlendirmeler.
///
/// Sunucuda "bu işi değerlendirdim mi" diye sorulacak bir uç yok: ikinci
/// değerlendirme reddediliyor, o kadar. "Değerlendir" butonunun yerinde
/// "Değerlendirildi" rozetini gösterebilmek için değerlendirilen atamaların
/// kimlikleri cihazda tutuluyor.
///
/// Bu bir önbellek, kaynak değil: kayıt kaybolursa (uygulama silinip
/// kurulursa, kullanıcı başka cihaza geçerse) buton geri gelir, basıldığında
/// sunucu reddeder ve kayıt oradan tazelenir. Yani yanlış tarafa düşse bile
/// akış tıkanmıyor — **eksik tarafa** düşerse. Fazla tarafa düşmesi kalıcı:
/// [_prefsKey] diske yazılıyor ve onu silen tek şey çıkış.
class ReviewProvider extends ChangeNotifier {
  ReviewProvider({ReviewService? service})
    : _service = service ?? ReviewService() {
    // Disk okunamazsa (platform kanalı yok) kayıtsız başlanıyor; bekleyen
    // çağrılar hata yerine boş önbellekle devam ediyor.
    _restored = _restore().catchError((Object _) {});
  }

  /// Değerlendirilmiş atamaların kimlikleri; cihazda saklanan anahtar.
  static const String _prefsKey = 'reviewed_assignments';

  /// Kendi yazdığımız değerlendirmelerin içeriği (atama kimliği →
  /// [Review.toJson]); "Değerlendirdiniz: ★4 · yorum" satırı buradan
  /// çiziliyor. [_prefsKey]'den ayrı, çünkü içerik olmadan da kimlik
  /// işaretli olabilir (409'dan öğrenilen, başka cihazda yazılmış kayıt).
  static const String _detailsPrefsKey = 'reviewed_assignment_details';

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
  /// (`{review.already.reviewed}` → `REVIEW_ALREADY_REVIEWED`). Sunucunun
  /// ayrı bir kategori üretmesini beklemek yerine bugün gerçekten gönderdiği
  /// alana bakılıyor; kod, sınıfını değil **bu** hatayı tanımlıyor.
  static const String _alreadyReviewedErrorCode = 'REVIEW_ALREADY_REVIEWED';

  final ReviewService _service;

  final Set<String> _reviewedAssignmentIds = {};
  final Map<String, Review> _ownReviews = {};

  /// Kurucudaki disk okuması; provider tembel kurulduğunda ilk çağrı okuma
  /// bitmeden gelebiliyor, [loadOwnReview] önce bunu bekliyor.
  late final Future<void> _restored;

  /// Sunucudan kendi kaydını arayan istekler; aynı atama için ikinci kez
  /// gidilmesin.
  final Set<String> _lookingUp = {};

  bool _isSubmitting = false;
  String? _errorMessage;

  /// Değerlendirilmiş atamaların kimlikleri.
  Set<String> get reviewedAssignmentIds =>
      Set.unmodifiable(_reviewedAssignmentIds);

  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

  /// Bu atama değerlendirilmiş mi.
  bool hasReviewed(String? assignmentId) =>
      assignmentId != null && _reviewedAssignmentIds.contains(assignmentId);

  /// Bu atamaya kendi yazdığımız değerlendirme; içeriği bilinmiyorsa `null`.
  ///
  /// `null`, "değerlendirilmedi" demek değil — [hasReviewed] ona bakar. Kayıt
  /// bu cihazda yazıldıysa içerik yanıttan geliyor; başka cihazda yazıldıysa
  /// [loadOwnReview] sunucudan tamamlamayı dener.
  Review? ownReviewFor(String? assignmentId) =>
      assignmentId == null ? null : _ownReviews[assignmentId];

  /// Tamamlanmış bir işi değerlendirir. Başarılıysa `true` döner.
  ///
  /// Sunucu reddederse atama **yalnızca** [_alreadyReviewedErrorCode] ile
  /// işaretleniyor: orada sonuç kullanıcı açısından "yazıldı" demek, buton
  /// bir daha çıkmasın. Emin olunamayan her durumda — kod gelmedi, kod
  /// tanınmadı, başka bir hata — hiç işaretlenmiyor.
  ///
  /// Asimetri bilinçli, çünkü iki yanlışın bedeli eşit değil: işaretlememek
  /// kullanıcıya fazladan bir "Değerlendir" butonu gösterir ve bir sonraki
  /// denemede sunucu doğruyu söyler; yanlışlıkla işaretlemek diske yazılır ve
  /// o atamayı **kalıcı olarak** değerlendirilemez yapar.
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
      await _markReviewed(assignmentId, review: review);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      // Kategoriye değil koda bakılıyor: `dataConflict` "zaten
      // değerlendirilmiş" ile "iş henüz tamamlanmamış"ı aynı torbaya koyuyor.
      // İkincisini işaretlemek, işi tamamlanmadan değerlendirmeye çalışan
      // kullanıcının o atamayı iş bittikten sonra da hiç değerlendirememesi
      // demekti.
      if (error.errorCode == _alreadyReviewedErrorCode) {
        await _markReviewed(assignmentId);
      }
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// İşaretli ama içeriği bilinmeyen atamanın değerlendirmesini sunucudan
  /// tamamlar: `GET /users/{subjectUserId}/reviews` içinde yazarı biz olan
  /// kayıt aranıyor.
  ///
  /// Sunucu "hangi atamaya" demiyor (`ReviewDto`'da atama kimliği yok), bu
  /// yüzden bu arama **yalnızca** [hasReviewed] doğruyken çalışıyor —
  /// değerlendirilmişliğe karar vermek için değil, bilinen kaydın içeriğini
  /// göstermek için. Aynı kişiyle birden çok iş yapılmışsa
  /// [completedAt]'ten sonra yazılmış en eski kayıt seçiliyor; bulunamazsa
  /// satır içeriksiz kalıyor, yanlış kayıt bağlanmıyor.
  Future<void> loadOwnReview({
    required String assignmentId,
    required String subjectUserId,
    required String authorUserId,
    DateTime? completedAt,
  }) async {
    await _restored;
    if (!hasReviewed(assignmentId) ||
        _ownReviews.containsKey(assignmentId) ||
        !_lookingUp.add(assignmentId)) {
      return;
    }

    try {
      final page = await _service.fetchReviewsAbout(subjectUserId);
      final mine =
          page.reviews
              .where((review) => review.author?.id == authorUserId)
              .where(
                (review) =>
                    completedAt == null ||
                    review.createdAt == null ||
                    !review.createdAt!.isBefore(completedAt),
              )
              .toList()
            ..sort(_byCreatedAtAscending);
      final match = mine.firstOrNull;
      if (match == null) return;

      _ownReviews[assignmentId] = match;
      notifyListeners();
      await _persistDetails();
    } on ApiException {
      // Sessiz: satır "Değerlendirdiniz." olarak kalıyor, bir sonraki açılışta
      // yeniden denenir.
    } finally {
      _lookingUp.remove(assignmentId);
    }
  }

  static int _byCreatedAtAscending(Review a, Review b) {
    final left = a.createdAt;
    final right = b.createdAt;
    if (left == null || right == null) return left == null ? 1 : -1;
    return left.compareTo(right);
  }

  /// Çıkışta önceki kullanıcının kayıtları kalmasın.
  Future<void> clear() async {
    _reviewedAssignmentIds.clear();
    _ownReviews.clear();
    _errorMessage = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_detailsPrefsKey);
  }

  Future<void> _markReviewed(String assignmentId, {Review? review}) async {
    final added = _reviewedAssignmentIds.add(assignmentId);
    if (review != null) _ownReviews[assignmentId] = review;
    if (!added && review == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (added) {
      await prefs.setStringList(_prefsKey, _reviewedAssignmentIds.toList());
    }
    if (review != null) await _persistDetails();
  }

  Future<void> _persistDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _detailsPrefsKey,
      jsonEncode({
        for (final entry in _ownReviews.entries)
          entry.key: entry.value.toJson(),
      }),
    );
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey);
    if (stored == null || stored.isEmpty) return;

    _reviewedAssignmentIds.addAll(stored);
    _ownReviews.addAll(_decodeDetails(prefs.getString(_detailsPrefsKey)));
    notifyListeners();
  }

  /// Bozuk ya da eski biçimli kayıt içerik kaybettirir, kimlikleri değil.
  static Map<String, Review> _decodeDetails(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: Review.fromJson(entry.value as Map<String, dynamic>),
      };
    } on FormatException {
      return const {};
    }
  }
}
