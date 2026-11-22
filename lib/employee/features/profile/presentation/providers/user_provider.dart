import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Oturum sahibinin profili; profil, ayarlar ve hesap düzenleme aynı kaydı
/// okuyor.
class UserProvider extends ChangeNotifier {
  UserProvider({UserService? userService})
    : _userService = userService ?? UserService();

  final UserService _userService;

  CurrentUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

  /// Sessiz tazelemede [_isLoading] kapalı kaldığı için tekrar ayrı bayrakla
  /// engelleniyor.
  bool _isRequestInFlight = false;

  /// Çıkıştan sonra dönen istekler yeni oturuma yazmasın.
  int _generation = 0;

  /// İlk yükleme bitene kadar `null`.
  CurrentUser? get user => _user;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  bool get hasError => _errorMessage != null;

  /// Süren istek; ikinci çağıran bunu bekler.
  Future<void>? _loading;

  /// Kullanıcıyı çeker. Elde veri varken [silent] göstergeyi açmaz. Süren istek
  /// varken gelen çağrı yeni istek atmaz ama **bekler**: soğuk açılışta push
  /// dokunması boş kullanıcı bulmasın (#170).
  Future<void> load({bool silent = false}) {
    if (_isRequestInFlight) return _loading ?? Future.value();

    late final Future<void> loading;
    loading = _loadNow(silent: silent).whenComplete(() {
      if (identical(_loading, loading)) _loading = null;
    });
    return _loading = loading;
  }

  Future<void> _loadNow({required bool silent}) async {
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

  /// Profili günceller. Başarıda doğrulama bekleyen alanlar döner (boş değilse
  /// e-posta/telefon henüz yazılmadı); hatada `null`.
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

  Future<bool> uploadProfilePicture(String filePath) {
    return _mutateAndReloadCurrentUser(
      () => _userService.uploadProfilePicture(filePath),
    );
  }

  Future<bool> uploadCv(String filePath) {
    return _mutateAndReloadCurrentUser(() async {
      await _userService.uploadCv(filePath);
    });
  }

  Future<bool> deleteCv() {
    return _mutateAndReloadCurrentUser(_userService.deleteCv);
  }

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

  void clear() {
    _generation++;
    _user = null;
    _isRequestInFlight = false;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
