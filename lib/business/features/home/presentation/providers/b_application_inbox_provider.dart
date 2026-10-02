import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/received_application.dart';
import 'package:koala/business/features/home/services/received_application_service.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_exception.dart';

/// İşverenin ilanlar arası başvuru gelen kutusu: liste, süzgeç ve sayfalama.
///
/// **Sayfaya ait, uygulama boyunca yaşamıyor.** `BApplicationsPage` kendi
/// örneğini kuruyor ve kapanınca atıyor; `main.dart`'ta kayıtlı değil ve
/// çıkışta temizlenecek bir şey bırakmıyor. Gelen kutusu başvuranların adını
/// ve fotoğrafını taşıyor: uygulama boyunca yaşayan bir provider çıkış
/// yolunda bir temizleme çağrısına bağımlı olurdu, oturum süresi dolunca
/// (`SessionManager.end`) o çağrı hiç çalışmıyor.
///
/// Süzgeç değişince eski süzgecin satırları **hemen** düşüyor: yeni çipin
/// altında eski satırları göstermek yanlış kümeyi doğru gibi çizerdi. Çekip
/// yenilemede ise satırlar kalıyor ([refresh]).
class BApplicationInboxProvider extends ChangeNotifier {
  BApplicationInboxProvider({ReceivedApplicationService? service})
    : _service = service ?? ReceivedApplicationService();

  /// Bir "sayfa" kaç satır. Yenileme birkaç sayfayı tek istekte aldığında
  /// sonraki sayfa numarası bu boyuta göre hesaplanıyor; `size` değişirse
  /// `page * size` kayar.
  static const int pageSize = ReceivedApplicationService.defaultPageSize;

  /// Tek yenilemenin en fazla kaç sayfa derinliğinde olacağı; sunucunun sayfa
  /// boyutu üst sınırı (100) buna denk düşüyor.
  static const int maxRefreshPages =
      ReceivedApplicationService.maxPageSize ~/ pageSize;

  final ReceivedApplicationService _service;

  final List<ReceivedApplication> _items = [];

  ApplicationStatus? _status;
  String? _companyId;
  String? _jobId;

  /// Seçili ilanın başlığı; çipte yazıyor. Seçim anında biliniyor, sonuç boş
  /// dönse de çip adını koruyor.
  String? _jobTitle;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  bool _isLast = true;
  int _nextPage = 0;
  String? _errorMessage;
  String? _loadMoreError;

  /// Her baştan yükleme (ilk açılış, süzgeç, yenileme) bir numara alıyor;
  /// uçuştaki eski bir yanıt kendi numarası artık geçerli değilse atılıyor.
  /// Aksi hâlde süzgeç değişirken dönen eski sayfa yeni listeyi ezerdi.
  int _generation = 0;

  List<ReceivedApplication> get items => List.unmodifiable(_items);

  /// Süzgeçsiz tek durum olan `null` "tümü" demek.
  ApplicationStatus? get status => _status;

  String? get companyId => _companyId;

  String? get jobId => _jobId;

  String? get jobTitle => _jobTitle;

  /// Herhangi bir süzgeç açık mı; boş durum metni buna göre değişiyor.
  bool get isFiltered =>
      _status != null || _companyId != null || _jobId != null;

  /// Baştan yükleme sürüyor (yenileme hariç): liste henüz çizilemez.
  bool get isLoading => _isLoading;

  bool get isRefreshing => _isRefreshing;

  bool get isLoadingMore => _isLoadingMore;

  /// İlk istek bir kez sonuçlandı mı. Hata da olsa `true`.
  bool get hasLoaded => _hasLoaded;

  bool get hasMore => !_isLast;

  /// Son baştan yüklemenin hata mesajı; satır varken de dolu kalabilir
  /// (başarısız yenileme), ekranın tam hata durumuna geçip geçmeyeceğini
  /// satırların boşluğu belirliyor.
  String? get errorMessage => _errorMessage;

  /// Sonraki sayfanın hatası. Doluyken kaydırma kendiliğinden yeni istek
  /// atmıyor; liste sonundaki "Tekrar Dene" [retryLoadMore] çağırıyor.
  String? get loadMoreError => _loadMoreError;

  /// Süzgeci koruyarak ilk sayfayı yükler; satırlar düşer.
  Future<void> load() => _loadFirstPage(keepItems: false);

