import 'package:flutter/material.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/business/features/home/models/employer_stats.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/product/constants/upload_limits.dart';
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

  /// Çıkıştan sonra tamamlanan isteklerin yeni oturuma yazmasını engeller.
  int _generation = 0;

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

    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    _statsErrorMessage = null;
    notifyListeners();

    // İki istek paralel: biri diğerini beklemiyor ve biri düşerse öteki
    // yine de ekrana geliyor.
    await Future.wait([
      _loadCompany(companyId, isApproved: isApproved, generation: generation),
      _loadStats(userId, generation: generation),
    ]);

    if (generation != _generation) return;
    _isLoading = false;
    _loadedKey = key;
    notifyListeners();
  }

  Future<void> _loadCompany(
    String? companyId, {
    required bool isApproved,
    required int generation,
  }) async {
    if (companyId == null) {
      if (generation == _generation) _company = null;
      return;
    }

    try {
      final company = await _companyService.fetchCompany(companyId);
      if (generation != _generation) return;
      _company = company.copyWith(isApproved: isApproved);
    } on ApiException catch (error) {
      if (generation == _generation) {
        _company = null;
        _errorMessage = error.message;
      }
    }
  }

  Future<void> _loadStats(String userId, {required int generation}) async {
    try {
      final stats = await _service.fetchEmployerStats(userId);
      if (generation != _generation) return;
      _stats = stats;
    } on ApiException catch (error) {
      if (generation == _generation) {
        _stats = null;
        _statsErrorMessage = error.message;
      }
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

  // ----------------------------------------------------------------- Galeri

  /// Şirketin galerisi.
  ///
  /// Ayrı bir alanda değil şirketin içinde duruyor: `GET /companies/{id}`
  /// görselleri zaten gövdesinde döndürüyor ve iki kopya tutmak şirket
  /// detayındaki galeri ile buradakinin ayrışmasına açık kapı bırakırdı.
  List<GalleryImage> get galleryImages => _company?.images ?? const [];

  /// Galeriye görsel eklenebilir mi. Sunucu sınırı aştığında `409` döndürüyor;
  /// düğmenin kapalı olması kullanıcıyı o hatayı almadan durduruyor.
  bool get canAddGalleryImage =>
      _company != null && galleryImages.length < UploadLimits.maxGalleryImages;

  /// Galeri işlemi sürerken; düğmeler kapansın ve istek iki kez atılmasın.
  bool get isGalleryBusy => _isGalleryBusy;

  /// Galeri isteği düştüğünde dolan mesaj. Şirketin kendi hatasından ayrı:
  /// yükleme başarısız diye şirket bilgileri ekranı boşalmamalı.
  String? get galleryErrorMessage => _galleryErrorMessage;

  bool _isGalleryBusy = false;
  String? _galleryErrorMessage;

  /// Galeriye bir görsel ekler.
  ///
  /// [filePath] cihazdaki görselin yolu. Uzantı ve boyut denetimi çağıran
  /// ekranda; burada yalnız istek var.
  Future<bool> addGalleryImage(String filePath) {
    return _replaceGallery(
      (companyId) => _service.addCompanyImage(companyId, filePath),
    );
  }

  /// Sıralamayı ve kapak seçimini tek istekte kaydeder.
  ///
  /// [images] galerinin **tamamı** olmalı: sunucu listede olmayan görseli
  /// galeriden düşürüyor.
  Future<bool> replaceGallery(List<GalleryImage> images) {
    return _replaceGallery(
      (companyId) => _service.replaceCompanyGallery(companyId, images),
    );
  }

  /// Görseli galeriden çıkarır. Kapak silinirse sunucu kalanların ilkini
  /// kapak yapıyor; ekran dönen listeyi olduğu gibi gösteriyor.
  Future<bool> removeGalleryImage(String imageId) {
    return _replaceGallery(
      (companyId) => _service.removeCompanyImage(companyId, imageId),
    );
  }

  /// Galerinin yeni hâlini döndüren üç isteğin ortak sarmalayıcısı.
  ///
  /// Yanıt `Company` değil `List<GalleryImageDto>` olduğu için
  /// [_replaceCompany] kullanılamıyor: eldeki şirketin yalnızca galerisi
  /// değişiyor.
  Future<bool> _replaceGallery(
    Future<List<GalleryImage>> Function(String companyId) call,
  ) async {
    final current = _company;
    if (current == null || _isGalleryBusy) return false;

    final generation = _generation;
    _isGalleryBusy = true;
    _galleryErrorMessage = null;
    notifyListeners();

    try {
      final images = await call(current.id);
      if (generation != _generation || _company?.id != current.id) {
        return false;
      }
      _company = current.copyWith(images: images);
      return true;
    } on ApiException catch (error) {
      if (generation == _generation && _company?.id == current.id) {
        _galleryErrorMessage = error.message;
      }
      return false;
    } finally {
      if (generation == _generation) {
        _isGalleryBusy = false;
        notifyListeners();
      }
    }
  }

  /// Şirketin yeni hâlini döndüren isteklerin ortak sarmalayıcısı.
  ///
  /// Onay bilgisi yanıtlarda gelmeyebiliyor, eldeki değer korunuyor.
  Future<bool> _replaceCompany(Future<Company> Function() call) async {
    final current = _company;
    if (current == null) return false;

    final generation = _generation;
    _errorMessage = null;

    try {
      final updated = await call();
      if (generation != _generation || _company?.id != current.id) {
        return false;
      }
      _company = updated.copyWith(
        isApproved: updated.isApproved || current.isApproved,
      );
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (generation == _generation && _company?.id == current.id) {
        _errorMessage = error.message;
        notifyListeners();
      }
      return false;
    }
  }

  /// Çıkışta önceki işverenin şirketi kalmasın.
  void clear() {
    _generation++;
    _company = null;
    _stats = null;
    _isLoading = false;
    _isGalleryBusy = false;
    _errorMessage = null;
    _statsErrorMessage = null;
    _galleryErrorMessage = null;
    _loadedKey = null;
    notifyListeners();
  }
}
