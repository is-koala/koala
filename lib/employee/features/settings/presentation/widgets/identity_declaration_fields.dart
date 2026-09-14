import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/employee/features/settings/models/national_identity_number.dart';
import 'package:koala/product/widgets/settings_hint.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/my_textfield.dart';

/// Elle beyanın beş alanı: ad, soyad, TCKN, seri no ve doğum tarihi.
///
/// İki ekran aynı beyanı topluyor — çip/beyan formu
/// (`POST /users/me/identity-verification`) ve fotoğraflı inceleme
/// (`identity` JSON parçası). Alanlar ve doğum tarihi seçicinin sınırları
/// tek yerde dursun ki iki ekran farklı yaş sınırı ya da farklı etiket
/// taşımasın.
///
/// Denetleyiciler dışarıdan geliyor: sayfa beyanı onlardan kuruyor ve
/// gönderim gövdesi ekrandakiyle aynı kaynaktan okunuyor.
class IdentityDeclarationFields extends StatelessWidget {
  const IdentityDeclarationFields({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.tcIdentity,
    required this.tcDocument,
    required this.birthDate,
    required this.onChanged,
    required this.onBirthDateChanged,
  });

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController tcIdentity;
  final TextEditingController tcDocument;

  final DateTime? birthDate;

  /// Metin alanlarından biri değişti; sayfa gönder düğmesini yeniden
  /// değerlendiriyor.
  final VoidCallback onChanged;

  final ValueChanged<DateTime> onBirthDateChanged;

  /// Doğum tarihi seçicinin gidebileceği en eski yıl.
  static const int earliestYear = 1920;

  /// Çalışma yaşı alt sınırı; seçici bundan yenisini göstermiyor.
  static const int minimumAge = 15;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyTextfield(
          labelText: 'Ad',
          controller: firstName,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(
          labelText: 'Soyad',
          controller: lastName,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(
          labelText: 'TC Kimlik No',
          controller: tcIdentity,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(NationalIdentityNumber.length),
          ],
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(
          labelText: 'Seri No',
          controller: tcDocument,
          onChanged: (_) => onChanged(),
        ),
        const SettingsHint('Kimlik kartının ön yüzündeki seri numarası.'),
        const SizedBox(height: AppSizes.spaceMedium),
        _birthDateField(context),
      ],
    );
  }

  Widget _birthDateField(BuildContext context) {
    final selected = birthDate;

    return InkWell(
      onTap: () => _pickBirthDate(context),
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
              'Doğum tarihi',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              selected == null ? 'Seç' : selected.asShortDate,
              style: context.textTheme.bodyMedium?.copyWith(
                color: selected == null ? context.textTertiary : null,
                fontWeight: selected == null ? null : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthDate(BuildContext context) async {
    final now = DateTime.now();
    final latest = DateTime(now.year - minimumAge, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? latest,
      firstDate: DateTime(earliestYear),
      lastDate: latest,
    );
    if (picked == null) return;

    onBirthDateChanged(picked);
  }
}
