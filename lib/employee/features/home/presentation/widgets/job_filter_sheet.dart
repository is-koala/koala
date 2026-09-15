import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_filter_selection.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_start_on_chips.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/filter_pill.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/widgets/option_sheet.dart';
import 'package:koala/product/widgets/sheet_switch_row.dart';

/// Keşfet'in tek süzgeç sheet'i.
///
/// Sunucunun kabul ettiği on bir alan yatay bir çubuğa sığmadığı için üç ayrı
/// düğme yerine tek sheet var. Seçimler sayfaya **"Uygula"ya basılana kadar**
/// yansımıyor: her değişimde istek atmak `GET /jobs`'un dakikada 120 istekli
/// PUBLIC kovasını tüketirdi.
class JobFilterSheet extends StatefulWidget {
  const JobFilterSheet({
    super.key,
    required this.selection,
    required this.categories,
    required this.hasLocation,
    this.onRequestLocation,
    this.locationService,
  });

  final JobFilterSelection selection;

  /// Sunucudan gelen kategoriler; `JobCategoryProvider` bunları uygulama
  /// boyunca elde tutuyor.
  final List<JobCategory> categories;

  /// Konum biliniyor mu. Bilinmiyorsa mesafe süzgeci **sessizce atlanmıyor**,
  /// kapalı çiziliyor ve sebebini yazıyor.
  final bool hasLocation;

  /// Konum izni istemeyi dener; izin alınırsa `true` döner.
  final Future<bool> Function()? onRequestLocation;

  /// İl/ilçe listelerinin kaynağı. Verilmezse uygulamanın tekil örneği
  /// kullanılıyor; testler kendi istemcisini geçiyor.
  final ReferenceLocationService? locationService;

  /// Sheet'i açar ve **yalnız "Uygula"ya basılırsa** yeni seçimi döndürür.
  static Future<JobFilterSelection?> show(
    BuildContext context, {
    required JobFilterSelection selection,
    required List<JobCategory> categories,
    required bool hasLocation,
    Future<bool> Function()? onRequestLocation,
    ReferenceLocationService? locationService,
  }) {
    return AppBottomSheet.show<JobFilterSelection>(
      context,
      builder: (_) => JobFilterSheet(
        selection: selection,
        categories: categories,
        hasLocation: hasLocation,
        onRequestLocation: onRequestLocation,
        locationService: locationService,
      ),
    );
  }

  /// Mesafe süzgecinin kovaları, km. Sunucu yarıçap değil sınırlayıcı kutu
  /// süzüyor; kutu bir halkanın **dışını** ifade edemediği için "20+ km" gibi
  /// açık uçlu bir kova yok.
  static const List<double> radiusOptions = [5, 10, 20, 50];

  @override
  State<JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends State<JobFilterSheet> {
  /// İçeriğin kaplayabileceği en fazla yükseklik oranı; altındaki liste
  /// görünmeye devam etsin.
  static const double _maxHeightRatio = 0.75;

  late JobFilterSelection _draft = widget.selection;
  late bool _hasLocation = widget.hasLocation;

  late final ReferenceLocationService _locations =
      widget.locationService ?? ReferenceLocationService();

  late final TextEditingController _minSalaryController = TextEditingController(
    text: _asField(widget.selection.minSalary),
  );
  late final TextEditingController _maxSalaryController = TextEditingController(
    text: _asField(widget.selection.maxSalary),
  );

  bool _loadingCities = false;
  bool _loadingDistricts = false;
  String? _errorMessage;

  @override
  void dispose() {
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    super.dispose();
  }

  static String _asField(double? value) =>
      value == null ? '' : value.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Süzgeçler',
      child: Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: context.dynamicHeight(_maxHeightRatio),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) _errorRow(_errorMessage!),
                      _startOnSection(),
                      _categorySection(),
                      _typeSection(),
                      _locationSection(),
                      _salaryTypeSection(),
                      _employerTypeSection(),
                      _salaryRangeSection(),
                      _distanceSection(),
                      _requirementSection(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            _actions(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- Bölümler

  Widget _startOnSection() {
    return _section(
      'Başlangıç günü',
      JobStartOnChips(
        selected: _draft.startOn,
        onChanged: (value) =>
            setState(() => _draft = _draft.copyWith(startOn: value)),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textTheme.titleSmall),
          const SizedBox(height: AppSizes.spaceSmall),
          child,
        ],
      ),
    );
  }

  Widget _pills(List<Widget> children) => Wrap(
    spacing: AppSizes.spaceSmall,
    runSpacing: AppSizes.spaceSmall,
    children: children,
  );

