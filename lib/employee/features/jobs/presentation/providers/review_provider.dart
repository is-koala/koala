import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının bıraktığı değerlendirmeler.
///
/// Sunucuda "bu işi değerlendirdim mi" diye sorulacak bir uç yok: ikinci
/// değerlendirme `409` ile reddediliyor, o kadar. "Değerlendir" butonunun
/// yerinde "Değerlendirildi" rozetini gösterebilmek için değerlendirilen
/// atamaların kimlikleri cihazda tutuluyor.
///
/// Bu bir önbellek, kaynak değil: kayıt kaybolursa (uygulama silinip
/// kurulursa, kullanıcı başka cihaza geçerse) buton geri gelir, basıldığında
/// sunucu `409` döndürür ve kayıt oradan tazelenir. Yani yanlış tarafa
/// düşse bile akış tıkanmıyor.
class ReviewProvider extends ChangeNotifier {
  ReviewProvider({ReviewService? service})
    : _service = service ?? ReviewService() {
    _restore();
  }

  /// Değerlendirilmiş atamaların kimlikleri; cihazda saklanan anahtar.
  static const String _prefsKey = 'reviewed_assignments';

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
  /// `409` iki anlama geliyor: iş henüz tamamlanmamış ya da bu iş zaten
  /// değerlendirilmiş. İkincisinde sonuç kullanıcı açısından "yazıldı"
  /// demek, o yüzden atama yine işaretleniyor — buton bir daha çıkmıyor.
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
      // Yalnızca `dataConflict`: "bu atama zaten değerlendirilmiş" sunucudan
      // `ConflictException` ile geliyor. `businessRule` bir iş kuralı ihlali
      // (ör. sunucunun kendi tutarsızlığı) demek; onu da "değerlendirildi"
      // sayarsak kullanıcı bir daha hiç değerlendiremez.
      if (error.type == ApiErrorType.dataConflict) {
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
