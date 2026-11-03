import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/presentation/providers/map_explore_controller.dart';
import 'package:koala/employee/features/home/services/job_service.dart';

import '../../../../../support/fake_api.dart';

const _wide = JobMapBounds(
  minLatitude: 39.0,
  maxLatitude: 41.0,
  minLongitude: 32.0,
  maxLongitude: 34.0,
);

const _inside = JobMapBounds(
  minLatitude: 39.5,
  maxLatitude: 40.5,
  minLongitude: 32.5,
  maxLongitude: 33.5,
);

const _elsewhere = JobMapBounds(
  minLatitude: 36.0,
  maxLatitude: 37.0,
  minLongitude: 27.0,
  maxLongitude: 28.0,
);

Map<String, dynamic> _job(String id) => {
  'id': id,
  'title': 'İlan $id',
  'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
  'type': 'ONE_TIME',
  'salaryType': 'DAILY',
  'salary': 800,
  'status': 'OPEN',
  'latitude': 39.9,
  'longitude': 32.8,
};

Map<String, dynamic> _body(List<String> ids, {required bool last}) => {
  'success': true,
  'data': {
    'content': [for (final id in ids) _job(id)],
    'page': 0,
    'size': 100,
    'totalElements': ids.length,
    'totalPages': 1,
    'first': true,
    'last': last,
  },
};

FakeApi _api({List<String> ids = const ['a'], bool last = true}) {
  return FakeApi(
    handler: (_) =>
        FakeApiResponse(statusCode: 200, body: _body(ids, last: last)),
  );
}

/// Varsayılan olarak **paysız** controller: eski testler kutunun sunucuya
/// birebir gittiğini ölçüyor. Pay davranışı kendi grubunda, üretimdeki
/// varsayılanla sınanıyor.
MapExploreController _controller(
  FakeApi api, {
  Duration debounce = Duration.zero,
  double fetchMargin = 0,
  Duration refreshIndicatorDelay = const Duration(milliseconds: 400),
}) {
  return MapExploreController(
    service: JobService.withClient(api.client),
    debounce: debounce,
    fetchMargin: fetchMargin,
    refreshIndicatorDelay: refreshIndicatorDelay,
  );
}

Map<String, double> _sentBox(RequestOptions request) => {
  for (final key in [
    'minLatitude',
    'maxLatitude',
    'minLongitude',
    'maxLongitude',
  ])
    key: (request.queryParameters[key] as num).toDouble(),
};

/// Debounce zamanlayıcısını **sahte saatte** ilerletir ve yanıtın controller'a
/// dönmesi için mikro-görev turlarını boşaltır.
///
/// Eskiden burada gerçek `Future.delayed` vardı: 60 ms'lik debounce'a 120 ms
/// pay biçiliyordu. Pay bir eşitleme noktası değil, tahmin — yüklü bir makinede
/// sessizce yetmiyor ve üretim kodu doğruyken test kırmızıya dönüyor
/// (is-koala/koala#88). `tester.pump(Duration)` zamanlayıcıyı duvar saatinden
/// bağımsız ilerletiyor; liste tarafındaki testler baştan bunu yapıyordu.
Future<void> settle(
  WidgetTester tester, [
  Duration wait = Duration.zero,
]) async {
  await tester.pump(wait);
  await tester.pump();
}

