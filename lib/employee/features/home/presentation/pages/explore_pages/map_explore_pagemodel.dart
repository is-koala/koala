part of 'map_explore_page.dart';

abstract class MapExplorePageModel extends State<MapExplorePage>
    with AutomaticKeepAliveClientMixin<MapExplorePage> {
  GoogleMapController? _mapController;
  late LocationService _locationService;
  late JobService _jobService;

  bool _loading = true;
  LatLng? _currentLatLng;
  final LatLng _defaultLatLng = const LatLng(39.925533, 32.866287);

  String _loadingMessage = 'Harita Yükleniyor...';

  // İş verileri
  Set<Marker> _markers = {};
  List<Job> _allJobs = [];
  List<Job> _searchResults = [];

  // Arama
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _jobService = JobService();

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
    _loadJobs();
  }

  /// İşleri yükle ve marker'ları oluştur
  Future<void> _loadJobs() async {
    try {
      final jobs = (await _jobService.search()).jobs;
      _allJobs = jobs;

      final markers = await JobMarkerGenerator.generateMarkers(
        jobs: jobs,
        onMarkerTap: _onJobMarkerTap,
      );

      if (!mounted) return;
      setState(() {
        _markers = markers;
      });
    } catch (e) {
      debugPrint('İşler yüklenirken hata: $e');
    }
  }

  /// Haritada arama yap
  void _onMapSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _searchResults = _allJobs.where((job) {
        return job.title.toLowerCase().contains(lowerQuery) ||
            job.subtitle.toLowerCase().contains(lowerQuery) ||
            (job.company?.toLowerCase().contains(lowerQuery) ?? false) ||
            job.category.displayName.toLowerCase().contains(lowerQuery) ||
            (job.locationLabel?.toLowerCase().contains(lowerQuery) ?? false) ||
            (job.sector?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    });
  }

  /// Arama sonucuna tıklanınca haritada o işe odaklan
  void _focusOnJob(Job job) {
    _searchFocusNode.unfocus();

    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    searchProvider.stopSearching();
    _searchController.clear();

    setState(() {
      _searchResults = [];
    });

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
  void dispose() {
    _locationService.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
