import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';

/// Harita ekranlarının paylaştığı Koala harita stili (açık ve koyu).
///
/// Stil uygulamanın içinde, `GoogleMap.style` ile verilir; Google Cloud'daki
/// bulut stili (Map ID) bilerek kullanılmıyor. Map ID'li her harita açılışı
/// Dynamic Maps olarak ücretlendiriliyor, JSON stili ise mobil SDK'nın
/// ücretsiz kullanımında kalıyor. İkisi aynı uygulamada karıştırılamaz.
///
/// Amaç sade bir zemin: harita bilgisini taşıyan şey ilan pinleri. Bu yüzden
/// pinlerle yarışan katmanlar kapalı (dükkan/restoran ikonları, otobüs
/// durakları, otoyol tabelaları), konum bulmaya ve işe ulaşmaya yarayanlar
/// açık ama sönük (sokak ve semt adları, parklar, raylı sistem durakları).
class AppMapStyle {
  AppMapStyle._();

  /// Uygulamanın etkin temasına göre stil. `GoogleMap.style` değişince
  /// eklenti haritayı yeniden kurmadan günceller; tema değişimi anında yansır.
  static String of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Açık tema: hafif yeşile çalan kırık beyaz zemin, Koala yeşili parklar.
  static final String light = _encode(
    const _Palette(
      land: Color(0xFFF6F7F4),
      builtUp: Color(0xFFEFF1EC),
      park: AppColors.primarySoft,
      water: Color(0xFFD3E6E4),
      road: Color(0xFFFFFFFF),
      arterial: Color(0xFFFFFFFF),
      highway: Color(0xFFE6EEE3),
      roadStroke: Color(0xFFE2E6DF),
      transitLine: Color(0xFFDDE3DA),
      label: Color(0xFF878D84),
      labelStrong: Color(0xFF5E6A5B),
      parkLabel: AppColors.primaryDeep,
      labelHalo: Color(0xFFFFFFFF),
    ),
  );

  /// Koyu tema: uygulamanın koyu zeminine (`darkBackground`) yakın, yeşil
  /// tonlu; yollar zeminden yalnızca bir kademe açık, parlamaz.
  static final String dark = _encode(
    const _Palette(
      land: Color(0xFF181B18),
      builtUp: Color(0xFF1D201D),
      park: Color(0xFF1E2A1E),
      water: Color(0xFF132326),
      road: Color(0xFF2A2E2A),
      arterial: Color(0xFF2F342F),
      highway: Color(0xFF353B35),
      roadStroke: Color(0xFF181B18),
      transitLine: Color(0xFF2B302B),
      label: Color(0xFF8A9287),
      labelStrong: Color(0xFFAAB4A7),
      parkLabel: AppColors.primaryColor,
      labelHalo: AppColors.darkBackground,
    ),
  );

  static String _encode(_Palette p) => jsonEncode([
    // Zemin ve genel etiketler.
    _rule('all', 'geometry', {'color': p.land}),
    _rule('all', 'labels.text.fill', {'color': p.label}),
    _rule('all', 'labels.text.stroke', {'color': p.labelHalo}),
    _rule('landscape.man_made', 'geometry', {'color': p.builtUp}),
    _rule('water', 'geometry', {'color': p.water}),
    _rule('water', 'labels.text.fill', {'color': p.label}),

    // İdari sınırlar: semt ve ilçe adı yön bulmaya yarar, çizgiler ve
    // parsel bilgisi yalnızca kalabalık.
    _rule('administrative', 'geometry', {'visibility': 'off'}),
    _rule('administrative.land_parcel', 'all', {'visibility': 'off'}),
    _rule('administrative.locality', 'labels.text.fill', {
      'color': p.labelStrong,
    }),
    _rule('administrative.neighborhood', 'labels.text.fill', {
      'color': p.label,
    }),

    // Mekânlar: ilan pinleriyle yarışan ikonlar kapalı. İşletmeler
    // (dükkan, restoran, otel) tamamen; diğerleri yalnızca adıyla kalır.
    _rule('poi', 'labels.icon', {'visibility': 'off'}),
    _rule('poi', 'labels.text.fill', {'color': p.label}),
    _rule('poi.business', 'all', {'visibility': 'off'}),
    _rule('poi.park', 'geometry', {'color': p.park}),
    _rule('poi.park', 'labels.text.fill', {'color': p.parkLabel}),

    // Yollar: sokak adları adres için gerekli; otoyol tabelaları değil.
    _rule('road', 'geometry.fill', {'color': p.road}),
    _rule('road', 'geometry.stroke', {'color': p.roadStroke}),
    _rule('road', 'labels.icon', {'visibility': 'off'}),
    _rule('road.arterial', 'geometry.fill', {'color': p.arterial}),
    _rule('road.highway', 'geometry.fill', {'color': p.highway}),
    _rule('road.highway', 'geometry.stroke', {'color': p.roadStroke}),

    // Toplu taşıma: metro/tramvay durakları işe ulaşımı anlatır, kalır;
    // otobüs durakları sokak seviyesinde haritayı ikonla doldurur.
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

  /// Maps stil JSON'u `#RRGGBB` bekler; saydamlık taşımaz.
  static String _hex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

/// Bir temanın harita renkleri; iki tema aynı kuralları paylaşır, yalnızca
/// renkler değişir.
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
