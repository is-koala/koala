part of 'map_explore_page.dart';

abstract class MapExplorePageModel extends State<MapExplorePage>
    with AutomaticKeepAliveClientMixin<MapExplorePage> {
  GoogleMapController? _mapController;

  /// Kapalıysa (#172) harita kurulmaz, konum izni de sorulmaz.
  late final bool mapsAvailable = MapsAvailability.of(context).isAvailable;

  LocationService? _locationService;

  /// Testler [MapExplorePage.controller] ile verir; sahibi her durumda sayfa.
  late final MapExploreController _jobs =
      widget.controller ?? MapExploreController();

  bool _loading = true;
  LatLng? _currentLatLng;

  String _loadingMessage = 'Harita Yükleniyor...';

  Set<Marker> _markers = {};

  /// Daire ilanın verisinden eşzamanlı hesaplandığı için önbelleğe girmiyor.
  Set<Circle> _areas = {};

  /// Neyin saklanacağına [JobMarkerCache] karar veriyor; sayfa ilan kimliğiyle
  /// indekslenen bir map tutmamalı (#10).
  final JobMarkerCache _markerCache = JobMarkerCache();

  /// Eski asenkron üretim yenisinin üzerine yazmasın.
  int _markerToken = 0;

  /// Gruplama ekran pikseliyle ölçüyor; yakınlaştırma değişince gruplar yeniden
  /// kurulur (yalnız kamera durunca).
  double _zoom = AppMap.initialZoom;

  double? _clusteredZoom;

  /// Pin kenarı temaya bağlı.
  Brightness? _markerBrightness;

  /// Bu düzeyden sonra ayrılmayan ilanlar pratikte aynı binada; gruba dokunmak
  /// listeyi açar.
  static const double _clusterListZoom = 19;

  static const double _clusterFitPadding = 80;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// Harita kamera kutusunu koruduğu için yalnız başlangıç günü gider; yarıçap
  /// kutuyu ezerdi.
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_markerBrightness != null &&
        _markerBrightness != Theme.of(context).brightness) {
      unawaited(_rebuildMarkers());
    }
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

  /// Kutusuz `GET /jobs` bölgeyle ilgisiz ilk 20 ilanı döndürür.
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

    if (_clusteredZoom != _zoom) unawaited(_rebuildMarkers());
  }

  /// Tek ilan sıradan pin (ve dairesi); grup sayı rozetli tek pin. Grupta
  /// daireler çizilmez, sadelik kaybolurdu.
  Future<void> _rebuildMarkers() async {
    final zoom = _zoom;
    final brightness = Theme.of(context).brightness;
    final token = ++_markerToken;

    final clusters = JobClusterer.cluster(_jobs.jobs, zoom: zoom);
    final singles = [
      for (final cluster in clusters)
        if (cluster.isSingle) cluster.jobs.single,
    ];

    final markers = await _markerCache.markersFor(
      jobs: singles,
      onMarkerTap: _onJobMarkerTap,
      brightness: brightness,
    );
    final groups = await Future.wait([
      for (final cluster in clusters)
        if (!cluster.isSingle)
          JobMarkerGenerator.clusterMarkerFor(
            cluster,
            _onClusterTap,
            brightness: brightness,
          ),
    ]);

    if (!mounted || token != _markerToken) return;
    setState(() {
      _markers = {...markers, ...groups};
      _areas = JobMarkerGenerator.generateAreas(jobs: singles);
      _clusteredZoom = zoom;
      _markerBrightness = brightness;
    });
  }

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

  Future<void> _openFilterSheet() async {
    final picked = await JobFilterSheet.show(
      context,
      selection: _selection,
      categories: context.read<JobCategoryProvider>().categories,
      hasLocation: _currentLatLng != null,
      showSort: true,
    );
    if (picked == null || !mounted) return;

    setState(() => _selection = picked);
    _jobs.setSort(picked.sort);
    final window = picked.startOn?.toWindow();
    _jobs.setStartWindow(
      startFrom: window?.startFrom,
      startTo: window?.startTo,
    );
  }

  /// Metin sunucuya gider ve mevcut kutuyla süzülür.
  void _onMapSearch(String query) {
    _jobs.setSearchText(query.trim());
  }

  void _focusOnJob(Job job) {
    _searchFocusNode.unfocus();

    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    searchProvider.stopSearching();
    _searchController.clear();
    _jobs.setSearchText('');

    // Koordinatsız ilanda kamera oynamaz.
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

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        JobDetailBottomSheet.show(context, job);
      }
    });
  }

  void _onJobMarkerTap(Job job) {
    HapticFeedback.lightImpact();
    JobDetailBottomSheet.show(context, job);
  }

  @override
  bool get wantKeepAlive => true;
}
