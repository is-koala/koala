import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Keşfet'in sunucu taraflı arama durumu: sorgu, sayfalar ve sonsuz kaydırma.
///
/// Süzgeçler artık elde tutulan listenin üzerinde çalışmıyor — [query] sunucuya
/// gidiyor, liste kaydırıldıkça uzuyor. Sayfalama deseni `NotificationProvider`
/// ile aynı: `page`/`last` zarftan okunuyor, `totalPages` kullanılmıyor.
class JobSearchProvider extends ChangeNotifier {
  JobSearchProvider({JobService? service}) : _service = service ?? JobService();

  final JobService _service;

  final List<Job> _jobs = [];

  /// Listedeki ilan kimlikleri. Sayfa penceresi iki istek arasında kayabildiği
  /// için (varsayılan sıralama `createdAt DESC`, arada yeni ilan yayımlanabilir)
  /// aynı ilan iki sayfada birden gelebiliyor; aynı kartı iki kez çizmemek için
  /// eklerken buraya bakılıyor.
  final Set<String> _jobIds = {};

  JobSearchQuery _query = const JobSearchQuery();

  int _page = 0;
  int _totalElements = 0;
  bool _isLast = true;

  /// Bir ilk-sayfa isteği uçuyor mu. [_isLoading]'den ayrı: sessiz yükleme
  /// göstergeyi açmıyor ama yine de tek başına uçmalı.
  bool _isFetching = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  List<Job> get jobs => List.unmodifiable(_jobs);

  JobSearchQuery get query => _query;

  /// Sorguya uyan **toplam** ilan sayısı; ekrandaki kadarı değil.
  ///
  /// Arama özeti bunu gösteriyor: yalnız yüklenmiş sayfaları saymak "garson
  /// için 20 sonuç" gibi sonsuz kaydırmayla birlikte değişen bir sayı üretirdi.
  int get totalElements => _totalElements;

  bool get isLoading => _isLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasMore => !_isLast;

  String? get errorMessage => _errorMessage;

  /// İlk sayfayı çeker; aşağı çekince yenilemede de bu çağrılıyor.
  ///
  /// [silent] verildiğinde yükleniyor göstergesi açılmıyor — yenilemede
  /// listenin boşalıp yeniden dolması göz yoruyor.
  Future<void> load({bool silent = false}) async {
    if (_isFetching) return;

    _isFetching = true;
    _isLoading = !silent;
    _errorMessage = null;
    if (!silent) notifyListeners();

    try {
      final page = await _service.search(_query, page: 0);

      _jobs.clear();
      _jobIds.clear();
      _addAll(page.jobs);
      _page = page.page;
      _totalElements = page.totalElements;
      _isLast = page.last;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sonraki sayfayı listenin sonuna ekler.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isFetching || _isLast) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _service.search(_query, page: _page + 1);

      _addAll(page.jobs);
      _page = page.page;
      _totalElements = page.totalElements;
      _isLast = page.last;
    } on ApiException catch (error) {
      // Sayfa eklenemedi diye eldeki liste silinmiyor; kullanıcı gördüğü
      // ilanlara bakmayı sürdürebilsin.
      _errorMessage = error.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Yeni ölçütleri uygular ve listeyi ilk sayfadan kurar.
  ///
  /// Sorgu değişmediyse ağa çıkmıyor: süzgeç sheet'i "Uygula" ile kapanıyor ve
  /// hiçbir şey değiştirmeden kapanan sheet istek doğurmamalı — `GET /jobs`
  /// PUBLIC kovasında dakikada 120 istekle sınırlı.
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

  /// İki sorgu sunucu açısından aynı mı.
  ///
  /// Eşitlik alan alan değil, **isteğe dönüşmüş hâli** üzerinden ölçülüyor:
  /// sunucuya aynı parametreleri üretecek iki sorgu arasında fark yok.
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
