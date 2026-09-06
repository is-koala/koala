import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/business/features/home/models/create_job_request.dart';
import 'package:koala/business/features/home/models/job_template.dart';
import 'package:koala/business/features/home/models/b_pricing_breakdown.dart';
import 'package:koala/business/features/home/presentation/providers/b_job_templates_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/widgets/b_info_notice.dart';
import 'package:koala/business/features/home/presentation/widgets/b_option_sheet.dart';
import 'package:koala/business/features/home/presentation/widgets/b_selection_field.dart';
import 'package:koala/business/features/home/presentation/widgets/b_pricing_breakdown_card.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/canonical_address_form.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

part 'b_create_pagemodel.dart';

class BCreatePage extends StatefulWidget {
  const BCreatePage({super.key, this.paymentService, this.referenceService});

  final BPaymentService? paymentService;
  final ReferenceLocationService? referenceService;

  @override
  State<BCreatePage> createState() => _BCreatePageState();
}

class _BCreatePageState extends BCreatePageModel {
  @override
  Widget build(BuildContext context) {
    // İlan kurumsal mı bireysel mi açılacak: onaylı şirket üyeliği varsa
    // kurumsal. Kullanıcının bunu seçmesi gerekmiyor ama görmesi gerekiyor.
    final company = context.watch<UserProvider>().user?.activeCompany;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: "Yeni İlan Oluştur"),
      bottomNavigationBar: ButtonNavbar(
        onPressed: _isSubmitting ? null : _createJob,
        title: "İlanı Yayınla",
        isLoading: _isSubmitting,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _employerNotice(company?.companyName),
              ?_identityNotice(),
              _templateSection(),

              // Temel Bilgiler
              _sectionLabel("Temel Bilgiler"),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "İlan Başlığı *",
                controller: _titleController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Pozisyon *",
                controller: _positionController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(labelText: "Sektör", controller: _sectorController),
              const SizedBox(height: AppSizes.spaceMedium),
              _descriptionTextField(),

              const SizedBox(height: AppSizes.spaceLarge),

              // Kategori & Tip
              _sectionLabel("Kategori ve Tip"),
              const SizedBox(height: AppSizes.spaceMedium),
              _categorySelector(),
              const SizedBox(height: AppSizes.spaceMedium),
              _typeSelector(),

              const SizedBox(height: AppSizes.spaceLarge),

              // Ücret & Tarih
              _sectionLabel("Ücret ve Tarih"),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Ücret (₺) *",
                controller: _priceController,
                focusNode: _priceFocusNode,
                onChanged: _onPriceChanged,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              ..._pricingBreakdown(),
              const SizedBox(height: AppSizes.spaceMedium),
              _salaryTypeSelector(),
              const SizedBox(height: AppSizes.spaceMedium),
              BSelectionField(
                label: "Başlangıç *",
                value: _startDateTime?.asShortDateTime,
                placeholder: "Tarih ve saat seçin",
                onTap: _pickStartDateTime,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              BSelectionField(
                label: "Bitiş *",
                value: _endDateTime?.asShortDateTime,
                placeholder: "Tarih ve saat seçin",
                onTap: _pickEndDateTime,
              ),

              const SizedBox(height: AppSizes.spaceLarge),

              // Konum
              _sectionLabel("Konum"),
              const SizedBox(height: AppSizes.spaceMedium),
              _locationSection(),

              const SizedBox(height: AppSizes.spaceLarge),

              // Detaylı Bilgiler
              _sectionLabel("Detaylı Bilgiler"),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(labelText: "Görevler", controller: _dutiesController),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Kıyafet Kuralı",
                controller: _dressCodeController,
              ),

              const SizedBox(height: AppSizes.spaceLarge),

              // Gereksinimler
              _sectionLabel("Gereksinimler"),
              const SizedBox(height: AppSizes.space),
              Row(
                children: [
                  Expanded(
                    child: MyTextfield(
                      labelText: "Min Yaş *",
                      controller: _minAgeController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceMedium),
                  Expanded(
                    child: MyTextfield(
                      labelText: "Max Yaş *",
                      controller: _maxAgeController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space),
              _switchTile(
                title: "Deneyim Gerekli",
                value: _experienceRequired,
                onChanged: (v) => setState(() => _experienceRequired = v),
              ),
              // Sigorta yalnızca kurumsal ilanlarda sorulabiliyor: bireysel
              // ilan ucu `insuranceRequired`'ı zorla `false` yazıyor ve
              // sigorta gerektiren kategorilerde ilan açtırmıyor.
              if (company != null) ...[
                _switchTile(
                  title: "Sigorta Gerekli",
                  value: _insuranceRequired,
                  // Kategori sigorta zorunlu kılıyorsa anahtar kapatılamıyor:
                  // sunucu o ilanı zaten kabul etmiyor.
                  onChanged: _insuranceLocked
                      ? null
                      : (v) => setState(() => _insurancePreference = v),
                ),
                if (_insuranceLocked) _insuranceLockedNotice(),
              ] else
                _insuranceNotice(),

              const SizedBox(height: AppSizes.navBarClearance),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Başlık

  /// İlanın kimin adına açılacağını söyleyen bilgi satırı.
  Widget _employerNotice(String? companyName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceLarge),
      child: Container(
        width: double.infinity,
        padding: AppPadding.chip,
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: _noticeAlpha),
          borderRadius: AppRadius.innerCircular,
        ),
        child: Row(
          children: [
            AppIcon(
              companyName != null ? AppIcons.building : AppIcons.user,
              size: AppSizes.iconSmall,
              color: context.accentColor,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: Text(
                companyName != null
                    ? '$companyName adına yayınlanacak'
                    : 'Bireysel ilan olarak yayınlanacak',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bilgi kutularının zemin opaklığı.
  static const double _noticeAlpha = 0.1;

  /// "Şablondan doldur" düğmesi ve uygulandıktan sonraki bilgi satırı.
  ///
  /// Formun en üstünde ama kimlik uyarısının altında: uyarı ilanın hiç
  /// açılamayacağını söylüyor, şablon yalnızca yazma emeğini azaltıyor.
  Widget _templateSection() {
    final appliedName = _appliedTemplateName;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoadingTemplates ? null : _pickTemplate,
              icon: const AppIcon(AppIcons.fileText, size: AppSizes.iconSmall),
              label: Text(
                appliedName == null
                    ? 'Şablondan Doldur'
                    : 'Şablon: $appliedName',
              ),
            ),
          ),
          if (appliedName != null) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            const BInfoNotice(
              message:
                  'Şablon uygulandı. Adres ve tarih şablona dahil değil; '
                  'bu ikisini bu ilan için kendiniz girin.',
            ),
          ],
        ],
      ),
    );
  }

  /// Doğrulanmamış bireysel işverene gösterilen uyarı.
  ///
  /// Formu doldurup en sonda kapıya çarpmaktansa baştan söylemek daha iyi —
  /// sigorta kategorilerini baştan elemekle aynı gerekçe.
  Widget? _identityNotice() {
    if (!_needsIdentityVerification) return null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceLarge),
      child: Container(
        width: double.infinity,
        padding: AppPadding.chip,
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: _noticeAlpha),
          borderRadius: AppRadius.innerCircular,
        ),
        child: Row(
          children: [
            const AppIcon(
              AppIcons.shield,
              size: AppSizes.iconSmall,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: Text(
                'İlan yayınlamak için kimlik doğrulaması gerekiyor.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: _goToIdentityVerification,
              child: const Text('Doğrula'),
            ),
          ],
        ),
      ),
    );
  }

  /// Bireysel işverene sigorta anahtarı yerine gösterilen açıklama.
  ///
  /// Kural sunucuda: SGK bildirimi işverenin yükümlülüğü olduğu için bir
  /// günlük iş açan bireysel işverenden beklenmiyor; sigortalı çalışma
  /// gerektiren kategoriler de bireysel ilana kapalı. Anahtarı sessizce
  /// gizlemek yerine nedenini yazmak, kategori listesinde neden daha az
  /// seçenek olduğunu da açıklıyor.
  Widget _insuranceNotice() {
    return Container(
      width: double.infinity,
      padding: AppPadding.chip,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.info,
            size: AppSizes.iconSmall,
            color: context.textTertiary,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              'Sigortalı çalışma yalnızca şirket ilanlarında sunulabilir.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- Konum

  Widget _locationSection() {
    return CanonicalAddressForm(
      controller: _addressController,
      pickPosition: _pickAddressPosition,
      referenceService: widget.referenceService,
    );
  }

  // ------------------------------------------------------------ Başarı kutusu

  @override
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spaceLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: BCreatePageModel._successCircleSize,
                height: BCreatePageModel._successCircleSize,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: BCreatePageModel._successIconSize,
                ),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              Text(
                'İlan Oluşturuldu!',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.spaceSmall),
              Text(
                'İlanınız başarıyla oluşturuldu ve aktif ilanlarınızda görüntülenecek.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSizes.spaceLarge),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    context.go('/business/posts');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentColor,
                    foregroundColor: context.onAccentColor,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.innerCircular,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.spaceMedium,
                    ),
                    textStyle: context.textTheme.labelLarge,
                  ),
                  child: const Text('İlanlarıma Git'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- Parçalar

  /// Kategori çipleri çizilemediğinde onların yerine geçen kutu.
  Widget _categoryNotice(String message, {required bool canRetry}) {
    return Container(
      width: double.infinity,
      padding: AppPadding.chip,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
          if (canRetry) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            GestureDetector(
              onTap: () =>
                  context.read<JobCategoryProvider>().load(force: true),
              child: Text(
                'Tekrar dene',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) =>
      Text(title, style: context.textTheme.titleMedium);

  /// Kategori alanı.
  ///
  /// Liste sunucudan geliyor ve büyüyebilir; o yüzden çip dizisi değil, il
  /// seçimiyle aynı açılır alan. Kategoriler hiç gelmediyse (hata ya da boş
  /// tanım) alanın yerine açıklama kutusu çiziliyor — dokunulduğunda boş bir
  /// sheet açan bir alan göstermenin anlamı yok.
  Widget _categorySelector() {
    final provider = context.watch<JobCategoryProvider>();

    final message = provider.errorMessage;
    if (message != null) return _categoryNotice(message, canRetry: true);

    if (provider.isEmpty) {
      return _categoryNotice(
        'Kategoriler henüz tanımlı değil. Sunucuda tanımlandığında burada '
        'görünecek.',
        canRetry: true,
      );
    }

    final category = _selectedCategory;

    return BSelectionField(
      label: "Kategori *",
      value: category?.displayName,
      placeholder: "Seçin",
      icon: category?.icon,
      iconColor: category?.color,
      enabled: provider.categories.isNotEmpty,
      isLoading: provider.isLoading && provider.categories.isEmpty,
      onTap: _pickCategory,
    );
  }

  Widget _typeSelector() {
    return _segmentedSelector<JobType>(
      options: JobType.values,
      selected: _selectedType,
      labelOf: (type) => type.displayName,
      onSelected: (type) => setState(() => _selectedType = type),
    );
  }

  Widget _salaryTypeSelector() {
    return _segmentedSelector<SalaryType>(
      options: SalaryType.values,
      selected: _selectedSalaryType,
      labelOf: (type) => '${type.displayName} ücret',
      onSelected: (type) => setState(() => _selectedSalaryType = type),
    );
  }

  List<Widget> _pricingBreakdown() {
    if (_isLoadingPricing) {
      return const [
        SizedBox(height: AppSizes.spaceSmall),
        LinearProgressIndicator(),
      ];
    }

    final breakdown = _pricingBreakdownValue;
    if (breakdown != null) {
      return [
        const SizedBox(height: AppSizes.spaceSmall),
        BPricingBreakdownCard(breakdown: breakdown),
      ];
    }

    if (_pricingUnavailable) {
      return const [
        SizedBox(height: AppSizes.spaceSmall),
        BInfoNotice(
          message:
              'Fiyat dökümü şu an alınamadı. İlanı yine de yayınlayabilirsin.',
        ),
      ];
    }

    return const [];
  }

  /// Yan yana duran, tek seçimli kutucuklar. İş tipi ve ücret tipi aynı
  /// görünümü paylaşıyor.
  Widget _segmentedSelector<T>({
    required List<T> options,
    required T selected,
    required String Function(T) labelOf,
    required ValueChanged<T> onSelected,
  }) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(options[i]),
              child: Container(
                margin: EdgeInsets.only(
                  right: i == options.length - 1 ? 0 : AppSizes.spaceSmall,
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSizes.space),
                decoration: BoxDecoration(
                  color: options[i] == selected
                      ? context.accentColor.withValues(alpha: _noticeAlpha)
                      : context.tileColor,
                  borderRadius: AppRadius.innerCircular,
                  border: Border.all(
                    color: options[i] == selected
                        ? context.accentColor
                        : context.dividerColor,
                    width: options[i] == selected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    labelOf(options[i]),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: options[i] == selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: options[i] == selected
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _descriptionTextField() {
    return MyTextfield(
      labelText: "Açıklama *",
      controller: _descriptionController,
      height: BCreatePageModel._descriptionHeight,
      expands: true,
      // Tek satırlık alanların tam yuvarlak köşesi bu yükseklikte metni
      // sıkıştırıyor.
      borderRadius: AppRadius.innerCircular,
    );
  }

  /// Anahtar kilitliyken neden kapatılamadığını söyleyen açıklama.
  ///
  /// Devre dışı bir anahtar tek başına "bozuk" görünüyor; kuralın kategoriden
  /// geldiğini yazmak, kategoriyi değiştirince kilidin kalkacağını da
  /// anlatıyor.
  Widget _insuranceLockedNotice() {
    return const Padding(
      padding: EdgeInsets.only(top: AppSizes.spaceSmall),
      child: BInfoNotice(
        message:
            'Bu kategoride sigortalı çalışma zorunlu, ilan bu şekilde '
            'yayınlanır.',
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceTiny),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.accentColor,
          ),
        ],
      ),
    );
  }
}
