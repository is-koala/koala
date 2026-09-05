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
      'subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2',
      'flutter build appbundle',
      'r0adkll/upload-google-play@e738b9dd8f2476ea806d921b64aacd24f34515a5',
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
    expect(
      workflow,
      isNot(contains('r0adkll/upload-google-play@v1')),
      reason: 'Play yükleme aksiyonu değişebilir bir etikete bağlı olmamalı',
    );
    expect(
      workflow,
      isNot(contains('subosito/flutter-action@v2')),
      reason: 'Flutter kurulum aksiyonu değişebilir bir etikete bağlı olmamalı',
    );
    expect(
      workflow,
      isNot(contains('    env:\n      KOALA_ANDROID_KEYSTORE_BASE64')),
      reason: 'Android sırları job genelindeki tüm adımlara yayılmamalı',
    );
    expect(
      workflow,
      isNot(contains('    env:\n      APPLE_DISTRIBUTION_CERTIFICATE_BASE64')),
      reason: 'Apple sırları job genelindeki tüm adımlara yayılmamalı',
    );
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
