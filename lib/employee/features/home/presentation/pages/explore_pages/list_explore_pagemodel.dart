part of 'list_explore_page.dart';

abstract class ListExplorePagemodel extends State<ListExplorePage>
    with AutomaticKeepAliveClientMixin<ListExplorePage> {
  bool isOpen = true;

  /// Dibe değmeden yükleme başlasın.
  static const double _loadMoreThreshold = 240;

  /// Her tuşta istek dakikada 120'lik sınırı tek aramada tüketebilir.
  static const Duration _searchDebounce = Duration(milliseconds: 400);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _searchTimer;
  Position? _currentPosition;

  /// Süzgecin uygulanmış hâli; sorgu bundan türetiliyor, tersi mümkün değil
  /// (kutudan yarıçapa dönülemez).
  JobFilterSelection _selection = const JobFilterSelection();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _resolvePosition();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Süzgeç açıldığında kategoriler hazır olsun.
      context.read<JobCategoryProvider>().load();
      context.read<JobSearchProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  JobSearchProvider get _search => context.read<JobSearchProvider>();

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;

    if (remaining <= _loadMoreThreshold) _search.loadMore();
  }

  /// Konumu bir kez okur: `lat`/`lng` ve mesafe kutusu için. İzin yoksa mesafe
  /// süzgeci ve "En yakın" kapalı.
  Future<void> _resolvePosition() async {
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (_) {
      position = null;
    }

    if (!mounted) return;
    setState(() => _currentPosition = position);
    if (position != null) _applyQuery();
  }

  // ------------------------------------------------------------------- Arama

  /// Metin `_searchController`'dan okunuyor; ikinci kaynak ayrışabilirdi.
  void _onSearchChanged() {
    setState(() {}); // temizleme ikonu metne göre çiziliyor
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, _applyQuery);
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {});
    _applyQuery();
  }

  // --------------------------------------------------------------- Süzgeçler

  JobSearchQuery _buildQuery() {
    return _selection.toQuery(
      searchText: _searchController.text,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
    );
  }

  void _applyQuery() {
    if (!mounted) return;
    _search.applyQuery(_buildQuery());
  }

  /// Yalnız "Uygula"da değer döner; vazgeçilirse sorgu değişmez.
  Future<void> _openFilterSheet() async {
    final picked = await JobFilterSheet.show(
      context,
      selection: _selection,
      categories: context.read<JobCategoryProvider>().categories,
      hasLocation: _currentPosition != null,
      onRequestLocation: _requestLocation,
    );
    if (picked == null || !mounted) return;

    setState(() => _selection = picked);
    _applyQuery();
  }

  Future<void> _openSortSheet() async {
    final picked = await JobSortSheet.show(
      context,
      selected: _selection.sort,
      hasLocation: _currentPosition != null,
    );
    if (picked == null || !mounted) return;

    setState(() => _selection = _selection.copyWith(sort: picked));
    _applyQuery();
  }

  void _setStartOn(JobStartOn? startOn) {
    setState(() => _selection = _selection.copyWith(startOn: startOn));
    _applyQuery();
  }

  void _removeFilter(JobFilterField field) {
    setState(() => _selection = _selection.without(field));
    _applyQuery();
  }

  void _clearFilters() {
    setState(() => _selection = _selection.cleared());
    _applyQuery();
  }

  /// Mesafe süzgeci izinsiz çalışmaz; izin yoksa sessizce yok sayılmamalı.
  Future<bool> _requestLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    } catch (_) {
      return false;
    }

    await _resolvePosition();
    return _currentPosition != null;
  }

  @override
  bool get wantKeepAlive => true;
}
