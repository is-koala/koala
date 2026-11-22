import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Google ile giriş butonu; logo solda sabit, metin ortada.
class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({super.key, required this.title, this.onPressed});

  final String title;
  final VoidCallback? onPressed;

  /// `MyButton`'ın ters hâliyle aynı olmalı; yoksa alt alta farklı ağırlıkta.
  static const double _borderWidth = 3.0;

  /// Soldaki logo metni kaydırdığı için metin bu kadar sola çekilir.
  static const double _textBalance = 34.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.horizontalSmall,
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.primaryCircular,
              side: BorderSide(color: context.accentColor, width: _borderWidth),
            ),
            backgroundColor: context.backgroundColor,
            padding: AppPadding.button,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: AppSizes.spaceSmall),
                child: Image.asset(
                  AppAssets.googleLogo,
                  width: AppSizes.icon,
                  height: AppSizes.icon,
                ),
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: context.accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: _textBalance),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
