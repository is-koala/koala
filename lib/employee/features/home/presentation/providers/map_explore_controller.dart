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
/// 3. **Kapsama** — yeni alan yüklenmiş alanın içindeyse ve sonuç
///    kırpılmamışsa istek atılmıyor.
/// 4. **Jeton** — geç dönen eski yanıt yeni pinlerin üzerine yazamıyor.
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
  }) : assert(fetchMargin >= 0),
       _service = service ?? JobService(),
       _debounce = debounce;

  /// Görünen alanın her yöne ne kadar genişletileceği, alanın kendi
  /// boyutuna oranla. `0.5` her kenara yarım ekran ekliyor: kutu iki kat
  /// geniş, iki kat yüksek, yani yarım ekranlık bir kaydırma yeni istek
  /// doğurmuyor.
  static const double defaultFetchMargin = 0.5;

  final double fetchMargin;

  /// Pinler ekrandayken yenileme göstergesinin açılmadan önce beklediği süre.
  final Duration refreshIndicatorDelay;

  /// Harita için istenen sayfa boyutu.
  ///
  /// Sunucunun tavanı 100 (`PageableSanitizer`); pin sayfalanamadığı için
  /// tavana kadar çıkılıyor. Yanıt `last: false` gelirse alanda daha fazla ilan
  /// var demektir — pinler sessizce düşürülmüyor, [isTruncated] açılıyor.
  static const int mapPageSize = 100;

  final JobService _service;
  final Duration _debounce;

  Timer? _timer;
  Timer? _refreshIndicatorTimer;

  /// En son kamera olayının kutusu.
  JobMapBounds? _pendingBounds;

  /// En son **başarıyla** yüklenen kutu ve o yüklemenin kırpılmamış olup
  /// olmadığı. Kapsama kararı bu ikisine bakıyor.
  JobMapBounds? _loadedBounds;
  bool _loadedComplete = false;

  /// Uçan isteğin sıra numarası; yanıt döndüğünde hâlâ güncel mi diye
  /// karşılaştırılıyor.
  int _requestToken = 0;

  List<Job> _jobs = const [];
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

  List<Job> get jobs => List.unmodifiable(_jobs);

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

  void _invalidateAndRefetch() {
    _loadedBounds = null;
    _loadedComplete = false;
    _schedule();
  }

  /// Kamera durduğunda çağrılıyor.
  void onCameraIdle(JobMapBounds bounds) {
    _pendingBounds = bounds;

    // Önceki sonuç bu alanı zaten kapsıyorsa ve kırpılmamışsa yeni istek
    // hiçbir şey eklemez. Kırpılmış bir sonuçta ise yaklaşmak **yeni** pin
    // getirebilir, o yüzden orada istek atılıyor.
    final loaded = _loadedBounds;
    if (_loadedComplete && loaded != null && loaded.contains(bounds)) return;

    _schedule();
  }

  /// Harita arama kutusu. Metin mevcut kutuyla birlikte sunucuya gidiyor;
  /// eskiden eldeki ≤20 satır bellekte süzülüyordu.
  void setSearchText(String text) {
    if (text == _searchText) return;

    _searchText = text;
    // Arama değişti: kapsama koruması artık geçerli değil, aynı kutu için de
    // yeniden sorulmalı.
    _loadedBounds = null;
    _loadedComplete = false;
    _schedule();
  }

  /// Hata sonrası kullanıcının "Tekrar Dene"si.
  void retry() {
    _loadedBounds = null;
    _loadedComplete = false;
    _schedule();
  }

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

      _jobs = page.jobs;
      _isTruncated = !page.last;
      _loadedBounds = bounds;
      _loadedComplete = page.last;
      _hasLoaded = true;
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
