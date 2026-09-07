import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/presentation/providers/job_search_provider.dart';
import 'package:koala/employee/features/home/services/job_service.dart';

import '../../../../../support/fake_api.dart';

Map<String, dynamic> _job(String id) => {
  'id': id,
  'title': 'Garson $id',
  'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
  'type': 'ONE_TIME',
  'salaryType': 'DAILY',
  'salary': 800,
  'status': 'OPEN',
};

Map<String, dynamic> _page({
  required List<String> ids,
  required int page,
  required bool last,
}) => {
  'success': true,
  'data': {
    'content': [for (final id in ids) _job(id)],
    'page': page,
    'size': 20,
    'totalElements': ids.length,
    'totalPages': last ? page + 1 : page + 2,
    'first': page == 0,
    'last': last,
  },
};

/// Sayfa numarasına göre yanıt veren sahte sunucu.
FakeApi _pagedApi(Map<int, Map<String, dynamic>> pages) {
  return FakeApi(
    handler: (RequestOptions options) {
      final requested = options.queryParameters['page'] as int? ?? 0;
      final body = pages[requested];
      if (body == null) {
        return const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Beklenmeyen sayfa'},
        );
      }
      return FakeApiResponse(statusCode: 200, body: body);
    },
  );
}

JobSearchProvider _providerFor(FakeApi api) {
  return JobSearchProvider(service: JobService.withClient(api.client));
}

