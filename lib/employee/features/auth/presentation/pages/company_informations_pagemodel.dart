part of 'company_informations_page.dart';

abstract class CompanyInformationsPagemodel
    extends State<CompanyInformationsPage> {
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController companyAddressController =
      TextEditingController();
  final TextEditingController taxNumberController = TextEditingController();
  final TextEditingController sectorController = TextEditingController();
  final TextEditingController companyPhoneController = TextEditingController();
  final TextEditingController companyEmailController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Avatar hem rengini hem baş harflerini firma adından türetiyor; ad
    // değiştikçe yeniden çizilmesi gerekiyor.
    companyNameController.addListener(_onCompanyNameChanged);
  }

  @override
  void dispose() {
    companyNameController.removeListener(_onCompanyNameChanged);
    companyNameController.dispose();
    companyAddressController.dispose();
    taxNumberController.dispose();
    sectorController.dispose();
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

  void saveCompanyInformation() {
    if (companyNameController.text.isEmpty) {
      AppToast.error(context, 'Lütfen firma adını giriniz');
      return;
    }

    // TODO(backend): `POST /companies` ile kaydedilecek. Uç bugünkü formdan
    // fazlasını istiyor: şirket tipi (`CompanyType` enum'u) ve serbest metin
    // yerine yapılandırılmış adres (ülke kodu, il, ilçe, enlem/boylam). Bu
    // alanlar forma eklenmeden çağrı yapılamıyor.
    AppToast.success(context, 'Şirket bilgileri başarıyla kaydedildi');

    // Kayıt akışı burada bitiyor; oturum şifre adımında açılmıştı.
    context.go('/business/home');
  }
}
