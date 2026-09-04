import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/employee/features/auth/models/education.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/employee/features/profile/presentation/widgets/academic_picker_sheet.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/models/academic_reference.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/academic_reference_service.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/sheet_switch_row.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

/// Formun döndürdüğü değerler.
///
/// Sheet ağa yazmıyor: kaydetmeyi çağıran sayfa yapıyor, böylece hata ve
/// tazeleme tek yerde kalıyor. Referans listelerini **okumak** için ağa
/// çıkıyor, o ayrı iş.
class EducationFormResult {
  const EducationFormResult({
    required this.universityId,
    required this.facultyId,
    required this.departmentId,
    required this.type,
    required this.startDate,
    this.gpa,
    this.endDate,
  });

  final String universityId;
  final String facultyId;
  final String departmentId;
  final GradeType type;
  final DateTime startDate;
  final double? gpa;
  final DateTime? endDate;
}

/// Öğrenim kaydı ekleme ve düzenleme formu.
///
/// Üç seçim birbirine bağlı: fakülteler üniversiteye, bölümler fakülteye
/// göre isteniyor. Üsttekini değiştirmek alttakileri temizliyor — aksi
/// hâlde başka üniversitenin fakültesi seçili kalırdı.
class EducationSheet extends StatefulWidget {
  const EducationSheet({super.key, this.initial});

  final Education? initial;

  static Future<EducationFormResult?> show(
    BuildContext context, {
    Education? initial,
  }) {
    return AppBottomSheet.show<EducationFormResult>(
      context,
      builder: (_) => EducationSheet(initial: initial),
    );
  }

  @override
  State<EducationSheet> createState() => _EducationSheetState();
}

class _EducationSheetState extends State<EducationSheet> {
  final AcademicReferenceService _reference = AcademicReferenceService();
  late final TextEditingController _gpa;

  AcademicReference? _university;
  AcademicReference? _faculty;
  AcademicReference? _department;

  late GradeType _type;
  DateTime? _startDate;
  DateTime? _endDate;

  /// Öğrenim sürüyor mu. Sunucuda karşılığı `endDate: null`.
  late bool _isContinuing;

  /// Hangi alanın listesi çekiliyor; o alanın yerine göstergesi çıkıyor.
  String? _loadingField;

  /// Tarih seçicinin gidebileceği en eski yıl.
  static const int _earliestYear = 1960;

  /// Not ortalamasının üst sınırı; sunucu da 0–4 aralığını zorluyor.
  static const double _maxGpa = 4;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;

    _gpa = TextEditingController(
      text: initial?.gpa == null ? '' : '${initial!.gpa}',
    );
    _type = initial?.type ?? GradeType.graduate;
    _startDate = initial?.startDate;
    _endDate = initial?.endDate;
    _isContinuing = initial != null && initial.endDate == null;

