import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/models/b_company.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

/// Firma bilgilerini düzenleme ekranı.
///
/// Backend `PATCH /companies/{id}` yalnızca **beş** alan kabul ediyor
/// (`UpdateCompanyRequestDto`): ad, e-posta, telefon, website, açıklama.
/// Vergi numarası, adres, tür ve logo şirket kurulurken belirleniyor ve
/// sonradan değiştirilemiyor — o alanlar ekranda duruyor ama kapalı, çünkü
/// işverenin kayıtlı değeri görmesi gerekiyor.
class BCompanyInfoPage extends StatefulWidget {
  const BCompanyInfoPage({super.key});

  @override
  State<BCompanyInfoPage> createState() => _BCompanyInfoPageState();
}

class _BCompanyInfoPageState extends State<BCompanyInfoPage> {
  /// "Hakkımızda" alanının yüksekliği: yaklaşık dört satır.
  static const double _descriptionHeight = 120;

  /// Bilgi kutusunun zemin opaklığı.
  static const double _noticeAlpha = 0.1;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _addressLineController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();

  /// Alanların hangi şirketten dolduğu. Sağlayıcı sonradan veriyi getirince
  /// alanlar bir kez doldurulsun, kullanıcının yazdığı üstüne yazılmasın.
  String? _filledFrom;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<UserProvider>().user;
      if (user != null) context.read<BCompanyProvider>().loadFor(user);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _taxNumberController.dispose();
    _addressLineController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Alanları şirketin son hâliyle doldurur.
  void _fill(BCompany company) {
    if (_filledFrom == company.id) return;
    _filledFrom = company.id;

    _nameController.text = company.name;
    _emailController.text = company.email ?? '';
    _phoneController.text = company.phoneNumber ?? '';
    _websiteController.text = company.website ?? '';
    _descriptionController.text = company.description ?? '';
    _taxNumberController.text = company.taxNumber ?? '';
    _addressLineController.text = company.address?.addressLine ?? '';
    _districtController.text = company.address?.districtName ?? '';
    _cityController.text = company.address?.cityName ?? '';
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.error(context, 'Firma adı boş bırakılamaz');
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<BCompanyProvider>();
    final saved = await provider.updateCompany(
      name: name,
      // Boş bırakılan alan `null` gidiyor: sunucu gövdede olmayan alana
      // dokunmuyor, boş metin göndermek değeri silmek olurdu.
      email: _trimmedOrNull(_emailController),
      phoneNumber: _trimmedOrNull(_phoneController),
      website: _trimmedOrNull(_websiteController),
      description: _trimmedOrNull(_descriptionController),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved) {
      AppToast.success(context, 'Firma bilgileri güncellendi');
      context.pop();
    } else {
      AppToast.error(context, provider.errorMessage ?? 'Güncelleme başarısız');
    }
  }

  static String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BCompanyProvider>();
    final company = provider.company;

    if (company != null) _fill(company);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: "Firma Bilgileri"),
      bottomNavigationBar: company == null
          ? null
          : ButtonNavbar(
              onPressed: _isSaving ? null : _save,
              title: "Kaydet",
              isLoading: _isSaving,
            ),
      body: _body(provider, company),
    );
  }

  Widget _body(BCompanyProvider provider, BCompany? company) {
    if (provider.isLoading && company == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = provider.errorMessage;
    if (message != null && company == null) {
      return EmptyState(
        icon: AppIcons.alert,
        title: 'Firma bilgileri alınamadı',
        description: message,
        action: OutlinedButton(
          onPressed: () {
            final user = context.read<UserProvider>().user;
            if (user != null) {
              context.read<BCompanyProvider>().loadFor(user, force: true);
            }
          },
          child: const Text('Tekrar Dene'),
        ),
      );
    }

    if (company == null) return _noCompanyState();

    return SingleChildScrollView(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel("Firma Bilgileri"),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(labelText: "Firma Adı", controller: _nameController),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: "E-posta",
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: "Telefon",
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: "Website",
              controller: _websiteController,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSizes.spaceLarge),
            _sectionLabel("Hakkımızda"),
            const SizedBox(height: AppSizes.space),
            _descriptionTextField(),
            const SizedBox(height: AppSizes.spaceLarge),
            _sectionLabel("Değiştirilemeyen Bilgiler"),
            const SizedBox(height: AppSizes.space),
            _lockedNotice(),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: "Vergi Numarası",
              controller: _taxNumberController,
              enabled: false,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: "Açık Adres",
              controller: _addressLineController,
              enabled: false,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: "İlçe",
              controller: _districtController,
              enabled: false,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: "Şehir",
              controller: _cityController,
              enabled: false,
            ),
            const SizedBox(height: AppSizes.sectionSpace),
          ],
        ),
      ),
    );
  }

  /// Şirketi olmayan işverenin gördüğü ekran.
  ///
  /// TODO(backend): Şirket kurma akışı henüz yok. `POST /companies` multipart
  /// bir istek (şirket bilgileri + logo) ve kullanıcının kimliğinin
  /// doğrulanmış olmasını şart koşuyor; dosya seçici de gerektirdiği için
  /// ayrı bir ekran olarak planlanmalı.
  Widget _noCompanyState() {
    return const EmptyState(
      icon: AppIcons.building,
      title: 'Kayıtlı firmanız yok',
      description:
          'Bireysel işveren olarak ilan yayınlıyorsunuz. Firma kaydı '
          'oluşturma uygulamaya henüz eklenmedi.',
    );
  }

  /// Neden bazı alanların kapalı olduğunu anlatan kutu.
  Widget _lockedNotice() {
    return Container(
      width: double.infinity,
      padding: AppPadding.chip,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: _noticeAlpha),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.info,
            size: AppSizes.iconSmall,
            color: context.accentColor,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              'Vergi numarası ve adres firma kaydıyla birlikte belirleniyor; '
              'değiştirmek için destek ekibiyle iletişime geçin.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) =>
      Text(title, style: context.textTheme.titleMedium);

  Widget _descriptionTextField() {
    return MyTextfield(
      labelText: "Açıklama",
      controller: _descriptionController,
      height: _descriptionHeight,
      expands: true,
      // Tek satırlık alanların tam yuvarlak köşesi bu yükseklikte metni
      // sıkıştırıyor.
      borderRadius: AppRadius.innerCircular,
    );
  }
}
