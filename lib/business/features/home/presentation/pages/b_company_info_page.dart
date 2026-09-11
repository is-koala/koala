import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/constants/upload_limits.dart';
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

  /// Logonun önizleme boyutu.
  static const double _logoSize = 88;

  /// Galeri satırındaki kapak önizlemesi; logodan küçük çünkü satırın
  /// yüksekliğini belirlemesi gerekmiyor.
  static const double _galleryCoverSize = 48;

  /// Logo işlemi sürerken; iki kez tetiklenmesin diye.
  bool _isLogoBusy = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _displayAddressController = TextEditingController();
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
    _displayAddressController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Alanları şirketin son hâliyle doldurur.
  void _fill(Company company) {
    if (_filledFrom == company.id) return;
    _filledFrom = company.id;

    _nameController.text = company.name;
    _emailController.text = company.email ?? '';
    _phoneController.text = company.phoneNumber ?? '';
    _websiteController.text = company.website ?? '';
    _descriptionController.text = company.description ?? '';
    _taxNumberController.text = company.taxNumber ?? '';
    _displayAddressController.text = company.address?.displayAddress ?? '';
    _districtController.text = company.address?.districtName ?? '';
    _cityController.text = company.address?.cityName ?? '';
  }

  // ------------------------------------------------------------------- Logo

  /// Galeriden logo seçer ve yükler.
  ///
  /// Boyut ve uzantı istemcide de kontrol ediliyor: sunucu aynı kuralları
  /// uyguluyor ama kullanıcıyı yüklemeyi bekleyip hata almaya bırakmanın
  /// anlamı yok.
  Future<void> _pickLogo() async {
    if (_isLogoBusy) return;

    // Ham dosya gönderiliyor: yeniden kodlamak PNG saydamlığını kaybettirir,
    // logolarda bu görünür bir bozulma.
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    if (!UploadLimits.hasAllowedImageExtension(picked.path)) {
      AppToast.error(context, 'Yalnızca PNG, JPG veya WEBP yükleyebilirsiniz');
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

  Widget _body(BCompanyProvider provider, Company? company) {
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
              controller: _displayAddressController,
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

  /// Logo önizlemesi ve değiştirme/kaldırma eylemleri.
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

  /// Galeri ekranına giriş: kapak önizlemesi, sayı ve chevron.
  ///
  /// Kapağı `Company.coverImage` veriyor — kapak işaretli görsel, yoksa
  /// galerinin ilki. Hesabı sunucu yapıyor, ekran yalnız gösteriyor.
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
