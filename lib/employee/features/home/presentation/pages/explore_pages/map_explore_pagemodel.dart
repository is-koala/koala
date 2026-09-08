part of 'map_explore_page.dart';

abstract class MapExplorePageModel extends State<MapExplorePage>
    with AutomaticKeepAliveClientMixin<MapExplorePage> {
  GoogleMapController? _mapController;
  late LocationService _locationService;
  late final MapExploreController _jobs = MapExploreController();

  bool _loading = true;
  LatLng? _currentLatLng;

  String _loadingMessage = 'Harita Yükleniyor...';

  Set<Marker> _markers = {};

  /// Yaklaşık konumlu ilanların belirsizlik daireleri.
  ///
  /// Marker'lardan ayrı tutuluyor: daire ilanın kendi verisinden hesaplanıyor,
  /// üretimi asenkron değil, o yüzden önbelleğe de girmiyor.
  Set<Circle> _areas = {};

  /// Üretilmiş marker'lar, [JobMarkerGenerator.cacheKeyFor] anahtarıyla.
  ///
  /// Her `onCameraIdle` sonrası bütün pinleri yeniden üretmek gereksiz. Ama
  /// anahtar yalnız ilan kimliği **olamaz**: aynı ilan, yetki sona erdiğinde
  /// yuvarlanmış koordinat ve `APPROXIMATE` bayrağıyla geri geliyor ve
  /// kimliğe bakan bir önbellek eski kesin pini ekranda tutardı.
  final Map<String, Marker> _markerCache = {};

  /// Marker üretimi de asenkron; iki güncelleme üst üste gelirse eskisi
  /// yenisinin üzerine yazmasın diye jetonla korunuyor.
  int _markerToken = 0;

  // Arama
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _jobs.addListener(_onJobsChanged);

    _locationService = LocationService(
      context,
      onLocationReceived: (pos) {
        setState(() {
          _currentLatLng = LatLng(pos.latitude, pos.longitude);
          _loading = false;
        });

        // Haritayı konuma taşı
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentLatLng!, 16),
          );
        }
      },
    );

    _locationService.init();
  }

  @override
  void dispose() {
    _jobs
      ..removeListener(_onJobsChanged)
      ..dispose();
    _locationService.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onJobsChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_rebuildMarkers());
  }

  /// Kamera durduğunda görünen alanı sunucuya bildirir.
  ///
  /// Eskiden harita `GET /jobs`'u argümansız çağırıyordu: haritada en fazla 20
  /// pin oluyordu ve o 20 ilan sunucunun `createdAt,desc` sırasından geliyordu,
  /// yani kullanıcının baktığı bölgeyle ilgisi yoktu. Kaydırmak da hiçbir şey
  /// getirmiyordu.
  Future<void> _onCameraIdle() async {
    final controller = _mapController;
    if (controller == null) return;

    final LatLngBounds region;
    try {
      region = await controller.getVisibleRegion();
    } catch (_) {
      return;
    }
    if (!mounted) return;

    _jobs.onCameraIdle(
      JobMapBounds(
        minLatitude: region.southwest.latitude,
        maxLatitude: region.northeast.latitude,
        minLongitude: region.southwest.longitude,
        maxLongitude: region.northeast.longitude,
      ),
    );
  }

  Future<void> _rebuildMarkers() async {
    final jobs = _jobs.jobs;
    final token = ++_markerToken;

    final missing = [
      for (final job in jobs)
        if (!_markerCache.containsKey(JobMarkerGenerator.cacheKeyFor(job))) job,
    ];

    if (missing.isNotEmpty) {
      final generated = await JobMarkerGenerator.generateMarkers(
        jobs: missing,
        onMarkerTap: _onJobMarkerTap,
      );
      if (!mounted || token != _markerToken) return;

      _markerCache.addAll(generated);
    }

    // Görünen alandan çıkan **ve** kesinliği değişen ilanların marker'ı
    // bellekte kalmasın; ikincisi anahtarın kesinliği taşımasından geliyor.
    JobMarkerGenerator.evictStale(_markerCache, jobs);

    if (!mounted || token != _markerToken) return;
    setState(() {
      _markers = _markerCache.values.toSet();
      _areas = JobMarkerGenerator.generateAreas(jobs: jobs);
    });
  }

  /// Haritada arama yap.
  ///
  /// Metin **sunucuya** gidiyor ve mevcut sınırlayıcı kutuyla birlikte
  /// süzülüyor; eskiden eldeki en fazla 20 satır bellekte eleniyordu.
  void _onMapSearch(String query) {
    _jobs.setSearchText(query.trim());
  }

  /// Arama sonucuna tıklanınca haritada o işe odaklan
  void _focusOnJob(Job job) {
    _searchFocusNode.unfocus();

    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    searchProvider.stopSearching();
    _searchController.clear();
    _jobs.setSearchText('');

    // Haritayı o konuma taşı. Koordinatı olmayan ilan haritada zaten
    // görünmüyor, kamerayı da oynatmıyoruz.
    if (_mapController != null && job.hasLocation) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(job.latitude!, job.longitude!),
            zoom: 17.0,
          ),
        ),
      );
    }

    // Kısa bir gecikme ile bottom sheet aç
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        JobDetailBottomSheet.show(context, job);
      }
    });
  }

  /// Marker'a tıklandığında bottom sheet göster
  void _onJobMarkerTap(Job job) {
    HapticFeedback.lightImpact();
    JobDetailBottomSheet.show(context, job);
  }

  @override
  bool get wantKeepAlive => true;
}
