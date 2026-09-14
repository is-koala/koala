import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Harita çizen her dosya bayrağı sormalı (is-koala/koala#172).
///
/// Kural AGENTS.md'de yazıyor ama analyzer onu görmez: yeni bir ekran
/// `GoogleMap` kurup `MapsAvailability`'yi atlarsa iOS'ta anahtarsız
/// derleme yine çöker ve hiçbir test kırmızı olmaz. Bu test kaynak ağacını
/// okuyup o ihtimali kapatıyor.
void main() {
  test('GoogleMap kuran her lib dosyası kurulumu bayrağa bağlar', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    // Bayrağın adının geçmesi yetmez; harita kurulumu ona **koşullu** olmalı:
    // `if (!mapsAvailable)` erken dönüşü ya da `mapsAvailable ? harita :
    // yer tutucu` seçimi. Bayrağı okuyup yine de haritayı koşulsuz kuran bir
    // dosya bu testten geçmez.
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
