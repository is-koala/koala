import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';
import 'package:koala/employee/features/jobs/services/payout_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('PayoutService.fetchMyPayouts', () {
    test('düz listeyi yeniden eskiye ayrıştırır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'payout-new',
                'jobAssignmentId': 'assignment-new',
                'amount': '1000.10',
                'currency': 'TRY',
                'status': 'PROCESSING',
                'createdAt': '2026-09-06T12:00:00Z',
              },
              {
                'id': 'payout-old',
                'jobAssignmentId': 'assignment-old',
                'amount': '250.20',
                'currency': 'TRY',
                'status': 'COMPLETED',
                'completedAt': '2026-09-05T13:00:00Z',
                'createdAt': '2026-09-05T12:00:00Z',
              },
            ],
          },
        ),
      );

      final payouts = await PayoutService.withClient(
        api.client,
      ).fetchMyPayouts();

      expect(api.requests.single.path, '/users/me/payouts');
      expect(api.requests.single.method, 'GET');
      expect(payouts.map((payout) => payout.id), ['payout-new', 'payout-old']);
      expect(payouts.first.amount, '1000.10');
      expect(payouts.first.status, PayoutStatus.processing);
    });

    test('boş liste hata değildir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );

      final payouts = await PayoutService.withClient(
        api.client,
      ).fetchMyPayouts();

      expect(payouts, isEmpty);
    });

    test('tutarı sayı döndüren sözleşme dışı yanıtı reddeder', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'payout-1',
                'jobAssignmentId': 'assignment-1',
                'amount': 1000.10,
                'currency': 'TRY',
                'status': 'PROCESSING',
                'createdAt': '2026-09-06T12:00:00Z',
              },
            ],
          },
        ),
      );

      await expectLater(
        PayoutService.withClient(api.client).fetchMyPayouts(),
        throwsA(isA<ApiException>()),
      );
    });

    for (final statusCode in [401, 500]) {
      test('$statusCode yanıtı ApiException yükseltir', () async {
        final api = FakeApi(
          handler: (_) => FakeApiResponse(
            statusCode: statusCode,
            body: const {'success': false, 'message': 'Ödemeler alınamadı.'},
          ),
        );

        await expectLater(
          PayoutService.withClient(api.client).fetchMyPayouts(),
          throwsA(isA<ApiException>()),
        );
      });
    }
  });
}
