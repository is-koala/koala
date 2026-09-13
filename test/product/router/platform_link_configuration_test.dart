import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/product/router/app_link_destination.dart';

/// `config/<flavor>.json` içindeki `WEB_HOSTS`, Dart'ın okuduğu sırayla.
List<String> configuredWebHosts(String flavor) {
  final decoded =
      jsonDecode(File('config/$flavor.json').readAsStringSync())
          as Map<String, dynamic>;
  return (decoded['WEB_HOSTS'] as String)
      .split(',')
      .map((host) => host.trim())
      .where((host) => host.isNotEmpty)
      .toList();
}

void main() {
  const flavors = ['staging', 'production'];

  test('flavor manifestleri hostu yapılandırma placeholderından alır', () {
    for (final flavor in flavors) {
      final hosts = configuredWebHosts(flavor);
      final manifest = File(
        'android/app/src/$flavor/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:autoVerify="true"'), reason: flavor);
      expect(manifest, contains('android:scheme="https"'), reason: flavor);
      expect(
        manifest,
        contains(r'android:host="${appLinkHost}"'),
        reason: flavor,
      );
      expect(
        manifest.contains(r'android:host="${appLinkHostAlias}"'),
        hosts.length == 2,
        reason:
            '$flavor manifestindeki host satırı sayısı config/$flavor.json '
            'WEB_HOSTS ile aynı olmalı: $hosts',
      );
      expect(
        RegExp(r'android:host="(?!\$\{)').hasMatch(manifest),
        isFalse,
        reason: '$flavor manifesti sabit host taşımamalı',
      );
      for (final path in AppLinkDestination.httpsPathPrefixes) {
        expect(
          manifest,
          contains('android:pathPrefix="$path"'),
          reason: '$flavor $path',
        );
      }
      expect(
        RegExp(r'android:pathPrefix=').allMatches(manifest).length,
        AppLinkDestination.httpsPathPrefixes.length,
        reason: '$flavor manifesti Dart listesinde olmayan yol sahiplenmemeli',
      );
    }
  });

  test('Gradle placeholderı config dosyasındaki WEB_HOSTS ile doldurur', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('config/\$flavor.json'));
    expect(gradle, contains('"WEB_HOSTS"'));
    expect(gradle, contains('"appLinkHost"'));
    expect(gradle, contains('"appLinkHostAlias"'));
    expect(
      gradle,
      contains('appLinkPlaceholders("staging", manifestHostLines = 1)'),
    );
    expect(
      gradle,
      contains('appLinkPlaceholders("production", manifestHostLines = 2)'),
    );
  });

  test('dev ve ana manifest https App Links filtresi taşımaz', () {
    final main = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(main, isNot(contains('android:scheme="https"')));
    expect(main, isNot(contains('android:autoVerify')));

    final dev = File('android/app/src/dev/AndroidManifest.xml');
    if (dev.existsSync()) {
      expect(dev.readAsStringSync(), isNot(contains('android:autoVerify')));
    }
  });

  test(
    'iOS entitlements flavorın yapılandırılmış hostlarını birebir taşır',
    () {
      final files = {
        'staging': 'ios/Runner/Runner-staging.entitlements',
        'production': 'ios/Runner/Runner.entitlements',
      };
      for (final flavor in flavors) {
        final entitlements = File(files[flavor]!).readAsStringSync();
        final declared = RegExp(
          r'<string>applinks:([^<]+)</string>',
        ).allMatches(entitlements).map((match) => match.group(1)).toList();
        expect(declared, configuredWebHosts(flavor), reason: flavor);
      }

      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(
        project,
        contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
      );
      expect(
        project,
        contains(
          'CODE_SIGN_ENTITLEMENTS = Runner/Runner-staging.entitlements;',
        ),
      );
    },
  );

  test('staging bugün production web hostunu kullanır', () {
    // E-postalar https://iskoala.com/... üretiyor ve staging aynı API/web ile
    // çalışıyor (#155). Ayrı staging web'i geldiğinde config/staging.json ile
    // birlikte bu beklenti de değişir; sessizce ayrışmasın diye sabitlendi.
    expect(configuredWebHosts('staging'), ['iskoala.com']);
    expect(configuredWebHosts('production'), [
      'iskoala.com',
      'www.iskoala.com',
    ]);
    for (final flavor in flavors) {
      expect(
        ApiConfig.resolveWebHosts(
          flavor: flavor,
          configuredHosts: configuredWebHosts(flavor).join(','),
        ),
        contains('iskoala.com'),
      );
    }
  });
}
