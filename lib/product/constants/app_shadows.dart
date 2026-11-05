import 'package:flutter/painting.dart';
import 'package:koala/product/constants/app_colors.dart';

/// Sayfanın üstünde yüzen öğelerin ortak gölgesi: navbar, harita düğmeleri
/// ve harita üstündeki marka yazısı.
///
/// Gölge **kaydırılmamış**: öğenin tam altında ve her yanına eşit yayılıyor.
/// Aşağı kaydırılmış gölge (eski navbar'daki 10'luk ofset, FAB'ın yükseltisi)
/// öğeyi yerinden kaymış gibi gösteriyordu. Yayılım ve koyuluk bilerek düşük;
/// gölge öğeyi zeminden ayırmalı, kendisi görünmemeli.
class AppShadows {
  AppShadows._();

  /// Gölgenin yayılımı.
  static const double _blur = 6;

  /// Gölgenin koyuluğu ([AppColors.navShadow]'un saydamlığının yerine).
  static const double _alpha = 0.20;

  static final Color _color = AppColors.navShadow.withValues(alpha: _alpha);

  /// Kutu ve daire biçimli yüzen öğeler için (`BoxDecoration.boxShadow`).
  static final List<BoxShadow> floating = [
    BoxShadow(color: _color, blurRadius: _blur),
  ];

  /// Yüzen yazı için (`TextStyle.shadows`).
  static final List<Shadow> floatingText = [
    Shadow(color: _color, blurRadius: _blur),
  ];
}
