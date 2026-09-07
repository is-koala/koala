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
  /// İki işi var: kartlardaki mesafe satırı ve mesafe süzgecinin sınırlayıcı
  /// kutusu. İzin yoksa mesafe süzgeci sheet'te kapalı çiziliyor ve izin
  /// istemeyi öneriyor — bkz. [_requestLocation].
  Future<void> _resolvePosition() async {
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (_) {
      position = null;
    }

    if (!mounted) return;
    setState(() => _currentPosition = position);
  }

  /// İlana olan uzaklık, km. Konum izni yoksa ya da ilanın koordinatı
  /// yoksa `null` — mesafe satırı o zaman hiç çizilmiyor.
  double? _getDistance(Job job) {
    if (_currentPosition == null || !job.hasLocation) return null;
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      job.latitude!,
      job.longitude!,
    );
    return distance / 1000; // km'ye çevir
  }

  /// Ekrana çizilecek liste.
  ///
  /// Mesafeye göre sıralama **yalnız mesafe süzgeci seçiliyken** uygulanıyor.
  /// Sunucuda mesafe sıralaması yok (`SORTABLE_FIELDS` dört alan taşıyor), yani
  /// bu sıralama o ana kadar yüklenmiş sayfaların üzerinde çalışıyor ve yeni
  /// sayfa geldikçe kartlar yer değiştiriyor. Süzgeç açıkken sonuç zaten
  /// kullanıcının çevresindeki kutuyla sınırlı olduğu için sıralama orada
  /// anlamlı; süzgeç kapalıyken sunucunun `createdAt DESC` sırası korunuyor,
  /// aksi hâlde liste sebepsiz yere gözün önünde karışırdı.
  List<Job> _visibleJobs(List<Job> jobs) {
    if (_selection.radiusKm == null || _currentPosition == null) return jobs;

    final origin = _currentPosition!;
    // Koordinatı olmayan ilanlar sona düşüyor: uzaklıkları bilinmiyor, en
    // yakın diye göstermek yanlış olur.
    return [...jobs]..sort(
      (a, b) => _rawDistance(origin, a).compareTo(_rawDistance(origin, b)),
    );
  }

  static double _rawDistance(Position origin, Job job) {
    if (!job.hasLocation) return double.infinity;
    return Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      job.latitude!,
      job.longitude!,
    );
  }

  // ------------------------------------------------------------------- Arama

  void _onSearchChanged(String query) {
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
    final picked = await JobSortSheet.show(context, selected: _selection.sort);
    if (picked == null || !mounted) return;

    setState(() => _selection = _selection.copyWith(sort: picked));
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
