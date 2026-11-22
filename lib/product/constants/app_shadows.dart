import 'package:flutter/painting.dart';
import 'package:koala/product/constants/app_colors.dart';

/// Yüzen öğelerin ortak gölgesi (navbar, harita düğmeleri). Kaydırılmamış:
/// aşağı kayan gölge öğeyi yerinden kaymış gösteriyor. Gölge öğeyi ayırmalı,
/// kendisi görünmemeli.
class AppShadows {
  AppShadows._();

  static const double _blur = 6;

  static const double _alpha = 0.20;

  static final Color _color = AppColors.navShadow.withValues(alpha: _alpha);

  static final List<BoxShadow> floating = [
    BoxShadow(color: _color, blurRadius: _blur),
  ];

  static final List<Shadow> floatingText = [
    Shadow(color: _color, blurRadius: _blur),
  ];

  /// Kısa süre duran yüzey (toast): sayfayla aynı zemindeki kartı ayıran şey
  /// bu, o yüzden daha geniş ve aşağı kaymış.
  static final List<BoxShadow> overlay = [
    BoxShadow(
      color: AppColors.navShadow.withValues(alpha: _overlayAlpha),
      blurRadius: _overlayBlur,
      offset: const Offset(0, _overlayOffsetY),
    ),
  ];

  static const double _overlayAlpha = 0.18;
  static const double _overlayBlur = 24;
  static const double _overlayOffsetY = 8;
}
