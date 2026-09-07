import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
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

/// Debounce zamanlayıcısı ve ağ çağrısı bitene kadar olay kuyruğunu boşaltır.
Future<void> settle([Duration wait = Duration.zero]) async {
  if (wait > Duration.zero) await Future<void>.delayed(wait);
  await pumpEventQueue(times: 50);
}

void main() {
  test('görünen alan dört sınırlayıcı kutu parametresiyle gidiyor', () async {
    final api = _api();
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle();

    final query = api.requests.single.queryParameters;
    expect(query['minLatitude'], 39.0);
    expect(query['maxLatitude'], 41.0);
    expect(query['minLongitude'], 32.0);
    expect(query['maxLongitude'], 34.0);
    controller.dispose();
  });

  test('harita sayfa boyutu sunucunun üst sınırına çıkıyor', () async {
    final api = _api();
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle();

    expect(api.requests.single.queryParameters['size'], 100);
    expect(MapExploreController.mapPageSize, 100);
    controller.dispose();
  });

  test('art arda gelen kamera olayları tek istek üretiyor', () async {
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
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    await settle(const Duration(milliseconds: 120));

    expect(api.requests.length, 1);
    controller.dispose();
  });

  test('kırpılmamış sonuçtan sonra içeriye yaklaşmak istek atmıyor', () async {
    final api = _api(last: true);
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle();
    expect(api.requests.length, 1);

    controller.onCameraIdle(_inside);
    await settle();

    expect(api.requests.length, 1);
    controller.dispose();
  });

  test('kırpılmış sonuçtan sonra içeriye yaklaşmak istek atıyor', () async {
    final api = _api(last: false);
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle();

    controller.onCameraIdle(_inside);
    await settle();

    expect(api.requests.length, 2);
    controller.dispose();
  });

  test('dışarı kayan görünen alan istek atıyor', () async {
    final api = _api();
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle();

    controller.onCameraIdle(_elsewhere);
    await settle();

    expect(api.requests.length, 2);
    controller.dispose();
  });

  test('kırpılma bayrağı `last: false` ile açılıyor', () async {
    final api = _api(last: false);
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle();

    expect(controller.isTruncated, isTrue);
    controller.dispose();
  });

  test('kırpılmayan sonuçta bayrak kapalı', () async {
    final api = _api(last: true);
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle();

    expect(controller.isTruncated, isFalse);
    controller.dispose();
  });

  test('geç dönen eski yanıt yeni sonucun üzerine yazmıyor', () async {
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
    await settle();
    controller.onCameraIdle(_elsewhere);
    await settle();
    expect(call, 2);

    // İkinci yanıt önce dönüyor, birincisi sonra: eski yanıt kazanmamalı.
    second.complete(
      FakeApiResponse(statusCode: 200, body: _body(['yeni'], last: true)),
    );
    await settle();
    first.complete(
      FakeApiResponse(statusCode: 200, body: _body(['eski'], last: true)),
    );
    await settle();

    expect(controller.jobs.map((job) => job.id), ['yeni']);
    controller.dispose();
  });

  test('arama metni mevcut kutuyla birlikte sunucuya gidiyor', () async {
    final api = _api();
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle();

    controller.setSearchText('garson');
    await settle();

    final query = api.requests.last.queryParameters;
    expect(query['query'], 'garson');
    expect(query['minLatitude'], 39.0);
    controller.dispose();
  });

  test('aynı arama metni yeniden istek doğurmuyor', () async {
    final api = _api();
    final controller = _controller(api);

    controller.onCameraIdle(_wide);
    await settle();
    controller.setSearchText('garson');
    await settle();
    final count = api.requests.length;

    controller.setSearchText('garson');
    await settle();

    expect(api.requests.length, count);
    controller.dispose();
  });

  test('hata mesajı doluyor, eldeki pinler silinmiyor', () async {
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
    await settle();
    controller.onCameraIdle(_elsewhere);
    await settle();

    expect(controller.errorMessage, 'Sunucu hatası');
    expect(controller.jobs.map((job) => job.id), ['a']);
    expect(controller.isLoading, isFalse);
    controller.dispose();
  });

  test('dispose sonrası bekleyen zamanlayıcı istek atmıyor', () async {
    final api = _api();
    final controller = _controller(
      api,
      debounce: const Duration(milliseconds: 60),
    );

    controller.onCameraIdle(_wide);
    controller.dispose();
    await settle(const Duration(milliseconds: 120));

    expect(api.requests, isEmpty);
  });
}
