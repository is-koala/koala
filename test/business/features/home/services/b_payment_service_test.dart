import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/b_payment_attempt.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('BPaymentService.quote', () {
    test(
      'ücreti doğru gövdeyle gönderip ondalık dizeleri aynen taşır',
      () async {
        final api = FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'pricingVersion': 'v1',
                'currency': 'TRY',
                'workerPayout': '1000.10',
                'serviceFeeRate': '0.075',
                'serviceFeeAmount': '75.01',
                'employerTotal': '1075.11',
              },
            },
          ),
        );

        final quote = await BPaymentService.withClient(
          api.client,
        ).quote('1000.10');

        final request = api.requests.single;
        expect(request.path, '/payment-quotes');
        expect(request.method, 'POST');
        expect(request.data, {'workerPayout': '1000.10'});
        expect(quote.workerPayout, '1000.10');
        expect(quote.serviceFeeAmount, '75.01');
        expect(quote.employerTotal, '1075.11');
      },
    );

    test('sunucu hatasını ApiException olarak yükseltir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Döküm alınamadı.'},
        ),
      );

      await expectLater(
        BPaymentService.withClient(api.client).quote('1000.10'),
        throwsA(isA<ApiException>()),
      );
    });

    test('ondalıkları sayı döndüren sözleşme dışı yanıtı reddeder', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'pricingVersion': 'v1',
              'currency': 'TRY',
              'workerPayout': 1000.10,
              'serviceFeeRate': '0.075',
              'serviceFeeAmount': '75.01',
              'employerTotal': '1075.11',
            },
          },
        ),
      );

      await expectLater(
        BPaymentService.withClient(api.client).quote('1000.10'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('BPaymentService.fetchAttempts', () {
    test('atamanın denemelerini yeniden eskiye ayrıştırır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'attempt-old',
                'status': 'FAILED',
                'currency': 'TRY',
                'workerPayout': '1000.10',
                'commissionAmount': '75.01',
                'commissionRate': '0.075',
                'totalCharged': '1075.11',
                'pricing': {
                  'pricingVersion': 'v1',
                  'currency': 'TRY',
                  'workerPayout': '1000.10',
                  'serviceFeeRate': '0.075',
                  'serviceFeeAmount': '75.01',
                  'employerTotal': '1075.11',
                },
                'failureReason': 'Kart reddedildi.',
                'createdAt': '2026-09-05T12:00:00Z',
              },
              {
                'id': 'attempt-new',
                'status': 'SUCCEEDED',
                'currency': 'TRY',
                'workerPayout': '1000.10',
                'commissionAmount': '75.01',
                'commissionRate': '0.075',
                'totalCharged': '1075.11',
                'createdAt': '2026-09-06T12:00:00Z',
                'completedAt': '2026-09-06T12:03:00Z',
              },
            ],
          },
        ),
      );

      final attempts = await BPaymentService.withClient(
        api.client,
      ).fetchAttempts('assignment-1');

      expect(
        api.requests.single.path,
        '/job-assignments/assignment-1/payments',
      );
      expect(api.requests.single.method, 'GET');
      expect(attempts.map((attempt) => attempt.id), [
        'attempt-new',
        'attempt-old',
      ]);
      expect(attempts.last.status, BPaymentAttemptStatus.failed);
      expect(attempts.last.pricing?.workerPayout, '1000.10');
    });

    test('boş deneme listesi hata değildir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );

      final attempts = await BPaymentService.withClient(
        api.client,
      ).fetchAttempts('assignment-1');

      expect(attempts, isEmpty);
    });

    test('ondalık alanları sayı olan denemeyi reddeder', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'attempt-1',
                'status': 'FAILED',
                'currency': 'TRY',
                'workerPayout': 1000.10,
                'commissionAmount': '75.01',
                'commissionRate': '0.075',
                'totalCharged': '1075.11',
                'createdAt': '2026-09-05T12:00:00Z',
              },
            ],
          },
        ),
      );

      await expectLater(
        BPaymentService.withClient(api.client).fetchAttempts('assignment-1'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
