import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/providers/b_application_inbox_provider.dart';
import 'package:koala/business/features/home/services/received_application_service.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/received_application_fixtures.dart';

/// Yanıtı testin elinde bekleyen sahte sunucu: hangi isteğin ne zaman
/// döneceğini test seçiyor, böylece yarışlar duvar saatine değil sıraya
/// bağlı sınanıyor.
class _DeferredServer {
  _DeferredServer() {
    api = FakeApi(
      handler: (options) {
        final completer = Completer<FakeApiResponse>();
        pending.add((options: options, completer: completer));
        return completer.future;
      },
    );
  }

  late final FakeApi api;
  final List<({RequestOptions options, Completer<FakeApiResponse> completer})>
  pending = [];

  Future<void> reach(int count) => api.requestsReach(count);

  Map<String, dynamic> query(int index) =>
      pending[index].options.queryParameters;

  void reply(int index, FakeApiResponse response) =>
      pending[index].completer.complete(response);
}

BApplicationInboxProvider _providerOn(FakeApi api) => BApplicationInboxProvider(
  service: ReceivedApplicationService.withClient(api.client),
);

/// Her istek için sırayla bir yanıt veren sahte sunucu.
FakeApi _scripted(List<FakeApiResponse> responses) {
  var index = 0;
  return FakeApi(handler: (_) => responses[index++]);
}

List<Map<String, dynamic>> _rows(String prefix, int count) => [
  for (var i = 0; i < count; i++) receivedApplicationJson('$prefix-$i'),
];

