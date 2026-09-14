import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/models/identity_declaration.dart';
import 'package:koala/employee/features/settings/models/identity_error.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_chip_page.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_chip_card.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_declaration_fields.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_photo_path_card.dart';
import 'package:koala/employee/features/settings/presentation/widgets/locked_field.dart';
import 'package:koala/employee/features/settings/presentation/widgets/settings_hint.dart';
import 'package:koala/employee/features/settings/services/chip_reader.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

part 'identity_verification_pagemodel.dart';

/// Kimlik doğrulamanın giriş ekranı.
///
/// İlana başvurabilmenin ilk şartı: sunucu doğrulanmamış kullanıcının
/// başvurusunu `APPLICANT_IDENTITY_NOT_VERIFIED` ile reddediyor.
///
/// Ekran açılırken önce **hangi yolun** açılacağına karar veriyor
/// ([IdentityVerificationPagemodel.enter]):
///
/// - Bekleyen ya da onaylanmış bir inceleme varsa, telefon iOS'sa (çip
///   okuma Apple üyeliği istiyor ve bu sürümde yok) ya da NFC donanımı
///   yoksa **doğrudan fotoğraf akışı** (`/identity-documents`) açılıyor; o
///   kapanınca bu ekran da aynı sonuçla kapanıyor. Reddedilmiş inceleme çip
///   yolunu kapatmıyor; fotoğraf kartı gerekçeyi yazıyor.
/// - Aksi hâlde bu ekran çiziliyor: tepede fotoğraflı yol (ürünün ana
///   yolu), altında çip kartı ve beyan formu.
///
/// Çip yolunun **iki hâli** var ve ikincisi zorunlu değil:
///
/// 1. **Beyan** — beş alan doldurulup gönderiliyor. Sunucudaki
///    `IDENTITY_PASSIVE_AUTH_ENABLED` bugün `false` olduğu için bu yol tek
///    başına çalışıyor.
/// 2. **Çip** — kimlik kartının çipi okunup kanıt (`sod`, `dg1`, varsa
///    `dg11`/`dg15` ve imza) aynı isteğe ekleniyor.
///
/// Çip okunduğunda beş alan da **kanıttan türüyor ve salt okunur**; elle
/// düzenlemeye dönüşün tek yolu okumayı bırakmak — kullanıcı "Okumayı
/// Kaldır" der ya da sunucu kanıtı `IDENTITY_CHALLENGE_INVALID` ile reddeder
/// (is-koala/koala#136). Çip yolu bir hata verdiğinde — cihazda
/// (`ChipReadFailure`) ya da sunucuda (`IdentityError`) — kullanıcı
/// "Fotoğrafla Devam Et" ile fotoğraf akışına geçebiliyor; çip bir kapı
/// değil.
///
/// Doğrulama başarılı olduğunda ad ve soyad **kilitleniyor** — hesap
/// bilgileri ekranı da o noktadan sonra ikisini düzenletmiyor.
class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({
    super.key,
    required this.user,
    this.userService,
    this.chipReader,
  });

  final CurrentUser user;

  /// Testlerde gerçek API yerine sahte sunucuya bağlı servis kullanılabilir.
  final UserService? userService;

  /// NFC donanımının varlığını soran sınır; testlerde yerli eklenti olmadan
  /// "var" ya da "yok" denebilsin diye dışarıdan veriliyor.
  final ChipReader? chipReader;

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends IdentityVerificationPagemodel {
  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      // Karar verilene ve fotoğraf akışı kapanana kadar boş bir sayfa:
      // çip formunu bir an gösterip kaldırmak kullanıcıya iki ekran
      // arasında sekiyormuş gibi görünürdü.
      return Scaffold(
        appBar: MyAppbar(title: 'Kimlik Doğrulama'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
            _photoPath(),
            const SizedBox(height: AppSizes.spaceLarge),
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

  /// Fotoğraflı yol: ürünün ana yolu olarak tepede. Son inceleme
  /// reddedildiyse kart gerekçeyi yazıyor; çip yolu az önce başarısız
  /// olduysa aynı kart uyarı olarak çiziliyor — kullanıcı tıkandığı yerde
  /// çıkışı görsün.
  Widget _photoPath() {
    final rejected = rejectedReview;
    if (rejected != null && !chipFailed) {
      final reason = rejected.rejectionReason;
      return IdentityPhotoPathCard(
        onContinue: openPhotos,
        title: 'Belgelerin reddedildi',
        message: reason == null
            ? 'Personel gönderdiğin fotoğrafları onaylamadı. Yeni fotoğraflarla '
                  'tekrar gönderebilir ya da kartını okutabilirsin.'
            : 'Personel gerekçesi: $reason. Yeni fotoğraflarla tekrar '
                  'gönderebilir ya da kartını okutabilirsin.',
        buttonLabel: 'Yeni Fotoğraflarla Gönder',
        isWarning: true,
      );
    }
    if (!chipFailed) return IdentityPhotoPathCard(onContinue: openPhotos);

    return IdentityPhotoPathCard(
      onContinue: openPhotos,
      title: 'Çip yolu bu sefer tamamlanamadı',
      message:
          'Kimliğini dört fotoğrafla incelemeye gönderebilirsin; personel '
          'onaylayınca doğrulanmış olur. Kartı yeniden okutmayı da '
          'deneyebilirsin.',
      buttonLabel: 'Fotoğrafla Devam Et',
      isWarning: true,
    );
  }

  /// Elle beyan: dört metin alanı ve doğum tarihi seçici.
  List<Widget> _manualFields() {
    return [
      IdentityDeclarationFields(
        firstName: firstName,
        lastName: lastName,
        tcIdentity: tcIdentity,
        tcDocument: tcDocument,
        birthDate: birthDate,
        onChanged: () => setState(() {}),
        onBirthDateChanged: (picked) => setState(() => birthDate = picked),
      ),
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
}
