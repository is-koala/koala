import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';

/// Koala harita stili (açık ve koyu).
///
/// `GoogleMap.style` ile veriliyor, bulut Map ID değil: Map ID'li her açılış
/// ücretli, JSON stili ücretsiz. Pinlerle yarışan katmanlar (dükkan ikonları,
/// otobüs durakları) kapalı; yön bulmaya yarayanlar açık ama sönük.
class AppMapStyle {
  AppMapStyle._();

  static String of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static const Color _darkLand = Color(0xFF161916);

  /// Pin kenarı: açık zeminde beyaz, koyu zeminde zeminin rengi. Koyu haritada
  /// beyaz kenar gözü pinden çok çerçeveye çekiyor.
  static Color pinRim(Brightness brightness) =>
      brightness == Brightness.dark ? _darkLand : AppColors.onAccent;

  static final String light = _encode(
    const _Palette(
      land: Color(0xFFF2F4EF),
      builtUp: Color(0xFFE7EAE3),
      park: Color(0xFFC8E3C6),
      water: Color(0xFFB4D8DC),
      road: Color(0xFFFFFFFF),
      arterial: Color(0xFFFFFFFF),
      highway: Color(0xFFE0EDD6),
      roadStroke: Color(0xFFD2D9CE),
      transitLine: Color(0xFFC4CEC0),
      label: Color(0xFF5F675C),
      labelStrong: Color(0xFF3B4738),
      parkLabel: AppColors.primaryDeep,
      labelHalo: Color(0xFFFFFFFF),
    ),
  );

  static final String dark = _encode(
    const _Palette(
      land: _darkLand,
      builtUp: Color(0xFF1D211D),
      park: Color(0xFF223622),
      water: Color(0xFF0E2B31),
      road: Color(0xFF373D37),
      arterial: Color(0xFF3F463F),
      highway: Color(0xFF4B544B),
      roadStroke: Color(0xFF121412),
      transitLine: Color(0xFF3B423B),
      label: Color(0xFFA4AD9F),
      labelStrong: Color(0xFFCBD4C7),
      parkLabel: AppColors.primaryColor,
      labelHalo: AppColors.darkBackground,
    ),
  );

  static String _encode(_Palette p) => jsonEncode([
    _rule('all', 'geometry', {'color': p.land}),
    _rule('all', 'labels.text.fill', {'color': p.label}),
    _rule('all', 'labels.text.stroke', {'color': p.labelHalo}),
    _rule('landscape.man_made', 'geometry', {'color': p.builtUp}),
    _rule('water', 'geometry', {'color': p.water}),
    _rule('water', 'labels.text.fill', {'color': p.label}),

    // İdari sınırlar: semt adı yön bulmaya yarar, çizgiler yalnız kalabalık.
    _rule('administrative', 'geometry', {'visibility': 'off'}),
    _rule('administrative.land_parcel', 'all', {'visibility': 'off'}),
    _rule('administrative.locality', 'labels.text.fill', {
      'color': p.labelStrong,
    }),
    _rule('administrative.neighborhood', 'labels.text.fill', {
      'color': p.label,
    }),

    // Mekân ikonları ilan pinleriyle yarıştığı için kapalı.
    _rule('poi', 'labels.icon', {'visibility': 'off'}),
    _rule('poi', 'labels.text.fill', {'color': p.label}),
    _rule('poi.business', 'all', {'visibility': 'off'}),
    _rule('poi.park', 'geometry', {'color': p.park}),
    _rule('poi.park', 'labels.text.fill', {'color': p.parkLabel}),

    // Sokak adları adres için gerekli; otoyol tabelaları değil.
    _rule('road', 'geometry.fill', {'color': p.road}),
    _rule('road', 'geometry.stroke', {'color': p.roadStroke}),
    _rule('road', 'labels.icon', {'visibility': 'off'}),
    _rule('road.arterial', 'geometry.fill', {'color': p.arterial}),
    _rule('road.highway', 'geometry.fill', {'color': p.highway}),
    _rule('road.highway', 'geometry.stroke', {'color': p.roadStroke}),

    // Raylı sistem durakları kalır; otobüs durakları haritayı ikonla doldurur.
    _rule('transit.line', 'geometry', {'color': p.transitLine}),
    _rule('transit.station.bus', 'all', {'visibility': 'off'}),
    _rule('transit.station', 'labels.text.fill', {'color': p.label}),
  ]);

  static Map<String, Object> _rule(
    String featureType,
    String elementType,
    Map<String, Object> styler,
  ) => {
    'featureType': featureType,
    'elementType': elementType,
    'stylers': [
      for (final entry in styler.entries)
        {
          entry.key: switch (entry.value) {
            final Color color => _hex(color),
            final Object other => other,
          },
        },
    ],
  };

  static String _hex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class _Palette {
  const _Palette({
    required this.land,
    required this.builtUp,
    required this.park,
    required this.water,
    required this.road,
    required this.arterial,
    required this.highway,
    required this.roadStroke,
    required this.transitLine,
    required this.label,
    required this.labelStrong,
    required this.parkLabel,
    required this.labelHalo,
  });

  final Color land;
  final Color builtUp;
  final Color park;
  final Color water;
  final Color road;
  final Color arterial;
  final Color highway;
  final Color roadStroke;
  final Color transitLine;
  final Color label;
  final Color labelStrong;
  final Color parkLabel;
  final Color labelHalo;
}
