import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/business/features/home/models/employer_stats.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/product/constants/upload_limits.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/network/api_exception.dart';

/// İşverenin şirketi ve özet sayıları; profil, ayarlar ve firma bilgileri aynı
/// kaydı okuyor. Kimlikleri çağıran veriyor ki provider'lar birbirine
/// bağlanmasın.
class BCompanyProvider extends ChangeNotifier {
  BCompanyProvider({BCompanyService? service, CompanyService? companyService})
    : _service = service ?? BCompanyService(),
      _companyService = companyService ?? CompanyService();

  final BCompanyService _service;

  final CompanyService _companyService;

  Company? _company;
  EmployerStats? _stats;

  bool _isLoading = false;
  String? _errorMessage;
  String? _statsErrorMessage;

  /// Oturum değişince eldeki veri geçersiz olsun.
  String? _loadedKey;

  /// Çıkıştan sonra dönen istekler yeni oturuma yazmasın.
  int _generation = 0;

  /// Bireysel işverende `null`; hata değil.
  Company? get company => _company;

  EmployerStats? get stats => _stats;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  /// Ayrı tutuluyor: sayıların gelmemesi profili gizlememeli.
  String? get statsErrorMessage => _statsErrorMessage;

  bool get hasLoaded => _loadedKey != null;

  /// [companyId] `null` ise yalnız istatistikler. [isApproved] `/users/me`'den,
  /// çünkü `CompanyDto` onay bilgisini döndürmüyor.
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

    // Paralel: biri düşerse öteki yine gelir.
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

  Future<void> loadFor(CurrentUser user, {bool force = false}) {
    final membership = user.primaryCompany;

    return load(
      userId: user.id,
      companyId: membership?.companyId,
      isApproved: membership?.approved ?? false,
      force: force,
    );
  }

  /// Firma bilgilerini günceller (adres [updateAddress] ile ayrı).
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

  /// Şirket adresini değiştirir. `bool` değil `ApiException` fırlatır: harita
  /// ekranı açık kalıp mesajı gösterir ve kullanıcı yeniden dener.
  Future<void> updateAddress(ConfirmedAddress address) async {
    final current = _company;
    if (current == null) {
      throw StateError('Şirket yüklenmeden adres güncellenemez');
    }

    final generation = _generation;
    final updated = await _service.updateCompany(
      current.id,
      address: address.toWrite(),
    );
    if (generation != _generation || _company?.id != current.id) return;

    _company = updated.copyWith(
      isApproved: updated.isApproved || current.isApproved,
    );
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> updateLogo(String filePath) {
    final current = _company;
    if (current == null) return Future.value(false);

    return _replaceCompany(() => _service.updateLogo(current.id, filePath));
  }

  Future<bool> removeLogo() {
    final current = _company;
    if (current == null) return Future.value(false);

    return _replaceCompany(() => _service.removeLogo(current.id));
  }

  // ----------------------------------------------------------------- Galeri

  /// Galeri şirketin içinde duruyor; iki kopya tutmak ayrışmaya kapı açardı.
  List<GalleryImage> get galleryImages => _company?.images ?? const [];

  /// Sınırda düğme kapanır, kullanıcı `409` almasın.
  bool get canAddGalleryImage =>
      _company != null && galleryImages.length < UploadLimits.maxGalleryImages;

  bool get isGalleryBusy => _isGalleryBusy;

  /// Şirketin hatasından ayrı: yükleme düştü diye ekran boşalmamalı.
  String? get galleryErrorMessage => _galleryErrorMessage;

  bool _isGalleryBusy = false;
  String? _galleryErrorMessage;

  /// Uzantı ve boyut denetimi çağıranda.
  Future<bool> addGalleryImage(String filePath) {
    return _replaceGallery(
      (companyId) => _service.addCompanyImage(companyId, filePath),
    );
  }

  /// [images] galerinin **tamamı** olmalı.
  Future<bool> replaceGallery(List<GalleryImage> images) {
    return _replaceGallery(
      (companyId) => _service.replaceCompanyGallery(companyId, images),
    );
  }

  Future<bool> removeGalleryImage(String imageId) {
    return _replaceGallery(
      (companyId) => _service.removeCompanyImage(companyId, imageId),
    );
  }

  /// Yanıt `List<GalleryImageDto>` olduğu için yalnız galeri değişiyor.
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

  /// Onay bilgisi yanıtlarda gelmeyebiliyor; eldeki korunur.
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
