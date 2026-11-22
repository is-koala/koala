import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/employee/features/home/models/job_page.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Harita sekmesinin ilan durumu. Liste ile ortak olan **sorgu modeli**: kamera
/// kutusu [JobSearchQuery]'ye yazılıyor.
///
/// Kamera her durduğunda istek atılmıyor:
/// 1. **Debounce:** hızlı kaydırmada tek istek.
/// 2. **Pay:** istenen alan [fetchMargin] kadar geniş.
/// 3. **Önbellek:** görünen alan eksiksiz ve taze ([areaTtl]) yüklenmiş bir
///    alandaysa istek yok. Sorgu değişince sıfırlanır.
/// 4. **Jeton:** geç dönen yanıt yeni pinlerin üzerine yazamaz.
///
/// [jobs] yalnız görünen (paylı) alandakiler. [isRefreshing] yalnız istek
/// [refreshIndicatorDelay]'den uzunsa açılır; hızlı yenileme bir şey yakıp
/// söndürmesin.
class MapExploreController extends ChangeNotifier {
  MapExploreController({
    JobService? service,
    this._debounce = const Duration(milliseconds: 500),
    this.fetchMargin = defaultFetchMargin,
    this.refreshIndicatorDelay = const Duration(milliseconds: 400),
    this.areaTtl = const Duration(minutes: 3),
    DateTime Function()? clock,
  }) : assert(fetchMargin >= 0),
       _service = service ?? JobService(),
       _clock = clock ?? DateTime.now;

  /// `0.5` her kenara yarım ekran: yarım ekranlık kaydırma istek doğurmaz.
  static const double defaultFetchMargin = 0.5;

  final double fetchMargin;

  final Duration refreshIndicatorDelay;

  /// Dolunca alan yeniden sorulur: kapanan ilan sonsuza kadar kalmaz, yetkisi
  /// biten kesin konum en geç bu sürede yuvarlanır.
  final Duration areaTtl;

  /// Aşılırsa önbellek son yanıtla yeniden başlar; bellek sınırsız büyümesin.
  static const int maxCachedJobs = 500;

  /// Sunucu tavanı 100; pin sayfalanmadığı için tavana çıkılıyor. `last: false`
  /// gelirse [isTruncated] açılır, pinler sessizce düşmez.
  static const int mapPageSize = 100;

  final JobService _service;
  final Duration _debounce;
  final DateTime Function() _clock;

  Timer? _timer;
  Timer? _refreshIndicatorTimer;

  JobMapBounds? _pendingBounds;

  /// Aynı ilan yeniden gelince yenisi yazılır; kesinliği değişenin eski
  /// koordinatı düşer.
  final Map<String, Job> _cache = {};

  final List<_LoadedArea> _areas = [];

  /// Sonraki yanıt önbelleğin yerine geçer; önbellek hemen boşalmaz, harita boş
  /// kalmasın.
  bool _replaceOnNext = false;

  /// Arama kartı sunucunun sırasını korusun.
  List<String> _lastOrder = const [];

  int _requestToken = 0;

  List<Job> _visible = const [];
  String _searchText = '';
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isRefreshing = false;
  bool _isTruncated = false;
  bool _disposed = false;
  String? _errorMessage;

  double? _latitude;
  double? _longitude;
  DateTime? _startFrom;
  DateTime? _startTo;
  JobSortOption _sort = JobSortOption.newest;

  List<Job> get jobs => List.unmodifiable(_visible);

  String get searchText => _searchText;

  /// Bir istek uçuşta mı (ilk yükleme ya da yenileme).
  bool get isLoading => _isLoading;

  /// Hiç sonuç yokken süren yükleme; belirgin gösterilir.
  bool get isInitialLoading => _isLoading && !_hasLoaded;

  /// Pinler dururken uzun süren yenileme; sessiz gösterilir.
  bool get isRefreshing => _isRefreshing;

  /// Arayüzde "yaklaş" uyarısı.
  bool get isTruncated => _isTruncated;

  String? get errorMessage => _errorMessage;

  /// Yokken `lat`/`lng` gönderilmez.
  void setOrigin({double? latitude, double? longitude}) {
    if (_latitude == latitude && _longitude == longitude) return;
    _latitude = latitude;
    _longitude = longitude;
    _invalidateAndRefetch();
  }

  void setSort(JobSortOption sort) {
    if (_sort == sort) return;
    _sort = sort;
    _invalidateAndRefetch();
  }

  /// İkisi birden `null` süzgeci kaldırır.
  void setStartWindow({DateTime? startFrom, DateTime? startTo}) {
    if (_startFrom == startFrom && _startTo == startTo) return;
    _startFrom = startFrom;
    _startTo = startTo;
    _invalidateAndRefetch();
  }

  /// Yüklenen alanlar artık bu sorgunun cevabı değil; uçan istek de jetonla
  /// düşürülür.
  void _invalidateAndRefetch() {
    _areas.clear();
    _replaceOnNext = true;
    _requestToken++;
    _schedule();
  }

  void onCameraIdle(JobMapBounds bounds) {
    _pendingBounds = bounds;
    if (_updateVisible()) _notify();

    // Taze ve eksiksiz yüklenmiş alan kutuyu kapsıyorsa istek bir şey eklemez.
    // Kırpılmış alan kapsama sayılmaz: yaklaşmak yeni pin getirebilir.
    if (_isCovered(bounds)) return;

    _schedule();
  }

