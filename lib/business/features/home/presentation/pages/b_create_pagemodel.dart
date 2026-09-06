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

  /// Ücret alanından çıkarken art arda gelen odak/değer olaylarını tek fiyat
  /// isteğinde birleştiren kısa bekleme.
  static const Duration _pricingDebounce = Duration(milliseconds: 350);

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _priceFocusNode = FocusNode();
  final _sectorController = TextEditingController();
  final _positionController = TextEditingController();
  final _dutiesController = TextEditingController();
  final _dressCodeController = TextEditingController();
  final _minAgeController = TextEditingController();
  final _maxAgeController = TextEditingController();

  final _addressController = CanonicalAddressFormController();

  /// Kategoriler `/reference/job-categories`'ten geldiği için başlangıçta
  /// seçili kategori yok; kullanıcı listeden seçiyor.
  JobCategory? _selectedCategory;
  JobType _selectedType = JobType.oneTime;
  SalaryType _selectedSalaryType = SalaryType.daily;
  bool _experienceRequired = false;

  /// Kullanıcının sigorta anahtarında bıraktığı tercih.
  ///
  /// İsteğe giden değer bu değil [_insuranceRequired]: kategori sigortayı
  /// zorunlu kılıyorsa tercih ne olursa olsun `true` gidiyor. İkisi ayrı
  /// duruyor ki kilit kalktığında kullanıcının kendi tercihi geri gelsin.
  bool _insurancePreference = false;

  DateTime? _startDateTime;
  DateTime? _endDateTime;

  bool _isSubmitting = false;

  BPricingBreakdown? _pricingBreakdownValue;
  bool _isLoadingPricing = false;
  bool _pricingUnavailable = false;
  Timer? _pricingTimer;
  int _pricingGeneration = 0;

  BPaymentService get _paymentService =>
      widget.paymentService ?? BPaymentService();

  /// Uygulanan şablonun adı; hiç uygulanmadıysa `null`. Düğmenin metnini ve
  /// "adres ile tarih dahil değil" bilgisini bu belirliyor.
  String? _appliedTemplateName;

  /// Şablon listesi çekiliyor mu; düğme o sırada kilitli.
  bool _isLoadingTemplates = false;

  /// Başarı kutusunu açar. Gövdesi arayüz tarafında ([BCreatePage]).
  void _showSuccessDialog();

  @override
  void initState() {
    super.initState();
    _priceFocusNode.addListener(_onPriceFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<JobCategoryProvider>().load();
      // Şirket bilgisi `/users/me`'den geliyor ve ilanın kurumsal mı bireysel
      // mi açılacağını o belirliyor; ekran açılırken elde olmalı.
      final userProvider = context.read<UserProvider>();
      if (userProvider.user == null) userProvider.load(silent: true);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _priceFocusNode
      ..removeListener(_onPriceFocusChanged)
      ..dispose();
    _pricingTimer?.cancel();
    _addressController.dispose();
    _sectorController.dispose();
    _positionController.dispose();
    _dutiesController.dispose();
    _dressCodeController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    super.dispose();
  }

  /// İlanın şirket adına mı açılacağı.
  ///
  /// Sigorta kuralı buna bağlı: bireysel ilan sunucuda `insuranceRequired`'ı
  /// zorla `false` yazıyor ve sigorta gerektiren bir kategoride bireysel ilan
  /// açılmasını hiç kabul etmiyor.
  bool get _isCompanyJob =>
      context.read<UserProvider>().user?.activeCompany != null;

  /// Sigorta anahtarı kilitli mi: seçilen kategori sigortalı çalışma
  /// gerektiriyor ve ilan şirket adına açılıyor.
  ///
  /// Sunucu bu durumda `insuranceRequired=false` gelen ilanı `400` ile geri
  /// çeviriyor (`JobManager`), yani anahtarın kapatılabilir olması kullanıcıyı
  /// formu doldurup en sonda hataya bırakıyordu.
  ///
  /// Değer **türetiliyor, saklanmıyor**: kategori seçiminde elle güncellenen
  /// bir alan tam olarak bu hatayı doğurmuştu (is-koala/koala#24) — kategoriyi
  /// değiştiren her yolun (seçici, şablon) alanı güncellemeyi hatırlaması
  /// gerekirdi, biri unutulduğunda kural sessizce düşüyordu.
  bool get _insuranceLocked =>
      _selectedCategory?.requiresInsurance == true && _isCompanyJob;

  /// İsteğe konacak sigorta değeri. Kilitliyken kullanıcının tercihi
  /// dinlenmiyor.
  bool get _insuranceRequired => _insuranceLocked || _insurancePreference;

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

  // --------------------------------------------------------------- Şablon

  /// Şablon listesini açar ve seçileni forma uygular.
  ///
  /// Liste sunucudan bir kez çekiliyor. Boşken sheet açmak yerine nasıl
  /// şablon oluşturulacağını söylemek gerekiyor: şablon bu formdan değil,
  /// yayınlanmış bir ilanın detayından çıkarılıyor.
  Future<void> _pickTemplate() async {
    if (_isLoadingTemplates) return;

    final provider = context.read<BJobTemplatesProvider>();

    setState(() => _isLoadingTemplates = true);
    await provider.load();
    if (!mounted) return;
    setState(() => _isLoadingTemplates = false);

    final error = provider.errorMessage;
    if (error != null) {
      AppToast.error(context, error);
      return;
    }

    if (provider.templates.isEmpty) {
      AppToast.info(
        context,
        'Henüz şablonunuz yok. Yayınladığınız bir ilanın detayından '
        '"Şablon olarak kaydet" ile oluşturabilirsiniz.',
      );
      return;
    }

    final picked = await BOptionSheet.show<JobTemplate>(
      context,
      title: 'Şablondan doldur',
      options: provider.templates,
      labelOf: (template) => template.templateName,
    );

    if (picked == null || !mounted) return;

    _applyTemplate(picked);
  }

  /// Şablonu form alanlarına yazar.
  ///
  /// **Adres ve tarih alanlarına dokunulmuyor** — sunucu da taşımıyor, çünkü
  /// aynı ilan bir sonraki hafta başka güne ve çoğu zaman başka adrese
  /// açılıyor. Kategori ile sigortanın bu işverende ne olacağına
  /// [JobTemplate.applyFor] karar veriyor; düşen bir alan varsa uyarı
  /// yazılıyor, sessizce değiştirilmiyor.
  void _applyTemplate(JobTemplate template) {
    final applied = template.applyFor(isCompanyJob: _isCompanyJob);

    setState(() {
      _titleController.text = template.title ?? '';
      _descriptionController.text = template.description ?? '';
      _sectorController.text = template.sector ?? '';
      _positionController.text = template.position ?? '';
      _dutiesController.text = template.duties ?? '';
      _dressCodeController.text = template.dressCode ?? '';
      _priceController.text = _salaryText(template.salary);
      _minAgeController.text = template.minAge?.toString() ?? '';
      _maxAgeController.text = template.maxAge?.toString() ?? '';

      _selectedCategory = applied.category;
      _selectedType = template.type;
      _selectedSalaryType = template.salaryType;
      _experienceRequired = template.experienceRequired;
      _insurancePreference = applied.insuranceRequired;

      _appliedTemplateName = template.templateName;
    });

    _schedulePricingQuote();

    final warning = applied.warning;
    if (warning != null) {
      AppToast.info(context, warning);
    }
  }

  /// Ücreti alana yazılabilir metne çeviriyor.
  ///
  /// Tam sayı ücrette ondalık gösterme: `1500.0` yerine `1500`. Küsuratlı
  /// ücret olduğu gibi kalıyor, alan onu `double.tryParse` ile geri okuyor.
  static String _salaryText(double? salary) {
    if (salary == null) return '';
    if (salary == salary.roundToDouble()) return salary.toStringAsFixed(0);
    return '$salary';
  }

  void _onPriceChanged(String _) {
    _pricingGeneration++;
    _pricingTimer?.cancel();
    if (_pricingBreakdownValue == null && !_pricingUnavailable) return;
    setState(() {
      _pricingBreakdownValue = null;
      _pricingUnavailable = false;
    });
  }

  void _onPriceFocusChanged() {
    if (!_priceFocusNode.hasFocus) _schedulePricingQuote();
  }

  void _schedulePricingQuote() {
    _pricingTimer?.cancel();
    final workerPayout = _normalizedWorkerPayout;
    if (workerPayout == null) {
      if (_pricingBreakdownValue != null || _pricingUnavailable) {
        setState(() {
          _pricingBreakdownValue = null;
          _pricingUnavailable = false;
        });
      }
      return;
    }

    final generation = ++_pricingGeneration;
    _pricingTimer = Timer(_pricingDebounce, () {
      _loadPricing(workerPayout, generation);
    });
  }

  String? get _normalizedWorkerPayout {
    final value = _priceController.text.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.\d+)?$').firstMatch(value);
    if (match == null) return null;

    final wholePart = match.group(1)!;
    final isAtLeastOne = wholePart.contains(RegExp(r'[1-9]'));
    return isAtLeastOne ? value : null;
  }

  Future<void> _loadPricing(String workerPayout, int generation) async {
    if (!mounted || generation != _pricingGeneration) return;
    setState(() {
      _isLoadingPricing = true;
      _pricingUnavailable = false;
    });

    try {
      final breakdown = await _paymentService.quote(workerPayout);
      if (!mounted || generation != _pricingGeneration) return;
      setState(() => _pricingBreakdownValue = breakdown);
    } on ApiException {
      if (!mounted || generation != _pricingGeneration) return;
      setState(() {
        _pricingBreakdownValue = null;
        _pricingUnavailable = true;
      });
    } finally {
      if (mounted && generation == _pricingGeneration) {
        setState(() => _isLoadingPricing = false);
      }
    }
  }

  /// Haritadan koordinat seçtirir.
  Future<LatLng?> _pickAddressPosition(LatLng? initialPosition) {
    return context.push<LatLng>(
      '/business/pick-location',
      extra: initialPosition,
    );
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

  /// Bireysel ilan açan işverenin kimliği doğrulanmış mı.
  ///
  /// Şirket adına açılan ilanda gerekmiyor: şirket kurmak zaten kimlik
  /// doğrulaması istiyor ve ödemede alıcı kimliği şirketin VKN'si oluyor.
  /// Bireysel ilanda ise alıcı kimliği işverenin TCKN'si ve o yalnızca
  /// doğrulamayla dolduruluyor.
  bool get _needsIdentityVerification {
    if (_isCompanyJob) return false;

    return context.read<UserProvider>().user?.identityVerified != true;
  }

  /// Kimlik doğrulama ekranına yönlendirir.
  Future<void> _goToIdentityVerification() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    await context.push('/identity-verification', extra: user);
    // Doğrulama yapıldıysa uyarı kutusunun kalkması için kullanıcı
    // tazeleniyor.
    if (mounted) await context.read<UserProvider>().load(silent: true);
  }

  /// Formu doğrular ve ilanı açar.
  ///
  /// Doğrulama burada da yapılıyor çünkü backend'in reddi tek bir alan adı
  /// döndürüyor; kullanıcıya eksik alanı Türkçe ve sırayla söylemek daha
  /// anlaşılır.
  Future<void> _createJob() async {
    if (_isSubmitting) return;

    // Sunucuda bu kontrol yok: doğrulanmamış bireysel işverenin ilanı
    // açılıyor, hata ancak bir adayı kabul ettiğinde İyzico'dan anlaşılmaz
    // bir mesajla geliyor. Kapıyı burada tutmak, kullanıcıyı işin en kötü
    // anında şaşırtmaktan iyi.
    if (_needsIdentityVerification) {
      await _showIdentityRequired();
      return;
    }

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

  Future<void> _showIdentityRequired() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Kimlik doğrulaması gerekli',
      message:
          'Bireysel ilan açabilmek ve çalışana ödeme yapabilmek için '
          'kimliğinizi doğrulamanız gerekiyor. Doğrulama birkaç dakika '
          'sürüyor ve bir kez yapılıyor.',
      actionLabel: 'Doğrula',
      // Yıkıcı bir işlem değil, yönlendirme: kırmızı düğme yanlış sinyal.
      isDestructive: false,
    );

    if (confirmed != true || !mounted) return;

    await _goToIdentityVerification();
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
    // Şirket ilanında son savunma. [_insuranceRequired] kategoriden
    // türetildiği için buraya normalde düşülmüyor; anahtar tarafındaki kural
    // ileride bozulursa istek sunucuya hiç gitmesin diye duruyor.
    if (category.requiresInsurance && !_insuranceRequired) {
      return _warn('Bu kategoride sigortalı çalışma zorunlu');
    }

    final position = _positionController.text.trim();
    if (position.isEmpty) return _warn('Pozisyon zorunlu');

    final description = _descriptionController.text.trim();
    if (description.isEmpty) return _warn('Açıklama zorunlu');

    final salary = _normalizedWorkerPayout;
    if (salary == null) {
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

    final address = _addressController.value;
    if (address == null) {
      return _warn(
        _addressController.validationMessage ?? 'Adres bilgilerini tamamlayın',
      );
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
      address: address,
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
