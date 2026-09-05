import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/validate_release_tag.dart';

void main() {
  test('release etiketi pubspec ve istemci sürümüyle aynı olmalıdır', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final appInfo = File(
      'lib/product/constants/app_info.dart',
    ).readAsStringSync();

    expect(
      releaseValidationError(
        tag: 'mobile-v1.0.0',
        pubspecContent: pubspec,
        appInfoContent: appInfo,
      ),
      isNull,
    );
    expect(
      releaseValidationError(
        tag: 'mobile-v9.9.9',
        pubspecContent: pubspec,
        appInfoContent: appInfo,
      ),
      isNotNull,
    );
  });

  test('Android release build debug anahtara düşmez', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('KOALA_ANDROID_KEYSTORE_PATH'));
    expect(gradle, contains('KOALA_ANDROID_KEYSTORE_PASSWORD'));
    expect(gradle, contains('KOALA_ANDROID_KEY_ALIAS'));
    expect(gradle, contains('KOALA_ANDROID_KEY_PASSWORD'));
    expect(
      gradle,
      isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
    );
  });

  test('mobil release workflow etiketten iki iç test kanalını yükler', () {
    final workflow = File(
      '.github/workflows/mobile-release.yml',
    ).readAsStringSync();

    for (final contract in [
      'mobile-v*',
      'git merge-base --is-ancestor',
      'tool/validate_release_tag.dart',
      'flutter build appbundle',
      'r0adkll/upload-google-play',
      'track: internal',
      'flutter build ipa',
      'xcrun altool',
      '--type ios',
      '--apiKey',
      'APP_STORE_CONNECT_API_KEY_ID',
      'PLAY_SERVICE_ACCOUNT_JSON',
      'KOALA_ANDROID_MAPS_API_KEY_PRODUCTION',
      'KOALA_IOS_MAPS_API_KEY_PRODUCTION',
      r'--build-number ${{ github.run_number }}',
    ]) {
      expect(workflow, contains(contract), reason: '$contract eksik');
    }
  });

  test('yayın ve gizlilik belgeleri insan kapılarını açıkça ayırır', () {
    final release = File('docs/release.md').readAsStringSync();
    final privacy = File('docs/store-privacy-inventory.md').readAsStringSync();

    for (final contract in [
      'APP_MINIMUM_VERSION',
      'mobile-v<semver>',
      'Play App Signing',
      'TestFlight',
      'gerçek cihaz',
      'geri alma',
    ]) {
      expect(release, contains(contract), reason: '$contract eksik');
    }

    for (final dataType in [
      'Konum',
      'Kimlik belgesi',
      'Özgeçmiş',
      'İletişim',
      'Ödeme',
      'Mesaj',
      'Tanılama',
      'Hesap silme',
    ]) {
      expect(privacy, contains(dataType), reason: '$dataType eksik');
    }
  });
}