  /// Çekip yenileme: satırlar yenisi gelene kadar yerinde kalıyor. Başarılıysa
  /// `true`; başarısızsa eski satırlar korunur ve sebep [errorMessage]'da.
  ///
  /// Yenileme **eldeki derinliği** koruyor: üç sayfa yüklüydüyse tek istekle
  /// ilk 60 satır geliyor ([maxRefreshPages] ile sınırlı; sunucu sayfa
  /// boyutunu 100'e kadar kabul ediyor). Karar ekranından dönünce liste ilk
  /// sayfaya çökmesin diye.
  Future<bool> refresh() async {
    await _loadFirstPage(keepItems: true);
    return _errorMessage == null;
  }

  /// Bütün süzgeçleri kaldırıp baştan yükler; süzgeçli boş durumun çıkışı.
  Future<void> clearFilters() {
    if (!isFiltered) return Future.value();
    _status = null;
    _companyId = null;
    _jobId = null;
    _jobTitle = null;
    return load();
  }

  Future<void> setStatus(ApplicationStatus? value) {
    assert(
      value != ApplicationStatus.unknown,
      'Sunucu bilinmeyen durumu 400 ile reddeder',
    );
    if (value == _status) return Future.value();
    _status = value;
    return load();
  }

  Future<void> setCompany(String? value) {
    if (value == _companyId) return Future.value();
    _companyId = value;
    return load();
  }

  /// Listeyi tek bir ilana süzer; [title] çipte yazar.
  Future<void> setJob(String id, String title) {
    if (id == _jobId) return Future.value();
    _jobId = id;
    _jobTitle = title;
    return load();
  }

  Future<void> clearJob() {
    if (_jobId == null) return Future.value();
    _jobId = null;
    _jobTitle = null;
    return load();
  }

  Future<void> _loadFirstPage({required bool keepItems}) async {
    final generation = ++_generation;
    // Uçuştaki sonraki-sayfa isteği artık eskimiş sayılıyor; bayrağı onun
    // `finally`'sine bırakmak yeni yüklemenin kilidini sonsuza dek tutardı.
    _isLoadingMore = false;
    _loadMoreError = null;
    _errorMessage = null;
    if (keepItems) {
      _isRefreshing = true;
    } else {
      _isRefreshing = false;
      _isLoading = true;
      _items.clear();
      _isLast = true;
    }
    notifyListeners();

    final pages = keepItems ? _nextPage.clamp(1, maxRefreshPages) : 1;

    try {
      final page = await _fetch(0, size: pages * pageSize);
      if (generation != _generation) return;
      _items
        ..clear()
        ..addAll(page.applications);
      _isLast = page.last || page.applications.isEmpty;
      _nextPage = pages;
    } on ApiException catch (error) {
      if (generation != _generation) return;
      _errorMessage = error.message;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _isRefreshing = false;
        _hasLoaded = true;
        notifyListeners();
      }
    }
  }

  /// Sonraki sayfayı ekler. Yükleme sürerken, son sayfadaysa ya da önceki
  /// sayfa hata verdiyse ([retryLoadMore] ister) hiçbir şey yapmaz. Başarısız
  /// bir yenilemeden sonra eldeki satırların devamı hâlâ istenebilir.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || _isRefreshing || _isLast) return;
    if (!_hasLoaded || _loadMoreError != null) return;

    final generation = _generation;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _fetch(_nextPage);
      if (generation != _generation) return;

      // Sayfalar arasında yeni başvuru gelirse (bekleyenler öne alınıyor) bir
      // satır iki sayfanın sınırında tekrar edebilir; aynı kimlik bir kez
      // çiziliyor.
      final known = {for (final item in _items) item.id};
      _items.addAll(page.applications.where((item) => known.add(item.id)));
      _isLast = page.last || page.applications.isEmpty;
      _nextPage++;
    } on ApiException catch (error) {
      if (generation != _generation) return;
      _loadMoreError = error.message;
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Liste sonundaki hata satırının "Tekrar Dene"si.
  Future<void> retryLoadMore() {
    _loadMoreError = null;
    return loadMore();
  }

  /// Sayfa kapanırken uçuştaki istekler eskimiş sayılıyor: dönen yanıt artık
  /// atılmış bir `ChangeNotifier`'a `notifyListeners` demesin.
  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<ReceivedApplicationPage> _fetch(int page, {int size = pageSize}) {
    return _service.fetchReceivedApplications(
      status: _status,
      jobId: _jobId,
      companyId: _companyId,
      page: page,
      size: size,
    );
  }
}
