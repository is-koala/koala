import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_info.dart';
import 'package:koala/product/network/device_hints.dart';

void main() {
  group('DeviceHints.describeOs', () {
    test('iOS sürüm dizgesinden kısa ad çıkarılır', () {
      expect(
        DeviceHints.describeOs(
          operatingSystem: 'ios',
          operatingSystemVersion: 'Version 18.1 (Build 22B83)',
        ),
        'iOS 18.1',
      );
    });

    test('üç basamaklı sürüm olduğu gibi kalır', () {
      expect(
        DeviceHints.describeOs(
          operatingSystem: 'ios',
          operatingSystemVersion: 'Version 17.5.1 (Build 21F90)',
        ),
        'iOS 17.5.1',
      );
    });

    // Android'de `operatingSystemVersion` çekirdek sürümünü taşıyor;
    // oradaki `android12` çekirdek dalı, işletim sistemi sürümü değil.
    test('Android çekirdek dizgesinden sürüm uydurulmaz', () {
      expect(
        DeviceHints.describeOs(
          operatingSystem: 'android',
          operatingSystemVersion:
              'Linux 5.10.43-android12-9-00003-g1f2e3d #1 SMP PREEMPT',
        ),
        'Android',
      );
    });

    test('sürüm bulunamazsa yalnız ad kalır', () {
      expect(
        DeviceHints.describeOs(
          operatingSystem: 'ios',
          operatingSystemVersion: 'bilinmiyor',
        ),
        'iOS',
      );
    });

    test('bilinmeyen platform adı olduğu gibi geçer', () {
      expect(
        DeviceHints.describeOs(
          operatingSystem: 'fuchsia',
          operatingSystemVersion: '1.2',
        ),
        'fuchsia 1.2',
      );
    });
  });

  group('DeviceHints.headers', () {
    test('dolu alanlar başlık olur', () {
      const hints = DeviceHints(
        model: 'iPhone15,3',
        os: 'iOS 18.1',
        appVersion: '1.1.0',
      );

      expect(hints.headers, {
        'X-Koala-Device-Model': 'iPhone15,3',
        'X-Koala-OS': 'iOS 18.1',
        'X-Koala-App-Version': '1.1.0',
      });
    });

    // Sunucu boş başlığı yok sayıyor ama hiç göndermemek daha temiz;
    // model bilgisi projede henüz yok, o başlık gitmemeli.
    test('boş ve null alanlar başlık olarak gitmez', () {
      const hints = DeviceHints(model: '  ', os: 'iOS 18.1', appVersion: null);

      expect(hints.headers, {'X-Koala-OS': 'iOS 18.1'});
      expect(DeviceHints.none.headers, isEmpty);
    });
  });

  group('DeviceHints.current', () {
    test('işletim sistemi ve uygulama sürümü dolu, model boş', () {
      final hints = DeviceHints.current();

      expect(hints.os, isNotEmpty);
      expect(hints.appVersion, AppInfo.version);
      // `device_info_plus` pubspec'te yok; model başlığı bilinçli olarak
      // gönderilmiyor (is-koala/koala#198).
      expect(hints.model, isNull);
      expect(hints.headers.keys, isNot(contains(DeviceHints.modelHeader)));
    });
  });
}