void main() {
  testWidgets('görünen alan dört sınırlayıcı kutu parametresiyle gidiyor', (
    tester,
  ) async {
    final api = _api();
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);

    final query = api.requests.single.queryParameters;
    expect(query['minLatitude'], 39.0);
    expect(query['maxLatitude'], 41.0);
    expect(query['minLongitude'], 32.0);
    expect(query['maxLongitude'], 34.0);
    controller.dispose();
  });

  testWidgets('konum ve yakınlık sıralaması lat/lng + sort=distance gider', (
    tester,
  ) async {
    final api = _api();
    final controller = _controller(api);

    controller.setOrigin(latitude: 41.008238123, longitude: 28.978359456);
    controller.setSort(JobSortOption.nearest);
    controller.onCameraIdle(_wide);
    await settle(tester);

    final query = api.requests.single.queryParameters;
    expect(query['lat'], 41.008238);
    expect(query['lng'], 28.978359);
    expect(query['sort'], 'distance,asc');
    controller.dispose();
  });

  testWidgets('tarih penceresi startFrom/startTo olarak gider', (tester) async {
    final api = _api();
    final controller = _controller(api);

    controller.setStartWindow(
      startFrom: DateTime.parse('2026-09-14T21:00:00.000Z'),
      startTo: DateTime.parse('2026-09-15T20:59:59.999Z'),
    );
    controller.onCameraIdle(_wide);
    await settle(tester);

    final query = api.requests.single.queryParameters;
    expect(query['startFrom'], '2026-09-14T21:00:00.000Z');
    expect(query['startTo'], '2026-09-15T20:59:59.999Z');
    controller.dispose();
  });

  testWidgets('harita sayfa boyutu sunucunun üst sınırına çıkıyor', (
    tester,
  ) async {
    final api = _api();
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);

    expect(api.requests.single.queryParameters['size'], 100);
    controller.dispose();
  });

  testWidgets('art arda gelen kamera olayları tek istek üretiyor', (
    tester,
  ) async {
    final api = _api();
    final controller = _controller(
      api,
      debounce: const Duration(milliseconds: 60),
    );

    for (var i = 0; i < 5; i++) {
      controller.onCameraIdle(
        JobMapBounds(
          minLatitude: 39.0 - i,
          maxLatitude: 41.0 + i,
          minLongitude: 32.0 - i,
          maxLongitude: 34.0 + i,
        ),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }

    await settle(tester, const Duration(milliseconds: 120));

    expect(api.requests.length, 1);
    controller.dispose();
  });

  testWidgets('kırpılmamış sonuçtan sonra içeriye yaklaşmak istek atmıyor', (
    tester,
  ) async {
    final api = _api(last: true);
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);
    expect(api.requests.length, 1);

    controller.onCameraIdle(_inside);
    await settle(tester);

    expect(api.requests.length, 1);
    controller.dispose();
  });

  testWidgets('kırpılmış sonuçtan sonra içeriye yaklaşmak istek atıyor', (
    tester,
  ) async {
    final api = _api(last: false);
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);

    controller.onCameraIdle(_inside);
    await settle(tester);

    expect(api.requests.length, 2);
    controller.dispose();
  });

  testWidgets('dışarı kayan görünen alan istek atıyor', (tester) async {
    final api = _api();
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);

    controller.onCameraIdle(_elsewhere);
    await settle(tester);

    expect(api.requests.length, 2);
    controller.dispose();
  });

  testWidgets('kırpılma bayrağı `last: false` ile açılıyor', (tester) async {
    final api = _api(last: false);
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);

    expect(controller.isTruncated, isTrue);
    controller.dispose();
  });

  testWidgets('kırpılmayan sonuçta bayrak kapalı', (tester) async {
    final api = _api(last: true);
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);

    expect(controller.isTruncated, isFalse);
    controller.dispose();
  });

  testWidgets('geç dönen eski yanıt yeni sonucun üzerine yazmıyor', (
    tester,
  ) async {
    final first = Completer<FakeApiResponse>();
    final second = Completer<FakeApiResponse>();
    var call = 0;

    final api = FakeApi(
      handler: (RequestOptions options) {
        call++;
        return call == 1 ? first.future : second.future;
      },
    );
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);
    controller.onCameraIdle(_elsewhere);
    await settle(tester);
    expect(call, 2);

    // İkinci yanıt önce dönüyor, birincisi sonra: eski yanıt kazanmamalı.
    second.complete(
      FakeApiResponse(statusCode: 200, body: _body(['yeni'], last: true)),
    );
    await settle(tester);
    first.complete(
      FakeApiResponse(statusCode: 200, body: _body(['eski'], last: true)),
    );
    await settle(tester);

    expect(controller.jobs.map((job) => job.id), ['yeni']);
    controller.dispose();
  });

  testWidgets('arama metni mevcut kutuyla birlikte sunucuya gidiyor', (
    tester,
  ) async {
    final api = _api();
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);

    controller.setSearchText('garson');
    await settle(tester);

    final query = api.requests.last.queryParameters;
    expect(query['query'], 'garson');
    expect(query['minLatitude'], 39.0);
    controller.dispose();
  });

  testWidgets('aynı arama metni yeniden istek doğurmuyor', (tester) async {
    final api = _api();
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);
    controller.setSearchText('garson');
    await settle(tester);
    final count = api.requests.length;

    controller.setSearchText('garson');
    await settle(tester);

    expect(api.requests.length, count);
    controller.dispose();
  });

  testWidgets('hata mesajı doluyor, eldeki pinler silinmiyor', (tester) async {
    var call = 0;
    final api = FakeApi(
      handler: (_) {
        call++;
        if (call == 1) {
          return FakeApiResponse(
            statusCode: 200,
            body: _body(['a'], last: true),
          );
        }
        return const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        );
      },
    );
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle(tester);
    controller.onCameraIdle(_elsewhere);
    await settle(tester);

    expect(controller.errorMessage, 'Sunucu hatası');
    expect(controller.jobs.map((job) => job.id), ['a']);
    expect(controller.isLoading, isFalse);
    controller.dispose();
  });

  testWidgets('dispose sonrası bekleyen zamanlayıcı istek atmıyor', (
    tester,
  ) async {
    final api = _api();
    final controller = _controller(
      api,
      debounce: const Duration(milliseconds: 60),
    );

    controller.onCameraIdle(_wide);
    controller.dispose();
    await settle(tester, const Duration(milliseconds: 120));

    expect(api.requests, isEmpty);
  });

  group('pay', () {
    testWidgets('varsayılan pay görünen alanı her yöne yarım kutu genişletir', (
      tester,
    ) async {
      final api = _api();
      final controller = _controller(
        api,
        fetchMargin: MapExploreController.defaultFetchMargin,
      );

      controller.onCameraIdle(_wide);
      await settle(tester);

      expect(_sentBox(api.requests.single), {
        'minLatitude': 38.0,
        'maxLatitude': 42.0,
        'minLongitude': 31.0,
        'maxLongitude': 35.0,
      });
      controller.dispose();
    });

    testWidgets('pay içinde kalan kaydırma istek atmıyor', (tester) async {
      final api = _api();
      final controller = _controller(
        api,
        fetchMargin: MapExploreController.defaultFetchMargin,
      );

      controller.onCameraIdle(_wide);
      await settle(tester);

      // Çeyrek kutu sağa-yukarı: görünen alan eski kutudan taşıyor ama
      // yüklenen geniş kutunun içinde.
      controller.onCameraIdle(
        const JobMapBounds(
          minLatitude: 39.5,
          maxLatitude: 41.5,
          minLongitude: 32.5,
          maxLongitude: 34.5,
        ),
      );
      await settle(tester);

      expect(api.requests, hasLength(1));
      controller.dispose();
    });

    testWidgets('paydan taşan kaydırma yeni istek atar', (tester) async {
      final api = _api();
      final controller = _controller(
        api,
        fetchMargin: MapExploreController.defaultFetchMargin,
      );

      controller.onCameraIdle(_wide);
      await settle(tester);
      controller.onCameraIdle(_elsewhere);
      await settle(tester);

      expect(api.requests, hasLength(2));
      controller.dispose();
    });

    testWidgets('geniş kutu kırpılırsa yalnız görünen alan yeniden sorulur', (
      tester,
    ) async {
      var call = 0;
      final api = FakeApi(
        handler: (_) {
          call++;
          // Geniş kutu 100'ü aşıyor, görünen alan aşmıyor.
          return FakeApiResponse(
            statusCode: 200,
            body: _body([call == 1 ? 'uzak' : 'ekranda'], last: call != 1),
          );
        },
      );
      final controller = _controller(
        api,
        fetchMargin: MapExploreController.defaultFetchMargin,
      );

      controller.onCameraIdle(_wide);
      await settle(tester);
      await settle(tester);

      expect(api.requests, hasLength(2));
      expect(_sentBox(api.requests.last), {
        'minLatitude': 39.0,
        'maxLatitude': 41.0,
        'minLongitude': 32.0,
        'maxLongitude': 34.0,
      });
      expect(controller.jobs.map((job) => job.id), ['ekranda']);
      expect(controller.isTruncated, isFalse);
      controller.dispose();
    });

    testWidgets('180. meridyeni aşan kutu genişletilmez', (tester) async {
      final api = _api();
      final controller = _controller(
        api,
        fetchMargin: MapExploreController.defaultFetchMargin,
      );
      const wrapping = JobMapBounds(
        minLatitude: 10,
        maxLatitude: 20,
        minLongitude: 170,
        maxLongitude: -170,
      );

      controller.onCameraIdle(wrapping);
      await settle(tester);

      expect(_sentBox(api.requests.single), {
        'minLatitude': 10.0,
        'maxLatitude': 20.0,
        'minLongitude': 170.0,
        'maxLongitude': -170.0,
      });
      controller.dispose();
    });
  });

  group('yükleme durumları', () {
    testWidgets('ilk yükleme belirgin, yenileme değil', (tester) async {
      final response = Completer<FakeApiResponse>();
      final api = FakeApi(handler: (_) => response.future);
      final controller = _controller(api);

      controller.onCameraIdle(_wide);
      await settle(tester, const Duration(seconds: 1));

      expect(controller.isInitialLoading, isTrue);
      expect(controller.isRefreshing, isFalse);

      response.complete(
        FakeApiResponse(statusCode: 200, body: _body(['a'], last: true)),
      );
      await settle(tester);

      expect(controller.isInitialLoading, isFalse);
      expect(controller.isLoading, isFalse);
      controller.dispose();
    });

    testWidgets('hızlı yenileme göstergeyi hiç açmaz', (tester) async {
      final api = _api();
      final controller = _controller(api);
      final refreshing = <bool>[];
      controller.addListener(() => refreshing.add(controller.isRefreshing));

      controller.onCameraIdle(_wide);
      await settle(tester);
      controller.onCameraIdle(_elsewhere);
      await settle(tester);
      // Gecikme dolsa bile istek çoktan bittiği için gösterge açılmamalı.
      await settle(tester, const Duration(seconds: 1));

      expect(api.requests, hasLength(2));
      expect(refreshing, everyElement(isFalse));
      expect(controller.isInitialLoading, isFalse);
      controller.dispose();
    });

    testWidgets('yavaş yenileme gecikmeden sonra sessiz göstergeyi açar', (
      tester,
    ) async {
      final slow = Completer<FakeApiResponse>();
      var call = 0;
      final api = FakeApi(
        handler: (_) {
          call++;
          return call == 1
              ? FakeApiResponse(statusCode: 200, body: _body(['a'], last: true))
              : slow.future;
        },
      );
      final controller = _controller(api);

      controller.onCameraIdle(_wide);
      await settle(tester);
      controller.onCameraIdle(_elsewhere);
      await settle(tester, const Duration(milliseconds: 300));

      expect(controller.isLoading, isTrue);
      expect(controller.isInitialLoading, isFalse);
      expect(controller.isRefreshing, isFalse);

      await settle(tester, const Duration(milliseconds: 200));
      expect(controller.isRefreshing, isTrue);
      // Eldeki pinler yenileme boyunca duruyor.
      expect(controller.jobs.map((job) => job.id), ['a']);

      slow.complete(
        FakeApiResponse(statusCode: 200, body: _body(['b'], last: true)),
      );
      await settle(tester);

      expect(controller.isRefreshing, isFalse);
      expect(controller.jobs.map((job) => job.id), ['b']);
      controller.dispose();
    });
  });
}
