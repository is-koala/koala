import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/employee/features/auth/presentation/company_identity_gate.dart';
import 'package:koala/employee/features/auth/presentation/registration_routes.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/constants/upload_limits.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/locked_field.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

/// Firma bilgileri. `PATCH /companies/{id}` beş metin alanını alıyor; adres
/// ayrı ekranda (`BCompanyAddressPage`, yalnız `ADMIN`). Vergi numarası
/// değiştirilemez ama görünsün diye kapalı alan olarak duruyor.
class BCompanyInfoPage extends StatefulWidget {
  const BCompanyInfoPage({super.key});

  @override
  State<BCompanyInfoPage> createState() => _BCompanyInfoPageState();
}

class _BCompanyInfoPageState extends State<BCompanyInfoPage> {
  static const double _descriptionHeight = 120;

  static const double _noticeAlpha = 0.1;

  static const double _logoSize = 88;

  static const double _galleryCoverSize = 48;

  bool _isLogoBusy = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _taxNumberController = TextEditingController();

  /// Alanlar bir kez dolsun, kullanıcının yazdığının üstüne yazılmasın.
  String? _filledFrom;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Önce kullanıcıyı, sonra şirketini çeker; şirket üyelikten çıkıyor.
  /// Kullanıcı okunmadan karar verilseydi şirketi olan işverene "firmanız yok"
  /// denirdi.
  Future<void> _load({bool force = false}) async {
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    if (userProvider.user == null) await userProvider.load(silent: true);

    if (!mounted) return;
    final user = userProvider.user;
    if (user == null) return;

    await context.read<BCompanyProvider>().loadFor(user, force: force);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _taxNumberController.dispose();
    super.dispose();
  }

  void _fill(Company company) {
    if (_filledFrom == company.id) return;
    _filledFrom = company.id;

    _nameController.text = company.name;
    _emailController.text = company.email ?? '';
    _phoneController.text = company.phoneNumber ?? '';
    _websiteController.text = company.website ?? '';
    _descriptionController.text = company.description ?? '';
    _taxNumberController.text = company.taxNumber ?? '';
  }

  // ------------------------------------------------------------------- Logo

  /// Uzantı ve boyut istemcide de kontrol ediliyor.
  Future<void> _pickLogo() async {
    if (_isLogoBusy) return;

    // Ham dosya: yeniden kodlamak PNG saydamlığını bozar.
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    if (!UploadLimits.hasAllowedImageExtension(picked.path)) {
      AppToast.error(context, 'Yalnızca PNG veya JPG yükleyebilirsiniz');
      return;
    }

    final length = await File(picked.path).length();
    if (!mounted) return;
    if (length > UploadLimits.maxImageBytes) {
      AppToast.error(context, 'Görsel en fazla 10 MB olabilir');
      return;
    }

    await _runLogoAction(
      () => context.read<BCompanyProvider>().updateLogo(picked.path),
      successMessage: 'Logo güncellendi',
    );
  }

  Future<void> _removeLogo() async {
    if (_isLogoBusy) return;

    await _runLogoAction(
      () => context.read<BCompanyProvider>().removeLogo(),
      successMessage: 'Logo kaldırıldı',
    );
  }

  Future<void> _runLogoAction(
    Future<bool> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _isLogoBusy = true);

    final provider = context.read<BCompanyProvider>();
    final succeeded = await action();

    if (!mounted) return;
    setState(() => _isLogoBusy = false);

