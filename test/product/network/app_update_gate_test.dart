import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/app_update_gate.dart';

import '../../support/fake_api.dart';

void main() {
  setUp(() => AppUpdateGate().reset());
  tearDown(() => AppUpdateGate().reset());

  group('AppUpdateGate', () {
    test('başlangıçta kapı açık', () {
      expect(AppUpdateGate().isBlocked, isFalse);
    });

    test('boş mesajda varsayılan metin yazılır', () {
      AppUpdateGate().block(null);

      expect(AppUpdateGate().isBlocked, isTrue);
      expect(AppUpdateGate().message.value, 'Lütfen uygulamayı güncelleyin.');
    });

    // Her istek aynı cevabı alacağı için dinleyiciler boşuna uyanmamalı.
    test('aynı mesaj ikinci kez dinleyicileri uyandırmaz', () {
      var notifications = 0;
      void listener() => notifications++;

      AppUpdateGate().message.addListener(listener);
      addTearDown(() => AppUpdateGate().message.removeListener(listener));

      AppUpdateGate().block('Güncelleyin');
      AppUpdateGate().block('Güncelleyin');

      expect(notifications, 1);
    });
  });

  group('ApiClient ile bağlantısı', () {
    // Kapı her uçtan gelebiliyor; çağıranın yakalamasını beklemiyoruz.
    test('426 yanıtı kapıyı kapatır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 426,
          body: {
            'success': false,
            'errorCode': 'UPGRADE_REQUIRED',
            'message': 'Lutfen uygulamayi guncelleyin.',
          },
        ),
      );

      await expectLater(
        api.client.postWithoutData('/users/me'),
        throwsA(isA<ApiException>()),
      );

      expect(AppUpdateGate().isBlocked, isTrue);
      expect(AppUpdateGate().message.value, 'Lutfen uygulamayi guncelleyin.');
    });

    test('başka bir hata kapıyı kapatmaz', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      );

      await expectLater(
        api.client.postWithoutData('/users/me'),
        throwsA(isA<ApiException>()),
      );

      expect(AppUpdateGate().isBlocked, isFalse);
    });
  });
}
