import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_button.dart';

/// Fotoğraflı doğrulama yoluna açılan kart.
///
/// Kimlik ekranının tepesinde ana yol olarak, çip yolu bir hata verdiğinde
/// de çıkış yolu olarak duruyor. İkisi aynı kart: metin değişiyor, düğme
/// değişmiyor — kullanıcı hata ekranında gördüğü düğmeyi tepede de tanısın.
class IdentityPhotoPathCard extends StatelessWidget {
  const IdentityPhotoPathCard({
    super.key,
    required this.onContinue,
    this.title = 'Fotoğrafla doğrula',
    this.message =
        'Kimliğinin ön ve arka yüzünü, yüzünü ve kimlikle birlikte yüzünü '
        'çek; personel inceleyip onaylasın. Çip okutmak gerekmiyor.',
    this.buttonLabel = 'Fotoğrafla Doğrula',
    this.isWarning = false,
  });

  final VoidCallback onContinue;

  final String title;

  final String message;

  final String buttonLabel;

  /// Çip yolu az önce başarısız olduysa `true`: kart uyarı rengiyle
  /// çerçeveleniyor ki gözden kaçmasın.
  final bool isWarning;

  /// Uyarı zemininin saydamlığı; formun geri kalanı turuncuya boyanmasın.
  static const double _warningSurfaceAlpha = 0.1;

  /// Açıklama metninin satır aralığı; kimlik ekranındakiyle aynı.
  static const double _lineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: isWarning
            ? AppColors.warning.withValues(alpha: _warningSurfaceAlpha)
            : context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(
          color: isWarning ? AppColors.warning : context.accentColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                isWarning ? AppIcons.alert : AppIcons.camera,
                color: isWarning ? AppColors.warning : context.accentColor,
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              Expanded(child: Text(title, style: context.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            message,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              height: _lineHeight,
            ),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyButton(onPressed: onContinue, title: buttonLabel),
        ],
      ),
    );
  }
}