    if (succeeded) {
      AppToast.success(context, successMessage);
    } else {
      AppToast.error(context, provider.errorMessage ?? 'İşlem tamamlanamadı');
    }
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
      // Boş alan `null` gider; boş metin değeri silerdi.
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
    final userProvider = context.watch<UserProvider>();
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
      body: _body(userProvider, provider, company),
    );
  }

  Widget _body(
    UserProvider userProvider,
    BCompanyProvider provider,
    Company? company,
  ) {
    // Şirket var mı sorusunu üyelik cevaplıyor, sağlayıcının `null`'ı değil.
    final user = userProvider.user;
    if (user == null) {
      final userError = userProvider.errorMessage;
      if (userError != null) return _errorState(userError);
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.isLoading && company == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = provider.errorMessage;
    if (message != null && company == null) return _errorState(message);

    if (company == null) {
      // Üyelik var ama şirket daha gelmedi: bekleme, "firmanız yok" değil.
      if (user.primaryCompany != null) {
        return const Center(child: CircularProgressIndicator());
      }
      return _noCompanyState();
    }

    // Rol `/users/me`'deki üyelikten.
    final canEditAddress = user.primaryCompany?.isAdmin ?? false;

    return FormPageBody(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel("Logo"),
            const SizedBox(height: AppSizes.space),
            _logoSection(company),
            const SizedBox(height: AppSizes.spaceLarge),
            _sectionLabel("Şirket Galerisi"),
            const SizedBox(height: AppSizes.space),
            _galleryRow(company),
            const SizedBox(height: AppSizes.spaceLarge),
            _sectionLabel("Şirket Yetkilileri"),
            const SizedBox(height: AppSizes.space),
            _contactsRow(),
            const SizedBox(height: AppSizes.spaceLarge),
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
            _sectionLabel("Şirket Adresi"),
            const SizedBox(height: AppSizes.space),
            ..._addressSection(company, canEdit: canEditAddress),
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
            const SizedBox(height: AppSizes.sectionSpace),
          ],
        ),
      ),
    );
  }

  Widget _logoSection(Company company) {
    final hasLogo = company.logoUrl != null && company.logoUrl!.isNotEmpty;

    return Row(
      children: [
        _logoPreview(company.logoUrl),
        const SizedBox(width: AppSizes.spaceMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                UploadLimits.imageRuleLabel,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.textTertiary,
                ),
              ),
              const SizedBox(height: AppSizes.spaceSmall),
              Row(
                children: [
                  TextButton(
                    onPressed: _isLogoBusy ? null : _pickLogo,
                    style: TextButton.styleFrom(
                      foregroundColor: context.accentColor,
                      padding: EdgeInsets.zero,
                      textStyle: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(hasLogo ? 'Değiştir' : 'Logo Yükle'),
                  ),
                  if (hasLogo) ...[
                    const SizedBox(width: AppSizes.spaceMedium),
                    TextButton(
                      onPressed: _isLogoBusy ? null : _removeLogo,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: EdgeInsets.zero,
                        textStyle: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Kaldır'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Kapağı `Company.coverImage` veriyor; ekran yalnız gösteriyor.
  Widget _galleryRow(Company company) {
    final cover = company.coverImage;
    final count = company.images.length;

    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/business/company-gallery'),
        child: Padding(
          padding: AppPadding.card,
          child: Row(
            children: [
              _galleryCover(cover),
              const SizedBox(width: AppSizes.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Şirket Galerisi',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSizes.smallGap),
                    Text(
                      count == 0
                          ? 'Henüz görsel yok'
                          : '$count görsel · en fazla '
                                '${UploadLimits.maxGalleryImages}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                AppIcons.arrowRight,
                size: AppSizes.iconMedium,
                color: context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactsRow() {
    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/business/company-contacts'),
        child: Padding(
          padding: AppPadding.card,
          child: Row(
            children: [
              SizedBox.square(
                dimension: _galleryCoverSize,
                child: ColoredBox(
                  color: context.elevatedColor,
                  child: Center(
                    child: AppIcon(
                      AppIcons.userMultiple,
                      size: AppSizes.iconMedium,
                      color: context.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Şirket Yetkilileri',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSizes.smallGap),
                    Text(
                      'Davet gönderin veya yetkili çıkarın',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                AppIcons.arrowRight,
                size: AppSizes.iconMedium,
                color: context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _galleryCover(GalleryImage? cover) {
    final placeholder = AppIcon(
      AppIcons.gallery,
      size: AppSizes.iconMedium,
      color: context.textTertiary,
    );

    return ClipRRect(
      borderRadius: AppRadius.smallCircular,
      child: SizedBox.square(
        dimension: _galleryCoverSize,
        child: ColoredBox(
          color: context.elevatedColor,
          child: cover == null
              ? Center(child: placeholder)
              : Image.network(
                  cover.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(child: placeholder),
                ),
        ),
      ),
    );
  }

  Widget _logoPreview(String? logoUrl) {
    return Container(
      width: _logoSize,
      height: _logoSize,
      decoration: BoxDecoration(
        color: context.tileColor,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: _isLogoBusy
          ? Center(
              child: SizedBox(
                width: AppSizes.icon,
                height: AppSizes.icon,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.accentColor,
                  ),
                ),
              ),
            )
          : logoUrl == null || logoUrl.isEmpty
          ? _logoPlaceholder()
          : Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _logoPlaceholder(),
            ),
    );
  }

  Widget _logoPlaceholder() {
    return AppIcon(
      AppIcons.building,
      size: AppSizes.iconLarge,
      color: context.textTertiary,
    );
  }

  Widget _errorState(String message) {
    return EmptyState(
      icon: AppIcons.alert,
      title: 'Firma bilgileri alınamadı',
      description: message,
      action: OutlinedButton(
        onPressed: () => _load(force: true),
        child: const Text('Tekrar Dene'),
      ),
    );
  }

  /// Şirketi olmayan işveren: kayıt akışındaki form buradan açılır, kaydedince
  /// bu ekran yeni şirketi çizer.
  Widget _noCompanyState() {
    return EmptyState(
      icon: AppIcons.building,
      title: 'Kayıtlı firmanız yok',
      description:
          'Bireysel işveren olarak ilan yayınlıyorsunuz. Şirket adına ilan '
          'vermek için firma kaydı oluşturabilirsiniz.',
      action: OutlinedButton(
        onPressed: _createCompany,
        child: const Text('Firma Kaydı Oluştur'),
      ),
    );
  }

  /// `POST /companies` doğrulanmamış kullanıcıyı reddettiği için form kimlik
  /// kapısından sonra açılır.
  Future<void> _createCompany() async {
    final verified = await CompanyIdentityGate.ensureVerified(context);
    if (!verified || !mounted) return;

    await context.push(RegistrationRoutes.companyInformations);
  }

  /// Şirket adresi salt okunur ([LockedField]) ve doğrudan şirketten: sağlayıcı
  /// tazelenince kendiliğinden güncellenir. ADMIN'e *Adresi değiştir*,
  /// diğerlerine not.
  List<Widget> _addressSection(Company company, {required bool canEdit}) {
    final address = company.address;
    return [
      if (address == null)
        const LockedField(label: 'Adres', value: 'Adres kayıtlı değil')
      else ...[
        LockedField(label: 'Açık Adres', value: address.displayAddress ?? '—'),
        const SizedBox(height: AppSizes.spaceSmall),
        LockedField(label: 'İlçe', value: address.districtName),
        const SizedBox(height: AppSizes.spaceSmall),
        LockedField(label: 'Şehir', value: address.cityName),
      ],
      const SizedBox(height: AppSizes.spaceMedium),
      if (canEdit)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('company-address-change'),
            onPressed: _changeAddress,
            child: const Text('Adresi değiştir'),
          ),
        )
      else
        _notice('Şirket adresini yalnızca şirket yöneticisi değiştirebilir.'),
    ];
  }

  void _changeAddress() => context.push('/business/company-address');

  Widget _lockedNotice() => _notice(
    'Vergi numarası firma kaydıyla birlikte belirleniyor; değiştirmek için '
    'destek ekibiyle iletişime geçin.',
  );

  Widget _notice(String message) {
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
              message,
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
      // Tam yuvarlak köşe bu yükseklikte metni sıkıştırıyor.
      borderRadius: AppRadius.innerCircular,
    );
  }
}
