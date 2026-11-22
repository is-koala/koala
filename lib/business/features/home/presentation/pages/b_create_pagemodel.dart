part of 'b_create_page.dart';

abstract class BCreatePageModel extends State<BCreatePage> {
  static const double _descriptionHeight = 120;

  static const double _successCircleSize = 72;
  static const double _successIconSize = 48;

  /// Alt sınır backend'in `@Min(1)`'inden sıkı; üst sınır üç haneyi engelliyor.
  static const int _minAllowedAge = 15;
  static const int _maxAllowedAge = 99;

  static const Duration _defaultShiftDuration = Duration(hours: 8);

  /// Art arda gelen odak/değer olayları tek fiyat isteği olsun.
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

  late ConfirmedAddress? _address = widget.initialAddress;

  /// Ulaşım taslağı (#197); ilan açıldıktan **sonra** ilanın kimliğiyle ayrıca
  /// yazılıyor.
  late TransportPlanDraft? _transport = widget.initialTransport;

  TransportService get _transportService =>
      widget.transportService ?? TransportService();

  JobCategory? _selectedCategory;
  JobType _selectedType = JobType.oneTime;
  SalaryType _selectedSalaryType = SalaryType.daily;
  bool _experienceRequired = false;

  /// Kullanıcının sigorta tercihi. İsteğe giden [_insuranceRequired]; ayrı
  /// tutuluyor ki kilit kalkınca tercih geri gelsin.
  bool _insurancePreference = false;

  /// "Adresi gizle"; varsayılan kapalı, yani tam konum açık. Bireysel ilanda
  /// isteğe girmiyor.
  bool _hideAddress = false;

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

  String? _appliedTemplateName;

  bool _isLoadingTemplates = false;

  /// [transportError] doluysa kutu planın yazılamadığını söyler ve ilan
  /// detayına götürür; toast kutunun altında kalırdı.
  void _showSuccessDialog({required String jobId, String? transportError});

