import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/auth/presentation/widgets/auth_divider.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/models/identity_declaration.dart';
import 'package:koala/employee/features/settings/models/identity_error.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_chip_page.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_chip_card.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_declaration_fields.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_photo_path_card.dart';
import 'package:koala/employee/features/settings/services/chip_reader.dart';
import 'package:koala/product/widgets/locked_field.dart';
import 'package:koala/product/widgets/settings_hint.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

part 'identity_verification_pagemodel.dart';

/// Kimlik doğrulamanın giriş ekranı; başvurunun ilk şartı.
///
/// Açılışta yol seçilir ([IdentityVerificationPagemodel.enter]): bekleyen ya da
/// onaylı inceleme varsa, iOS'ta (çip okuma bu sürümde yok) ya da NFC yoksa
/// **doğrudan fotoğraf akışı**. Aksi hâlde tepede fotoğraf yolu, altında çip
/// kartı ve beyan formu.
///
/// Çip okunduğunda beş alan kanıttan türer ve salt okunur; elle düzenlemeye
/// dönüş yalnız "Okumayı Kaldır" ya da `IDENTITY_CHALLENGE_INVALID` ile (#136).
/// Doğrulamadan sonra ad ve soyad kilitlenir.
class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({
    super.key,
    required this.user,
    this.userService,
    this.chipReader,
  });

  final CurrentUser user;

  final UserService? userService;

  final ChipReader? chipReader;

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends IdentityVerificationPagemodel {
  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      // Karar verilene kadar boş sayfa; formu bir an gösterip kaldırmak sekme
      // gibi görünür.
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
      body: FormPageBody(
        padding: AppPadding.primaryAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İki yol arasında "YA DA": üstte fotoğraf, altta bilgiler ve
            // "Doğrula".
            _intro(),
            const SizedBox(height: AppSizes.spaceLarge),
            _photoPath(),
            const SizedBox(height: AppSizes.spaceLarge),
            const AuthDivider(),
            const SizedBox(height: AppSizes.spaceLarge),
            Text('Bilgilerinle doğrula', style: context.textTheme.titleMedium),
            const SizedBox(height: AppSizes.space),
            IdentityChipCard(
              result: chip,
              onRead: readChip,
              onRemove: removeChip,
            ),
            const SizedBox(height: AppSizes.spaceLarge),
            // Formu beyanın tipi seçiyor; ayrı "kilitli mi" bayrağı
            // ayrışabilirdi.
            ...switch (declaration) {
              ManualDeclaration() => _manualFields(),
              ChipDeclaration(:final chip) => _lockedFields(chip),
            },
            const SizedBox(height: AppSizes.spaceLarge),
          ],
        ),
      ),
    );
  }

  /// Ana yol tepede. Ret gerekçesi ya da az önceki çip hatası kartta yazılır;
  /// kullanıcı tıkandığı yerde çıkışı görsün.
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

  /// Değerler doğrudan kanıttan; denetleyicilere bakılmıyor.
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
    return Text(
      'İşe başvurabilmen ve ücretini alabilmen için kimliğini bir kez '
      'doğrulaman gerekiyor. Bilgiler kimlik kartındakiyle birebir aynı '
      'olmalı; doğrulandıktan sonra adın, soyadın ve doğum tarihin '
      'değiştirilemez.',
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.textSecondary,
        height: _lineHeight,
      ),
    );
  }

  static const double _lineHeight = 1.4;
}
