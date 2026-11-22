import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:reicon_flutter/reicon_flutter.dart';

/// Reicon ikonlarını `Icon` gibi kullandırır; ikonlar `IconData` değil SVG
/// path, çözme ve renklendirme burada.
///
/// ```dart
/// AppIcon(AppIcons.home, filled: true, color: context.accentColor)
/// ```
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    this.size = AppSizes.icon,
    this.color,
    this.filled = false,
  });

  final AppIconData name;

  final double size;

  /// Verilmezse `IconTheme`, o da yoksa `context.textPrimary`.
  final Color? color;

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final pathData = (filled ? Reicon.filled : Reicon.outline)[name];

    if (pathData == null) {
      assert(false, 'AppIcon: "$name" adında ikon bulunamadı.');
      return SizedBox.square(dimension: size);
    }

    final resolvedColor =
        color ?? IconTheme.of(context).color ?? context.textPrimary;

    return SizedBox.square(
      dimension: size,
      child: SvgPicture.string(
        reiconSvg(pathData, size: size.round()),
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
      ),
    );
  }
}