  bool _isCovered(JobMapBounds bounds) {
    final now = _clock();
    return _areas.any(
      (area) =>
          area.complete &&
          now.difference(area.loadedAt) < areaTtl &&
          area.bounds.contains(bounds),
    );
  }

  /// Metin mevcut kutuyla sunucuya gider.
  void setSearchText(String text) {
    if (text == _searchText) return;

    _searchText = text;
    _invalidateAndRefetch();
  }

  /// Önbelleğe güvenmeden baştan.
  void retry() => _invalidateAndRefetch();

  void _schedule() {
    if (_disposed || _pendingBounds == null) return;

    _timer?.cancel();
    _timer = Timer(_debounce, _fetch);
  }

  Future<void> _fetch() async {
    final viewport = _pendingBounds;
    if (_disposed || viewport == null) return;

    final token = ++_requestToken;

    _isLoading = true;
    _errorMessage = null;
    _refreshIndicatorTimer?.cancel();
    if (_hasLoaded) {
      _refreshIndicatorTimer = Timer(refreshIndicatorDelay, () {
        if (_disposed || token != _requestToken || !_isLoading) return;
        _isRefreshing = true;
        _notify();
      });
    }
    _notify();

    try {
      final padded = _padded(viewport);
      var bounds = padded;
      var page = await _search(padded);
      if (token != _requestToken) return;

      // Geniş kutu kırpıldıysa ekrandakiler düşmüş olabilir; yalnız görünen
      // alan yeniden sorulur.
      if (!page.last && padded != viewport) {
        bounds = viewport;
        page = await _search(viewport);
        if (token != _requestToken) return;
      }

      _merge(page, bounds);
      _isTruncated = !page.last;
      _hasLoaded = true;
      _updateVisible();
    } on ApiException catch (error) {
      if (token != _requestToken) return;

      // Eldeki pinler silinmez.
      _errorMessage = error.message;
    } finally {
      if (token == _requestToken) {
        _isLoading = false;
        _isRefreshing = false;
        _refreshIndicatorTimer?.cancel();
        _notify();
      }
    }
  }

  void _merge(JobPage page, JobMapBounds bounds) {
    if (_replaceOnNext || _cache.length + page.jobs.length > maxCachedJobs) {
      _cache.clear();
      _areas.clear();
      _replaceOnNext = false;
    }

    // Eksiksiz yanıt alanın tamamını söyler: yanıtta olmayan ilan kapanmış ya
    // da taşınmış. Kırpılmış yanıtta silinmez.
    if (page.last) {
      _cache.removeWhere(
        (_, job) =>
            job.hasLocation &&
            bounds.containsPoint(job.latitude!, job.longitude!),
      );
    }
    for (final job in page.jobs) {
      _cache[job.id] = job;
    }
    _lastOrder = [for (final job in page.jobs) job.id];

    final now = _clock();
    _areas
      ..removeWhere(
        (area) =>
            now.difference(area.loadedAt) >= areaTtl ||
            (page.last && bounds.contains(area.bounds)),
      )
      ..add(_LoadedArea(bounds, complete: page.last, loadedAt: now));
  }

  /// Değiştiyse `true`.
  bool _updateVisible() {
    final viewport = _pendingBounds;
    final List<Job> next;
    if (viewport == null) {
      next = const [];
    } else {
      final box = _padded(viewport);
      bool inView(Job job) =>
          job.hasLocation && box.containsPoint(job.latitude!, job.longitude!);
      final ordered = <Job>[
        for (final id in _lastOrder)
          if (_cache[id] case final job? when inView(job)) job,
      ];
      final seen = {for (final job in ordered) job.id};
      next = [
        ...ordered,
        for (final job in _cache.values)
          if (!seen.contains(job.id) && inView(job)) job,
      ];
    }

    if (listEquals(next, _visible)) return false;
    _visible = next;
    return true;
  }

  Future<JobPage> _search(JobMapBounds bounds) => _service.search(
    JobSearchQuery(
      query: _searchText,
      bounds: bounds,
      latitude: _latitude,
      longitude: _longitude,
      startFrom: _startFrom,
      startTo: _startTo,
      sort: _sort,
    ),
    size: mapPageSize,
  );

  /// Görünen alanı genişletir, kenarlarda kırpar. Meridyeni aşan kutu
  /// genişletilmez; düz aritmetik kutuyu ters çevirir.
  JobMapBounds _padded(JobMapBounds viewport) {
    if (fetchMargin == 0 || viewport.wrapsAntimeridian) return viewport;

    final latPad = (viewport.maxLatitude - viewport.minLatitude) * fetchMargin;
    final lngPad =
        (viewport.maxLongitude - viewport.minLongitude) * fetchMargin;
    return JobMapBounds(
      minLatitude: (viewport.minLatitude - latPad).clamp(-90, 90),
      maxLatitude: (viewport.maxLatitude + latPad).clamp(-90, 90),
      minLongitude: (viewport.minLongitude - lngPad).clamp(-180, 180),
      maxLongitude: (viewport.maxLongitude + lngPad).clamp(-180, 180),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _refreshIndicatorTimer?.cancel();
    super.dispose();
  }
}

class _LoadedArea {
  const _LoadedArea(
    this.bounds, {
    required this.complete,
    required this.loadedAt,
  });

  final JobMapBounds bounds;

  final bool complete;

  final DateTime loadedAt;
}
