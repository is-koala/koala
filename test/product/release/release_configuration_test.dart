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
        tag: 'mobile-v1.1.1',
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

  test('PR kapısı GitHub-hosted Linux’ta; macOS PR’da koşmaz', () {
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    final ios = File('.github/workflows/ios.yml').readAsStringSync();
    final release = File(
      '.github/workflows/mobile-release.yml',
    ).readAsStringSync();

    expect(ci, contains('pull_request:'));
    expect(ci, contains('workflow_dispatch:'));
    expect(ci, contains('runs-on: ubuntu-latest'));
    // macOS dakikası 10 kat sayılır: PR zincirinde macOS işi olmamalı.
    expect(ci, isNot(contains('macos')));
    expect(ios, isNot(contains('pull_request:')));
    expect(ios, isNot(contains('push:')));
    expect(ios, contains('workflow_dispatch:'));
    // Self-hosted runner kaldırıldı; ona bağlı iş kuyrukta sonsuza dek bekler.
    for (final workflow in [ci, ios, release]) {
      expect(workflow, isNot(contains('self-hosted')));
    }
    expect(
      ci,
      contains(
        'flutter test --flavor staging --dart-define-from-file=config/staging.json',
      ),
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

  test('Android nöbetçisi yalnız güncel AGP aapt2 adaylarını ölçer', () {
    final action = File(
      '.github/actions/setup-android-x64-tools/action.yml',
    ).readAsStringSync();
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final agpVersion = RegExp(
      r'id\("com\.android\.application"\) version "([^"]+)"',
    ).firstMatch(settings)!.group(1)!;
    final aapt2Version = RegExp(
      r'agp-aapt2-version:[\s\S]*?default: "([^"]+)"',
    ).firstMatch(action)!.group(1)!;

    expect(aapt2Version, startsWith('$agpVersion-'));
    expect(action, contains(r'-path "*/aapt2-$AGP_AAPT2_VERSION-linux/aapt2"'));
    expect(
      action,
      contains(r'for agp_aapt2 in "${agp_aapt2_candidates[@]}"; do'),
    );
    expect(action, isNot(contains('-name aapt2 -print -quit')));
  });

  test('Android nöbetçisinin bütün hataları tek runbooka yönlenir', () {
    final action = File(
      '.github/actions/setup-android-x64-tools/action.yml',
    ).readAsStringSync();
    final errorLines = action
        .split('\n')
        .where((line) => line.contains('echo "::error::'))
        .toList();

    expect(errorLines, isNotEmpty);
    for (final line in errorLines) {
      expect(
        line,
        contains('docs/research/raspberry-pi-self-hosted-ci.md'),
        reason: 'Kanonik runbooka yönlenmeyen hata: $line',
      );
    }
  });

  test('Android nöbetçisi runbooku PR ve etiket yayınını ayırır', () {
    final runbook = File(
      'docs/research/raspberry-pi-self-hosted-ci.md',
    ).readAsStringSync();

    expect(runbook, contains('workflow_dispatch'));
    expect(runbook, contains('mobile-v*'));
    expect(runbook, contains('Play internal'));
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
