import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class MyButton extends StatelessWidget {
  const MyButton({
    super.key,
    required this.onPressed,
    required this.title,
    this.isReversed = false,
    this.isLoading = false,
    this.semanticHint,
  });

  final VoidCallback? onPressed;
  final String title;
  final bool? isReversed;
  final bool isLoading;

  /// Ekran okuyucunun düğmeye odaklanınca başlığın ardından okuduğu ipucu;
  /// düğme kapalıyken nedenini söylemek için. Düğmenin **kendi** semantik
  /// düğümüne yazılır: `ElevatedButton` çocuklarını kendi düğümünde
  /// birleştirdiği için ipucu içeride durmalı — düğmeyi dışarıdan
  /// `Semantics(hint:)` ile sarmak ayrı bir üst düğüm üretiyor ve odak
  /// düğmedeyken okunmuyor (is-koala/koala#174 incelemesi).
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.horizontalSmall,
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.primaryCircular,
            ),
            backgroundColor: isReversed!
                // Ters buton yeşilin üstünde değil, yeşilin yerine duruyor:
                // zemini sayfanınkiyle aynı, ayıran şey yeşil kenarlığı.
                ? context.backgroundColor
                : context.accentColor,
            disabledBackgroundColor: context.accentColor.withValues(alpha: 0.7),
            overlayColor: !isReversed! ? AppColors.primarySoft : null,
            padding: AppPadding.button,
            side: isReversed!
                ? BorderSide(color: context.accentColor, width: 3.0)
                : null,
          ),
          child: isLoading
              ? SizedBox(
                  width: AppSizes.icon,
                  height: AppSizes.icon,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: isReversed!
                        ? context.accentColor
                        : context.onAccentColor,
                  ),
                )
              : Semantics(
                  hint: semanticHint,
                  child: Text(
                    title,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: isReversed!
                          ? context.accentColor
                          : context.onAccentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
