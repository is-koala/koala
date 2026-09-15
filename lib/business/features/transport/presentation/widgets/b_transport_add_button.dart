import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// "Ulaşım planı ekle" düğmesi (is-koala/koala#197).
///
/// İlan formu (taslak yokken) ve ilan detayı (sunucuda plan yokken) aynı
/// düğmeyi çiziyor; iki yerde ayrı ayrı kurmak metnin ve ikonun zamanla
/// birbirinden ayrılması demekti.
class BTransportAddButton extends StatelessWidget {
  const BTransportAddButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: AppIcon(
          AppIcons.bus,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        label: const Text('Ulaşım planı ekle'),
        style: context.accentOutlinedButtonStyle,
      ),
    );
  }
}
