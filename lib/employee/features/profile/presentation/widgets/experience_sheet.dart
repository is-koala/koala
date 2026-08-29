import 'package:flutter/material.dart';
import 'package:koala/employee/features/auth/models/experience.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

/// Formun döndürdüğü değerler.
///
/// Sheet'in kendisi ağa çıkmıyor: kaydetmeyi çağıran sayfa yapıyor, böylece
/// hata ve tazeleme tek yerde kalıyor.
class ExperienceFormResult {
  const ExperienceFormResult({
    required this.title,
    required this.startDate,
    this.companyName,
    this.employmentType,
    this.cityName,
    this.endDate,
    this.description,
  });

  final String title;
  final DateTime startDate;
  final String? companyName;
  final EmploymentType? employmentType;
  final String? cityName;
  final DateTime? endDate;
  final String? description;
}

/// Deneyim ekleme ve düzenleme formu.
///
/// [initial] doluysa düzenleme: uç `PUT` olduğu için alanlar mevcut
/// değerlerle doluyor — boş bırakılan alan sunucuda temizleniyor.
class ExperienceSheet extends StatefulWidget {
  const ExperienceSheet({super.key, this.initial});

  final Experience? initial;

  /// Sheet'i açar; kaydedilirse form sonucunu, vazgeçilirse `null` döner.
  static Future<ExperienceFormResult?> show(
    BuildContext context, {
    Experience? initial,
  }) {
    return AppBottomSheet.show<ExperienceFormResult>(
      context,
      builder: (_) => ExperienceSheet(initial: initial),
    );
  }

  @override
  State<ExperienceSheet> createState() => _ExperienceSheetState();
}

class _ExperienceSheetState extends State<ExperienceSheet> {
  late final TextEditingController _title;
  late final TextEditingController _company;
  late final TextEditingController _city;
  late final TextEditingController _description;

  late EmploymentType _employmentType;
  DateTime? _startDate;
  DateTime? _endDate;

  /// Deneyim hâlâ sürüyor mu. Sunucuda karşılığı `endDate: null`.
  late bool _isCurrent;

  /// Tarih seçicinin gidebileceği en eski yıl; iş geçmişi için fazlasıyla
  /// yeterli ve seçiciyi gereksiz uzatmıyor.
  static const int _earliestYear = 1960;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;

    _title = TextEditingController(text: initial?.title ?? '');
    _company = TextEditingController(text: initial?.companyName ?? '');
    _city = TextEditingController(text: initial?.cityName ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _employmentType = initial?.employmentType ?? EmploymentType.fullTime;
    _startDate = initial?.startDate;
    _endDate = initial?.endDate;
    _isCurrent = initial != null && initial.endDate == null;
  }

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _city.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Kaydedilebilir mi: sunucunun zorunlu tuttuğu iki alan dolu mu.
  bool get _canSave => _title.text.trim().isNotEmpty && _startDate != null;

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: widget.initial == null ? 'Deneyim Ekle' : 'Deneyimi Düzenle',
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyTextfield(
                labelText: 'Pozisyon',
                controller: _title,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.space),
              MyTextfield(labelText: 'Şirket', controller: _company),
              const SizedBox(height: AppSizes.space),
              MyTextfield(labelText: 'Şehir', controller: _city),
              const SizedBox(height: AppSizes.space),
              _employmentTypeField(),
              const SizedBox(height: AppSizes.space),
              _dateField(
                label: 'Başlangıç',
                value: _startDate,
                onTap: _pickStartDate,
              ),
              const SizedBox(height: AppSizes.space),
              _currentToggle(),
              if (!_isCurrent) ...[
                const SizedBox(height: AppSizes.space),
                _dateField(
                  label: 'Bitiş',
                  value: _endDate,
                  onTap: _pickEndDate,
                ),
              ],
              const SizedBox(height: AppSizes.space),
              MyTextfield(
                labelText: 'Açıklama',
                controller: _description,
                expands: true,
                height: _descriptionHeight,
              ),
              const SizedBox(height: AppSizes.spaceLarge),
              MyButton(title: 'Kaydet', onPressed: _canSave ? _submit : null),
            ],
          ),
        ),
      ),
    );
  }

  /// Çok satırlı açıklama alanının yüksekliği.
  static const double _descriptionHeight = 100;

  Widget _employmentTypeField() {
    return DropdownButtonFormField<EmploymentType>(
      initialValue: _employmentType,
      decoration: InputDecoration(
        labelText: 'Çalışma biçimi',
        border: OutlineInputBorder(borderRadius: AppRadius.innerCircular),
      ),
      items: EmploymentType.values
          .map(
            (type) =>
                DropdownMenuItem(value: type, child: Text(type.displayName)),
          )
          .toList(),
      onChanged: (type) =>
          setState(() => _employmentType = type ?? _employmentType),
    );
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

  Widget _currentToggle() {
    return SwitchListTile.adaptive(
      contentPadding: AppPadding.zero,
      value: _isCurrent,
      onChanged: (value) => setState(() {
        _isCurrent = value;
        // Sunucuda "sürüyor" demek bitiş tarihinin olmaması demek.
        if (value) _endDate = null;
      }),
      title: Text('Hâlâ çalışıyorum', style: context.textTheme.bodyMedium),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    // Sunucu gelecekte başlangıç kabul etmiyor (`@PastOrPresent`).
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

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: _startDate ?? DateTime(_earliestYear),
      lastDate: now,
    );
    if (picked == null) return;

    setState(() => _endDate = picked);
  }

  void _submit() {
    Navigator.pop(
      context,
      ExperienceFormResult(
        title: _title.text.trim(),
        startDate: _startDate!,
        companyName: _company.text,
        employmentType: _employmentType,
        cityName: _city.text,
        endDate: _isCurrent ? null : _endDate,
        description: _description.text,
      ),
    );
  }
}