  @override
  void initState() {
    super.initState();
    _priceFocusNode.addListener(_onPriceFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<JobCategoryProvider>().load();
      // İlanın kurumsal mı bireysel mi olduğunu `/users/me` belirliyor.
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
    _sectorController.dispose();
    _positionController.dispose();
    _dutiesController.dispose();
    _dressCodeController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    super.dispose();
  }

  /// Bireysel ilanda sunucu sigortayı `false` yazıyor ve sigortalı kategoriyi
  /// kabul etmiyor.
  bool get _isCompanyJob =>
      context.read<UserProvider>().user?.activeCompany != null;

  /// Sigorta anahtarı kilitli mi. Değer **türetiliyor, saklanmıyor**: elle
  /// güncellenen alan kategoriyi değiştiren bir yolda unutulup kuralı sessizce
  /// düşürmüştü (#24).
  bool get _insuranceLocked =>
      _selectedCategory?.requiresInsurance == true && _isCompanyJob;

  bool get _insuranceRequired => _insuranceLocked || _insurancePreference;

  /// Bireysel işverende sigorta zorunlu kategoriler eleniyor; sunucu onları
  /// `400` ile reddediyor.
  List<JobCategory> get _selectableCategories {
    final categories = context.read<JobCategoryProvider>().categories;
    if (_isCompanyJob) return categories;

    return categories.where((category) => !category.requiresInsurance).toList();
  }

  Future<void> _pickCategory() async {
    final picked = await OptionSheet.show<JobCategory>(
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

  /// Şablonu seçip uygular. Liste bir kez çekilir; boşken şablonun ilan
  /// detayından çıkarıldığı söylenir.
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

    final picked = await OptionSheet.show<JobTemplate>(
      context,
      title: 'Şablondan doldur',
      options: provider.templates,
      labelOf: (template) => template.templateName,
    );

    if (picked == null || !mounted) return;

    _applyTemplate(picked);
  }

  /// Şablonu forma yazar. **Adres ve tarih değişmez.** Kategori ve sigortaya
  /// [JobTemplate.applyFor] karar verir; düşen alan uyarıyla söylenir.
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

  /// Tam sayıda ondalık gösterme (`1500.0` → `1500`); küsurat olduğu gibi
  /// kalır.
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

  Future<void> _pickAddress() async {
    final picked = await context.push<ConfirmedAddress>(
      '/pick-address',
      extra: _address,
    );
    if (picked == null || !mounted) return;
    setState(() => _address = picked);
  }

  /// Düzenleyiciyi taslak modunda açar.
  Future<void> _editTransport() async {
    final saved = await context.push<TransportPlanDraft>(
      BusinessRoutes.transportPlan,
      extra: BTransportPlanArgs(initial: _transport, jobStart: _startDateTime),
    );
    if (saved == null || !mounted) return;
    setState(() => _transport = saved);
  }

  void _removeTransport() => setState(() => _transport = null);

  /// İlan açıldıktan sonra taslağı yazar; düşerse sunucunun mesajını döndürür.
  /// Boş taslak yazılmaz. Yazım düşerse ilan yine açıktır; başarı kutusu bunu
  /// söyler.
  Future<String?> _saveTransport(JobDetail created) async {
    final draft = _transport;
    if (draft == null || draft.isBlank) return null;

    try {
      await _transportService.savePlan(created.id, draft.toWrite());
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<void> _pickStartDateTime() async {
    final picked = await DateTimePicking.pick(context, initial: _startDateTime);
    if (picked == null || !mounted) return;

    setState(() {
      _startDateTime = picked;
      // Bitiş başlangıçtan önce kaldıysa bir vardiya kadar ileri alınır.
      final end = _endDateTime;
      if (end == null || !end.isAfter(picked)) {
        _endDateTime = picked.add(_defaultShiftDuration);
      }
    });
  }

  Future<void> _pickEndDateTime() async {
    final picked = await DateTimePicking.pick(
      context,
      initial: _endDateTime ?? _startDateTime,
    );
    if (picked == null || !mounted) return;

    setState(() => _endDateTime = picked);
  }

  // -------------------------------------------------------------- Yayınlama

  /// Bireysel ilan açan işverenin kimliği doğrulanmış mı. Şirket ilanında
  /// gerekmiyor: ödemede alıcı kimliği şirketin VKN'si; bireyselde TCKN ve o
  /// yalnız doğrulamayla doluyor.
  bool get _needsIdentityVerification {
    if (_isCompanyJob) return false;

    return context.read<UserProvider>().user?.identityVerified != true;
  }

  Future<void> _goToIdentityVerification() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    await context.push('/identity-verification', extra: user);
    // Doğrulandıysa uyarı kutusu kalksın.
    if (mounted) await context.read<UserProvider>().load(silent: true);
  }

  /// Doğrulayıp ilanı açar; sunucunun reddi tek alan adı döndürüyor, eksikleri
  /// Türkçe ve sırayla söylemek daha anlaşılır.
  Future<void> _createJob() async {
    if (_isSubmitting) return;

    // Sunucuda bu kontrol yok: hata ancak aday kabul edilince İyzico'dan
    // anlaşılmaz bir mesajla gelir. Kapı burada.
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

    if (created != null) {
      final transportError = await _saveTransport(created);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSuccessDialog(jobId: created.id, transportError: transportError);
    } else {
      setState(() => _isSubmitting = false);
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
      // Yönlendirme, yıkıcı değil.
      isDestructive: false,
    );

    if (confirmed != true || !mounted) return;

    await _goToIdentityVerification();
  }

  /// Eksik varsa uyarıp `null` döner.
  CreateJobRequest? _buildRequest() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return _warn('İlan başlığı zorunlu');

    final category = _selectedCategory;
    if (category == null) return _warn('Bir kategori seçin');
    // Seçici zaten elemiş olmalı; `400` yerine anlaşılır mesaj.
    if (category.requiresInsurance && !_isCompanyJob) {
      return _warn('Bu kategoride ilan yalnızca şirket adına açılabilir');
    }
    // Son savunma: kural kategoriden türetildiği için normalde buraya düşülmez.
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

    final address = _address;
    if (address == null) return _warn('İlan adresini haritadan seçin');

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
      addressPublic: !_hideAddress,
      address: address.toWrite(),
    );
  }

  CreateJobRequest? _warn(String message) {
    AppToast.error(context, message);
    return null;
  }

  /// Sunucu boş metni de değer sayıyor; hiç gönderilmemeli.
  static String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }
}
