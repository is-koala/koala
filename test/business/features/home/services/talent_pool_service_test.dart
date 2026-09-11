import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/services/talent_pool_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

const _worker = {
  'id': 'worker-1',
  'firstName': 'Ayşe',
  'lastName': 'Yılmaz',
  'username': 'ayse',
  'profilePictureUrl': 'https://cdn.example/ayse.jpg',
};

const _entry = {
  'id': 'entry-1',
  'worker': _worker,
  'companyId': null,
  'note': 'Geçen hafta çok iyiydi',
  'createdAt': '2026-09-10T08:00:00Z',
};

Map<String, dynamic> poolPage({
  List<Map<String, dynamic>> content = const [_entry],
  int page = 0,
  int size = 20,
  int totalElements = 1,
  int totalPages = 1,
  bool first = true,
  bool last = true,
}) {
  return {
    'content': content,
    'page': page,
    'size': size,
    'totalElements': totalElements,
    'totalPages': totalPages,
    'first': first,
    'last': last,
  };
}

void main() {
  group('TalentPoolService.fetchTalentPool', () {
    test('sayfalı yanıt modele çevriliyor', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': poolPage()},
        ),
      );

      final result = await TalentPoolService.withClient(
        api.client,
      ).fetchTalentPool(page: 0, size: 20);

      final request = api.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/users/me/talent-pool');
      expect(request.queryParameters, {'page': 0, 'size': 20});
      expect(result.entries, hasLength(1));
      expect(result.entries.single.worker.firstName, 'Ayşe');
      expect(result.entries.single.note, 'Geçen hafta çok iyiydi');
      expect(result.page, 0);
      expect(result.size, 20);
      expect(result.totalElements, 1);
      expect(result.last, isTrue);
    });

    test('ikinci sayfa sayfa ve boyut parametrelerini taşır', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': poolPage(page: 1, first: false, last: true),
          },
        ),
      );

      await TalentPoolService.withClient(
        api.client,
      ).fetchTalentPool(page: 1, size: 20);

      expect(api.requests.single.queryParameters, {'page': 1, 'size': 20});
    });

    test('boş havuz hata değil', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': poolPage(content: const [], totalElements: 0),
          },
        ),
      );

      final result = await TalentPoolService.withClient(
        api.client,
      ).fetchTalentPool();

      expect(result.entries, isEmpty);
      expect(result.totalElements, 0);
    });
  });

  group('TalentPoolService.addWorker', () {
    test('PUT upsert notu gövdede taşır, companyId göndermez', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _entry},
        ),
      );

      final saved = await TalentPoolService.withClient(
        api.client,
      ).addWorker('worker-1', note: 'Geçen hafta çok iyiydi');

      final request = api.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/users/me/talent-pool/worker-1');
      expect(request.data, {'note': 'Geçen hafta çok iyiydi'});
      expect((request.data as Map).containsKey('companyId'), isFalse);
      expect(saved.id, 'entry-1');
      expect(saved.worker.fullName, 'Ayşe Yılmaz');
    });

    test('1000 karakteri aşan not kesilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _entry},
        ),
      );

      await TalentPoolService.withClient(
        api.client,
      ).addWorker('worker-1', note: 'a' * 1001);

      expect((api.requests.single.data as Map)['note'], 'a' * 1000);
    });

    test('kendini eklemek TALENT_CANNOT_ADD_SELF kodunu taşır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Cannot add self',
            'errorCode': 'TALENT_CANNOT_ADD_SELF',
            'errorCategory': 'BUSINESS_RULE_VIOLATION',
          },
        ),
      );

      expect(
        () => TalentPoolService.withClient(api.client).addWorker('me'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.errorCode,
            'errorCode',
            'TALENT_CANNOT_ADD_SELF',
          ),
        ),
      );
    });
  });

  group('TalentPoolService.removeWorker', () {
    test('DELETE yolu işçi kimliğini taşır', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await TalentPoolService.withClient(api.client).removeWorker('worker-1');

      final request = api.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/users/me/talent-pool/worker-1');
    });
  });
}
