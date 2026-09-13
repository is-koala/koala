import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Gradle FCM eklentisini ayarlar', () {
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final appGradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(
      settings,
      contains('id("com.google.gms.google-services")'),
      reason:
          'google-services settings.gradle.kts eklenti bloğunda apply false olmalı',
    );
    expect(
      settings,
      contains(
        'id("com.google.gms.google-services") version "4.5.0" apply false',
      ),
    );
    expect(
      appGradle,
      contains('id("com.google.gms.google-services")'),
      reason: 'Uygulama modülü google-services eklentisini uygulamalı',
    );
  });

  test('ana manifest POST_NOTIFICATIONS ister', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
  });

  test('üç flavor google-services.json doğru Firebase projesini gösterir', () {
    const flavors = {
      'dev': 'iskoala-staging',
      'staging': 'iskoala-staging',
      'production': 'iskoala',
    };

    for (final entry in flavors.entries) {
      final file = File('android/app/src/${entry.key}/google-services.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: '${entry.key} google-services.json yok',
      );

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final project = json['project_info'] as Map<String, dynamic>;
      expect(
        project['project_id'],
        entry.value,
        reason: '${entry.key} project_id ${entry.value} olmalı',
      );
    }
  });
}
