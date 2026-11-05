import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android yalnız mevcut Latin OCR sürümünü Play Services ile değiştirir',
    () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      const bundledModule = 'com.google.mlkit:text-recognition:16.0.1';
      const unbundledModule =
          'com.google.android.gms:play-services-mlkit-text-recognition:19.0.1';

      final substitution = RegExp(
        '${RegExp.escape('substitute(module("$bundledModule"))')}\\s*'
        '${RegExp.escape('.using(module("$unbundledModule"))')}',
      );

      expect(substitution.allMatches(gradle), hasLength(1));
    },
  );

  test('Android production grafiğini check ve paketleme öncesi doğrular', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('verifyUnbundledMlKitModels'));
    expect(gradle, contains('productionReleaseRuntimeClasspath'));
    expect(gradle, contains('tasks.named("check")'));
    expect(gradle, contains('it.name.startsWith("assemble")'));
    expect(gradle, contains('it.name.startsWith("bundle")'));
  });

  test('Android barkod modelini de Play Services varyantından alır', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final properties = File('android/gradle.properties').readAsStringSync();

    expect(
      RegExp(
        r'^dev\.steenbakker\.mobile_scanner\.useUnbundled=true$',
        multiLine: true,
      ).allMatches(properties),
      hasLength(1),
    );
    expect(gradle, contains('play-services-mlkit-barcode-scanning'));
    expect(gradle, contains('it.name == "barcode-scanning"'));
  });

  test(
    'Android OCR ve barkod modellerini kurulum sırasında hazırlamayı ister',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final metadata = RegExp(
        r'<meta-data\s+'
        r'android:name="com\.google\.mlkit\.vision\.DEPENDENCIES"\s+'
        r'android:value="ocr,barcode"\s*/>',
      );
      final match = metadata.firstMatch(manifest);
      final applicationStart = manifest.indexOf('<application');
      final applicationEnd = manifest.indexOf('</application>');

      expect(metadata.allMatches(manifest), hasLength(1));
      expect(match!.start, greaterThan(applicationStart));
      expect(match.end, lessThan(applicationEnd));
    },
  );
}