void main() {
  group('load', () {
    test('ilk sayfayı süzgeçsiz ister ve satırları tutar', () async {
      final api = _scripted([
        receivedApplicationsResponse(_rows('a', 3), last: false),
      ]);
      final provider = _providerOn(api);

      final notifications = <bool>[];
      provider.addListener(() => notifications.add(provider.isLoading));
      await provider.load();

      expect(api.requests.single.queryParameters, {'page': 0, 'size': 20});
      expect(provider.items.map((item) => item.id), ['a-0', 'a-1', 'a-2']);
      expect(provider.hasMore, isTrue);
      expect(provider.hasLoaded, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      // Yükleniyor durumu önce açılıp sonra kapanıyor.
      expect(notifications, [true, false]);
    });

    test(
      'hata satır bırakmaz ve mesajı taşır; yeniden deneme çalışır',
      () async {
        final api = _scripted([
          receivedApplicationsFailure,
          receivedApplicationsResponse(_rows('a', 1)),
        ]);
        final provider = _providerOn(api);

        await provider.load();
        expect(provider.items, isEmpty);
        expect(provider.errorMessage, 'Başvurular alınamadı');
        expect(provider.hasLoaded, isTrue);
        expect(provider.hasMore, isFalse);

        await provider.load();
        expect(provider.errorMessage, isNull);
        expect(provider.items, hasLength(1));
      },
    );

    test('boş yanıt hata değil', () async {
      final provider = _providerOn(
        _scripted([receivedApplicationsResponse(const [])]),
      );

      await provider.load();

      expect(provider.items, isEmpty);
      expect(provider.errorMessage, isNull);
      expect(provider.hasMore, isFalse);
    });
  });

  group('loadMore', () {
    test('sonraki sayfayı ekler, son sayfada durur', () async {
      final api = _scripted([
        receivedApplicationsResponse(_rows('a', 2), last: false),
        receivedApplicationsResponse(_rows('b', 2), page: 1),
      ]);
      final provider = _providerOn(api);
      await provider.load();

      await provider.loadMore();
      expect(api.requests.last.queryParameters, {'page': 1, 'size': 20});
      expect(provider.items.map((item) => item.id), [
        'a-0',
        'a-1',
        'b-0',
        'b-1',
      ]);
      expect(provider.hasMore, isFalse);

      // Son sayfadan sonra istek atılmıyor.
      await provider.loadMore();
      expect(api.requests, hasLength(2));
    });

    // Bekleyenler öne alındığı için sayfalar arasında yeni başvuru gelirse bir
    // satır iki sayfanın sınırında tekrar edebilir.
    test('iki sayfanın sınırında tekrar eden satır bir kez çizilir', () async {
      final api = _scripted([
        receivedApplicationsResponse([
          receivedApplicationJson('a-0'),
          receivedApplicationJson('a-1'),
        ], last: false),
        receivedApplicationsResponse([
          receivedApplicationJson('a-1'),
          receivedApplicationJson('b-0'),
        ], page: 1),
      ]);
      final provider = _providerOn(api);
      await provider.load();

      await provider.loadMore();

      expect(provider.items.map((item) => item.id), ['a-0', 'a-1', 'b-0']);
    });

    test('boş sayfa "daha var" demiş olsa da döngüye girmez', () async {
      final api = _scripted([
        receivedApplicationsResponse(_rows('a', 1), last: false),
        receivedApplicationsResponse(const [], page: 1, last: false),
      ]);
      final provider = _providerOn(api);
      await provider.load();

      await provider.loadMore();

      expect(provider.hasMore, isFalse);
    });

    test(
      'hata kendiliğinden tekrarlanmaz, retryLoadMore tekrar dener',
      () async {
        final api = _scripted([
          receivedApplicationsResponse(_rows('a', 1), last: false),
          receivedApplicationsFailure,
          receivedApplicationsResponse(_rows('b', 1), page: 1),
        ]);
        final provider = _providerOn(api);
        await provider.load();

        await provider.loadMore();
        expect(provider.loadMoreError, 'Başvurular alınamadı');
        expect(provider.items, hasLength(1));
        expect(provider.hasMore, isTrue);

        // Kaydırma olayları sürerken sunucuya yüklenilmiyor.
        await provider.loadMore();
        await provider.loadMore();
        expect(api.requests, hasLength(2));

        await provider.retryLoadMore();
        expect(provider.loadMoreError, isNull);
        expect(provider.items.map((item) => item.id), ['a-0', 'b-0']);
        expect(api.requests.last.queryParameters['page'], 1);
      },
    );

    test('yükleme sürerken ikinci istek atılmaz', () async {
      final server = _DeferredServer();
      final provider = _providerOn(server.api);
      final first = provider.load();
      await server.reach(1);
      server.reply(0, receivedApplicationsResponse(_rows('a', 1), last: false));
      await first;

      final more = provider.loadMore();
      await server.reach(2);
      unawaited(provider.loadMore());
      unawaited(provider.loadMore());
      await Future<void>.delayed(Duration.zero);
      expect(server.pending, hasLength(2));

      server.reply(1, receivedApplicationsResponse(_rows('b', 1), page: 1));
      await more;
      expect(provider.items, hasLength(2));
    });
  });

  group('süzgeç', () {
    test(
      'durum değişince eski satırlar hemen düşer, sunucuya adıyla gider',
      () async {
        final server = _DeferredServer();
        final provider = _providerOn(server.api);
        final initial = provider.load();
        await server.reach(1);
        server.reply(0, receivedApplicationsResponse(_rows('a', 2)));
        await initial;
        expect(provider.items, hasLength(2));

        final pending = provider.setStatus(ApplicationStatus.accepted);
        // Yeni çipin altında eski süzgecin satırları kalmıyor.
        expect(provider.items, isEmpty);
        expect(provider.isLoading, isTrue);
        await server.reach(2);
        expect(server.query(1), {'status': 'ACCEPTED', 'page': 0, 'size': 20});

        server.reply(
          1,
          receivedApplicationsResponse([
            receivedApplicationJson('c-0', status: 'ACCEPTED'),
          ]),
        );
        await pending;
        expect(provider.items.single.id, 'c-0');
        expect(provider.status, ApplicationStatus.accepted);
      },
    );

    test('aynı süzgeç yeniden seçilirse istek atılmaz', () async {
      final api = _scripted([
        receivedApplicationsResponse(_rows('a', 1)),
        receivedApplicationsResponse(_rows('b', 1)),
      ]);
      final provider = _providerOn(api);
      await provider.load();

      await provider.setStatus(null);
      await provider.setCompany(null);
      await provider.clearJob();
      await provider.clearFilters();

      expect(api.requests, hasLength(1));
    });

    test(
      'şirket, ilan ve durum birlikte gider; clearFilters hepsini kaldırır',
      () async {
        final api = _scripted([
          receivedApplicationsResponse(_rows('a', 1)),
          receivedApplicationsResponse(_rows('b', 1)),
          receivedApplicationsResponse(_rows('c', 1)),
          receivedApplicationsResponse(_rows('d', 1)),
        ]);
        final provider = _providerOn(api);

        await provider.setCompany('company-1');
        await provider.setJob('job-9', 'Garson');
        await provider.setStatus(ApplicationStatus.rejected);

        expect(api.requests.last.queryParameters, {
          'status': 'REJECTED',
          'jobId': 'job-9',
          'companyId': 'company-1',
          'page': 0,
          'size': 20,
        });
        expect(provider.isFiltered, isTrue);
        expect(provider.jobTitle, 'Garson');

        await provider.clearFilters();
        expect(api.requests.last.queryParameters, {'page': 0, 'size': 20});
        expect(provider.isFiltered, isFalse);
        expect(provider.jobTitle, isNull);
      },
    );

    test('ilan süzgeci kaldırılınca çip adı da gider', () async {
      final api = _scripted([
        receivedApplicationsResponse(_rows('a', 1)),
        receivedApplicationsResponse(_rows('b', 1)),
      ]);
      final provider = _providerOn(api);
      await provider.setJob('job-9', 'Garson');

      await provider.clearJob();

      expect(provider.jobId, isNull);
      expect(provider.jobTitle, isNull);
      expect(api.requests.last.queryParameters.containsKey('jobId'), isFalse);
    });
  });

  group('yarışlar', () {
    // Süzgeç değişirken eski sürüm yanıtı geç dönerse yeni listeyi ezmemeli:
    // ekran yeni çipi gösterip eski sonuçları çizerdi.
    test('eski süzgecin geç dönen yanıtı yeni listeyi ezmez', () async {
      final server = _DeferredServer();
      final provider = _providerOn(server.api);
      final first = provider.load();
      await server.reach(1);

      final second = provider.setStatus(ApplicationStatus.applied);
      await server.reach(2);

      server.reply(
        1,
        receivedApplicationsResponse([
          receivedApplicationJson('new-0', status: 'APPLIED'),
        ]),
      );
      await second;
      // Eski (süzgeçsiz) istek en son dönüyor.
      server.reply(0, receivedApplicationsResponse(_rows('old', 5)));
      await first;

      expect(provider.items.map((item) => item.id), ['new-0']);
      expect(provider.isLoading, isFalse);
    });

    test('eski yanıtın hatası da yeni listeyi bozmaz', () async {
      final server = _DeferredServer();
      final provider = _providerOn(server.api);
      final first = provider.load();
      await server.reach(1);
      final second = provider.setCompany('company-1');
      await server.reach(2);

      server.reply(1, receivedApplicationsResponse(_rows('new', 1)));
      await second;
      server.reply(0, receivedApplicationsFailure);
      await first;

      expect(provider.errorMessage, isNull);
      expect(provider.items, hasLength(1));
    });

    test(
      'süzgeç değişince uçuştaki sonraki sayfa atılır ve kilit kalmaz',
      () async {
        final server = _DeferredServer();
        final provider = _providerOn(server.api);
        final initial = provider.load();
        await server.reach(1);
        server.reply(
          0,
          receivedApplicationsResponse(_rows('a', 1), last: false),
        );
        await initial;

        final more = provider.loadMore();
        await server.reach(2);
        expect(provider.isLoadingMore, isTrue);

        final filtered = provider.setStatus(ApplicationStatus.rejected);
        expect(provider.isLoadingMore, isFalse);
        await server.reach(3);
        server.reply(2, receivedApplicationsResponse(_rows('r', 1)));
        await filtered;
        // Eski sayfa süzgeçten sonra dönüyor; yeni kümeye karışmamalı.
        server.reply(
          1,
          receivedApplicationsResponse(_rows('stale', 2), page: 1),
        );
        await more;

        expect(provider.items.map((item) => item.id), ['r-0']);
        expect(provider.isLoadingMore, isFalse);
      },
    );

    test('yenileme sürerken sonraki sayfa istenmez', () async {
      final server = _DeferredServer();
      final provider = _providerOn(server.api);
      final initial = provider.load();
      await server.reach(1);
      server.reply(0, receivedApplicationsResponse(_rows('a', 1), last: false));
      await initial;

      final refreshing = provider.refresh();
      await server.reach(2);
      await provider.loadMore();
      expect(server.pending, hasLength(2));

      server.reply(1, receivedApplicationsResponse(_rows('a', 1), last: false));
      await refreshing;
    });

    test('sayfa kapanırken dönen yanıt dinleyiciyi uyandırmaz', () async {
      final server = _DeferredServer();
      final provider = _providerOn(server.api);
      var notifications = 0;
      provider.addListener(() => notifications++);

      final loading = provider.load();
      await server.reach(1);
      final before = notifications;
      provider.dispose();
      server.reply(0, receivedApplicationsResponse(_rows('a', 1)));
      await loading;

      // Atılmış ChangeNotifier'a `notifyListeners` demek fırlatırdı; test bu
      // satıra hatasız geliyorsa yanıt atılmıştır.
      expect(notifications, before);
    });
  });

  group('refresh', () {
    test('satırlar yenisi gelene kadar yerinde kalır, sonra değişir', () async {
      final server = _DeferredServer();
      final provider = _providerOn(server.api);
      final initial = provider.load();
      await server.reach(1);
      server.reply(0, receivedApplicationsResponse(_rows('a', 2)));
      await initial;

      final refreshing = provider.refresh();
      await server.reach(2);
      expect(provider.items, hasLength(2));
      expect(provider.isLoading, isFalse);
      expect(provider.isRefreshing, isTrue);

      server.reply(1, receivedApplicationsResponse(_rows('b', 1)));
      expect(await refreshing, isTrue);
      expect(provider.items.map((item) => item.id), ['b-0']);
      expect(provider.isRefreshing, isFalse);
    });

    test('başarısız yenileme eski satırları korur ve false döner', () async {
      final api = _scripted([
        receivedApplicationsResponse(_rows('a', 2), last: false),
        receivedApplicationsFailure,
        receivedApplicationsResponse(_rows('b', 1), page: 1),
      ]);
      final provider = _providerOn(api);
      await provider.load();

      expect(await provider.refresh(), isFalse);
      expect(provider.items, hasLength(2));
      expect(provider.errorMessage, 'Başvurular alınamadı');

      // Eldeki satırların devamı hâlâ istenebilir.
      await provider.loadMore();
      expect(provider.items.map((item) => item.id), ['a-0', 'a-1', 'b-0']);
    });

    // Karar ekranından dönünce liste ilk sayfaya çökmesin: yüklü derinlik tek
    // istekle yeniden okunuyor, sonraki sayfa numarası boyutla tutarlı.
    test(
      'yüklü derinliği tek istekle yeniler, sayfalama oradan sürer',
      () async {
        final api = _scripted([
          receivedApplicationsResponse(_rows('a', 20), last: false),
          receivedApplicationsResponse(_rows('b', 20), page: 1, last: false),
          receivedApplicationsResponse(_rows('c', 20), page: 2, last: false),
          receivedApplicationsResponse(_rows('r', 60), size: 60, last: false),
          receivedApplicationsResponse(_rows('d', 20), page: 3),
        ]);
        final provider = _providerOn(api);
        await provider.load();
        await provider.loadMore();
        await provider.loadMore();
        expect(provider.items, hasLength(60));

        await provider.refresh();
        expect(api.requests[3].queryParameters, {'page': 0, 'size': 60});
        expect(provider.items, hasLength(60));

        await provider.loadMore();
        // 60 satır okundu → sıradaki sayfa 3 (60 / 20).
        expect(api.requests[4].queryParameters, {'page': 3, 'size': 20});
        expect(provider.items, hasLength(80));
      },
    );

    test(
      'yenileme derinliği sunucunun sayfa boyutu tavanıyla sınırlı',
      () async {
        final responses = <FakeApiResponse>[
          receivedApplicationsResponse(_rows('p0', 20), last: false),
          for (var page = 1; page < 7; page++)
            receivedApplicationsResponse(
              _rows('p$page', 20),
              page: page,
              last: false,
            ),
          receivedApplicationsResponse(_rows('r', 100), size: 100, last: false),
        ];
        final api = _scripted(responses);
        final provider = _providerOn(api);
        await provider.load();
        for (var i = 0; i < 6; i++) {
          await provider.loadMore();
        }
        expect(provider.items, hasLength(140));

        await provider.refresh();

        expect(api.requests.last.queryParameters, {'page': 0, 'size': 100});
        expect(provider.items, hasLength(100));
        expect(BApplicationInboxProvider.maxRefreshPages, 5);
      },
    );

    test('süzgeç değişince yenileme derinliği sıfırlanır', () async {
      final api = _scripted([
        receivedApplicationsResponse(_rows('a', 20), last: false),
        receivedApplicationsResponse(_rows('b', 20), page: 1, last: false),
        receivedApplicationsResponse(_rows('c', 3)),
        receivedApplicationsResponse(_rows('d', 3)),
      ]);
      final provider = _providerOn(api);
      await provider.load();
      await provider.loadMore();

      await provider.setStatus(ApplicationStatus.accepted);
      await provider.refresh();

      expect(api.requests.last.queryParameters, {
        'status': 'ACCEPTED',
        'page': 0,
        'size': 20,
      });
    });
  });
}
