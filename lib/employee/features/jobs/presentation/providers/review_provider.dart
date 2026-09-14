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
/// disk yazılıyor ve onu silen tek şey çıkış.
///
/// **Kayıt kullanıcıya bağlı.** Anahtarlar oturum sahibinin kimliğiyle
/// ekleniyor (`reviewed_assignments:<userId>`); aynı cihazda başka bir hesap
/// açılınca — örneğin aynı atamanın öbür tarafı — öncekinin işareti ve yorumu
/// görünmüyor, çıkışta `clear` unutulsa bile. Kimlik [userIdOf] ile dışarıdan
/// geliyor; kim olduğu bilinmiyorsa hiçbir şey işaretli sayılmıyor.
class ReviewProvider extends ChangeNotifier {
  ReviewProvider({required String? Function() userIdOf, ReviewService? service})
    : _userIdOf = userIdOf,
      _service = service ?? ReviewService();

  /// Değerlendirilmiş atamaların kimlikleri; kullanıcı kimliğiyle eklenir.
  static const String _idsPrefsPrefix = 'reviewed_assignments';

  /// Kendi yazdığımız değerlendirmelerin içeriği (atama kimliği →
  /// [Review.toJson]); "Değerlendirdiniz: ★4 · yorum" satırı buradan
  /// çiziliyor. Kimlik listesinden ayrı, çünkü içerik olmadan da kimlik
  /// işaretli olabilir (409'dan öğrenilen, başka cihazda yazılmış kayıt).
  static const String _detailsPrefsPrefix = 'reviewed_assignment_details';

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

  final String? Function() _userIdOf;
  final ReviewService _service;

  /// Bellekteki kayıtların ait olduğu kullanıcı; `null` ise henüz kimsenin
  /// kaydı yüklenmedi.
  String? _loadedUserId;
  Future<void>? _loading;
  String? _loadingUserId;

  final Set<String> _reviewedAssignmentIds = {};

  /// Kendi gönderdiğimiz kayıtların içeriği; diske yazılıyor.
  final Map<String, Review> _ownReviews = {};

  /// Sunucudan bulunan **tahmini** kayıtlar; yalnızca bellekte, oturumluk.
  /// Sunucu "hangi atamaya" demediği için tahmin yanlış çıkabilir; yanlışı
  /// kalıcı yapmamak için diske hiç yazılmıyor.
  final Map<String, Review> _serverReviews = {};

  /// Sunucudan kendi kaydını arayan istekler; aynı atama için ikinci kez
  /// gidilmesin.
  final Set<String> _lookingUp = {};

  bool _isSubmitting = false;
  String? _errorMessage;

  /// Değerlendirilmiş atamaların kimlikleri.
  Set<String> get reviewedAssignmentIds => Set.unmodifiable(
    _isCurrentUserLoaded ? _reviewedAssignmentIds : const {},
  );

  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

  bool get _isCurrentUserLoaded {
    final userId = _userIdOf();
    return userId != null && userId == _loadedUserId;
  }

  /// Bu atama değerlendirilmiş mi.
  ///
  /// Kayıt oturum sahibine göre tembel yükleniyor: kimlik değiştiyse önce
  /// `false` dönüp yüklemeyi başlatıyor, bitince dinleyenleri uyarıyor.
  bool hasReviewed(String? assignmentId) {
    final userId = _userIdOf();
    if (assignmentId == null || userId == null) return false;
    if (userId != _loadedUserId) {
      _ensureLoaded(userId);
      return false;
    }
    return _reviewedAssignmentIds.contains(assignmentId);
  }

