import 'package:flutter/material.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Oturum açmış kullanıcının profil verisi.
///
/// Profil, ayarlar ve hesap düzenleme ekranları aynı kaydı gösterdiği için
/// veri sayfada değil burada tutuluyor: düzenleme ekranından dönüldüğünde
/// profil başlığı da kendiliğinden tazeleniyor.
class UserProvider extends ChangeNotifier {
  UserProvider({UserService? userService})
    : _userService = userService ?? UserService();

  final UserService _userService;

  CurrentUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

  /// Ağda bekleyen bir istek var mı. [_isLoading] yalnızca arayüzün
  /// göstergeyi çizip çizmeyeceğini söylüyor; sessiz tazelemede o kapalı
  /// kaldığı için tekrarı ayrı bir bayrakla engellemek gerekiyor.
  bool _isRequestInFlight = false;

  /// Güncel kullanıcı. İlk yükleme bitene kadar `null`.
  CurrentUser? get user => _user;

  bool get isLoading => _isLoading;

  /// Son isteğin hata mesajı; başarılıysa `null`.
  String? get errorMessage => _errorMessage;

  /// Elde gösterilecek veri yokken hata varsa ekran boş değil hatalı çizilmeli.
  bool get hasError => _errorMessage != null;

  /// Kullanıcıyı sunucudan çeker.
  ///
  /// Elde veri varken tekrar çağrıldığında yükleme göstergesi açılmıyor
  /// ([silent]): sayfaya her dönüşte iskelet ekranın yanıp sönmesi, tazeleme
  /// için ödenecek makul bir bedel değil.
  Future<void> load({bool silent = false}) async {
    if (_isRequestInFlight) return;
    _isRequestInFlight = true;

    _isLoading = !silent || _user == null;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _userService.fetchCurrentUser();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isRequestInFlight = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Profil alanlarını günceller ve eldeki kullanıcıyı yanıttakiyle değiştirir.
  ///
  /// Başarılıysa doğrulama bekleyen alanların listesi dönüyor; boş değilse
  /// e-posta ya da telefon değişikliği henüz yazılmamış demektir. Hata
  /// durumunda `null` dönüp mesajı [errorMessage]'a koyuyor.
  Future<List<PendingVerification>?> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? email,
    DateTime? birthDate,
    Gender? gender,
    String? jobTitle,
    String? about,
    String? qualifications,
    String? interests,
  }) async {
    _isRequestInFlight = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _userService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        email: email,
        birthDate: birthDate,
        gender: gender,
        jobTitle: jobTitle,
        about: about,
        qualifications: qualifications,
        interests: interests,
      );

      _user = result.user;
      return result.pendingVerifications;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } finally {
      _isRequestInFlight = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Çıkış yapıldığında eldeki kullanıcıyı düşürür; bir sonraki oturum
  /// öncekinin profilini görmesin.
  void clear() {
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }
}
