part of 'list_explore_page.dart';

abstract class ListExplorePagemodel extends State<ListExplorePage>
    with AutomaticKeepAliveClientMixin<ListExplorePage> {
  bool isOpen = true;
  List<Job> _jobs = [];
  List<Job> _filteredJobs = [];
  Position? _currentPosition;
  bool _loading = true;
  final JobService _jobService = JobService();

  // Arama
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Aktif filtreler
  String _selectedFilter = 'all';
  String _selectedPriceRange = 'all';
  String _selectedDistance = 'all';

  // Geçici filtreler (bottomsheet'te seçilenler)
  String _tempFilter = 'all';
  String _tempPriceRange = 'all';
  String _tempDistance = 'all';

  @override
  void initState() {
    super.initState();
    _loadJobsAndLocation();
    // Filtre sheet'i açıldığında kategoriler hazır olsun; provider aynı
    // listeyi ikinci kez çekmiyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<JobCategoryProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadJobsAndLocation() async {
    try {
      // İşleri yükle
      final jobs = await _jobService.getJobs();

      // Konumu al
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        // Konum alınamazsa varsayılan konum kullan
        position = null;
      }

      // Konuma göre sırala
      if (position != null) {
        jobs.sort((a, b) {
          final distA = Geolocator.distanceBetween(
            position!.latitude,
            position.longitude,
            a.latitude,
            a.longitude,
          );
          final distB = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            b.latitude,
            b.longitude,
          );
          return distA.compareTo(distB);
        });
      }

      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _filteredJobs = jobs;
        _currentPosition = position;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  double? _getDistance(Job job) {
    if (_currentPosition == null) return null;
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      job.latitude,
      job.longitude,
    );
    return distance / 1000; // km'ye çevir
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyAllFilters();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _applyAllFilters();
    });
  }

  void _applyAllFilters() {
    List<Job> filtered = _jobs;

    // Arama filtresi
    if (_searchQuery.trim().isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered.where((job) {
        return job.title.toLowerCase().contains(lowerQuery) ||
            job.subtitle.toLowerCase().contains(lowerQuery) ||
            (job.company?.toLowerCase().contains(lowerQuery) ?? false) ||
            job.category.displayName.toLowerCase().contains(lowerQuery) ||
            (job.address?.toLowerCase().contains(lowerQuery) ?? false) ||
            (job.sector?.toLowerCase().contains(lowerQuery) ?? false) ||
            (job.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }

    // Kategori ve tip filtresi
    if (_selectedFilter != 'all') {
      if (_selectedFilter == 'oneTime') {
        filtered = filtered
            .where((job) => job.type == JobType.oneTime)
            .toList();
      } else if (_selectedFilter == 'recurring') {
        filtered = filtered
            .where((job) => job.type == JobType.recurring)
            .toList();
      } else {
        // Geriye kalan tek seçenek kategori: filtre anahtarı kategorinin
        // backend'deki `code` değeri. Tanınmayan bir anahtar hiçbir işi
        // elemesin diye doğrudan kodla karşılaştırılıyor.
        filtered = filtered
            .where((job) => job.category.code == _selectedFilter)
            .toList();
      }
    }

    // Ücret aralığı filtresi
    if (_selectedPriceRange != 'all') {
      if (_selectedPriceRange == '0-500') {
        filtered = filtered.where((job) => job.price <= 500).toList();
      } else if (_selectedPriceRange == '500-1000') {
        filtered = filtered
            .where((job) => job.price > 500 && job.price <= 1000)
            .toList();
      } else if (_selectedPriceRange == '1000-2000') {
        filtered = filtered
            .where((job) => job.price > 1000 && job.price <= 2000)
            .toList();
      } else if (_selectedPriceRange == '2000+') {
        filtered = filtered.where((job) => job.price > 2000).toList();
      }
    }

    // Mesafe filtresi
    if (_selectedDistance != 'all' && _currentPosition != null) {
      if (_selectedDistance == '0-5') {
        filtered = filtered.where((job) {
          final distance = _getDistance(job);
          return distance != null && distance <= 5;
        }).toList();
      } else if (_selectedDistance == '5-10') {
        filtered = filtered.where((job) {
          final distance = _getDistance(job);
          return distance != null && distance > 5 && distance <= 10;
        }).toList();
      } else if (_selectedDistance == '10-20') {
        filtered = filtered.where((job) {
          final distance = _getDistance(job);
          return distance != null && distance > 10 && distance <= 20;
        }).toList();
      } else if (_selectedDistance == '20+') {
        filtered = filtered.where((job) {
          final distance = _getDistance(job);
          return distance != null && distance > 20;
        }).toList();
      }
    }

    _filteredJobs = filtered;
  }

  void _showCategoryFilter() {
    _tempFilter = _selectedFilter;
  }

  void _showPriceFilter() {
    _tempPriceRange = _selectedPriceRange;
  }

  void _showDistanceFilter() {
    _tempDistance = _selectedDistance;
  }

  void _applyTempFilters() {
    setState(() {
      _selectedFilter = _tempFilter;
      _selectedPriceRange = _tempPriceRange;
      _selectedDistance = _tempDistance;
      _applyAllFilters();
    });
    Navigator.pop(context);
  }

  @override
  bool get wantKeepAlive => true;
}