    // Düzenlemede kimlikler ve adlar zaten kayıtta; listeleri beklemeden
    // seçili göstermek için doğrudan kuruluyor.
    _university = _referenceOf(initial?.universityId, initial?.universityName);
    _faculty = _referenceOf(initial?.facultyId, initial?.facultyName);
    _department = _referenceOf(initial?.departmentId, initial?.departmentName);
  }

  static AcademicReference? _referenceOf(String? id, String? name) {
    return id == null ? null : AcademicReference(id: id, name: name ?? '');
  }

  @override
  void dispose() {
    _gpa.dispose();
    super.dispose();
  }

  /// Sunucunun zorunlu tuttuğu alanlar dolu mu.
  bool get _canSave =>
      _university != null &&
      _faculty != null &&
      _department != null &&
      _startDate != null &&
      _isGpaAcceptable;

  /// Not alanı boş ya da geçerli mi. Boş bırakmak serbest; girilen değer
  /// aralık dışındaysa kaydettirmiyoruz.
  bool get _isGpaAcceptable => _gpaText.isEmpty || _parsedGpa != null;

  String get _gpaText => _gpa.text.trim().replaceAll(',', '.');

  /// Girilen not. Boşsa ya da okunamıyorsa `null`.
  ///
  /// "Girilmedi" ile "hatalı girildi" ayrımı [_isGpaAcceptable] üzerinden
  /// yapılıyor; ikisini tek bir sayıya (ör. `-1`) sıkıştırmak, sayı gibi
  /// davranmayan bir sayı üretiyordu.
  double? get _parsedGpa {
    final text = _gpaText;
    if (text.isEmpty) return null;

    final value = double.tryParse(text);
    if (value == null || value < 0 || value > _maxGpa) return null;

    return value;
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: widget.initial == null ? 'Eğitim Ekle' : 'Eğitimi Düzenle',
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pickerField(
                label: 'Üniversite',
                value: _university?.name,
                onTap: _pickUniversity,
              ),
              const SizedBox(height: AppSizes.space),
              _pickerField(
                label: 'Fakülte',
                value: _faculty?.name,
                // Üniversite seçilmeden fakülte istenemiyor; uç
                // üniversitenin kimliğiyle çağrılıyor.
                onTap: _university == null ? null : _pickFaculty,
              ),
              const SizedBox(height: AppSizes.space),
              _pickerField(
                label: 'Bölüm',
                value: _department?.name,
                onTap: _faculty == null ? null : _pickDepartment,
              ),
              const SizedBox(height: AppSizes.space),
              _typeField(),
              const SizedBox(height: AppSizes.space),
              MyTextfield(
                labelText: 'Not ortalaması (isteğe bağlı)',
                controller: _gpa,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
              if (!_isGpaAcceptable) _gpaError(),
              const SizedBox(height: AppSizes.space),
              _dateField(
                label: 'Başlangıç',
                value: _startDate,
                onTap: _pickStartDate,
              ),
              const SizedBox(height: AppSizes.space),
              _continuingToggle(),
              if (!_isContinuing) ...[
                const SizedBox(height: AppSizes.space),
                _dateField(
                  label: 'Bitiş',
                  value: _endDate,
                  onTap: _pickEndDate,
                ),
              ],
              const SizedBox(height: AppSizes.spaceLarge),
              MyButton(title: 'Kaydet', onPressed: _canSave ? _submit : null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gpaError() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spaceTiny),
      child: Text(
        'Not ortalaması 0 ile 4 arasında olmalı.',
        style: context.textTheme.labelMedium?.copyWith(color: AppColors.danger),
      ),
    );
  }

  Widget _typeField() {
    return DropdownButtonFormField<GradeType>(
      initialValue: _type,
      decoration: InputDecoration(
        labelText: 'Kademe',
        border: OutlineInputBorder(borderRadius: AppRadius.innerCircular),
      ),
      items: GradeType.values
          .map(
            (type) =>
                DropdownMenuItem(value: type, child: Text(type.displayName)),
          )
          .toList(),
      onChanged: (type) => setState(() => _type = type ?? _type),
    );
  }

  /// Seçim alanı. [onTap] `null` ise alan sönük çiziliyor — üstteki seçim
  /// yapılmadan alttaki istenemiyor.
  Widget _pickerField({
    required String label,
    required String? value,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    final isLoading = _loadingField == label;

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: AppRadius.innerCircular,
      child: Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          borderRadius: AppRadius.innerCircular,
          border: Border.all(color: context.dividerColor),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: isEnabled ? context.textSecondary : context.textTertiary,
              ),
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(child: _pickerValue(value, isEnabled, isLoading)),
          ],
        ),
      ),
    );
  }

  Widget _pickerValue(String? value, bool isEnabled, bool isLoading) {
    if (isLoading) {
      return const Align(
        alignment: Alignment.centerRight,
        child: SizedBox.square(
          dimension: AppSizes.iconMedium,
          child: CircularProgressIndicator(strokeWidth: _spinnerStroke),
        ),
      );
    }

    return Text(
      value == null || value.isEmpty ? 'Seç' : value,
      textAlign: TextAlign.right,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodyMedium?.copyWith(
        color: value == null || value.isEmpty ? context.textTertiary : null,
        fontWeight: value == null || value.isEmpty ? null : FontWeight.w600,
      ),
    );
  }

  /// Alan içindeki göstergenin çizgi kalınlığı; varsayılanı kutuda kaba
  /// duruyor.
  static const double _spinnerStroke = 2;

  Widget _continuingToggle() {
    return SheetSwitchRow(
      title: 'Hâlâ okuyorum',
      value: _isContinuing,
      onChanged: (value) => setState(() {
        _isContinuing = value;
        if (value) _endDate = null;
      }),
    );
  }

  /// Listeyi çeker ve seçtirir. Çağrı düşerse hata gösteriliyor, seçim
  /// değişmiyor.
  Future<AcademicReference?> _pick({
    required String label,
    required Future<List<AcademicReference>> Function() load,
    AcademicReference? selected,
  }) async {
    setState(() => _loadingField = label);

    try {
      final items = await load();
      if (!mounted) return null;

      return await AcademicPickerSheet.show(
        context,
        title: label,
        items: items,
        selected: selected,
      );
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
      return null;
    } finally {
      if (mounted) setState(() => _loadingField = null);
    }
  }

  Future<void> _pickUniversity() async {
    final picked = await _pick(
      label: 'Üniversite',
      load: _reference.fetchUniversities,
      selected: _university,
    );
    if (picked == null || picked == _university) return;

    setState(() {
      _university = picked;
      // Üniversite değişti: altındaki iki seçim artık başka bir okula ait.
      _faculty = null;
      _department = null;
    });
  }

  Future<void> _pickFaculty() async {
    final university = _university;
    if (university == null) return;

    final picked = await _pick(
      label: 'Fakülte',
      load: () => _reference.fetchFaculties(university.id),
      selected: _faculty,
    );
    if (picked == null || picked == _faculty) return;

    setState(() {
      _faculty = picked;
      _department = null;
    });
  }

  Future<void> _pickDepartment() async {
    final faculty = _faculty;
    if (faculty == null) return;

    final picked = await _pick(
      label: 'Bölüm',
      load: () => _reference.fetchDepartments(faculty.id),
      selected: _department,
    );
    if (picked == null) return;

    setState(() => _department = picked);
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.innerCircular,
      child: Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          borderRadius: AppRadius.innerCircular,
          border: Border.all(color: context.dividerColor),
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
            Text(
              value == null ? 'Seç' : value.asMonthYear,
              style: context.textTheme.bodyMedium?.copyWith(
                color: value == null ? context.textTertiary : null,
                fontWeight: value == null ? null : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(_earliestYear),
      lastDate: now,
    );
    if (picked == null) return;

    setState(() {
      _startDate = picked;
      // Bitiş başlangıçtan önce kalamaz; sunucu da reddediyor.
      if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
    });
  }

  /// Bitiş **gelecekte olabilir**: mezuniyet tarihi henüz gelmemiş olabilir.
  /// Sunucu yalnızca bitişin başlangıçtan önce olmamasını istiyor.
  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: _startDate ?? DateTime(_earliestYear),
      lastDate: DateTime(now.year + _futureYears),
    );
    if (picked == null) return;

    setState(() => _endDate = picked);
  }

  /// Bitiş tarihinin gidebileceği ileri yıl sayısı; bir lisans öğrencisinin
  /// mezuniyetini seçmesine yetiyor.
  static const int _futureYears = 8;

  void _submit() {
    Navigator.pop(
      context,
      EducationFormResult(
        universityId: _university!.id,
        facultyId: _faculty!.id,
        departmentId: _department!.id,
        type: _type,
        startDate: _startDate!,
        gpa: _parsedGpa,
        endDate: _isContinuing ? null : _endDate,
      ),
    );
  }
}
