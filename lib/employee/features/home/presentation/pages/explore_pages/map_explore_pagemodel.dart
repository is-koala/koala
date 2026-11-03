part of 'map_explore_page.dart';

abstract class MapExplorePageModel extends State<MapExplorePage>
    with AutomaticKeepAliveClientMixin<MapExplorePage> {
  GoogleMapController? _mapController;

  /// Harita bu derlemede çizilebilir mi (is-koala/koala#172). Kapalıysa
  /// sayfa haritayı hiç kurmaz, konum iznini de sormaz: sorulacak bir
  /// haritanın üstü yok.
  late final bool mapsAvailable = MapsAvailability.of(context).isAvailable;

  /// Konum akışı; harita kapalıyken hiç kurulmaz.
  LocationService? _locationService;

  /// İlan durumu. Sayfa kendi kontrolcüsünü kuruyor; test onu
  /// [MapExplorePage.controller] ile dışarıdan veriyor, çünkü pinlerin
  /// kesinliğe göre yenilenmesi ancak gerçek ilan akışı üzerinden sınanabilir.
  /// Kim kurarsa kursun sahibi sayfa: [dispose] onu kapatıyor.
  late final MapExploreController _jobs =
      widget.controller ?? MapExploreController();

  bool _loading = true;
  LatLng? _currentLatLng;

  String _loadingMessage = 'Harita Yükleniyor...';

  Set<Marker> _markers = {};

  /// Yaklaşık konumlu ilanların belirsizlik daireleri.
  ///
  /// Marker'lardan ayrı tutuluyor: daire ilanın kendi verisinden hesaplanıyor,
  /// üretimi asenkron değil, o yüzden önbelleğe de girmiyor.
  Set<Circle> _areas = {};

  /// Üretilmiş marker'lar.
  ///
  /// Her `onCameraIdle` sonrası bütün pinleri yeniden üretmek gereksiz; neyin
  /// saklanabileceğine [JobMarkerCache] karar veriyor. Sayfa burada bir map
  /// tutmuyor — tuttuğu gün onu ilan kimliğiyle indeksleyebilirdi, ki
  /// is-koala/koala#10'un düşen maddesi tam olarak buydu.
  final JobMarkerCache _markerCache = JobMarkerCache();

  /// Marker üretimi de asenkron; iki güncelleme üst üste gelirse eskisi
  /// yenisinin üzerine yazmasın diye jetonla korunuyor.
  int _markerToken = 0;

  /// Kameranın son yakınlaştırması. Gruplama ekran pikseliyle ölçüyor, yani
  /// yakınlaştırma değişince ilanlar değişmese de gruplar yeniden kuruluyor.
  /// Kamera hareket ederken her karede güncelleniyor ama yeniden çizim
  /// yalnız kamera durunca yapılıyor.
  double _zoom = AppMap.initialZoom;

  /// Pinlerin en son hangi yakınlaştırmaya göre gruplandığı.
  double? _clusteredZoom;

  /// Bu yakınlaştırmadan sonra gruba dokunmak kamerayı yaklaştırmıyor, listeyi
  /// açıyor: sokak ölçeğinin de ötesinde hâlâ ayrılmayan ilanlar pratikte
  /// aynı binada.
  static const double _clusterListZoom = 19;

  /// Gruba yaklaşırken ilanların ekran kenarına bırakılan payı (piksel).
  static const double _clusterFitPadding = 80;

  // Arama
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  JobSortOption _sort = JobSortOption.newest;

  /// Süzgeç sheet'inin uygulanmış hâli.
  ///
  /// Harita kameranın kutusunu koruduğu için sheet'ten yalnız başlangıç günü
  /// penceresi sunucuya gider; mesafe yarıçapı kutuyu ezerdi.
  JobFilterSelection _selection = const JobFilterSelection();

  @override
  void initState() {
    super.initState();

    _jobs.addListener(_onJobsChanged);
    if (!mapsAvailable) return;

    _locationService = LocationService(
      context,
      onLocationReceived: (pos) {
        setState(() {
          _currentLatLng = LatLng(pos.latitude, pos.longitude);
          _loading = false;
        });
        _jobs.setOrigin(latitude: pos.latitude, longitude: pos.longitude);

        // Haritayı konuma taşı
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentLatLng!, 16),
          );
        }
      },
    );

    _locationService!.init();
  }

  @override
  void dispose() {
    _jobs
      ..removeListener(_onJobsChanged)
      ..dispose();
    _locationService?.dispose();
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

    // İlanlar değişmese de yakınlaştırma değiştiyse gruplar değişti.
    if (_clusteredZoom != _zoom) unawaited(_rebuildMarkers());
  }

  /// Pinleri gruplayıp yeniden üretir.
  ///
  /// Tek kalan ilan sıradan pinini (ve yaklaşık konumdaysa çemberini) alıyor;
  /// birden fazla ilanlı grup tek bir sayı rozetli pin oluyor. Gruptaki
  /// ilanların çemberleri çizilmiyor: üst üste binen çemberler, pinlerin
  /// birleşmesinden kazanılan sadeliği geri götürürdü.
  Future<void> _rebuildMarkers() async {
    final zoom = _zoom;
    final token = ++_markerToken;

    final clusters = JobClusterer.cluster(_jobs.jobs, zoom: zoom);
    final singles = [
      for (final cluster in clusters)
        if (cluster.isSingle) cluster.jobs.single,
    ];

    final markers = await _markerCache.markersFor(
      jobs: singles,
      onMarkerTap: _onJobMarkerTap,
    );
    final groups = await Future.wait([
      for (final cluster in clusters)
        if (!cluster.isSingle)
          JobMarkerGenerator.clusterMarkerFor(cluster, _onClusterTap),
    ]);

    if (!mounted || token != _markerToken) return;
    setState(() {
      _markers = {...markers, ...groups};
      _areas = JobMarkerGenerator.generateAreas(jobs: singles);
      _clusteredZoom = zoom;
    });
  }

  /// Gruba dokunuldu: ilanları ayıracak kadar yaklaş, ayrılmıyorsa listele.
  void _onClusterTap(JobCluster cluster) {
    HapticFeedback.lightImpact();

    final controller = _mapController;
    if (cluster.isStacked || _zoom >= _clusterListZoom || controller == null) {
      JobClusterSheet.show(context, cluster.jobs);
      return;
    }

    final bounds = cluster.bounds;
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(bounds.minLatitude, bounds.minLongitude),
          northeast: LatLng(bounds.maxLatitude, bounds.maxLongitude),
        ),
        _clusterFitPadding,
      ),
    );
  }

  Future<void> _openSortSheet() async {
    final picked = await JobSortSheet.show(
      context,
      selected: _sort,
      hasLocation: _currentLatLng != null,
    );
    if (picked == null || !mounted) return;

    setState(() => _sort = picked);
    _jobs.setSort(picked);
  }

  Future<void> _openFilterSheet() async {
    final picked = await JobFilterSheet.show(
      context,
      selection: _selection,
      categories: context.read<JobCategoryProvider>().categories,
      hasLocation: _currentLatLng != null,
    );
    if (picked == null || !mounted) return;

    setState(() => _selection = picked);
    final window = picked.startOn?.toWindow();
    _jobs.setStartWindow(
      startFrom: window?.startFrom,
      startTo: window?.startTo,
    );
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
