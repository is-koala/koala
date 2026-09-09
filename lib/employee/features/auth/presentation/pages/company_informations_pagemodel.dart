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

  void goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go('/employer-type');
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
