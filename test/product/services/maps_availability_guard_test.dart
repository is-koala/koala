import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Harita çizen her dosya bayrağı sormalı (is-koala/koala#172).
///
/// Kural AGENTS.md'de yazıyor ama analyzer onu görmez: yeni bir ekran
/// `GoogleMap` kurup `MapsAvailability`'yi atlarsa iOS'ta anahtarsız
/// derleme yine çöker ve hiçbir test kırmızı olmaz. Bu test kaynak ağacını
/// okuyup o ihtimali kapatıyor.
void main() {
  test('GoogleMap kuran her lib dosyası MapsAvailability bayrağını okur', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final source = file.readAsStringSync();
      if (!RegExp(r'\bGoogleMap\(').hasMatch(source)) continue;
      final asksFlag =
          source.contains('MapsAvailability.of(') ||
          source.contains('mapsAvailable');
      if (!asksFlag) offenders.add(file.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dosyalar GoogleMap kuruyor ama MapsAvailability bayrağına '
          'bakmıyor; anahtarsız iOS derlemesinde çökerler.',
    );
  });
}
