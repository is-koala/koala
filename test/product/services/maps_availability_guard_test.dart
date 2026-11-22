import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Harita çizen her dosya bayrağı sormalı (#172); analyzer bunu görmez, test
/// kaynak ağacını okuyor.
void main() {
  test('GoogleMap kuran her lib dosyası kurulumu bayrağa bağlar', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    // Bayrağın adı yetmez; harita kurulumu ona **koşullu** olmalı.
    final conditional = RegExp(
      r'if \(!\s*(?:this\.)?mapsAvailable\)|\bmapsAvailable\s*\?',
    );

    for (final file in files) {
      final source = file.readAsStringSync();
      if (!RegExp(r'\bGoogleMap\(').hasMatch(source)) continue;
      if (!conditional.hasMatch(source)) offenders.add(file.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dosyalar GoogleMap kuruyor ama kurulumu MapsAvailability '
          'bayrağına bağlamıyor (`if (!mapsAvailable)` ya da '
          '`mapsAvailable ? … : …`); anahtarsız iOS derlemesinde çökerler.',
    );
  });
}
