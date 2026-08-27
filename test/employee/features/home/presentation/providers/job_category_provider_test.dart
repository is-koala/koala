import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';

import '../../../../../support/fake_api.dart';

FakeApiResponse okWith(List<Map<String, dynamic>> categories) {
  return FakeApiResponse(
    statusCode: 200,
    body: {'success': true, 'data': categories},
  );
}

const _waiter = {'id': 'cat-2', 'code': 'WAITER', 'name': 'Garsonluk'};

JobCategoryProvider buildProvider(FakeApi api) {
  return JobCategoryProvider(
    service: JobCategoryService.withClient(api.client),
  );
}

void main() {
  group('JobCategoryProvider.load', () {
    test('başlangıçta liste boş ve yükleme yapılmamış', () {
      final api = FakeApi(handler: (_) => okWith(const []));
      final provider = buildProvider(api);

      expect(provider.categories, isEmpty);
      expect(provider.hasLoaded, isFalse);
      expect(provider.isEmpty, isFalse);
    });

    test('kategoriler dolar', () async {
      final api = FakeApi(handler: (_) => okWith(const [_waiter]));
      final provider = buildProvider(api);

      await provider.load();

      expect(provider.categories.single.code, 'WAITER');
      expect(provider.hasLoaded, isTrue);
      expect(provider.errorMessage, isNull);
    });

    test('ikinci çağrı ağa çıkmaz', () async {
      final api = FakeApi(handler: (_) => okWith(const [_waiter]));
      final provider = buildProvider(api);

      await provider.load();
      await provider.load();

      expect(api.requests, hasLength(1));
    });

    test('force ile yeniden çekilir', () async {
      final api = FakeApi(handler: (_) => okWith(const [_waiter]));
      final provider = buildProvider(api);

      await provider.load();
      await provider.load(force: true);

      expect(api.requests, hasLength(2));
    });

    test('boş liste hata değil ama isEmpty ile ayırt edilir', () async {
      final api = FakeApi(handler: (_) => okWith(const []));
      final provider = buildProvider(api);

      await provider.load();

      expect(provider.isEmpty, isTrue);
      expect(provider.errorMessage, isNull);
    });

    test('hata sonrası tekrar denenebilir', () async {
      var shouldFail = true;
      final api = FakeApi(
        handler: (_) => shouldFail
            ? const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'Sunucu hatası'},
              )
            : okWith(const [_waiter]),
      );
      final provider = buildProvider(api);

      await provider.load();
      expect(provider.errorMessage, 'Sunucu hatası');
      expect(provider.isEmpty, isFalse, reason: 'hata boşlukla karışmamalı');

      // Hatadan sonra force'suz çağrı da yeniden denemeli.
      shouldFail = false;
      await provider.load();

      expect(provider.categories, hasLength(1));
      expect(provider.errorMessage, isNull);
    });
  });

  group('JobCategoryProvider.byCode', () {
    test('kod eşleşirse kategori döner, eşleşmezse null', () async {
      final api = FakeApi(handler: (_) => okWith(const [_waiter]));
      final provider = buildProvider(api);
      await provider.load();

      expect(provider.byCode('WAITER')?.displayName, 'Garsonluk');
      expect(provider.byCode('PLUMBING'), isNull);
    });
  });
}