void main() {
  group('JobSearchProvider.load', () {
    test('ilk sayfa listeye yazılıyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a', 'b'], page: 0, last: false),
      });
      final provider = _providerFor(api);

      await provider.load();

      expect(provider.jobs.map((job) => job.id), ['a', 'b']);
      expect(provider.isLoading, isFalse);
      expect(provider.hasMore, isTrue);
      expect(provider.errorMessage, isNull);
    });

    test('yeniden yükleme listeyi baştan kuruyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a'], page: 0, last: true),
      });
      final provider = _providerFor(api);

      await provider.load();
      await provider.load();

      expect(provider.jobs.map((job) => job.id), ['a']);
    });

    test('hata mesajı doluyor, liste boş kalıyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      );
      final provider = _providerFor(api);

      await provider.load();

      expect(provider.errorMessage, 'Sunucu hatası');
      expect(provider.jobs, isEmpty);
      expect(provider.isLoading, isFalse);
    });
  });

  group('JobSearchProvider.loadMore', () {
    test('ikinci sayfa listeye ekleniyor, silmiyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a', 'b'], page: 0, last: false),
        1: _page(ids: ['c', 'd'], page: 1, last: true),
      });
      final provider = _providerFor(api);

      await provider.load();
      await provider.loadMore();

      expect(provider.jobs.map((job) => job.id), ['a', 'b', 'c', 'd']);
      expect(provider.hasMore, isFalse);
    });

    test('last: true gelince istek atmıyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a'], page: 0, last: true),
      });
      final provider = _providerFor(api);

      await provider.load();
      final requestsAfterLoad = api.requests.length;

      await provider.loadMore();

      expect(api.requests.length, requestsAfterLoad);
    });

    test('yükleme sürerken ikinci loadMore istek atmıyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a'], page: 0, last: false),
        1: _page(ids: ['b'], page: 1, last: true),
      });
      final provider = _providerFor(api);

      await provider.load();
      final requestsAfterLoad = api.requests.length;

      await Future.wait<void>([provider.loadMore(), provider.loadMore()]);

      expect(api.requests.length, requestsAfterLoad + 1);
    });

    test('hata eldeki listeyi koruyor ve mesaj doluyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a', 'b'], page: 0, last: false),
      });
      final provider = _providerFor(api);

      await provider.load();
      await provider.loadMore();

      expect(provider.jobs.map((job) => job.id), ['a', 'b']);
      expect(provider.errorMessage, isNotNull);
      expect(provider.isLoadingMore, isFalse);
    });

    test(
      'sayfa kayması yüzünden tekrar gelen ilan iki kez çizilmiyor',
      () async {
        final api = _pagedApi({
          0: _page(ids: ['a', 'b'], page: 0, last: false),
          1: _page(ids: ['b', 'c'], page: 1, last: true),
        });
        final provider = _providerFor(api);

        await provider.load();
        await provider.loadMore();

        expect(provider.jobs.map((job) => job.id), ['a', 'b', 'c']);
      },
    );

    test('sonraki sayfa sunucudan gelen sayfa numarasını izliyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a'], page: 0, last: false),
        1: _page(ids: ['b'], page: 1, last: false),
        2: _page(ids: ['c'], page: 2, last: true),
      });
      final provider = _providerFor(api);

      await provider.load();
      await provider.loadMore();
      await provider.loadMore();

      expect(api.requests.map((request) => request.queryParameters['page']), [
        0,
        1,
        2,
      ]);
    });
  });

  group('JobSearchProvider.applyQuery', () {
    test('süzgeç sunucuya gidiyor ve liste baştan kuruluyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a'], page: 0, last: true),
      });
      final provider = _providerFor(api);

      await provider.load();
      await provider.applyQuery(
        const JobSearchQuery(query: 'garson', categoryId: 'cat-1'),
      );

      expect(provider.query.query, 'garson');
      expect(api.requests.last.queryParameters['query'], 'garson');
      expect(api.requests.last.queryParameters['categoryId'], 'cat-1');
      expect(api.requests.last.queryParameters['page'], 0);
      expect(provider.jobs.map((job) => job.id), ['a']);
    });

    test('aynı sorgu tekrar uygulanınca istek atılmıyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a'], page: 0, last: true),
      });
      final provider = _providerFor(api);

      await provider.applyQuery(const JobSearchQuery(query: 'garson'));
      final requestCount = api.requests.length;

      await provider.applyQuery(const JobSearchQuery(query: 'garson'));

      expect(api.requests.length, requestCount);
    });

    test('yeni süzgeç sonraki sayfada da taşınıyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a'], page: 0, last: false),
        1: _page(ids: ['b'], page: 1, last: true),
      });
      final provider = _providerFor(api);

      await provider.applyQuery(const JobSearchQuery(categoryId: 'cat-1'));
      await provider.loadMore();

      expect(api.requests.last.queryParameters['categoryId'], 'cat-1');
      expect(api.requests.last.queryParameters['page'], 1);
    });

    test('süzgeç değişince eski sayfa numarası sıfırlanıyor', () async {
      final api = _pagedApi({
        0: _page(ids: ['a'], page: 0, last: false),
        1: _page(ids: ['b'], page: 1, last: false),
      });
      final provider = _providerFor(api);

      await provider.load();
      await provider.loadMore();
      await provider.applyQuery(const JobSearchQuery(categoryId: 'cat-1'));

      expect(api.requests.last.queryParameters['page'], 0);
      expect(provider.jobs.map((job) => job.id), ['a']);
    });
  });

  // Haritada jeton baştan vardı, listede yoktu: uçan bir istek varken gelen
  // süzgeç `_query`'ye yazılıyor ama istek sessizce düşüyordu.
  group('JobSearchProvider yarış jetonu', () {
    test('uçan istek varken yeni süzgeç sessizce düşmüyor', () async {
      final first = Completer<FakeApiResponse>();
      var call = 0;

      final api = FakeApi(
        handler: (_) {
          call++;
          if (call == 1) return first.future;
          return FakeApiResponse(
            statusCode: 200,
            body: _page(ids: ['yeni'], page: 0, last: true),
          );
        },
      );
      final provider = _providerFor(api);

      // İlk yükleme uçuşta kalıyor; kullanıcı bu sırada süzgeci değiştiriyor.
      final pending = provider.load();
      await api.requestsReach(1);

      await provider.applyQuery(const JobSearchQuery(categoryId: 'cat-1'));

      // Yeni ölçüt gerçekten yola çıktı.
      expect(api.requests, hasLength(2));
      expect(api.requests.last.queryParameters['categoryId'], 'cat-1');
      expect(provider.jobs.map((job) => job.id), ['yeni']);

      // Geç dönen ilk yanıt yeni sonucun üstüne yazamıyor.
      first.complete(
        FakeApiResponse(
          statusCode: 200,
          body: _page(ids: ['eski'], page: 0, last: true),
        ),
      );
      await pending;

      expect(provider.jobs.map((job) => job.id), ['yeni']);
      expect(provider.query.categoryId, 'cat-1');
    });

    test('geç dönen eski hata yeni sonucu bozmuyor', () async {
      final first = Completer<FakeApiResponse>();
      var call = 0;

      final api = FakeApi(
        handler: (_) {
          call++;
          if (call == 1) return first.future;
          return FakeApiResponse(
            statusCode: 200,
            body: _page(ids: ['yeni'], page: 0, last: true),
          );
        },
      );
      final provider = _providerFor(api);

      final pending = provider.load();
      await api.requestsReach(1);
      await provider.applyQuery(const JobSearchQuery(categoryId: 'cat-1'));

      first.complete(
        const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      );
      await pending;

      // Eski istek patladı diye yeni sonucun üstüne hata şeridi düşmüyor.
      expect(provider.errorMessage, isNull);
      expect(provider.jobs.map((job) => job.id), ['yeni']);
      expect(provider.isLoading, isFalse);
    });

    test('uçan sayfa yeni süzgecin sonucuna karışmıyor', () async {
      final second = Completer<FakeApiResponse>();
      var call = 0;

      final api = FakeApi(
        handler: (RequestOptions options) {
          call++;
          if (call == 1) {
            return FakeApiResponse(
              statusCode: 200,
              body: _page(ids: ['a'], page: 0, last: false),
            );
          }
          // 2. çağrı: loadMore. 3. çağrı: yeni süzgecin ilk sayfası.
          if (call == 2) return second.future;
          return FakeApiResponse(
            statusCode: 200,
            body: _page(ids: ['c'], page: 0, last: true),
          );
        },
      );
      final provider = _providerFor(api);

      await provider.load();
      final more = provider.loadMore();
      await api.requestsReach(2);

      await provider.applyQuery(const JobSearchQuery(categoryId: 'cat-1'));

      second.complete(
        FakeApiResponse(
          statusCode: 200,
          body: _page(ids: ['b'], page: 1, last: true),
        ),
      );
      await more;

      // 'b' eski ölçütün ikinci sayfasıydı; yeni listeye eklenmemeli.
      expect(provider.jobs.map((job) => job.id), ['c']);
    });
  });
}
