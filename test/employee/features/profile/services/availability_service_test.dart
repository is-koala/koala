import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/profile/models/availability_slot.dart';
import 'package:koala/employee/features/profile/services/availability_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

const Map<String, dynamic> _availabilityData = {
  'slots': [
    {
      'id': 'slot_1',
      'dayOfWeek': 'MONDAY',
      'startTime': '09:00:00',
      'endTime': '17:00:00',
    },
  ],
  'exceptions': [
    {
      'id': 'exception_1',
      'date': '2026-09-12',
      'available': false,
      'note': 'Şehir dışında',
    },
  ],
};

void main() {
  test('kullanıcının müsaitliğini herkese açık uçtan getirir', () async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': _availabilityData},
      ),
    );

    final availability = await AvailabilityService.withClient(
      api.client,
    ).fetchForUser('user_1');

    expect(api.requests.single.method, 'GET');
    expect(api.requests.single.path, '/users/user_1/availability');
    expect(availability.slots.single.dayLabel, 'Pazartesi');
    expect(availability.exceptions.single.note, 'Şehir dışında');
  });

  group('haftalık şablonu değiştirme', () {
    test('bütün aralıkları tek PUT gövdesinde gönderir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _availabilityData},
        ),
      );

      await AvailabilityService.withClient(api.client).replaceSlots(const [
        AvailabilitySlot(
          id: 'yerel-kimlik-gönderilmez',
          dayOfWeek: 'MONDAY',
          startTime: '09:00',
          endTime: '17:00',
        ),
        AvailabilitySlot(
          dayOfWeek: 'TUESDAY',
          startTime: '10:00',
          endTime: '18:00',
        ),
      ]);

      final request = api.requests.single;
      final body = request.data as Map<String, dynamic>;
      final slots = body['slots'] as List<dynamic>;
      expect(request.method, 'PUT');
      expect(request.path, '/users/me/availability');
      expect(slots, hasLength(2));
      expect(slots.first, {
        'dayOfWeek': 'MONDAY',
        'startTime': '09:00',
        'endTime': '17:00',
      });
    });

    test(
      'bitişi başlangıçtan önce olan aralıkta sunucunun 400 hatasını taşır',
      () async {
        final api = FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 400,
            body: {
              'success': false,
              'message': 'Bitiş saati başlangıçtan sonra olmalıdır',
            },
          ),
        );

        await expectLater(
          AvailabilityService.withClient(api.client).replaceSlots(const [
            AvailabilitySlot(
              dayOfWeek: 'MONDAY',
              startTime: '17:00',
              endTime: '09:00',
            ),
          ]),
          throwsA(
            isA<ApiException>().having(
              (error) => error.type,
              'type',
              ApiErrorType.validation,
            ),
          ),
        );
      },
    );

    test('çakışan aralıkta sunucunun 409 hatasını taşır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {'success': false, 'message': 'Müsaitlik aralıkları çakışıyor'},
        ),
      );

      await expectLater(
        AvailabilityService.withClient(api.client).replaceSlots(const [
          AvailabilitySlot(
            dayOfWeek: 'MONDAY',
            startTime: '09:00',
            endTime: '12:00',
          ),
          AvailabilitySlot(
            dayOfWeek: 'MONDAY',
            startTime: '11:00',
            endTime: '13:00',
          ),
        ]),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.conflict,
          ),
        ),
      );
    });
  });

  group('tarih istisnaları', () {
    test('istisnayı LocalDate gövdesiyle kaydeder', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'exception_2',
              'date': '2026-09-14',
              'available': true,
              'note': null,
            },
          },
        ),
      );

      final exception = await AvailabilityService.withClient(api.client)
          .saveException(
            date: DateTime(2026, 9, 14, 18),
            available: true,
            note: '   ',
          );

      final request = api.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/users/me/availability/exceptions');
      expect(request.data, {
        'date': '2026-09-14',
        'available': true,
        'note': null,
      });
      expect(exception.id, 'exception_2');
    });

    test('geçmiş tarihte sunucunun 400 hatasını taşır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Geçmiş tarihe istisna eklenemez',
          },
        ),
      );

      await expectLater(
        AvailabilityService.withClient(
          api.client,
        ).saveException(date: DateTime(2020), available: false),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.validation,
          ),
        ),
      );
    });

    test('istisnayı kimlikli uçtan siler', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await AvailabilityService.withClient(
        api.client,
      ).deleteException('exception_1');

      expect(api.requests.single.method, 'DELETE');
      expect(
        api.requests.single.path,
        '/users/me/availability/exceptions/exception_1',
      );
    });
  });
}
