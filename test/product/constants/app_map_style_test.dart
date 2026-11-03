import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_map_style.dart';

import '../../support/pump.dart';

List<Map<String, dynamic>> _rules(String style) =>
    (jsonDecode(style) as List).cast<Map<String, dynamic>>();

/// Verilen kuralın stilerlerini tek bir haritada toplar.
Map<String, dynamic>? _stylers(String style, String feature, String element) {
  for (final rule in _rules(style)) {
    if (rule['featureType'] == feature && rule['elementType'] == element) {
      return {
        for (final styler in (rule['stylers'] as List).cast<Map>())
          ...styler.cast<String, dynamic>(),
      };
    }
  }
  return null;
}

void main() {
  final themes = {'açık': AppMapStyle.light, 'koyu': AppMapStyle.dark};

  group('AppMapStyle', () {
    for (final MapEntry(key: name, value: style) in themes.entries) {
      group('$name tema', () {
        test('geçerli bir Maps stil JSON listesidir', () {
          final rules = _rules(style);
          expect(rules, isNotEmpty);
          for (final rule in rules) {
            expect(rule.keys, containsAll(['featureType', 'elementType']));
            expect(rule['stylers'], isA<List>());
          }
        });

        test('renkler #RRGGBB biçimindedir', () {
          final colors = _rules(style)
              .expand((rule) => (rule['stylers'] as List).cast<Map>())
              .where((styler) => styler.containsKey('color'))
              .map((styler) => styler['color']);
          expect(colors, isNotEmpty);
          for (final color in colors) {
            expect(color, matches(RegExp(r'^#[0-9A-F]{6}$')));
          }
        });

        test('ilan pinleriyle yarışan katmanlar kapalıdır', () {
          for (final (feature, element) in [
            ('poi.business', 'all'),
            ('poi', 'labels.icon'),
            ('transit.station.bus', 'all'),
            ('road', 'labels.icon'),
          ]) {
            expect(
              _stylers(style, feature, element)?['visibility'],
              'off',
              reason: '$feature / $element',
            );
          }
        });

        test('yön bulmaya yarayan katmanlar kapatılmaz', () {
          for (final feature in [
            'road',
            'poi.park',
            'transit.station',
            'transit.station.rail',
            'administrative.locality',
            'administrative.neighborhood',
          ]) {
            for (final rule in _rules(style)) {
              if (rule['featureType'] != feature) continue;
              final hidden = (rule['stylers'] as List).cast<Map>().any(
                (styler) => styler['visibility'] == 'off',
              );
              final element = rule['elementType'] as String;
              final iconOnly = element == 'labels.icon';
              expect(
                hidden && !iconOnly,
                isFalse,
                reason: '$feature / $element gizlenmemeli',
              );
            }
          }
        });
      });
    }

    test('açık ve koyu stiller farklıdır', () {
      expect(AppMapStyle.light, isNot(AppMapStyle.dark));
    });

    for (final brightness in Brightness.values) {
      testWidgets('of(context) ${brightness.name} temada doğru stili verir', (
        tester,
      ) async {
        late String resolved;
        await pumpInApp(
          tester,
          Builder(
            builder: (context) {
              resolved = AppMapStyle.of(context);
              return const SizedBox.shrink();
            },
          ),
          brightness: brightness,
        );
        expect(
          resolved,
          brightness == Brightness.dark ? AppMapStyle.dark : AppMapStyle.light,
        );
      });
    }
  });
}
