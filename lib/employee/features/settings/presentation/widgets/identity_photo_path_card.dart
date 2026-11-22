import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_button.dart';

/// Fotoğraflı yola açılan kart: tepede ana yol, çip hatasında çıkış. Metin
/// değişir, düğme aynı kalır ki kullanıcı tanısın.
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

  final bool isWarning;

  static const double _lineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    // Kutusuz bölüm; iç içe kutular ekranı karmaşıklaştırıyor.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppIcon(
              isWarning ? AppIcons.alert : AppIcons.camera,
              color: isWarning ? AppColors.warning : context.textPrimary,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(child: Text(title, style: context.textTheme.titleMedium)),
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
    );
  }
}
