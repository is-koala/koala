import 'package:flutter/material.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/business/features/home/models/employer_stats.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/product/network/api_exception.dart';

/// İşverenin profil verisi: şirketi ve özet sayıları.
///
/// Sayfada değil burada duruyor çünkü aynı kaydı üç ekran okuyor — profil,
/// ayarlar ve firma bilgileri. Firma bilgileri kaydedip geri döndüğünde
/// profil başlığı kendiliğinden tazeleniyor.
///
/// Kimin yükleneceğini provider bilmiyor: kullanıcı kimliği ve şirket
/// kimliği `/users/me`'den geliyor ve çağıran taraf veriyor. İki provider'ı
/// birbirine bağlamamak için bilerek böyle.
class BCompanyProvider extends ChangeNotifier {
  BCompanyProvider({BCompanyService? service, CompanyService? companyService})
    : _service = service ?? BCompanyService(),
      _companyService = companyService ?? CompanyService();

  final BCompanyService _service;

  /// Şirketi okumak iki uygulamada da aynı uç; okuma oradan geliyor.
  final CompanyService _companyService;

  Company? _company;
  EmployerStats? _stats;

  bool _isLoading = false;
  String? _errorMessage;
  String? _statsErrorMessage;

  /// En son hangi kullanıcı/şirket çifti için yüklendiği. Oturum değişince
  /// eldeki veri geçersiz olsun diye.
  String? _loadedKey;

  /// Şirket. İşveren bireyselse (şirket üyeliği yoksa) `null` — bu bir hata
  /// değil, profilin kişi olarak çizileceği anlamına geliyor.
  Company? get company => _company;

  EmployerStats? get stats => _stats;

  bool get isLoading => _isLoading;

  /// Şirket çekilemediğinde dolan mesaj; profil bu durumda çizilemiyor.
  String? get errorMessage => _errorMessage;

  /// İstatistikler çekilemediğinde dolan mesaj. Ayrı tutuluyor: sayıların
  /// gelmemesi profilin geri kalanını gizlememeli.
  String? get statsErrorMessage => _statsErrorMessage;

  bool get hasLoaded => _loadedKey != null;

  /// Şirketi ve istatistikleri çeker.
  ///
  /// [companyId] `null` ise yalnızca istatistikler isteniyor. [isApproved]
  /// `/users/me`'deki üyelik kaydından geliyor: `CompanyDto` onay bilgisini
  /// döndürmüyor.
  Future<void> load({
    required String userId,
    String? companyId,
    bool isApproved = false,
    bool force = false,
  }) async {
    final key = '$userId|$companyId';
    if (_isLoading) return;
    if (!force && _loadedKey == key && _errorMessage == null) return;

    _isLoading = true;
    _errorMessage = null;
    _statsErrorMessage = null;
    notifyListeners();

    // İki istek paralel: biri diğerini beklemiyor ve biri düşerse öteki
    // yine de ekrana geliyor.
    await Future.wait([
      _loadCompany(companyId, isApproved: isApproved),
      _loadStats(userId),
    ]);

    _isLoading = false;
    _loadedKey = key;
    notifyListeners();
  }

  Future<void> _loadCompany(
    String? companyId, {
    required bool isApproved,
  }) async {
    if (companyId == null) {
      _company = null;
      return;
    }

    try {
      final company = await _companyService.fetchCompany(companyId);
      _company = company.copyWith(isApproved: isApproved);
    } on ApiException catch (error) {
      _company = null;
      _errorMessage = error.message;
    }
  }

  Future<void> _loadStats(String userId) async {
    try {
      _stats = await _service.fetchEmployerStats(userId);
    } on ApiException catch (error) {
      _stats = null;
      _statsErrorMessage = error.message;
    }
  }

  /// [load]'u `/users/me` yanıtındaki kimliklerle çağırır.
  ///
  /// Şirket kimliği ve onay durumu orada duruyor; her ekranın bunu tek tek
  /// çıkarması yerine tek yerde.
  Future<void> loadFor(CurrentUser user, {bool force = false}) {
    final membership = user.primaryCompany;

    return load(
      userId: user.id,
      companyId: membership?.companyId,
      isApproved: membership?.approved ?? false,
      force: force,
    );
  }

  /// Firma bilgilerini günceller.
  ///
  /// Sunucu yalnızca beş alanı kabul ediyor; vergi numarası, adres ve logo
  /// buradan değiştirilemiyor. Başarılıysa eldeki kayıt yanıttakiyle
  /// değişiyor ve `true` dönüyor.
  Future<bool> updateCompany({
    String? name,
    String? email,
    String? phoneNumber,
    String? website,
    String? description,
  }) async {
    final current = _company;
    if (current == null) return false;

    return _replaceCompany(
      () => _service.updateCompany(
        current.id,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        website: website,
        description: description,
      ),
    );
  }

  /// Şirketin logosunu değiştirir.
  ///
  /// [filePath] cihazdaki görselin yolu. Başarılıysa eldeki kayıt yanıttakiyle
  /// değişiyor ve profil başlığı kendiliğinden tazeleniyor.
  Future<bool> updateLogo(String filePath) {
    final current = _company;
    if (current == null) return Future.value(false);

    return _replaceCompany(() => _service.updateLogo(current.id, filePath));
  }

  /// Şirketin logosunu kaldırır.
  Future<bool> removeLogo() {
    final current = _company;
    if (current == null) return Future.value(false);

    return _replaceCompany(() => _service.removeLogo(current.id));
  }

  /// Şirketin yeni hâlini döndüren isteklerin ortak sarmalayıcısı.
  ///
  /// Onay bilgisi yanıtlarda gelmeyebiliyor, eldeki değer korunuyor.
  Future<bool> _replaceCompany(Future<Company> Function() call) async {
    final current = _company;
    if (current == null) return false;

    _errorMessage = null;

    try {
      final updated = await call();
      _company = updated.copyWith(
        isApproved: updated.isApproved || current.isApproved,
      );
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }
  }

  /// Çıkışta önceki işverenin şirketi kalmasın.
  void clear() {
    _company = null;
    _stats = null;
    _errorMessage = null;
    _statsErrorMessage = null;
    _loadedKey = null;
    notifyListeners();
  }
}
