import 'package:material_ui/material_ui.dart';
import 'package:koala/business/features/home/models/received_application.dart';
import 'package:koala/business/features/home/services/received_application_service.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_exception.dart';

/// İlanlar arası başvuru kutusu: liste, süzgeç, sayfalama.
///
/// **Sayfaya ait.** Başvuranların ad ve fotoğrafını taşıyor; uygulama boyunca
/// yaşasa temizlik oturum düşünce (`SessionManager.end`) hiç çalışmayabilirdi.
/// Süzgeç değişince eski satırlar hemen düşer; çekip yenilemede kalır.
class BApplicationInboxProvider extends ChangeNotifier {
  BApplicationInboxProvider({ReceivedApplicationService? service})
    : _service = service ?? ReceivedApplicationService();

  /// Yenileme birkaç sayfayı tek istekte alıyor; sonraki sayfa bu boyuttan
  /// hesaplanıyor.
  static const int pageSize = ReceivedApplicationService.defaultPageSize;

  static const int maxRefreshPages =
      ReceivedApplicationService.maxPageSize ~/ pageSize;

  final ReceivedApplicationService _service;

  final List<ReceivedApplication> _items = [];

  ApplicationStatus? _status;
  String? _companyId;
  String? _jobId;

  /// Seçim anında biliniyor; sonuç boş dönse de çip adını korur.
  String? _jobTitle;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  bool _isLast = true;
  int _nextPage = 0;
  String? _errorMessage;
  String? _loadMoreError;

  /// Her baştan yükleme bir nesil alır; eski yanıt yeni listeyi ezmesin.
  int _generation = 0;

  List<ReceivedApplication> get items => List.unmodifiable(_items);

  /// `null` "tümü".
  ApplicationStatus? get status => _status;

  String? get companyId => _companyId;

  String? get jobId => _jobId;

  String? get jobTitle => _jobTitle;

  bool get isFiltered =>
      _status != null || _companyId != null || _jobId != null;

  bool get isLoading => _isLoading;

  bool get isRefreshing => _isRefreshing;

  bool get isLoadingMore => _isLoadingMore;

  /// Hata da olsa `true`.
  bool get hasLoaded => _hasLoaded;

  bool get hasMore => !_isLast;

  /// Satır varken de dolu olabilir (başarısız yenileme); tam hata ekranına
  /// geçişi satırların boşluğu belirler.
  String? get errorMessage => _errorMessage;

  /// Doluyken kaydırma kendiliğinden istek atmaz; [retryLoadMore] gerekir.
  String? get loadMoreError => _loadMoreError;

  Future<void> load() => _loadFirstPage(keepItems: false);

  /// Çekip yenileme; satırlar yerinde kalır. Eldeki derinlik korunur (üç sayfa
  /// yüklüyse tek istekte 60 satır), karar ekranından dönünce liste ilk sayfaya
  /// çökmesin.
  Future<bool> refresh() async {
    await _loadFirstPage(keepItems: true);
    return _errorMessage == null;
  }

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
    // Eski sonraki-sayfa isteğinin `finally`'sine bırakmak yeni yüklemenin
    // kilidini sonsuza dek tutardı.
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

  /// Sonraki sayfayı ekler; yükleme sürüyorsa, son sayfadaysa ya da önceki
  /// sayfa hata verdiyse bir şey yapmaz.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || _isRefreshing || _isLast) return;
    if (!_hasLoaded || _loadMoreError != null) return;

    final generation = _generation;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _fetch(_nextPage);
      if (generation != _generation) return;

      // Sayfalar arasında yeni başvuru gelirse satır sınırda tekrar edebilir.
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

  Future<void> retryLoadMore() {
    _loadMoreError = null;
    return loadMore();
  }

  /// Kapanınca uçuştaki yanıtlar atılan nesneye `notifyListeners` demesin.
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
