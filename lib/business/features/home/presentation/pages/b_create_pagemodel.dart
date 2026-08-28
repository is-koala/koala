part of 'b_create_page.dart';

abstract class BCreatePageModel extends State<BCreatePage> {
  /// Açıklama alanının yüksekliği: yaklaşık dört satır.
  static const double _descriptionHeight = 120;

  /// Başarı diyaloğundaki tik dairesi.
  static const double _successCircleSize = 72;
  static const double _successIconSize = 48;

  /// Yaş alanlarının kabul ettiği aralık. Alt sınır backend'in `@Min(1)`
  /// kuralı, üst sınır tipografik bir emniyet: üç haneli yaş kabul etmiyoruz.
  static const int _minAllowedAge = 15;
  static const int _maxAllowedAge = 99;

  /// İlanın varsayılan başlangıcı: yarın. Bugünün geçmiş bir saatine ilan
  /// açılmasın diye tarih seçici de bugünden öncesini kapatıyor.
  static const Duration _defaultStartOffset = Duration(days: 1);

  /// Başlangıç seçildiğinde bitişin varsayılan olarak kaydırıldığı süre.
  static const Duration _defaultShiftDuration = Duration(hours: 8);

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressLineController = TextEditingController();
  final _sectorController = TextEditingController();
  final _positionController = TextEditingController();
  final _dutiesController = TextEditingController();
  final _dressCodeController = TextEditingController();
  final _minAgeController = TextEditingController();
  final _maxAgeController = TextEditingController();

  final _referenceService = ReferenceLocationService();

  /// Kategoriler `/reference/job-categories`'ten geldiği için başlangıçta
  /// seçili kategori yok; kullanıcı listeden seçiyor.
  JobCategory? _selectedCategory;
  JobType _selectedType = JobType.oneTime;
  SalaryType _selectedSalaryType = SalaryType.daily;
  bool _experienceRequired = false;
  bool _insuranceRequired = false;

  DateTime? _startDateTime;
  DateTime? _endDateTime;

  List<ReferenceLocation> _countries = const [];
  List<ReferenceLocation> _cities = const [];
  List<ReferenceLocation> _districts = const [];

  ReferenceLocation? _selectedCountry;
  ReferenceLocation? _selectedCity;
  ReferenceLocation? _selectedDistrict;

  bool _loadingCountries = false;
  bool _loadingCities = false;
  bool _loadingDistricts = false;

  /// Haritadan seçilen koordinat. Backend bunu zorunlu tuttuğu için ilan
  /// bu değer olmadan yayınlanamıyor.
  LatLng? _pickedLocation;

  bool _isSubmitting = false;

  /// Başarı kutusunu açar. Gövdesi arayüz tarafında ([BCreatePage]).
  void _showSuccessDialog();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<JobCategoryProvider>().load();
      // Şirket bilgisi `/users/me`'den geliyor ve ilanın kurumsal mı bireysel
      // mi açılacağını o belirliyor; ekran açılırken elde olmalı.
      final userProvider = context.read<UserProvider>();
      if (userProvider.user == null) userProvider.load(silent: true);
      _loadCountries();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressLineController.dispose();
    _sectorController.dispose();
    _positionController.dispose();
    _dutiesController.dispose();
    _dressCodeController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------- Referans veriler

