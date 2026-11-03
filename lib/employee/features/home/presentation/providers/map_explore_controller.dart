import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/employee/features/home/models/job_page.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Harita sekmesinin ilan durumu: görünen alan, arama ve pinler.
///
/// Harita listeden ayrı bir durum tutuyor — ikisini tek sağlayıcıya bağlamak
/// doğru yön ama ayrı bir iş. Ortak olan **sorgu modeli**: kamera kutusu
/// [JobSearchQuery]'nin sınırlayıcı kutu alanlarına yazılıyor, liste sekmesinin
/// kullandığı alanların aynısı.
///
/// Kamera her durduğunda istek atmıyor; dört koruma var:
/// 1. **Debounce** — hızlı kaydırmada tek istek çıkıyor.
/// 2. **Pay** — istenen alan görünen alandan [fetchMargin] kadar geniş; küçük
///    bir kaydırma yüklenmiş alanın içinde kalıyor.
/// 3. **Önbellek** — yüklenen ilanlar ve alanlar oturum boyunca saklanıyor.
///    Görünen alan, eksiksiz yüklenmiş ve bayatlamamış ([areaTtl]) bir alanın
///    içindeyse istek atılmıyor; geri dönülen bölgenin pinleri önbellekten
///    çiziliyor. Arama, süzgeç, sıralama ya da konum değişince önbellek
///    sıfırlanıyor: başka bir sorgunun sonucu bu sorgunun cevabı değil.
/// 4. **Jeton** — geç dönen eski yanıt yeni pinlerin üzerine yazamıyor.
///
/// [jobs] önbelleğin tamamı değil, görünen alanın (paylı) içindeki ilanlar:
/// ekrandan çıkan pin haritada tutulmuyor, pin sayısı da görünen alanla
/// sınırlı kalıyor.
///
/// Yükleme iki ayrı durum olarak dışarı veriliyor: [isInitialLoading] haritada
/// henüz hiç sonuç yokken, [isRefreshing] eldeki pinler dururken. İkincisi
/// yalnız istek [refreshIndicatorDelay]'den uzun sürerse açılıyor; hızlı bir
/// yenileme ekranda hiçbir şey yakıp söndürmüyor.
class MapExploreController extends ChangeNotifier {
  MapExploreController({
    JobService? service,
    Duration debounce = const Duration(milliseconds: 500),
    this.fetchMargin = defaultFetchMargin,
    this.refreshIndicatorDelay = const Duration(milliseconds: 400),
    this.areaTtl = const Duration(minutes: 3),
    DateTime Function()? clock,
  }) : assert(fetchMargin >= 0),
       _service = service ?? JobService(),
       _debounce = debounce,
       _clock = clock ?? DateTime.now;

  /// Görünen alanın her yöne ne kadar genişletileceği, alanın kendi
  /// boyutuna oranla. `0.5` her kenara yarım ekran ekliyor: kutu iki kat
  /// geniş, iki kat yüksek, yani yarım ekranlık bir kaydırma yeni istek
  /// doğurmuyor.
  static const double defaultFetchMargin = 0.5;

  final double fetchMargin;

  /// Pinler ekrandayken yenileme göstergesinin açılmadan önce beklediği süre.
  final Duration refreshIndicatorDelay;

  /// Yüklenmiş bir alanın "bu bölgeyi biliyorum" sayıldığı süre. Dolunca
  /// alan yeniden soruluyor; kapanan ya da dolan ilan haritada sonsuza kadar
  /// kalmıyor, yetkisi biten kesin konum da en geç bu sürede yuvarlanıyor.
  final Duration areaTtl;

  /// Önbellekteki ilan tavanı. Aşılırsa önbellek son yanıtla yeniden
  /// başlıyor; uzun bir oturumda bellek ve pin üretimi sınırsız büyümüyor.
  static const int maxCachedJobs = 500;

  /// Harita için istenen sayfa boyutu.
  ///
  /// Sunucunun tavanı 100 (`PageableSanitizer`); pin sayfalanamadığı için
  /// tavana kadar çıkılıyor. Yanıt `last: false` gelirse alanda daha fazla ilan
  /// var demektir — pinler sessizce düşürülmüyor, [isTruncated] açılıyor.
  static const int mapPageSize = 100;

  final JobService _service;
  final Duration _debounce;
  final DateTime Function() _clock;

  Timer? _timer;
  Timer? _refreshIndicatorTimer;

  /// En son kamera olayının kutusu.
  JobMapBounds? _pendingBounds;

  /// Yüklenen ilanlar, kimliğe göre. Aynı ilan yeniden geldiğinde yenisi
  /// yazılıyor; kesinliği değişen ilanın eski koordinatı böyle düşüyor.
  final Map<String, Job> _cache = {};

  /// Başarıyla yüklenen alanlar. Kapsama kararı bunlara bakıyor.
  final List<_LoadedArea> _areas = [];

  /// Sorgu değişti: bir sonraki yanıt önbelleğe eklenmiyor, yerine geçiyor.
  /// Önbellek hemen boşaltılmıyor ki yanıt gelene kadar harita boş kalmasın.
  bool _replaceOnNext = false;

  /// Son yanıtın sırası; görünen liste önce bunu, sonra önbelleğin kalanını
  /// veriyor (arama sonucu kartı sunucunun sırasını korusun).
  List<String> _lastOrder = const [];

