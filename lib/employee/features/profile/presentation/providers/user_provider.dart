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

  /// Çıkıştan sonra tamamlanan isteklerin yeni oturuma yazmasını engeller.
  int _generation = 0;

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
    final generation = _generation;
    _isRequestInFlight = true;

    _isLoading = !silent || _user == null;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _userService.fetchCurrentUser();
      if (generation != _generation) return;
      _user = user;
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = error.message;
    } finally {
      if (generation == _generation) {
        _isRequestInFlight = false;
        _isLoading = false;
        notifyListeners();
      }
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
    String? iban,
  }) async {
    final generation = _generation;
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
        iban: iban,
      );

      if (generation != _generation) return null;
      _user = result.user;
      return result.pendingVerifications;
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = error.message;
      return null;
    } finally {
      if (generation == _generation) {
        _isRequestInFlight = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Profil fotoğrafını yükleyip `/users/me` yanıtını yeniler.
  Future<bool> uploadProfilePicture(String filePath) {
    return _mutateAndReloadCurrentUser(
      () => _userService.uploadProfilePicture(filePath),
    );
  }

  /// Özgeçmişi yükleyip profil kartındaki durumu tazeler.
  Future<bool> uploadCv(String filePath) {
    return _mutateAndReloadCurrentUser(() async {
      await _userService.uploadCv(filePath);
    });
  }

  Future<bool> deleteCv() {
    return _mutateAndReloadCurrentUser(_userService.deleteCv);
  }

  /// Profili etkileyen dosya işlemini yapıp güncel kullanıcıyı yeniden okur.
  Future<bool> _mutateAndReloadCurrentUser(
    Future<void> Function() action,
  ) async {
    final generation = _generation;
    _isRequestInFlight = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      if (generation != _generation) return false;
      final user = await _userService.fetchCurrentUser();
      if (generation != _generation) return false;
      _user = user;
      return true;
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = error.message;
      return false;
    } finally {
      if (generation == _generation) {
        _isRequestInFlight = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Çıkış yapıldığında eldeki kullanıcıyı düşürür; bir sonraki oturum
  /// öncekinin profilini görmesin.
  void clear() {
    _generation++;
    _user = null;
    _isRequestInFlight = false;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