  /// Ülkeleri çeker ve tek ülke varsa onu seçip illerini de yükler.
  ///
  /// Bugün sunucuda yalnızca Türkiye tanımlı; kullanıcıyı tek seçenekli bir
  /// listeye sokmamak için o durumda seçim kendiliğinden yapılıyor.
  Future<void> _loadCountries() async {
    setState(() => _loadingCountries = true);

    try {
      final countries = await _referenceService.fetchCountries();
      if (!mounted) return;

      setState(() {
        _countries = countries;
        _loadingCountries = false;
      });

      if (countries.length == 1) await _selectCountry(countries.first);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loadingCountries = false);
      AppToast.error(context, error.message);
    }
  }

  Future<void> _selectCountry(ReferenceLocation country) async {
    setState(() {
      _selectedCountry = country;
      // Ülke değişti: altındaki seçimler artık geçerli değil.
      _selectedCity = null;
      _selectedDistrict = null;
      _cities = const [];
      _districts = const [];
      _loadingCities = true;
    });

    try {
      final cities = await _referenceService.fetchCities(country.id);
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _loadingCities = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loadingCities = false);
      AppToast.error(context, error.message);
    }
  }

  Future<void> _selectCity(ReferenceLocation city) async {
    setState(() {
      _selectedCity = city;
      _selectedDistrict = null;
      _districts = const [];
      _loadingDistricts = true;
    });

    try {
      final districts = await _referenceService.fetchDistricts(city.id);
      if (!mounted) return;
      setState(() {
        _districts = districts;
        _loadingDistricts = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loadingDistricts = false);
      AppToast.error(context, error.message);
    }
  }

  // ------------------------------------------------------------------ Seçimler

  /// Ülke / il / ilçe listesinden tek seçim yaptırır.
  Future<void> _pickReference({
    required String title,
    required List<ReferenceLocation> options,
    required ReferenceLocation? selected,
    required ValueChanged<ReferenceLocation> onSelected,
  }) async {
    final picked = await BOptionSheet.show<ReferenceLocation>(
      context,
      title: title,
      options: options,
      selected: selected,
      labelOf: (option) => option.name,
    );

    if (picked != null) onSelected(picked);
  }

  /// İlanın şirket adına mı açılacağı.
  ///
  /// Sigorta kuralı buna bağlı: bireysel ilan sunucuda `insuranceRequired`'ı
  /// zorla `false` yazıyor ve sigorta gerektiren bir kategoride bireysel ilan
  /// açılmasını hiç kabul etmiyor.
  bool get _isCompanyJob =>
      context.read<UserProvider>().user?.activeCompany != null;

  /// Seçilebilir kategoriler.
  ///
  /// Bireysel işverende sigorta zorunlu kategoriler eleniyor: sunucu o
  /// kategoride bireysel ilanı `400` ile geri çeviriyor (SGK bildirimi
  /// işverenin yükümlülüğü, bir günlük iş için bireysel işverenden
  /// beklenmiyor). Listeden çıkarmak, kullanıcıyı formu doldurup en sonda
  /// hata almaya bırakmaktan iyi.
  List<JobCategory> get _selectableCategories {
    final categories = context.read<JobCategoryProvider>().categories;
    if (_isCompanyJob) return categories;

    return categories.where((category) => !category.requiresInsurance).toList();
  }

  /// Kategoriyi seçtirir.
  ///
  /// Kategoriler `/reference/job-categories`'ten geliyor ve sayısı artabilir;
  /// bu yüzden çip dizisi değil, il seçimiyle aynı açılır liste.
  Future<void> _pickCategory() async {
    final picked = await BOptionSheet.show<JobCategory>(
      context,
      title: 'Kategori',
      options: _selectableCategories,
      selected: _selectedCategory,
      labelOf: (category) => category.displayName,
      iconOf: (category) => category.icon,
      colorOf: (category) => category.color,
    );

    if (picked != null && mounted) {
      setState(() => _selectedCategory = picked);
    }
  }

  /// Haritadan koordinat seçtirir.
  Future<void> _pickLocation() async {
    final picked = await context.push<LatLng>(
      '/business/pick-location',
      extra: _pickedLocation,
    );

    if (picked != null && mounted) {
      setState(() => _pickedLocation = picked);
    }
  }

  /// Tarih ve saati birlikte seçtirir; ikisinden biri iptal edilirse hiçbir
  /// şey değişmiyor.
  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final base = initial ?? now.add(_defaultStartOffset);

    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStartDateTime() async {
    final picked = await _pickDateTime(_startDateTime);
    if (picked == null || !mounted) return;

    setState(() {
      _startDateTime = picked;
      // Bitiş başlangıçtan önce kaldıysa anlamsız; makul bir vardiya kadar
      // ileri alınıyor, kullanıcı yine de değiştirebiliyor.
      final end = _endDateTime;
      if (end == null || !end.isAfter(picked)) {
        _endDateTime = picked.add(_defaultShiftDuration);
      }
    });
  }

  Future<void> _pickEndDateTime() async {
    final picked = await _pickDateTime(_endDateTime ?? _startDateTime);
    if (picked == null || !mounted) return;

    setState(() => _endDateTime = picked);
  }

  // -------------------------------------------------------------- Yayınlama

  /// Formu doğrular ve ilanı açar.
  ///
  /// Doğrulama burada da yapılıyor çünkü backend'in reddi tek bir alan adı
  /// döndürüyor; kullanıcıya eksik alanı Türkçe ve sırayla söylemek daha
  /// anlaşılır.
  Future<void> _createJob() async {
    if (_isSubmitting) return;

    final request = _buildRequest();
    if (request == null) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<BJobsProvider>();
    final company = context.read<UserProvider>().user?.activeCompany;

    final created = await provider.createJobPost(
      request,
      companyId: company?.companyId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (created) {
      _showSuccessDialog();
    } else {
      AppToast.error(context, provider.errorMessage ?? 'İlan oluşturulamadı');
    }
  }

  /// Alanları doğrulayıp isteği kurar; eksik varsa uyarıp `null` döner.
  CreateJobRequest? _buildRequest() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return _warn('İlan başlığı zorunlu');

    final category = _selectedCategory;
    if (category == null) return _warn('Bir kategori seçin');
    // Seçici zaten elemiş olmalı; sunucudan `400` almaktansa burada anlaşılır
    // bir mesaj vermek daha iyi.
    if (category.requiresInsurance && !_isCompanyJob) {
      return _warn('Bu kategoride ilan yalnızca şirket adına açılabilir');
    }

    final position = _positionController.text.trim();
    if (position.isEmpty) return _warn('Pozisyon zorunlu');

    final description = _descriptionController.text.trim();
    if (description.isEmpty) return _warn('Açıklama zorunlu');

    final salary = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );
    if (salary == null || salary < 1) {
      return _warn('Geçerli bir ücret girin');
    }

    final start = _startDateTime;
    final end = _endDateTime;
    if (start == null) return _warn('Başlangıç tarihini seçin');
    if (end == null) return _warn('Bitiş tarihini seçin');
    if (!end.isAfter(start)) {
      return _warn('Bitiş, başlangıçtan sonra olmalı');
    }

    final minAge = int.tryParse(_minAgeController.text.trim());
    final maxAge = int.tryParse(_maxAgeController.text.trim());
    if (minAge == null || maxAge == null) return _warn('Yaş aralığını girin');
    if (minAge < _minAllowedAge || maxAge > _maxAllowedAge) {
      return _warn('Yaş $_minAllowedAge ile $_maxAllowedAge arasında olmalı');
    }
    if (maxAge < minAge) {
      return _warn('Üst yaş sınırı alt sınırdan küçük olamaz');
    }

    final country = _selectedCountry;
    final city = _selectedCity;
    if (country == null) return _warn('Ülke seçin');
    if (city == null) return _warn('İl seçin');

    final addressLine = _addressLineController.text.trim();
    if (addressLine.isEmpty) return _warn('Açık adres zorunlu');

    final location = _pickedLocation;
    if (location == null) {
      return _warn('İlanın konumunu haritadan seçin');
    }

    return CreateJobRequest(
      categoryId: category.id,
      title: title,
      description: description,
      position: position,
      sector: _trimmedOrNull(_sectorController),
      duties: _trimmedOrNull(_dutiesController),
      dressCode: _trimmedOrNull(_dressCodeController),
      type: _selectedType,
      salaryType: _selectedSalaryType,
      salary: salary,
      startDateTime: start,
      endDateTime: end,
      minAge: minAge,
      maxAge: maxAge,
      experienceRequired: _experienceRequired,
      insuranceRequired: _insuranceRequired,
      address: CreateJobAddress(
        countryCode: country.code ?? '',
        cityName: city.name,
        districtName: _selectedDistrict?.name,
        addressLine: addressLine,
        latitude: location.latitude,
        longitude: location.longitude,
      ),
    );
  }

  /// Uyarıyı gösterip `null` döner; `return _warn(...)` yazılabilsin diye.
  CreateJobRequest? _warn(String message) {
    AppToast.error(context, message);
    return null;
  }

  /// Boş bırakılmış alanı `null`'a çeviriyor; sunucu boş metni de değer
  /// sayıyor, o yüzden hiç göndermemek gerekiyor.
  static String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }
}
