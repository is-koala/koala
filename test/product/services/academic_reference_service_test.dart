import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/academic_reference_service.dart';

import '../../support/fake_api.dart';

FakeApiResponse _list(String name) {
  return FakeApiResponse(
    statusCode: 200,
    body: {
      'success': true,
      'data': [
        {'id': 'ref_1', 'name': name},
      ],
    },
  );
}

void main() {
  group('AcademicReferenceService', () {
    test('üniversite, fakülte ve bölüm yolları', () async {
      final api = FakeApi(handler: (_) => _list('Boğaziçi Üniversitesi'));
      final service = AcademicReferenceService.withClient(api.client);

      await service.fetchUniversities();
      await service.fetchFaculties('uni_1');
      await service.fetchDepartments('fac_1');

      expect(api.requests.map((request) => request.path).toList(), [
        '/reference/universities',
        '/reference/universities/uni_1/faculties',
        '/reference/faculties/fac_1/departments',
      ]);
    });

    // Listeler oturum boyunca değişmiyor; her seçici açılışında istek
    // atmak boşuna.
    test('ikinci çağrı önbellekten gelir', () async {
      final api = FakeApi(handler: (_) => _list('Boğaziçi Üniversitesi'));
      final service = AcademicReferenceService.withClient(api.client);

      await service.fetchUniversities();
      await service.fetchUniversities();

      expect(api.requests, hasLength(1));
    });

    // Fakülte listesi üniversiteye bağlı; ikinci üniversite kendi isteğini
    // atmalı, birincinin önbelleğini okumamalı.
    test('fakülteler üniversite başına önbelleklenir', () async {
      final api = FakeApi(handler: (_) => _list('Mühendislik Fakültesi'));
      final service = AcademicReferenceService.withClient(api.client);

      await service.fetchFaculties('uni_1');
      await service.fetchFaculties('uni_2');
      await service.fetchFaculties('uni_1');

      expect(api.requests, hasLength(2));
    });

    test('boş liste hata değil', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );

      expect(
        await AcademicReferenceService.withClient(
          api.client,
        ).fetchUniversities(),
        isEmpty,
      );
    });
  });
}
