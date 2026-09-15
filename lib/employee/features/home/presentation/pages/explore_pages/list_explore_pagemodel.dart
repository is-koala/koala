part of 'list_explore_page.dart';

abstract class ListExplorePagemodel extends State<ListExplorePage>
    with AutomaticKeepAliveClientMixin<ListExplorePage> {
  bool isOpen = true;

  /// Listenin sonuna bu kadar kala sonraki sayfa isteniyor; kullanıcı dibe
  /// değmeden yükleme başlasın. `NotificationView` ile aynı eşik.
  static const double _loadMoreThreshold = 240;

  /// Arama kutusunda yazımın durmasını bu kadar bekliyoruz.
  ///
  /// Her tuşta istek atmak `GET /jobs`'un PUBLIC kovasındaki dakikada 120
  /// istek sınırını tek aramada tüketebiliyor.
  static const Duration _searchDebounce = Duration(milliseconds: 400);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _searchTimer;
  Position? _currentPosition;

  /// Süzgeç sheet'inin uygulanmış hâli.
  ///
  /// Sunucu sorgusu bundan **türetiliyor** ([JobFilterSelection.toQuery]);
  /// tersi mümkün değil, çünkü sorgu kategorinin adını ya da kullanıcının
  /// seçtiği kilometreyi taşımıyor — sınırlayıcı kutudan yarıçapa geri
  /// dönülemez. Çubuktaki çipler bu seçimden çiziliyor.
  JobFilterSelection _selection = const JobFilterSelection();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _resolvePosition();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Filtre sheet'i açıldığında kategoriler hazır olsun; provider aynı
      // listeyi ikinci kez çekmiyor.
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

  /// Konumu bir kez okur.
  ///
  /// İki işi var: `lat`/`lng` (kartın `distanceKm`'si ve yakınlık sıralaması)
  /// ve mesafe süzgecinin sınırlayıcı kutusu. İzin yoksa mesafe süzgeci ve
  /// "En yakın" kapalı çiziliyor — bkz. [_requestLocation].
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

  /// Parametre almıyor: aranan metni `_searchController` zaten tutuyor ve
  /// [_buildQuery] onu oradan okuyor. `onChanged`'in verdiği dizeyi ikinci bir
  /// kaynak olarak taşımak, ikisinin ayrışabileceği bir yer açardı.
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

  /// Arayüzdeki seçimleri tek bir sunucu sorgusuna çevirir.
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

  /// Süzgeç sheet'ini açar. Sheet yalnız "Uygula"ya basılırsa değer döndürüyor;
  /// vazgeçilerek kapatıldığında sorgu olduğu gibi kalıyor.
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

  /// Çubuktaki çipin çarpısı: yalnız o alanı temizliyor.
  void _removeFilter(JobFilterField field) {
    setState(() => _selection = _selection.without(field));
    _applyQuery();
  }

  /// Bütün süzgeçleri sıfırlar; boş sonuç ekranındaki çıkış da buna bağlı.
  void _clearFilters() {
    setState(() => _selection = _selection.cleared());
    _applyQuery();
  }

  /// Konum iznini ister ve alınırsa konumu tazeler.
  ///
  /// Mesafe süzgeci izin olmadan çalışamıyor; eskiden bu durumda süzgeç
  /// sessizce yok sayılıyordu.
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
