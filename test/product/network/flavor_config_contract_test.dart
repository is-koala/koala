import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'flavor yapılandırma dosyaları yalnız API kökünü ve web hostlarını taşır',
    () {
      for (final name in [
        'config/dev-ios.json',
        'config/dev-android.json',
        'config/staging.json',
        'config/production.json',
      ]) {
        final decoded =
            jsonDecode(File(name).readAsStringSync()) as Map<String, dynamic>;
        expect(decoded.keys.toList(), [
          'API_BASE_URL',
          'WEB_HOSTS',
        ], reason: name);
        expect(decoded['API_BASE_URL'], isA<String>());
        expect(decoded['API_BASE_URL'], isNot(contains('@')));
        expect(decoded['WEB_HOSTS'], isA<String>(), reason: name);
        expect(decoded['WEB_HOSTS'], isNot(contains('/')), reason: name);
      }
    },
  );

  test('yalnız dev public HTTPS hostu sahiplenmez', () {
    for (final name in ['config/dev-ios.json', 'config/dev-android.json']) {
      final decoded =
          jsonDecode(File(name).readAsStringSync()) as Map<String, dynamic>;
      expect(decoded['WEB_HOSTS'], isEmpty, reason: name);
    }
    for (final name in ['config/staging.json', 'config/production.json']) {
      final decoded =
          jsonDecode(File(name).readAsStringSync()) as Map<String, dynamic>;
      expect(decoded['WEB_HOSTS'], isNotEmpty, reason: name);
    }
  });

  test('canlı QA girişi kimlikleri yalnız derleme tanımlarından okur', () {
    final source = File(
      'integration_test/live_qa_login_test.dart',
    ).readAsStringSync();

    for (final name in [
      'QA_WORKER_EMAIL',
      'QA_EMPLOYER_EMAIL',
      'QA_WORKER_PASSWORD',
      'QA_EMPLOYER_PASSWORD',
    ]) {
      expect(source, contains("String.fromEnvironment('$name')"));
    }
    expect(source, isNot(contains('@gmail')));
    expect(source, isNot(contains('@hotmail')));
    expect(source, isNot(contains("password: '")));
    expect(source, isNot(contains('password: "')));
  });

  test('auth-email araştırması düzelmiş kodu hâlâ kusur diye yazmaz', () {
    final research = File(
      'docs/research/auth-email-app-links.md',
    ).readAsStringSync();

    expect(research, contains('#131'));
    expect(research, isNot(contains('scheme/authority doğrulamadan')));
    expect(research, isNot(contains('kullanılmış token kaydı kontrol etmez')));
    expect(research, isNot(contains('kayıt doğrulama şablonunu seçiyor')));
    expect(research, contains('passwordResetTokenService.consume'));
    expect(research, contains('AppLinkDestination'));
  });
}
