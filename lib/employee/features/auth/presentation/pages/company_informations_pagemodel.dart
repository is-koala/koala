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
  late final CanonicalAddressFormController addressController;
  CompanyType companyType = CompanyType.limited;
  String? logoPath;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    companyService = widget.service ?? BCompanyService();
    addressController = CanonicalAddressFormController(
      initialAddress: widget.initialAddress,
    );
    final initialLocation = widget.initialLocation;
    if (initialLocation != null) {
      addressController.selectPosition(initialLocation);
    }
    // Avatar hem rengini hem baş harflerini firma adından türetiyor; ad
    // değiştikçe yeniden çizilmesi gerekiyor.
    companyNameController.addListener(_onCompanyNameChanged);
  }

  @override
  void dispose() {
    companyNameController.removeListener(_onCompanyNameChanged);
    companyNameController.dispose();
    addressController.dispose();
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

  /// Logonun yerine gösterilen baş harfler.
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

  Future<LatLng?> pickPosition(LatLng? initialPosition) async {
    final result = await context.push<LatLng>(
      '/pick-location',
      extra: initialPosition,
    );
    return result;
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

    final address = addressController.value;
    if (address == null) {
      AppToast.error(
        context,
        addressController.validationMessage ?? 'Lütfen adresi tamamlayınız',
      );
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
        address: address,
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
        // Ayarlardan `push` ile açıldı: açan ekran tazelenmiş sağlayıcıyı
        // zaten izliyor, yeni şirketi göstermesi için geri dönmek yetiyor.
        context.pop(true);
      } else {
        // Kayıt akışı: yığında bu formdan başka sayfa yok.
        context.go('/business/home');
      }
    } on ApiException catch (error) {
      if (!mounted) return;

      // Sunucu son sözü söylüyor: yerel bayrak doğrulanmış görünse de ret
      // gelirse aynı onarım akışı açılıyor. Form arkada kalıyor, doğrulama
      // bitince kullanıcı taslağıyla buraya dönüp yeniden kaydediyor.
      if (CompanyIdentityGate.isIdentityRequired(error)) {
        // Kutu ve kimlik ekranı açıkken düğme dönmesin.
        setState(() => isSaving = false);
        await CompanyIdentityGate.startVerification(context);
        return;
      }

      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// Yeni şirketin üyeliğini ve şirket kaydını sağlayıcılara işler.
  ///
  /// Üyelik listesi `/users/me`'de duruyor; tazelenmezse işveren ana sayfası
  /// ve profil, kullanıcıyı hâlâ bireysel sanır. `BCompanyProvider` kimlik
  /// çiftine göre önbellekliyor, yeni şirket kimliği için zorla okunuyor.
  Future<void> _refreshMembership() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.load(silent: true);

    if (!mounted) return;
    final user = userProvider.user;
    if (user == null) return;

    await context.read<BCompanyProvider>().loadFor(user, force: true);
  }
}
