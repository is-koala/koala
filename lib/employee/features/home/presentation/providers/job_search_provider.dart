import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Keşfet'in sunucu taraflı araması: sorgu, sayfalar, sonsuz kaydırma.
class JobSearchProvider extends ChangeNotifier {
  JobSearchProvider({JobService? service}) : _service = service ?? JobService();

  final JobService _service;

  final List<Job> _jobs = [];

  /// Sayfa penceresi kayabildiği için aynı ilan iki sayfada gelebiliyor; kart
  /// iki kez çizilmesin.
  final Set<String> _jobIds = {};

  JobSearchQuery _query = const JobSearchQuery();

  int _page = 0;
  int _totalElements = 0;
  bool _isLast = true;

  /// Sessiz yükleme de tek başına uçmalı.
  bool _isFetching = false;

  /// Uçan isteğin numarası: yeni süzgeç her zaman istek atar, geç dönen eski
  /// yanıt yenisinin üzerine yazamaz.
  int _requestToken = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  List<Job> get jobs => List.unmodifiable(_jobs);

  JobSearchQuery get query => _query;

  /// **Toplam** sayı; yüklenen sayfaları saymak kaydırdıkça değişirdi.
  int get totalElements => _totalElements;

  bool get isLoading => _isLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasMore => !_isLast;

  String? get errorMessage => _errorMessage;

  /// [silent] göstergeyi açmaz.
  Future<void> load({bool silent = false}) async {
    final token = ++_requestToken;

    _isFetching = true;
    _isLoading = !silent;
    _errorMessage = null;
    if (!silent) notifyListeners();

    try {
      final page = await _service.search(_query, page: 0);

      if (token != _requestToken) return;

      _jobs.clear();
      _jobIds.clear();
      _addAll(page.jobs);
      _page = page.page;
      _totalElements = page.totalElements;
      _isLast = page.last;
    } on ApiException catch (error) {
      if (token != _requestToken) return;

      _errorMessage = error.message;
    } finally {
      // Bayrakları yalnız son istek indirir.
      if (token == _requestToken) {
        _isFetching = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isFetching || _isLast) return;

    final token = ++_requestToken;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _service.search(_query, page: _page + 1);

      // Araya yeni süzgeç girdiyse bu sayfa başka sorgunun sonucu.
      if (token != _requestToken) return;

      _addAll(page.jobs);
      _page = page.page;
      _totalElements = page.totalElements;
      _isLast = page.last;
    } on ApiException catch (error) {
      if (token != _requestToken) return;

      // Eldeki liste silinmez.
      _errorMessage = error.message;
    } finally {
      if (token == _requestToken) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Yeni ölçütü uygular. Sorgu değişmediyse ağa çıkmaz (dakikada 120 sınırı).
  /// Uçan istek beklenmez: yeni ölçüt kazanır, eski yanıt jetonla elenir.
  Future<void> applyQuery(JobSearchQuery query) async {
    if (_isSameQuery(query)) return;

    _query = query;
    _page = 0;
    _isLast = true;
    await load();
  }

  void _addAll(List<Job> incoming) {
    for (final job in incoming) {
      if (_jobIds.add(job.id)) _jobs.add(job);
    }
  }

  /// Eşitlik isteğe dönüşmüş hâlden ölçülür.
  bool _isSameQuery(JobSearchQuery other) {
    final current = _query.toQueryParameters();
    final candidate = other.toQueryParameters();

    if (current.length != candidate.length) return false;
    for (final entry in current.entries) {
      if (candidate[entry.key] != entry.value) return false;
    }
    return true;
  }
}
