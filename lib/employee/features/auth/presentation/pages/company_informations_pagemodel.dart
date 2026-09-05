part of 'company_informations_page.dart';

abstract class CompanyInformationsPagemodel
    extends State<CompanyInformationsPage> {
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController companyAddressController =
      TextEditingController();
  final TextEditingController districtController = TextEditingController();
  final TextEditingController taxNumberController = TextEditingController();
  final TextEditingController companyPhoneController = TextEditingController();
  final TextEditingController companyEmailController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  late final BCompanyService companyService;
  late LatLng? selectedLocation;
  CompanyType companyType = CompanyType.limited;
  String? logoPath;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    companyService = widget.service ?? BCompanyService();
    selectedLocation = widget.initialLocation;
    // Avatar hem rengini hem baş harflerini firma adından türetiyor; ad
    // değiştikçe yeniden çizilmesi gerekiyor.
    companyNameController.addListener(_onCompanyNameChanged);
  }

  @override
  void dispose() {
    companyNameController.removeListener(_onCompanyNameChanged);
    companyNameController.dispose();
    companyAddressController.dispose();
    districtController.dispose();
    taxNumberController.dispose();
    companyPhoneController.dispose();
    companyEmailController.dispose();
    websiteController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _onCompanyNameChanged() => setState(() {});

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

  Future<void> pickLocation() async {
    final result = await context.push<LatLng>(
      '/pick-location',
      extra: selectedLocation,
    );
    if (result == null || !mounted) return;
    setState(() => selectedLocation = result);
  }

  Future<void> saveCompanyInformation() async {
    final requiredFields = {
      'firma adını': companyNameController.text,
      'firma adresini': companyAddressController.text,
      'ilçeyi': districtController.text,
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

    final location = selectedLocation;
    if (location == null) {
      AppToast.error(context, 'Lütfen şirket konumunu haritadan seçiniz');
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
        address: {
          'countryCode': 'TR',
          'cityName': 'İSTANBUL',
          'districtName': districtController.text.trim().toUpperCase(),
          'addressLine': companyAddressController.text.trim(),
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
        website: websiteController.text.trim().isEmpty
            ? null
            : websiteController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        logoPath: logoPath,
      );

      if (!mounted) return;
      AppToast.success(context, 'Şirket bilgileri başarıyla kaydedildi');
      final onSaved = widget.onSaved;
      if (onSaved != null) {
        onSaved();
      } else {
        context.go('/business/home');
      }
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
}
