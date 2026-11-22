import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
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

  /// Açıklama metninin satır aralığı; kimlik ekranındakiyle aynı.
  static const double _lineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    // Kutusuz bir bölüm: sayfanın ana yolu, başlığı ve düğmesiyle kendini
    // anlatıyor. Eskiden yeşil çerçeveli bir kartın içindeydi; altındaki
    // çip kartı ve form da kutuluydu, iç içe kutular ekranı karmaşık
    // gösteriyordu. Uyarı hâlinde yalnız ikon uyarı renginde.
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
