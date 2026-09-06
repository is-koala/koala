import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const canonicalPaths = [
    '/hesap-dogrula',
    '/sifre-belirle',
    '/sifre-sifirla',
    '/eposta-onayla',
    '/payment/result',
  ];

  test(
    'production Android yapılandırması kanonik HTTPS yollarını doğrular',
    () {
      final manifest = File(
        'android/app/src/production/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:autoVerify="true"'));
      expect(manifest, contains('android:scheme="https"'));
      expect(manifest, contains('android:host="iskoala.com"'));
      expect(manifest, contains('android:host="www.iskoala.com"'));
      for (final path in canonicalPaths) {
        expect(manifest, contains('android:pathPrefix="$path"'));
      }
    },
  );

  test('staging Android yapılandırması yalnız staging hostunu doğrular', () {
    final manifest = File(
      'android/app/src/staging/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="staging.iskoala.com"'));
    expect(manifest, isNot(contains('android:host="iskoala.com"')));
    expect(manifest, isNot(contains('android:host="www.iskoala.com"')));
    for (final path in canonicalPaths) {
      expect(manifest, contains('android:pathPrefix="$path"'));
    }
  });

  test('iOS flavorları kendi Associated Domains dosyalarını kullanır', () {
    final production = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final staging = File(
      'ios/Runner/Runner-staging.entitlements',
    ).readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(production, contains('<string>applinks:iskoala.com</string>'));
    expect(production, contains('<string>applinks:www.iskoala.com</string>'));
    expect(
      production,
      isNot(contains('<string>applinks:staging.iskoala.com</string>')),
    );
    expect(staging, contains('<string>applinks:staging.iskoala.com</string>'));
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    );
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner-staging.entitlements;'),
    );
  });
}
