import 'package:flutter/material.dart';
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
    _restore();
  }

  /// Değerlendirilmiş atamaların kimlikleri; cihazda saklanan anahtar.
  static const String _prefsKey = 'reviewed_assignments';

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
      await _service.leaveReview(
        assignmentId: assignmentId,
        rating: rating,
        comment: comment,
        anonymous: anonymous,
      );
      await _markReviewed(assignmentId);
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

  /// Çıkışta önceki kullanıcının kayıtları kalmasın.
  Future<void> clear() async {
    _reviewedAssignmentIds.clear();
    _errorMessage = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> _markReviewed(String assignmentId) async {
    if (!_reviewedAssignmentIds.add(assignmentId)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _reviewedAssignmentIds.toList());
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey);
    if (stored == null || stored.isEmpty) return;

    _reviewedAssignmentIds.addAll(stored);
    notifyListeners();
  }
}
