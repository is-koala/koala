import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/agreement_version.dart';
import 'package:koala/employee/features/auth/models/consent_decision.dart';
import 'package:koala/employee/features/auth/services/legal_service.dart';
import 'package:koala/product/models/account_deletion.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('LegalService.fetchCurrentAgreements', () {
    test('sözleşmeler modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'a1',
                'type': 'TERMS_OF_SERVICE',
                'version': '1.0',
                'locale': 'tr',
                'mandatory': true,
              },
              {
                'id': 'a2',
                'type': 'COMMERCIAL_MESSAGE',
                'version': '1.0',
                'locale': 'tr',
                'mandatory': false,
              },
            ],
          },
        ),
      );

      final agreements = await LegalService.withClient(
        api.client,
      ).fetchCurrentAgreements();

      expect(api.requests.single.path, '/legal/agreements');
      expect(agreements, hasLength(2));
      expect(agreements.first.type, AgreementType.termsOfService);
      expect(agreements.first.mandatory, isTrue);
      expect(agreements.last.mandatory, isFalse);
    });

    test('boş liste dönerse boş liste verir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );

      final agreements = await LegalService.withClient(
        api.client,
      ).fetchCurrentAgreements();

      expect(agreements, isEmpty);
    });
  });

  group('LegalService.recordConsents', () {
    test('kararlar dizi olarak gönderilir', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await LegalService.withClient(api.client).recordConsents(const [
        ConsentDecision(agreementVersionId: 'a1', granted: true),
        ConsentDecision(agreementVersionId: 'a2', granted: false),
      ]);

      expect(api.requests.single.path, '/legal/consents');
      expect(api.requests.single.data, [
        {'agreementVersionId': 'a1', 'granted': true},
        {'agreementVersionId': 'a2', 'granted': false},
      ]);
    });
  });

  group('LegalService.requestAccountDeletion', () {
    test('isteğe gerekçeyi ekler ve açık atama engelini döndürür', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'request-1',
              'status': 'REQUESTED',
              'requestedAt': '2026-09-06T10:00:00Z',
              'blockedReason': 'Devam eden işinizin tamamlanması bekleniyor.',
            },
          },
        ),
      );

      final result = await LegalService.withClient(
        api.client,
      ).requestAccountDeletion(reason: 'Artık kullanmıyorum');

      expect(api.requests.single.path, '/legal/account-deletion');
      expect(api.requests.single.data, {'reason': 'Artık kullanmıyorum'});
      expect(result.status, AccountDeletionStatus.requested);
      expect(
        result.blockedReason,
        'Devam eden işinizin tamamlanması bekleniyor.',
      );
    });
  });
}