  /// Bu atamaya kendi yazdığımız değerlendirme; içeriği bilinmiyorsa `null`.
  ///
  /// `null`, "değerlendirilmedi" demek değil — [hasReviewed] ona bakar. Kayıt
  /// bu cihazda yazıldıysa içerik yanıttan geliyor; başka cihazda yazıldıysa
  /// [loadOwnReview] sunucudan tamamlamayı dener.
  Review? ownReviewFor(String? assignmentId) {
    if (assignmentId == null || !hasReviewed(assignmentId)) return null;
    return _ownReviews[assignmentId] ?? _serverReviews[assignmentId];
  }

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
  /// göstermek için. [completedAt] biliniyorsa ondan önce yazılmış kayıtlar
  /// eleniyor. Geriye **tam bir** aday kalırsa gösteriliyor; aynı kişiyle
  /// birden çok iş yapılmışsa (iki ve daha çok aday) eşleştirme yapılmıyor,
  /// satır içeriksiz "Değerlendirdiniz" olarak kalıyor. Bulunan kayıt yalnız
  /// bellekte tutuluyor; tahmin diske yazılmıyor.
  Future<void> loadOwnReview({
    required String assignmentId,
    required String subjectUserId,
    required String authorUserId,
    DateTime? completedAt,
  }) async {
    final userId = _userIdOf();
    if (userId == null) return;
    await _ensureLoaded(userId);
    if (!hasReviewed(assignmentId) ||
        _ownReviews.containsKey(assignmentId) ||
        _serverReviews.containsKey(assignmentId) ||
        !_lookingUp.add(assignmentId)) {
      return;
    }

    try {
      final page = await _service.fetchReviewsAbout(subjectUserId);
      final candidates = page.reviews
          .where((review) => review.author?.id == authorUserId)
          .where(
            (review) =>
                completedAt == null ||
                review.createdAt == null ||
                !review.createdAt!.isBefore(completedAt),
          )
          .toList();
      if (candidates.length != 1 || _loadedUserId != userId) return;

      _serverReviews[assignmentId] = candidates.single;
      notifyListeners();
    } on ApiException {
      // Sessiz: satır "Değerlendirdiniz." olarak kalıyor, bir sonraki açılışta
      // yeniden denenir.
    } finally {
      _lookingUp.remove(assignmentId);
    }
  }

  /// Çıkışta önceki kullanıcının kayıtları kalmasın.
  ///
  /// Diskte yalnızca yüklü kullanıcının anahtarları siliniyor; başkasının
  /// kaydına zaten kimlik olmadan ulaşılamıyor. Eski sürümün kimliksiz
  /// anahtarları da burada temizleniyor.
  Future<void> clear() async {
    final userId = _loadedUserId;
    _reset();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idsPrefsPrefix);
    await prefs.remove(_detailsPrefsPrefix);
    if (userId != null) {
      await prefs.remove(_idsKey(userId));
      await prefs.remove(_detailsKey(userId));
    }
  }

  void _reset() {
    _loadedUserId = null;
    _loading = null;
    _loadingUserId = null;
    _reviewedAssignmentIds.clear();
    _ownReviews.clear();
    _serverReviews.clear();
    _lookingUp.clear();
    _errorMessage = null;
  }

  static String _idsKey(String userId) => '$_idsPrefsPrefix:$userId';

  static String _detailsKey(String userId) => '$_detailsPrefsPrefix:$userId';

  Future<void> _markReviewed(String assignmentId, {Review? review}) async {
    final userId = _userIdOf();
    // Kim olduğu bilinmiyorsa diske yazılacak bir anahtar da yok; sunucu
    // kaydı tuttu, rozet bir sonraki denemede 409'dan gelir.
    if (userId == null) return;
    await _ensureLoaded(userId);
    if (_loadedUserId != userId) return;

    final added = _reviewedAssignmentIds.add(assignmentId);
    if (review != null) _ownReviews[assignmentId] = review;
    if (!added && review == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (added) {
      await prefs.setStringList(
        _idsKey(userId),
        _reviewedAssignmentIds.toList(),
      );
    }
    if (review != null) {
      await prefs.setString(
        _detailsKey(userId),
        jsonEncode({
          for (final entry in _ownReviews.entries)
            entry.key: entry.value.toJson(),
        }),
      );
    }
  }

  /// [userId]'nin kaydını belleğe alır; başka bir kullanıcının kaydı
  /// bellekteyse önce onu bırakır. Aynı kullanıcı için tek yükleme koşar.
  Future<void> _ensureLoaded(String userId) {
    if (_loadedUserId == userId) return Future.value();
    final inFlight = _loading;
    if (inFlight != null && _loadingUserId == userId) return inFlight;

    _loadingUserId = userId;
    // Disk okunamazsa (platform kanalı yok) kayıtsız başlanıyor; bekleyen
    // çağrılar hata yerine boş önbellekle devam ediyor.
    final future = _restore(userId).catchError((Object _) {
      if (_loadingUserId == userId) {
        _loading = null;
        _loadingUserId = null;
      }
    });
    _loading = future;
    return future;
  }

  Future<void> _restore(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    // Bu arada kimlik yeniden değiştiyse okunan kayıt artık başkasının.
    if (_loadingUserId != userId) return;

    _reviewedAssignmentIds
      ..clear()
      ..addAll(prefs.getStringList(_idsKey(userId)) ?? const []);
    _ownReviews
      ..clear()
      ..addAll(_decodeDetails(prefs.getString(_detailsKey(userId))));
    _serverReviews.clear();
    _loadedUserId = userId;
    _loading = null;
    _loadingUserId = null;
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