  Widget _errorRow(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceMedium),
      child: Text(
        message,
        style: context.textTheme.labelMedium?.copyWith(color: AppColors.danger),
      ),
    );
  }

  /// Kategori ve tür **ayrı** bölümler.
  ///
  /// Eskiden tek listedeydiler ve "Günlük" seçen kullanıcı kategorisini
  /// kaybediyordu: ikisi tek `String` alanda tutuluyordu. Sunucuda da ayrı iki
  /// alan — `categoryId` ve `type`.
  Widget _categorySection() {
    return _section(
      'Kategori',
      _pills([
        FilterPill(
          label: 'Tümü',
          isSelected: _draft.category == null,
          onTap: () => setState(() => _draft = _draft.copyWith(category: null)),
        ),
        for (final category in widget.categories)
          FilterPill(
            label: category.displayName,
            isSelected: _draft.category == category,
            onTap: () =>
                setState(() => _draft = _draft.copyWith(category: category)),
          ),
      ]),
    );
  }

  Widget _typeSection() {
    return _section(
      'Tür',
      _pills([
        FilterPill(
          label: 'Tümü',
          isSelected: _draft.type == null,
          onTap: () => setState(() => _draft = _draft.copyWith(type: null)),
        ),
        for (final type in JobType.values)
          FilterPill(
            label: type.displayName,
            isSelected: _draft.type == type,
            onTap: () => setState(() => _draft = _draft.copyWith(type: type)),
          ),
      ]),
    );
  }

  /// İl ve ilçe: 81 il çip dizisine sığmadığı için [OptionSheet].
  Widget _locationSection() {
    return _section(
      'Konum',
      Column(
        children: [
          _selectionRow(
            label: 'İl',
            value: _draft.city?.name,
            loading: _loadingCities,
            onTap: _pickCity,
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          _selectionRow(
            label: 'İlçe',
            value: _draft.district?.name,
            loading: _loadingDistricts,
            // İl seçilmeden ilçe listesi açılmıyor: uç
            // `/reference/cities/{cityId}/districts`, il kimliği olmadan
            // çağrılamıyor.
            onTap: _draft.city == null ? null : _pickDistrict,
          ),
        ],
      ),
    );
  }

  Widget _selectionRow({
    required String label,
    required String? value,
    required bool loading,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.innerCircular,
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: AppPadding.tile,
            decoration: BoxDecoration(
              color: context.tileColor,
              borderRadius: AppRadius.innerCircular,
            ),
            child: Row(
              children: [
                Text(
                  label,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox.square(
                    dimension: AppSizes.iconSmall,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  Text(
                    value ?? 'Tümü',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: value == null
                          ? context.textTertiary
                          : context.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceSmall),
                  AppIcon(
                    AppIcons.chevronDown,
                    size: AppSizes.iconMedium,
                    color: context.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _salaryTypeSection() {
    return _section(
      'Ücret tipi',
      _pills([
        FilterPill(
          label: 'Tümü',
          isSelected: _draft.salaryType == null,
          onTap: () =>
              setState(() => _draft = _draft.copyWith(salaryType: null)),
        ),
        for (final type in SalaryType.values)
          FilterPill(
            label: type.displayName,
            isSelected: _draft.salaryType == type,
            onTap: () =>
                setState(() => _draft = _draft.copyWith(salaryType: type)),
          ),
      ]),
    );
  }

  Widget _employerTypeSection() {
    return _section(
      'İşveren tipi',
      _pills([
        FilterPill(
          label: 'Tümü',
          isSelected: _draft.employerType == null,
          onTap: () =>
              setState(() => _draft = _draft.copyWith(employerType: null)),
        ),
        for (final type in JobEmployerType.values)
          FilterPill(
            label: type.displayName,
            isSelected: _draft.employerType == type,
            onTap: () =>
                setState(() => _draft = _draft.copyWith(employerType: type)),
          ),
      ]),
    );
  }

  /// Ücret aralığı iki sayısal alan.
  ///
  /// Kova çipleri (`0-500`, `2000+`) kaldırıldı: sunucuda karşılıkları
  /// `minSalary`/`maxSalary` `BigDecimal` çifti ve kovalar aradaki değerleri
  /// seçilemez yapıyordu. `lib/` altında hiç `RangeSlider` yok, bu yüzden
  /// mevcut desen olan iki `MyTextfield` kullanılıyor.
  Widget _salaryRangeSection() {
    return _section(
      'Ücret aralığı',
      Row(
        children: [
          Expanded(
            child: MyTextfield(
              labelText: 'En az ₺',
              controller: _minSalaryController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => setState(
                () => _draft = _draft.copyWith(minSalary: _parse(value)),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: MyTextfield(
              labelText: 'En çok ₺',
              controller: _maxSalaryController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => setState(
                () => _draft = _draft.copyWith(maxSalary: _parse(value)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double? _parse(String value) => double.tryParse(value.trim());

  /// Mesafe süzgeci.
  ///
  /// Konum izni yokken seçenekler **kapalı** çiziliyor ve altında sebebi
  /// yazıyor; eskiden izin yoksa süzgeç sessizce yok sayılıyordu ve kullanıcı
  /// seçtiği süzgecin çalışmadığını hiç öğrenmiyordu.
  Widget _distanceSection() {
    return _section(
      'Mesafe',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pills([
            FilterPill(
              label: 'Tümü',
              isSelected: _draft.radiusKm == null,
              enabled: _hasLocation,
              onTap: () =>
                  setState(() => _draft = _draft.copyWith(radiusKm: null)),
            ),
            for (final radius in JobFilterSheet.radiusOptions)
              FilterPill(
                label: '${radius.toStringAsFixed(0)} km içinde',
                isSelected: _draft.radiusKm == radius,
                enabled: _hasLocation,
                onTap: () =>
                    setState(() => _draft = _draft.copyWith(radiusKm: radius)),
              ),
          ]),
          if (!_hasLocation) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              'Mesafeye göre süzmek için konum izni gerekiyor.',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            if (widget.onRequestLocation != null)
              TextButton(
                onPressed: _requestLocation,
                child: Text(
                  'Konum İznini Aç',
                  style: context.textTheme.labelLarge?.copyWith(
                    color: context.accentColor,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Sigorta ve deneyim şartı.
  ///
  /// Anahtar kapalıyken alan sorguya **hiç konmuyor** (`null`), açıkken `true`
  /// gidiyor. Kapalıyı `false` göndermek "şartsız ilanları getir" demek olurdu;
  /// kullanıcı anahtarı kapatarak bunu istemiş olmuyor.
  Widget _requirementSection() {
    return _section(
      'Şartlar',
      Column(
        children: [
          SheetSwitchRow(
            title: 'Sigortalı ilanlar',
            value: _draft.insuranceRequired == true,
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(
                insuranceRequired: value ? true : null,
              ),
            ),
          ),
          SheetSwitchRow(
            title: 'Deneyim isteyen ilanlar',
            value: _draft.experienceRequired == true,
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(
                experienceRequired: value ? true : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: AppSizes.buttonHeightCompact,
            child: OutlinedButton(
              onPressed: _clear,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.dividerColor),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.innerCircular,
                ),
              ),
              child: Text(
                'Temizle',
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spaceSmall),
        Expanded(
          child: SizedBox(
            height: AppSizes.buttonHeightCompact,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _draft),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: context.onAccentColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.innerCircular,
                ),
                elevation: 0,
              ),
              // textTheme slotları renk taşıyor; verilmezse buton zemini yeşil
              // olduğu hâlde metin koyu kalır.
              child: Text(
                'Uygula',
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.onAccentColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- Eylemler

  /// Taslağı sıfırlar ama sayfaya yansıtmaz: "Uygula"ya basılana kadar hiçbir
  /// şey değişmemeli kuralı temizlemede de geçerli.
  void _clear() {
    setState(() {
      _draft = _draft.cleared();
      _minSalaryController.clear();
      _maxSalaryController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _requestLocation() async {
    final granted = await widget.onRequestLocation?.call() ?? false;
    if (!mounted) return;
    setState(() => _hasLocation = granted);
  }

  /// İl listesi bir **ülke kimliği** istiyor: `/reference/cities` diye bir uç
  /// yok, uç `/reference/countries/{countryId}/cities`.
  Future<void> _pickCity() async {
    setState(() {
      _loadingCities = true;
      _errorMessage = null;
    });

    List<ReferenceLocation> cities = const [];
    try {
      final countries = await _locations.fetchCountries();
      final country = countries.firstWhere(
        (item) => item.code == _turkeyCode,
        orElse: () => countries.isEmpty
            ? const ReferenceLocation(id: '', name: '')
            : countries.first,
      );
      if (country.id.isNotEmpty) {
        cities = await _locations.fetchCities(country.id);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCities = false;
        _errorMessage = error.message;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loadingCities = false);

    final picked = await OptionSheet.show<ReferenceLocation>(
      context,
      title: 'İl',
      options: cities,
      selected: _draft.city,
      labelOf: (city) => city.name,
    );
    if (picked == null || !mounted) return;

    // İl değişince ilçe seçimi düşüyor: başka bir ilin ilçesi sorguda kalırsa
    // sonuç sessizce boşalır.
    setState(() => _draft = _draft.copyWith(city: picked, district: null));
  }

  Future<void> _pickDistrict() async {
    final city = _draft.city;
    if (city == null) return;

    setState(() {
      _loadingDistricts = true;
      _errorMessage = null;
    });

    List<ReferenceLocation> districts = const [];
    try {
      districts = await _locations.fetchDistricts(city.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingDistricts = false;
        _errorMessage = error.message;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loadingDistricts = false);

    final picked = await OptionSheet.show<ReferenceLocation>(
      context,
      title: 'İlçe',
      options: districts,
      selected: _draft.district,
      labelOf: (district) => district.name,
    );
    if (picked == null || !mounted) return;

    setState(() => _draft = _draft.copyWith(district: picked));
  }

  /// `ReferenceLocation.code` ülkede ISO kodunu taşıyor.
  static const String _turkeyCode = 'TR';
}
