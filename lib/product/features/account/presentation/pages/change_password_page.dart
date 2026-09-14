import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/product/widgets/settings_hint.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/constants/password_rule.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/password_field.dart';

part 'change_password_pagemodel.dart';

/// Ayarlardan açılan parola değiştirme ekranı.
///
/// İki uygulamanın da ayarlarından aynı ekran açılıyor: parola kullanıcıya
/// ait, işveren ya da çalışan olmasına bağlı değil.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.userService, this.onCompleted});

  /// Testlerde sahte sunucuya bağlı örnek geçilebilsin diye.
  final UserService? userService;

  /// Parola değiştikten sonra çalışan geri çağırım. Verilmezse ekran
  /// kendini kapatıyor.
  final VoidCallback? onCompleted;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ChangePasswordPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Şifreyi Değiştir'),
      bottomNavigationBar: ButtonNavbar(
        onPressed: isSaving ? null : submit,
        title: 'Kaydet',
        isLoading: isSaving,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sessionWarning(),
              const SizedBox(height: AppSizes.spaceLarge),
              PasswordField(
                labelText: 'Mevcut Şifre',
                controller: currentPassword,
                isHidden: isCurrentHidden,
                onToggle: () =>
                    setState(() => isCurrentHidden = !isCurrentHidden),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              PasswordField(
                labelText: 'Yeni Şifre',
                controller: newPassword,
                isHidden: isNewHidden,
                onToggle: () => setState(() => isNewHidden = !isNewHidden),
              ),
              SettingsHint(PasswordRule.requirement),
              const SizedBox(height: AppSizes.spaceMedium),
              PasswordField(
                labelText: 'Yeni Şifre Tekrar',
                controller: confirmation,
                isHidden: isConfirmationHidden,
                onToggle: () => setState(
                  () => isConfirmationHidden = !isConfirmationHidden,
                ),
              ),
              const SizedBox(height: AppSizes.sectionSpace),
            ],
          ),
        ),
      ),
    );
  }

  /// Kaydetmeden **önce** görünen uyarı: sunucu parola değişince bu cihaz
  /// dışındaki bütün oturumları kapatıyor, kullanıcı bunu sonradan değil
  /// önceden bilmeli.
  Widget _sessionWarning() {
    return Container(
      width: double.infinity,
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.shield,
            color: AppColors.warning,
            size: AppSizes.iconMedium,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              'Şifrenizi değiştirdiğinizde bu cihaz dışındaki bütün '
              'oturumlarınız kapanacak. Bu cihazda açık kalırsınız.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
