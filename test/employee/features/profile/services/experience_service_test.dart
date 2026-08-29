import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/experience.dart';
import 'package:koala/employee/features/profile/services/experience_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

FakeApi savedApi({int statusCode = 201}) {
  return FakeApi(
    handler: (_) => FakeApiResponse(
      statusCode: statusCode,
      body: const {
        'success': true,
        'data': {
          'id': 'exp_1',
          'title': 'Barista',
          'companyName': 'Kahve Durağı',
          'employmentType': 'PART_TIME',
          'startDate': '2024-06-01',
        },
      },
    ),
  );
}

void main() {
  group('ExperienceService.create', () {
    test('zorunlu alanlar doğru yola gider', () async {
      final api = savedApi();

      final experience = await ExperienceService.withClient(api.client).create(
        title: 'Barista',
        startDate: DateTime(2024, 6),
        companyName: 'Kahve Durağı',
        employmentType: EmploymentType.partTime,
      );

      final request = api.requests.single;
      expect(request.path, '/users/me/experiences');
      expect(request.method, 'POST');
      expect(experience.title, 'Barista');
    });

    // Sunucu `LocalDate` bekliyor; `toIso8601String` saat de yazıyor ve
    // çözümleyici onu reddediyor.
    test('tarih saatsiz yyyy-MM-dd olarak gider', () async {
      final api = savedApi();

      await ExperienceService.withClient(api.client).create(
        title: 'Barista',
        startDate: DateTime(2024, 6, 3, 14, 30),
        endDate: DateTime(2025, 1, 9),
      );

      final body = api.requests.single.data as Map<String, dynamic>;
      expect(body['startDate'], '2024-06-03');
      expect(body['endDate'], '2025-01-09');
    });

    // Boş metin göndermek alanı boş bir metne eşitlerdi; kastedilen "yok".
    test('boş metinler null olarak gider', () async {
      final api = savedApi();

      await ExperienceService.withClient(api.client).create(
        title: 'Barista',
        startDate: DateTime(2024, 6),
        companyName: '   ',
        cityName: '',
      );

      final body = api.requests.single.data as Map<String, dynamic>;
      expect(body['companyName'], isNull);
      expect(body['cityName'], isNull);
    });

    // Devam eden deneyimin bitişi yok.
    test('bitiş verilmezse null gider', () async {
      final api = savedApi();

      await ExperienceService.withClient(
        api.client,
      ).create(title: 'Barista', startDate: DateTime(2024, 6));

      final body = api.requests.single.data as Map<String, dynamic>;
      expect(body['endDate'], isNull);
    });

    test('tarih tutarsızsa 400 yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Bitiş tarihi başlangıçtan önce olamaz',
          },
        ),
      );

      await expectLater(
        ExperienceService.withClient(
          api.client,
        ).create(title: 'Barista', startDate: DateTime(2024, 6)),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ExperienceService.update / delete', () {
    // Uç PUT: kaydın tamamı gönderiliyor, kısmi güncelleme değil.
    test('güncelleme PUT ile kayıt yoluna gider', () async {
      final api = savedApi(statusCode: 200);

      await ExperienceService.withClient(api.client).update(
        experienceId: 'exp_1',
        title: 'Kıdemli Barista',
        startDate: DateTime(2024, 6),
      );

      final request = api.requests.single;
      expect(request.path, '/users/me/experiences/exp_1');
      expect(request.method, 'PUT');
      expect(
        (request.data as Map<String, dynamic>)['title'],
        'Kıdemli Barista',
      );
    });

    test('silme DELETE atıyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await ExperienceService.withClient(api.client).delete('exp_1');

      expect(api.requests.single.path, '/users/me/experiences/exp_1');
      expect(api.requests.single.method, 'DELETE');
    });

    test('başkasının kaydı 404 yükseltir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {'success': false, 'message': 'Kayıt bulunamadı'},
        ),
      );

      await expectLater(
        ExperienceService.withClient(api.client).delete('exp_9'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.notFound,
          ),
        ),
      );
    });
  });
}