  /// Uçan isteğin sıra numarası; yanıt döndüğünde hâlâ güncel mi diye
  /// karşılaştırılıyor.
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

  /// Görünen alandaki ilanlar (önbellekten).
  List<Job> get jobs => List.unmodifiable(_visible);

  String get searchText => _searchText;

  /// Bir istek uçuşta mı (ilk yükleme ya da yenileme).
  bool get isLoading => _isLoading;

  /// Henüz hiç başarılı sonuç yokken süren yükleme. Arayüz bunu belirgin
  /// gösteriyor: harita boş ve kullanıcı neden boş olduğunu bilmeli.
  bool get isInitialLoading => _isLoading && !_hasLoaded;

  /// Eldeki pinler dururken [refreshIndicatorDelay]'den uzun süren yenileme.
  /// Arayüz bunu sessiz gösteriyor; pinler zaten ekranda.
  bool get isRefreshing => _isRefreshing;

  /// Görünen alanda [mapPageSize] taneden fazla ilan var mı. Arayüz bunu
  /// "yaklaş" uyarısı olarak gösteriyor.
  bool get isTruncated => _isTruncated;

  String? get errorMessage => _errorMessage;

  /// Kullanıcı konumu. Kartın `distanceKm`'si ve yakınlık sıralaması buna
  /// bağlı; yokken `lat`/`lng` gönderilmez.
  void setOrigin({double? latitude, double? longitude}) {
    if (_latitude == latitude && _longitude == longitude) return;
    _latitude = latitude;
    _longitude = longitude;
    _invalidateAndRefetch();
  }

  /// Sıralama. Mesafe sıralaması konum olmadan parametreye düşmez.
  void setSort(JobSortOption sort) {
    if (_sort == sort) return;
    _sort = sort;
    _invalidateAndRefetch();
  }

  /// Başlangıç günü penceresi. İkisi birden `null` süzgeci kaldırır.
  void setStartWindow({DateTime? startFrom, DateTime? startTo}) {
    if (_startFrom == startFrom && _startTo == startTo) return;
    _startFrom = startFrom;
    _startTo = startTo;
    _invalidateAndRefetch();
  }

  /// Sorgu değişti: yüklenen alanlar artık bu sorgunun cevabı değil. Uçan
  /// istek de eski sorguya ait; jeton ilerletilerek yanıtı düşürülüyor.
  void _invalidateAndRefetch() {
    _areas.clear();
    _replaceOnNext = true;
    _requestToken++;
    _schedule();
  }

  /// Kamera durduğunda çağrılıyor.
  void onCameraIdle(JobMapBounds bounds) {
    _pendingBounds = bounds;
    if (_updateVisible()) _notify();

    // Eksiksiz yüklenmiş taze bir alan bu kutuyu kapsıyorsa yeni istek hiçbir
    // şey eklemez. Kırpılmış bir sonuçta ise yaklaşmak **yeni** pin
    // getirebilir; kırpılmış alan kapsama sayılmıyor.
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

  /// Harita arama kutusu. Metin mevcut kutuyla birlikte sunucuya gidiyor;
  /// eskiden eldeki ≤20 satır bellekte süzülüyordu.
  void setSearchText(String text) {
    if (text == _searchText) return;

    _searchText = text;
    // Arama değişti: önbellek bu metnin cevabı değil, aynı kutu için de
    // yeniden sorulmalı.
    _invalidateAndRefetch();
  }

  /// Hata sonrası kullanıcının "Tekrar Dene"si: önbelleğe güvenmeden baştan.
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

      // Geniş kutu kırpıldıysa sunucunun döndürdüğü 100 ilanın çoğu ekran
      // dışında olabilir ve ekrandakiler düşebilir. O durumda yalnız görünen
      // alan yeniden soruluyor; yoğun olmayan bölgede bu ikinci istek hiç
      // atılmıyor.
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

      // Eldeki pinler silinmiyor: hata yüzünden haritayı boşaltmak
      // kullanıcının baktığı bilgiyi de götürürdü.
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

  /// Yanıtı önbelleğe işler.
  void _merge(JobPage page, JobMapBounds bounds) {
    if (_replaceOnNext || _cache.length + page.jobs.length > maxCachedJobs) {
      _cache.clear();
      _areas.clear();
      _replaceOnNext = false;
    }

    // Eksiksiz bir yanıt bu alanın tamamını söylüyor: önbellekte olup
    // yanıtta olmayan ilan kapanmış, dolmuş ya da taşınmış. Kırpılmış
    // yanıtta eksiklik bunu söylemiyor, orada hiçbir şey silinmiyor.
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

  /// Görünen listeyi önbellekten yeniden kurar; değiştiyse `true`.
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

  /// Görünen alanı [fetchMargin] oranında genişletir; enlemde kutuplara,
  /// boylamda ±180'e kırpılır. 180. meridyeni aşan kutu genişletilmez:
  /// orada düz aritmetik kutuyu ters çevirir.
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

/// Başarıyla yüklenmiş bir alan.
class _LoadedArea {
  const _LoadedArea(
    this.bounds, {
    required this.complete,
    required this.loadedAt,
  });

  final JobMapBounds bounds;

  /// Yanıt kırpılmamış mı; kırpılmış alan kapsama sayılmıyor.
  final bool complete;

  final DateTime loadedAt;
}
