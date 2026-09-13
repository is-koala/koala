import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/models/identity_declaration.dart';
import 'package:koala/employee/features/settings/models/identity_error.dart';
import 'package:koala/employee/features/settings/models/national_identity_number.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_chip_card.dart';
import 'package:koala/employee/features/settings/presentation/widgets/locked_field.dart';
import 'package:koala/employee/features/settings/presentation/widgets/settings_hint.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

part 'identity_verification_pagemodel.dart';

/// Kimlik doğrulama formu.
///
/// İlana başvurabilmenin ilk şartı: sunucu doğrulanmamış kullanıcının
/// başvurusunu `APPLICANT_IDENTITY_NOT_VERIFIED` ile reddediyor.
///
/// Ekranın **iki yolu** var ve ikincisi zorunlu değil:
///
/// 1. **Beyan** — beş alan doldurulup gönderiliyor. Sunucudaki
///    `IDENTITY_PASSIVE_AUTH_ENABLED` bugün `false` olduğu için bu yol tek
///    başına çalışıyor ve bu sürüm yayına çıktığında hiçbir şey değişmiyor.
/// 2. **Çip** — kimlik kartının çipi okunup kanıt (`sod`, `dg1`, varsa
///    `dg11`/`dg15` ve imza) aynı isteğe ekleniyor. NFC'si olmayan telefon,
///    okunmayan kart ya da vazgeçen kullanıcı birinci yola düşüyor; çip bir
///    kapı değil.
///
/// Çip okunduğunda beş alan da **kanıttan türüyor ve salt okunur**: ad,
/// soyad, TCKN, seri no ve doğum tarihi DG1/DG11'den geliyor, ekranda
/// yazılabilir bir alan kalmıyor. Elle düzenlemeye dönüşün tek yolu
/// okumayı kaldırmak; o da kanıtı ve türeyen alanları birlikte bırakıyor.
/// Böylece gönderilen beyan, ekranın kanıtın yanında gösterdiğinin birebir
/// aynısı (is-koala/koala#136).
///
/// Doğrulama başarılı olduğunda ad ve soyad **kilitleniyor** — hesap
/// bilgileri ekranı da o noktadan sonra ikisini düzenletmiyor.
class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({
    super.key,
    required this.user,
    this.userService,
  });

  final CurrentUser user;

  /// Testlerde gerçek API yerine sahte sunucuya bağlı servis kullanılabilir.
  final UserService? userService;

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends IdentityVerificationPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Kimlik Doğrulama'),
      bottomNavigationBar: ButtonNavbar(
        onPressed: canSubmit ? submit : null,
        title: 'Doğrula',
        isLoading: isSubmitting,
      ),
      body: SingleChildScrollView(
        padding: AppPadding.primaryAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _intro(),
            const SizedBox(height: AppSizes.spaceMedium),
            IdentityChipCard(
              result: chip,
              onRead: readChip,
              onRemove: removeChip,
            ),
            const SizedBox(height: AppSizes.spaceLarge),
            // Hangi form çizileceğine beyanın tipi karar veriyor; ayrı bir
            // "kilitli mi" bayrağı yok, olsaydı beyanla ayrışabilirdi.
            ...switch (declaration) {
              ManualDeclaration() => _manualFields(),
              ChipDeclaration(:final chip) => _lockedFields(chip),
            },
            const SizedBox(height: AppSizes.navBarClearance),
          ],
        ),
      ),
    );
  }

  /// Elle beyan: dört metin alanı ve doğum tarihi seçici.
  List<Widget> _manualFields() {
    return [
      MyTextfield(
        labelText: 'Ad',
        controller: firstName,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: AppSizes.spaceMedium),
      MyTextfield(
        labelText: 'Soyad',
        controller: lastName,
        onChanged: (_) => setState(() {}),
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
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: AppSizes.spaceMedium),
      MyTextfield(
        labelText: 'Seri No',
        controller: tcDocument,
        onChanged: (_) => setState(() {}),
      ),
      const SettingsHint('Kimlik kartının ön yüzündeki seri numarası.'),
      const SizedBox(height: AppSizes.spaceMedium),
      _birthDateField(),
    ];
  }

  /// Çipten türeyen beyan: beş satır, hepsi salt okunur ve değerleri
  /// doğrudan kanıttan. Denetleyicilere hiç bakılmıyor.
  List<Widget> _lockedFields(IdentityChipResult read) {
    final holder = read.holder;
    return [
      LockedField(label: 'Ad', value: holder.firstName),
      const SizedBox(height: AppSizes.spaceMedium),
      LockedField(label: 'Soyad', value: holder.lastName),
      const SizedBox(height: AppSizes.spaceMedium),
      LockedField(label: 'TC Kimlik No', value: holder.nationalIdentityNumber),
      const SizedBox(height: AppSizes.spaceMedium),
      LockedField(label: 'Seri No', value: holder.documentNumber),
      const SizedBox(height: AppSizes.spaceMedium),
      LockedField(label: 'Doğum tarihi', value: holder.birthDate.asShortDate),
      const SettingsHint(
        'Bu bilgiler kartın çipinden okundu; değiştirmek için okumayı kaldır.',
      ),
    ];
  }

  Widget _intro() {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Text(
        'İşe başvurabilmen ve ücretini alabilmen için kimliğini bir kez '
        'doğrulaman gerekiyor. Bilgiler kimlik kartındakiyle birebir aynı '
        'olmalı; doğrulandıktan sonra adın, soyadın ve doğum tarihin '
        'değiştirilemez.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.textSecondary,
          height: _lineHeight,
        ),
      ),
    );
  }

  /// Bilgilendirme metinlerinin satır aralığı.
  static const double _lineHeight = 1.4;

  Widget _birthDateField() {
    final selected = birthDate;

    return InkWell(
      onTap: pickBirthDate,
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
}
