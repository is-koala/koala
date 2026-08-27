import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('JobCategoryService.fetchCategories', () {
    test('kategoriler modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'cat-1',
                'code': 'PHOTOGRAPHY',
                'name': 'Fotoğrafçılık',
                'requiresInsurance': false,
              },
              {
                'id': 'cat-2',
                'code': 'WAITER',
                'name': 'Garsonluk',
                'requiresInsurance': true,
              },
            ],
          },
        ),
      );

      final categories = await JobCategoryService.withClient(
        api.client,
      ).fetchCategories();

      expect(api.requests.single.path, '/reference/job-categories');
      expect(categories, hasLength(2));
      expect(categories.first.displayName, 'Fotoğrafçılık');
      expect(categories.last.requiresInsurance, isTrue);
    });

    test('boş liste hata değil', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );

      final categories = await JobCategoryService.withClient(
        api.client,
      ).fetchCategories();

      expect(categories, isEmpty);
    });

    test('sunucu hatası ApiException olarak yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      );

      expect(
        () => JobCategoryService.withClient(api.client).fetchCategories(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
