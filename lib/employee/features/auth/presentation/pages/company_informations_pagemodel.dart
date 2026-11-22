part of 'company_informations_page.dart';

abstract class CompanyInformationsPagemodel
    extends State<CompanyInformationsPage> {
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController taxNumberController = TextEditingController();
  final TextEditingController companyPhoneController = TextEditingController();
  final TextEditingController companyEmailController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  late final BCompanyService companyService;

  late ConfirmedAddress? address = widget.initialAddress;
  CompanyType companyType = CompanyType.limited;
  String? logoPath;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    companyService = widget.service ?? BCompanyService();
    // Avatar rengi ve baş harfleri firma adından; ad değiştikçe yeniden
    // çizilir.
    companyNameController.addListener(_onCompanyNameChanged);
  }

  @override
  void dispose() {
    companyNameController.removeListener(_onCompanyNameChanged);
    companyNameController.dispose();
    taxNumberController.dispose();
    companyPhoneController.dispose();
    companyEmailController.dispose();
    websiteController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _onCompanyNameChanged() => setState(() {});

  bool get canGoBack => context.canPop();

  void goBack() {
    if (canGoBack) {
      context.pop();
      return;
    }

    context.go(RegistrationRoutes.employerType);
  }

  String get companyInitials {
    final text = companyNameController.text.trim();
    if (text.isEmpty) return 'Logo';
    return text.length >= 2
        ? text.substring(0, 2).toUpperCase()
        : text[0].toUpperCase();
  }

  Future<void> pickLogo() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;
    setState(() => logoPath = image.path);
  }

  Future<void> pickAddress() async {
    final picked = await context.push<ConfirmedAddress>(
      '/pick-address',
      extra: address,
    );
    if (picked == null || !mounted) return;
    setState(() => address = picked);
  }

  Future<void> saveCompanyInformation() async {
    final requiredFields = {
      'firma adını': companyNameController.text,
      'vergi numarasını': taxNumberController.text,
      'şirket telefonunu': companyPhoneController.text,
      'şirket e-postasını': companyEmailController.text,
    };
    for (final entry in requiredFields.entries) {
      if (entry.value.trim().isEmpty) {
        AppToast.error(context, 'Lütfen ${entry.key} giriniz');
        return;
      }
    }

    final confirmedAddress = address;
    if (confirmedAddress == null) {
      AppToast.error(context, 'Lütfen şirket adresini haritadan seçiniz');
      return;
    }

    setState(() => isSaving = true);
    try {
      await companyService.createCompany(
        name: companyNameController.text.trim(),
        email: companyEmailController.text.trim(),
        phoneNumber: companyPhoneController.text.trim(),
        taxNumber: taxNumberController.text.trim(),
        type: companyType,
        address: confirmedAddress.toWrite(),
        website: websiteController.text.trim().isEmpty
            ? null
            : websiteController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        logoPath: logoPath,
      );

      if (!mounted) return;
      await _refreshMembership();

      if (!mounted) return;
      AppToast.success(context, 'Şirket bilgileri başarıyla kaydedildi');
      final onSaved = widget.onSaved;
      if (onSaved != null) {
        onSaved();
      } else if (context.canPop()) {
        // Ayarlardan açıldıysa geri dönmek yeter; açan ekran sağlayıcıyı
        // izliyor.
        context.pop(true);
      } else {
        // Kayıt akışında yığında başka sayfa yok.
        context.go('/business/home');
      }
    } on ApiException catch (error) {
      if (!mounted) return;

      // Sunucu son söz: ret gelirse onarım akışı açılır, form arkada taslağıyla
      // bekler.
      if (CompanyIdentityGate.isIdentityRequired(error)) {
        setState(() => isSaving = false);
        await CompanyIdentityGate.startVerification(context);
        return;
      }

      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// Yeni üyeliği sağlayıcılara işler; tazelenmezse ana sayfa kullanıcıyı
  /// bireysel sanır.
  Future<void> _refreshMembership() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.load(silent: true);

    if (!mounted) return;
    final user = userProvider.user;
    if (user == null) return;

    await context.read<BCompanyProvider>().loadFor(user, force: true);
  }
}
