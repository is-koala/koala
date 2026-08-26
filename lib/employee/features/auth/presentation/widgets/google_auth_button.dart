import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Google ile giriş / kayıt butonu.
///
/// Görünümü `MyButton`'ın `isReversed` hâliyle aynı; ayrı bir widget olmasının
/// sebebi solda logoyu taşıması. Logo solda sabit dururken metin butonun
/// ortasında kalıyor.
class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({super.key, required this.title, this.onPressed});

  final String title;
  final VoidCallback? onPressed;

  /// Kenarlık kalınlığı; `MyButton`'ın ters hâliyle aynı olmalı, yoksa iki
  /// buton alt alta farklı ağırlıkta görünüyor.
  static const double _borderWidth = 3.0;

  /// Metnin sağındaki pay. Soldaki logo metni ortadan kaydırdığı için,
  /// metin bloğu bu kadar sola çekilerek butonun ortasına oturtuluyor.
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
            backgroundColor: context.onAccentColor,
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
