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

  /// Süzgeç çubuğundaki "hiçbiri" anahtarı.
  static const String _all = 'all';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _searchTimer;
  Position? _currentPosition;

  /// Süzgeç sheet'lerinin **kova anahtarları**.
  ///
  /// Sunucu kova bilmiyor: ücret `minSalary`/`maxSalary` çifti, mesafe ise
  /// sınırlayıcı kutu olarak gidiyor. Kovalar arayüzün kendi kavramı olduğu
  /// için burada duruyor ve [_buildQuery] tek noktada çeviriyor — sorgu
  /// modeline kova dizesi girmiyor.
  ///
  /// [_selectedCategory] üç şeyden biri: `_all`, bir [JobType] anahtarı ya da
  /// bir kategorinin **id**'si. Kategori sunucuya `categoryId` ile gidiyor;
  /// `code` yalnızca ikon/renk eşlemesinde kalıyor.
  String _selectedCategory = _all;
  String _selectedPriceRange = _all;
  String _selectedDistance = _all;

  // Geçici süzgeçler: sheet açıkken seçilenler, "Uygula"ya kadar sayfaya
  // yansımıyor.
  String _tempCategory = _all;
  String _tempPriceRange = _all;
  String _tempDistance = _all;

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
  /// kutusu. İzin yoksa ikisi de sessizce devre dışı kalıyor — süzgecin izin
  /// istemesi is-koala/koala#32'nin işi.
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
    if (_selectedDistance == _all || _currentPosition == null) return jobs;

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

  // ----------------------------------------------------------------- Süzgeçler

  /// Arayüzdeki seçimleri tek bir sunucu sorgusuna çevirir.
  JobSearchQuery _buildQuery() {
    final (minSalary, maxSalary) = _salaryRange;

    var query = JobSearchQuery(
      query: _searchController.text,
      categoryId: _categoryId,
      type: _jobType,
      minSalary: minSalary,
      maxSalary: maxSalary,
    );

    final radiusKm = _radiusKm;
    final position = _currentPosition;
    if (radiusKm != null && position != null) {
      query = query.withRadius(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: radiusKm,
      );
    }

    return query;
  }

  void _applyQuery() {
    if (!mounted) return;
    _search.applyQuery(_buildQuery());
  }

  /// Kategori süzgecinin sunucuya giden değeri.
  ///
  /// Tür anahtarları (`oneTime` / `recurring`) kategori değil; onlar [_jobType]
  /// üzerinden `type` alanına gidiyor.
  String? get _categoryId {
    if (_selectedCategory == _all) return null;
    if (_jobTypeKeys.containsKey(_selectedCategory)) return null;
    return _selectedCategory;
  }

  JobType? get _jobType => _jobTypeKeys[_selectedCategory];

  static final Map<String, JobType> _jobTypeKeys = {
    for (final type in JobType.values) type.name: type,
  };

  /// Ücret kovasının sunucu karşılığı. Üst sınırı olmayan kova `maxSalary`
  /// göndermiyor.
  (double?, double?) get _salaryRange => switch (_selectedPriceRange) {
    '0-500' => (null, 500),
    '500-1000' => (500, 1000),
    '1000-2000' => (1000, 2000),
    '2000+' => (2000, null),
    _ => (null, null),
  };

  /// Mesafe kovasının yarıçapı, km.
  ///
  /// Kovalar "X km içinde" biçiminde: sunucu sınırlayıcı kutu süzüyor, kutu ise
  /// "şu halkanın dışı" diye bir şey ifade edemiyor. Eski "20+ km" kovası bu
  /// yüzden kaldırıldı — istemcide kalsaydı yalnız yüklenmiş sayfalar üzerinde
  /// çalışıp sayfalandıkça yanlış sonuç verirdi.
  double? get _radiusKm => switch (_selectedDistance) {
    '0-5' => 5,
    '0-10' => 10,
    '0-20' => 20,
    _ => null,
  };

  void _showCategoryFilter() {
    _tempCategory = _selectedCategory;
  }

  void _showPriceFilter() {
    _tempPriceRange = _selectedPriceRange;
  }

  void _showDistanceFilter() {
    _tempDistance = _selectedDistance;
  }

  /// Bütün süzgeçleri sıfırlar; boş sonuç ekranındaki çıkış buna bağlı.
  void _clearFilters() {
    setState(() {
      _selectedCategory = _all;
      _selectedPriceRange = _all;
      _selectedDistance = _all;
      _tempCategory = _all;
      _tempPriceRange = _all;
      _tempDistance = _all;
    });
    _applyQuery();
  }

  void _applyTempFilters() {
    setState(() {
      _selectedCategory = _tempCategory;
      _selectedPriceRange = _tempPriceRange;
      _selectedDistance = _tempDistance;
    });
    Navigator.pop(context);
    _applyQuery();
  }

  @override
  bool get wantKeepAlive => true;
}
