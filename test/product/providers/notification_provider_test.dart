import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/services/notification_service.dart';

import '../../support/fake_api.dart';

Map<String, dynamic> feedResponse({
  required int page,
  required bool last,
  int unreadCount = 2,
  List<String> ids = const ['ntf_1'],
}) {
  return {
    'success': true,
    'data': {
      'notifications': {
        'content': [
          for (final id in ids)
            {
              'id': id,
              'channel': 'IN_APP',
              'category': 'APPLICATION_UPDATES',
              'status': 'SENT',
              'subject': 'Garson aranıyor',
              'body': 'Başvurunuz kabul edildi',
              'targetType': 'JOB_ASSIGNMENT',
              'targetId': 'asg_1',
              'sentAt': '2026-08-30T09:15:00Z',
            },
        ],
        'page': page,
        'last': last,
        'totalElements': 2,
      },
      'unreadCount': unreadCount,
    },
  };
}

NotificationProvider providerWith(FakeApi api) {
  return NotificationProvider(
    service: NotificationService.withClient(api.client),
  );
}

void main() {
  group('NotificationProvider.load', () {
    test('akış ve okunmamış sayısı yüklenir', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: feedResponse(page: 0, last: true),
        ),
      );

      final provider = providerWith(api);
      await provider.load();

      expect(provider.notifications, hasLength(1));
      expect(provider.unreadCount, 2);
      expect(provider.hasUnread, isTrue);
      expect(provider.hasMore, isFalse);
      expect(provider.errorMessage, isNull);
    });

    // Yenilemede liste sıfırdan kuruluyor, üstüne eklenmiyor.
    test('ikinci load listeyi tazeler, çoğaltmaz', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: feedResponse(page: 0, last: true),
        ),
      );

      final provider = providerWith(api);
      await provider.load();
      await provider.load();

      expect(provider.notifications, hasLength(1));
    });

    test('hata mesajı taşınır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      );

      final provider = providerWith(api);
      await provider.load();

      expect(provider.notifications, isEmpty);
      expect(provider.errorMessage, 'Sunucu hatası');
    });
  });

  group('NotificationProvider.loadMore', () {
    test('sonraki sayfa listenin sonuna eklenir', () async {
      final api = FakeApi(
        handler: (options) => FakeApiResponse(
          statusCode: 200,
          body: options.queryParameters['page'] == 0
              ? feedResponse(page: 0, last: false)
              : feedResponse(page: 1, last: true, ids: const ['ntf_2']),
        ),
      );

      final provider = providerWith(api);
      await provider.load();
      expect(provider.hasMore, isTrue);

      await provider.loadMore();

      expect(provider.notifications, hasLength(2));
      expect(provider.hasMore, isFalse);
    });

    // Son sayfadayken boşuna istek atılmamalı.
    test('son sayfada istek atmaz', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: feedResponse(page: 0, last: true),
        ),
      );

      final provider = providerWith(api);
      await provider.load();
      await provider.loadMore();

      expect(api.requests, hasLength(1));
    });

    // Sonraki sayfa gelmezse eldeki liste durmalı; kullanıcı okuduğunu
    // kaybetmesin.
    test('sayfa hatası eldeki listeyi silmez', () async {
      var call = 0;
      final api = FakeApi(
        handler: (_) {
          call++;
          return call == 1
              ? FakeApiResponse(
                  statusCode: 200,
                  body: feedResponse(page: 0, last: false),
                )
              : const FakeApiResponse(
                  statusCode: 500,
                  body: {'success': false, 'message': 'Sunucu hatası'},
                );
        },
      );

      final provider = providerWith(api);
      await provider.load();
      await provider.loadMore();

      expect(provider.notifications, hasLength(1));
      expect(provider.errorMessage, 'Sunucu hatası');
    });
  });

  group('NotificationProvider.markAllRead', () {
    test('işaretledikten sonra akışı tazeler', () async {
      var marked = false;
      final api = FakeApi(
        handler: (options) {
          if (options.path.endsWith('/read')) {
            marked = true;
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': 2},
            );
          }

          return FakeApiResponse(
            statusCode: 200,
            body: feedResponse(
              page: 0,
              last: true,
              unreadCount: marked ? 0 : 2,
            ),
          );
        },
      );

      final provider = providerWith(api);
      await provider.load();
      expect(provider.hasUnread, isTrue);

      final result = await provider.markAllRead();

      expect(result, isTrue);
      expect(provider.unreadCount, 0);
      expect(provider.hasUnread, isFalse);
    });

    // Okunmamış yokken sunucuya gitmenin anlamı yok.
    test('okunmamış yokken istek atmaz', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: feedResponse(page: 0, last: true, unreadCount: 0),
        ),
      );

      final provider = providerWith(api);
      await provider.load();

      expect(await provider.markAllRead(), isFalse);
      expect(api.requests, hasLength(1));
    });
  });

  group('NotificationProvider.ensureLoaded', () {
    test('bir kez yükler, ikinci çağrıda istek atmaz', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: feedResponse(page: 0, last: true),
        ),
      );

      final provider = providerWith(api);
      await provider.ensureLoaded();
      await provider.ensureLoaded();

      expect(api.requests, hasLength(1));
      expect(provider.unreadCount, 2);
    });

    // İlk deneme düşerse zil sonraki fırsatta yeniden denemeli.
    test('yükleme başarısızsa tekrar dener', () async {
      var call = 0;
      final api = FakeApi(
        handler: (_) {
          call++;
          return call == 1
              ? const FakeApiResponse(
                  statusCode: 500,
                  body: {'success': false, 'message': 'Sunucu hatası'},
                )
              : FakeApiResponse(
                  statusCode: 200,
                  body: feedResponse(page: 0, last: true),
                );
        },
      );

      final provider = providerWith(api);
      await provider.ensureLoaded();
      await provider.ensureLoaded();

      expect(api.requests, hasLength(2));
      expect(provider.unreadCount, 2);
    });
  });

  group('NotificationProvider.markRead', () {
    // Liste elde güncelleniyor: kullanıcı satıra dokunup gidiyor, dönüşte
    // listenin baştan kurulmasını beklemesin.
    test('satırı okundu yapar ve rozeti azaltır', () async {
      final api = FakeApi(
        handler: (options) => options.path.endsWith('/read')
            ? const FakeApiResponse(statusCode: 200, body: {'success': true})
            : FakeApiResponse(
                statusCode: 200,
                body: feedResponse(page: 0, last: true),
              ),
      );

      final provider = providerWith(api);
      await provider.load();
      await provider.markRead('ntf_1');

      expect(provider.notifications.single.isRead, isTrue);
      expect(provider.unreadCount, 1);
      // Liste yeniden çekilmiyor: yükleme + işaretleme, iki istek.
      expect(api.requests, hasLength(2));
    });

    // Okunmamışı okundu göstermek yanlış tarafa hata yapmak olurdu.
    test('çağrı düşerse satır okunmamış kalır', () async {
      final api = FakeApi(
        handler: (options) => options.path.endsWith('/read')
            ? const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'Sunucu hatası'},
              )
            : FakeApiResponse(
                statusCode: 200,
                body: feedResponse(page: 0, last: true),
              ),
      );

      final provider = providerWith(api);
      await provider.load();
      await provider.markRead('ntf_1');

      expect(provider.notifications.single.isRead, isFalse);
      expect(provider.unreadCount, 2);
      expect(provider.errorMessage, 'Sunucu hatası');
    });

    test('zaten okunmuş bildirimde istek atmaz', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: feedResponse(page: 0, last: true),
        ),
      );

      final provider = providerWith(api);
      await provider.load();
      await provider.markRead('bilinmeyen');

      expect(api.requests, hasLength(1));
    });
  });

  group('NotificationProvider eşzamanlılık', () {
    // Sessiz yükleme göstergeyi açmıyor ama yine de tek başına uçmalı:
    // bayrak tek olduğunda zilin ensureLoaded'ı ile ekranın load'u aynı
    // anda listeyi yeniden kuruyordu.
    test('sessiz yükleme ikinci yüklemeyi engeller', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: feedResponse(page: 0, last: true),
        ),
      );

      final provider = providerWith(api);
      final silent = provider.load(silent: true);
      final loud = provider.load();
      await Future.wait([silent, loud]);

      expect(api.requests, hasLength(1));
      expect(provider.notifications, hasLength(1));
    });

    test('yükleme bitince kapı yeniden açılır', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: feedResponse(page: 0, last: true),
        ),
      );

      final provider = providerWith(api);
      await provider.load(silent: true);
      await provider.load();

      expect(api.requests, hasLength(2));
    });
  });
}
