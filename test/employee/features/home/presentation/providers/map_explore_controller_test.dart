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

MapExploreController _controller(
  FakeApi api, {
  Duration debounce = Duration.zero,
}) {
  return MapExploreController(
    service: JobService.withClient(api.client),
    debounce: debounce,
  );
}

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
}
