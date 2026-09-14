import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/locked_field.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/widgets/settings_hint.dart';
import 'package:provider/provider.dart';

part 'account_info_pagemodel.dart';

/// Hesap bilgileri: fotoğraf, ad-soyad, telefon, e-posta, adres ve kimlik.
///
/// Hesap kullanıcıya ait, tarafına değil: çalışan da işveren de aynı ekranı
/// açıyor. Çalışana özgü profil alanları (meslek, IBAN, hakkımda,
/// yetkinlikler, ilgi alanları) yalnız `isEmployer == false` iken çiziliyor;
/// işverenin bunlara karşılık gelen bilgisi şirket ekranında.
///
/// Kimliği doğrulanmış kullanıcının ad ve soyadı çipten geliyor ve sunucu
/// değişikliği reddediyor (is-koala/koala#151); iki alan o zaman kapalı
/// metin kutusu değil [LockedField] olarak çiziliyor — düzenlenebilir gibi
/// görünüp reddedilen bir alan yerine, kimlik ekranındakiyle aynı "karttan
/// okunan değer" görünümü.
class AccountInfoPage extends StatefulWidget {
  final CurrentUser user;

  const AccountInfoPage({super.key, required this.user});

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends AccountInfoPagemodel {
  /// Profil fotoğrafının kenar uzunluğu.
  static const double _avatarSize = 100;

  /// "Hakkımda" alanının yüksekliği: yaklaşık dört satır.
  static const double _aboutHeight = 120;

  /// Yetkinlik ve ilgi alanı kutularının yüksekliği; tanıtım yazısından
  /// kısa metinler bekleniyor.
  static const double _multilineHeight = 90;

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<UserProvider>().isLoading;

    return Scaffold(
      appBar: MyAppbar(title: "Hesabı Düzenle"),
      bottomNavigationBar: ButtonNavbar(
        onPressed: isSaving ? null : save,
        title: "Kaydet",
        isLoading: isSaving,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _avatar()),
              const SizedBox(height: AppSizes.sectionSpace),
              ..._nameFields(),
              if (showsWorkerFields) ...[
                const SizedBox(height: AppSizes.spaceMedium),
                MyTextfield(
                  labelText: "Meslek",
                  controller: occupationController,
                ),
              ],
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Telefon",
                controller: phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "E-posta",
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              SettingsHint(
                "Telefonunuzu ya da e-postanızı değiştirirseniz yeni değere "
                "bir kod gönderiyoruz; kodu girene kadar eskisi geçerli "
                "kalıyor.",
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              // Adres kendi ekranında düzenleniyor: uç toptan yazıyor ve
              // harita üzerinde onaylanmış koordinat istiyor.
              _addressRow(),
              const SizedBox(height: AppSizes.spaceMedium),
              _identityRow(),
              if (showsWorkerFields) ..._workerFields(),
              const SizedBox(height: AppSizes.sectionSpace),
            ],
          ),
        ),
      ),
    );
  }

  /// Ad ve soyad: düzenlenebilirken metin kutusu, kimlik doğrulandıktan sonra
  /// kilitli satır.
  List<Widget> _nameFields() {
    if (canEditName) {
      return [
        MyTextfield(labelText: "Ad", controller: firstNameController),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(labelText: "Soyad", controller: lastNameController),
      ];
    }

    return [
      LockedField(label: 'Ad', value: widget.user.firstName),
      const SizedBox(height: AppSizes.spaceMedium),
      LockedField(label: 'Soyad', value: widget.user.lastName),
      SettingsHint(
        "Kimliğiniz doğrulandığı için ad ve soyad değiştirilemiyor.",
      ),
    ];
  }

  /// Çalışan profilinin alanları; işverende çizilmiyor.
  List<Widget> _workerFields() {
    return [
      const SizedBox(height: AppSizes.spaceMedium),
      MyTextfield(
        labelText: "IBAN",
        controller: ibanController,
        keyboardType: TextInputType.text,
      ),
      SettingsHint(
        widget.user.maskedIban == null
            ? "İşe başvurabilmeniz için ücretinizi alacağınız IBAN'ı "
                  "eklemeniz gerekiyor."
            : "Kayıtlı: ${widget.user.maskedIban}. Değiştirmek "
                  "istemiyorsanız boş bırakın.",
      ),
      const SizedBox(height: AppSizes.spaceMedium),
      _aboutTextField(),
      const SizedBox(height: AppSizes.spaceMedium),
      MyTextfield(
        labelText: "Yetkinlikler",
        controller: qualificationsController,
        expands: true,
        height: _multilineHeight,
      ),
      SettingsHint(
        "Yaptığınız işte öne çıkan taraflarınız. İşveren başvurunuzda "
        "bunları görüyor.",
      ),
      const SizedBox(height: AppSizes.spaceMedium),
      MyTextfield(
        labelText: "İlgi alanları",
        controller: interestsController,
        expands: true,
        height: _multilineHeight,
      ),
    ];
  }

  /// Adres satırı: özet ve düzenleme ekranına geçiş.
  Widget _addressRow() {
    final label = locationController.text;

    return _linkRow(
      key: const ValueKey('account-address-row'),
      label: "Adres",
      value: label.isEmpty ? "Eklenmedi" : label,
      isMissing: label.isEmpty,
      onTap: openAddress,
    );
  }

  /// Kimlik doğrulama satırı. Doğrulanmışsa yalnızca durumu gösteriyor;
  /// değilse incelemenin nerede olduğunu (bekliyor / reddedildi / hiç yok)
  /// ve dokununca kimlik ekranını açıyor — bekleyen incelemede de açılıyor,
  /// kullanıcı durumu oradan izliyor.
  Widget _identityRow() {
    final status = IdentityStatus.resolve(
      identityVerified: widget.user.identityVerified,
      review: context.watch<IdentityReviewProvider>().review,
    );

    return switch (status) {
      IdentityStatus.verified => _linkRow(
        label: "Kimlik",
        value: "Doğrulandı",
        isMissing: false,
        onTap: null,
      ),
      IdentityStatus.pending => _linkRow(
        label: "Kimlik",
        value: "İncelemede",
        isMissing: false,
        onTap: openIdentityVerification,
      ),
      IdentityStatus.rejected => _linkRow(
        label: "Kimlik",
        value: "Reddedildi",
        isMissing: true,
        onTap: openIdentityVerification,
      ),
      IdentityStatus.unverified => _linkRow(
        label: "Kimlik",
        value: "Doğrulanmadı",
        isMissing: true,
        onTap: openIdentityVerification,
      ),
    };
  }

  /// Başka bir ekrana götüren satır. Eksik bilgi vurgulu duruyor: adres ve
  /// kimlik çalışanda başvurunun, işverende ödemenin ön koşulu.
  Widget _linkRow({
    Key? key,
    required String label,
    required String value,
    required bool isMissing,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: AppRadius.innerCircular,
      child: Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          borderRadius: AppRadius.innerCircular,
          border: Border.all(
            color: isMissing ? AppColors.warning : context.dividerColor,
          ),
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
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isMissing ? AppColors.warning : context.textPrimary,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    final visibleUser = context.watch<UserProvider>().user ?? widget.user;
    return GestureDetector(
      key: const ValueKey('profile-picture-picker'),
      onTap: pickProfilePicture,
      child: Stack(
        children: [
          ProfileAvatar(
            imageUrl: visibleUser.profilePictureUrl,
            size: _avatarSize,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppSizes.spaceTiny),
              decoration: BoxDecoration(
                color: context.accentColor,
                shape: BoxShape.circle,
              ),
              child: AppIcon(
                AppIcons.camera,
                color: context.onAccentColor,
                size: AppSizes.iconSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutTextField() {
    return MyTextfield(
      labelText: "Hakkımda",
      controller: aboutController,
      height: _aboutHeight,
      expands: true,
      // Tek satırlık alanların tam yuvarlak köşesi bu yükseklikte metni
      // sıkıştırıyor.
      borderRadius: AppRadius.innerCircular,
    );
  }
}
