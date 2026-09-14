import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('NotificationProvider.refreshQuietly', () {
    // Ön plana dönüşte çağrılıyor: rozet için canlı kanal yok, arka planda
    // gelenler böyle sayılıyor. Hiç yüklenmemişse oturum olmayabilir; istek
    // atılmaz, zil kendi `ensureLoaded`'ını yapar.
    test('akış hiç çekilmediyse ağa çıkmaz', () async {
      var requests = 0;
      final api = FakeApi(
        handler: (_) {
          requests++;
          return FakeApiResponse(
            statusCode: 200,
            body: feedResponse(page: 0, last: true),
          );
        },
      );
      final provider = providerWith(api);

      await provider.refreshQuietly();

      expect(requests, 0);
    });

    test('yüklenmiş akışı göstergesiz yeniden çeker', () async {
      var unread = 2;
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: feedResponse(page: 0, last: true, unreadCount: unread),
        ),
      );
      final provider = providerWith(api);
      await provider.load();
      var sawSpinner = false;
      provider.addListener(() => sawSpinner = sawSpinner || provider.isLoading);

      unread = 5;
      await provider.refreshQuietly();

      expect(provider.unreadCount, 5);
      expect(sawSpinner, isFalse);
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

    test('beklerken yenilenen listede başka satırı okundu yapmaz', () async {
      final markReadResponse = Completer<FakeApiResponse>();
      var feedCall = 0;
      final api = FakeApi(
        handler: (options) {
          if (options.path.endsWith('/read')) return markReadResponse.future;

          feedCall++;
          return FakeApiResponse(
            statusCode: 200,
            body: feedResponse(
              page: 0,
              last: true,
              unreadCount: feedCall == 1 ? 2 : 5,
              ids: feedCall == 1
                  ? const ['hedef', 'diger']
                  : const ['yeni_satir'],
            ),
          );
        },
      );

      final provider = providerWith(api);
      await provider.load();
      final markRead = provider.markRead('hedef');
      await api.requestsReach(2);

      await provider.load();
      markReadResponse.complete(
        const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );
      await markRead;

      expect(provider.notifications.single.id, 'yeni_satir');
      expect(provider.notifications.single.isRead, isFalse);
      expect(provider.unreadCount, 5);
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

  group('NotificationProvider oturum yalıtımı', () {
    test(
      'zorunlu oturum sonu çıkan hesabı temizler ve yenisini yükler',
      () async {
        SharedPreferences.setMockInitialValues({});
        final session = SessionManager.withTokenStorage(FakeTokenStorage());
        await session.start(
          accessToken: 'hesap-a-token',
          refreshToken: 'hesap-a-refresh',
          isEmployer: false,
        );

        var call = 0;
        final api = FakeApi(
          handler: (_) {
            call++;
            return FakeApiResponse(
              statusCode: 200,
              body: feedResponse(
                page: 0,
                last: true,
                unreadCount: call,
                ids: [call == 1 ? 'hesap_a' : 'hesap_b'],
              ),
            );
          },
        );
        final provider = NotificationProvider(
          service: NotificationService.withClient(api.client),
          sessionManager: session,
        );
        await provider.ensureLoaded();

        // ApiClient'in onSessionExpired geri çağrısı bu sınıra gider.
        await session.end();

        expect(provider.notifications, isEmpty);
        expect(provider.unreadCount, 0);

        await session.start(
          accessToken: 'hesap-b-token',
          refreshToken: 'hesap-b-refresh',
          isEmployer: true,
        );
        await provider.ensureLoaded();

        expect(provider.notifications.single.id, 'hesap_b');
        expect(provider.unreadCount, 2);
        expect(api.requests, hasLength(2));

        provider.dispose();
      },
    );

    test(
      'clear çıkan hesabı düşürür ve yeni hesap için yeniden yükler',
      () async {
        var call = 0;
        final api = FakeApi(
          handler: (_) {
            call++;
            return FakeApiResponse(
              statusCode: 200,
              body: feedResponse(
                page: 0,
                last: call > 1,
                unreadCount: call,
                ids: [call == 1 ? 'hesap_a' : 'hesap_b'],
              ),
            );
          },
        );

        final provider = providerWith(api);
        await provider.ensureLoaded();

        provider.clear();

        expect(provider.notifications, isEmpty);
        expect(provider.unreadCount, 0);
        expect(provider.hasMore, isFalse);
        expect(provider.errorMessage, isNull);

        await provider.ensureLoaded();

        expect(provider.notifications.map((notification) => notification.id), [
          'hesap_b',
        ]);
        expect(provider.unreadCount, 2);
        expect(api.requests, hasLength(2));
      },
    );

    test(
      'yeni hesap yüklenirken ve hata aldığında eski içerik göstermez',
      () async {
        final accountBResponse = Completer<FakeApiResponse>();
        var call = 0;
        final api = FakeApi(
          handler: (_) {
            call++;
            if (call == 1) {
              return FakeApiResponse(
                statusCode: 200,
                body: feedResponse(
                  page: 0,
                  last: true,
                  unreadCount: 3,
                  ids: const ['hesap_a'],
                ),
              );
            }
            return accountBResponse.future;
          },
        );

        final provider = providerWith(api);
        await provider.load();

        provider.clear();
        final accountBLoad = provider.ensureLoaded();
        await api.requestsReach(2);

        expect(provider.notifications, isEmpty);
        expect(provider.unreadCount, 0);
        expect(provider.errorMessage, isNull);

        accountBResponse.complete(
          const FakeApiResponse(
            statusCode: 500,
            body: {'success': false, 'message': 'B hesabı yüklenemedi'},
          ),
        );
        await accountBLoad;

        expect(provider.notifications, isEmpty);
        expect(provider.unreadCount, 0);
        expect(provider.errorMessage, 'B hesabı yüklenemedi');
      },
    );

    test('önceki hesabın geç yanıtı yeni hesabın akışını ezmez', () async {
      final accountAResponse = Completer<FakeApiResponse>();
      var call = 0;
      final api = FakeApi(
        handler: (_) {
          call++;
          if (call == 1) return accountAResponse.future;
          return FakeApiResponse(
            statusCode: 200,
            body: feedResponse(
              page: 0,
              last: true,
              unreadCount: 1,
              ids: const ['hesap_b'],
            ),
          );
        },
      );

      final provider = providerWith(api);
      final accountALoad = provider.load();
      await api.requestsReach(1);

      provider.clear();
      final accountBLoad = provider.ensureLoaded();
      await api.requestsReach(2);
      await accountBLoad;

      accountAResponse.complete(
        FakeApiResponse(
          statusCode: 200,
          body: feedResponse(
            page: 0,
            last: true,
            unreadCount: 8,
            ids: const ['hesap_a'],
          ),
        ),
      );
      await accountALoad;

      expect(provider.notifications.map((notification) => notification.id), [
        'hesap_b',
      ]);
      expect(provider.unreadCount, 1);
    });

    test('önceki hesabın geç sayfası yeni hesabın akışına eklenmez', () async {
      final accountANextPage = Completer<FakeApiResponse>();
      var call = 0;
      final api = FakeApi(
        handler: (_) {
          call++;
          if (call == 1) {
            return FakeApiResponse(
              statusCode: 200,
              body: feedResponse(
                page: 0,
                last: false,
                unreadCount: 2,
                ids: const ['hesap_a'],
              ),
            );
          }
          if (call == 2) return accountANextPage.future;
          return FakeApiResponse(
            statusCode: 200,
            body: feedResponse(
              page: 0,
              last: true,
              unreadCount: 1,
              ids: const ['hesap_b'],
            ),
          );
        },
      );

      final provider = providerWith(api);
      await provider.load();
      final accountALoadMore = provider.loadMore();
      await api.requestsReach(2);

      provider.clear();
      await provider.ensureLoaded();

      accountANextPage.complete(
        FakeApiResponse(
          statusCode: 200,
          body: feedResponse(
            page: 1,
            last: true,
            unreadCount: 9,
            ids: const ['hesap_a_sayfa_2'],
          ),
        ),
      );
      await accountALoadMore;

      expect(provider.notifications.map((notification) => notification.id), [
        'hesap_b',
      ]);
      expect(provider.unreadCount, 1);
    });

    test('önceki hesabın geç okundu yanıtı yeni hesabı değiştirmez', () async {
      final accountAMarkRead = Completer<FakeApiResponse>();
      var feedCall = 0;
      final api = FakeApi(
        handler: (options) {
          if (options.path.endsWith('/read')) return accountAMarkRead.future;

          feedCall++;
          return FakeApiResponse(
            statusCode: 200,
            body: feedResponse(
              page: 0,
              last: true,
              unreadCount: feedCall == 1 ? 2 : 4,
              ids: [feedCall == 1 ? 'hesap_a' : 'hesap_b'],
            ),
          );
        },
      );

      final provider = providerWith(api);
      await provider.load();
      final accountAMark = provider.markRead('hesap_a');
      await api.requestsReach(2);

      provider.clear();
      await provider.ensureLoaded();

      accountAMarkRead.complete(
        const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );
      await accountAMark;

      expect(provider.notifications.single.id, 'hesap_b');
      expect(provider.notifications.single.isRead, isFalse);
      expect(provider.unreadCount, 4);
    });

    test(
      'önceki hesabın toplu okuması yeni hesapta yükleme başlatmaz',
      () async {
        final accountAMarkAll = Completer<FakeApiResponse>();
        var feedCall = 0;
        final api = FakeApi(
          handler: (options) {
            if (options.path.endsWith('/read')) return accountAMarkAll.future;

            feedCall++;
            return FakeApiResponse(
              statusCode: 200,
              body: feedResponse(
                page: 0,
                last: true,
                unreadCount: feedCall == 1 ? 2 : 4,
                ids: [feedCall == 1 ? 'hesap_a' : 'hesap_b'],
              ),
            );
          },
        );

        final provider = providerWith(api);
        await provider.load();
        final accountAMark = provider.markAllRead();
        await api.requestsReach(2);

        provider.clear();
        await provider.ensureLoaded();

        accountAMarkAll.complete(
          const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': 2},
          ),
        );
        await accountAMark;

        expect(api.requests, hasLength(3));
        expect(provider.notifications.single.id, 'hesap_b');
        expect(provider.unreadCount, 4);
      },
    );
  });
}
