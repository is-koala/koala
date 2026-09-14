import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';

import '../../../../support/identity_document_fixtures.dart';

void main() {
  group('IdentityReviewStatus.fromCode', () {
    test('sunucunun üç değerini tanıyor', () {
      expect(
        IdentityReviewStatus.fromCode('PENDING'),
        IdentityReviewStatus.pending,
      );
      expect(
        IdentityReviewStatus.fromCode('APPROVED'),
        IdentityReviewStatus.approved,
      );
      expect(
        IdentityReviewStatus.fromCode('REJECTED'),
        IdentityReviewStatus.rejected,
      );
    });

    test('PENDING_REVIEW de bekliyor sayılıyor', () {
      expect(
        IdentityReviewStatus.fromCode('PENDING_REVIEW'),
        IdentityReviewStatus.pending,
      );
    });

    test('tanımadığı değerde null, fırlatmıyor', () {
      expect(IdentityReviewStatus.fromCode('WITHDRAWN'), isNull);
      expect(IdentityReviewStatus.fromCode(null), isNull);
      expect(IdentityReviewStatus.fromCode(3), isNull);
    });
  });

  group('IdentityReview.fromJson', () {
    test('durum, gerekçe ve tarihleri okuyor', () {
      final review = IdentityReview.fromJson(
        identityReviewJson(
          status: 'REJECTED',
          rejectionReason: '  Arka yüz bulanık  ',
          rejectedAt: '2026-09-13T12:00:00Z',
        ),
      );

      expect(review, isNotNull);
      expect(review!.id, 'review-1');
      expect(review.isRejected, isTrue);
      expect(review.rejectionReason, 'Arka yüz bulanık');
      expect(review.rejectedAt, DateTime.utc(2026, 9, 13, 12).toLocal());
      expect(review.createdAt, DateTime.utc(2026, 9, 13, 11, 5).toLocal());
      expect(review.verifiedAt, isNull);
    });

    test('boş gerekçe null', () {
      final review = IdentityReview.fromJson(
        identityReviewJson(status: 'REJECTED', rejectionReason: '   '),
      );

      expect(review!.rejectionReason, isNull);
    });

    test('TCKN modele alınmıyor', () {
      // Yanıt taşıyor ama ekranın işi yok; bir yerde daha saklamak onu bir
      // log satırına yaklaştırır.
      final json = identityReviewJson(status: 'PENDING')
        ..['tcIdentityNumber'] = '12345678950';

      final review = IdentityReview.fromJson(json)!;

      expect(review.toString(), isNot(contains('12345678950')));
    });

    test('tanınmayan durumda null', () {
      expect(
        IdentityReview.fromJson(identityReviewJson(status: 'SOMETHING')),
        isNull,
      );
    });
  });

  group('IdentityStatus.resolve', () {
    IdentityReview review(IdentityReviewStatus status) =>
        IdentityReview(id: 'r', status: status);

    test('bayrak son söz: doğrulanmış kullanıcı incelemeye bakmıyor', () {
      expect(
        IdentityStatus.resolve(
          identityVerified: true,
          review: review(IdentityReviewStatus.rejected),
        ),
        IdentityStatus.verified,
      );
    });

    test('onaylı inceleme bayrak tazelenmeden de doğrulanmış', () {
      expect(
        IdentityStatus.resolve(
          identityVerified: false,
          review: review(IdentityReviewStatus.approved),
        ),
        IdentityStatus.verified,
      );
    });

    test('bekleyen ve reddedilen inceleme kendi durumunu veriyor', () {
      expect(
        IdentityStatus.resolve(
          identityVerified: false,
          review: review(IdentityReviewStatus.pending),
        ),
        IdentityStatus.pending,
      );
      expect(
        IdentityStatus.resolve(
          identityVerified: false,
          review: review(IdentityReviewStatus.rejected),
        ),
        IdentityStatus.rejected,
      );
    });

    test('inceleme yoksa doğrulanmamış', () {
      expect(
        IdentityStatus.resolve(identityVerified: false, review: null),
        IdentityStatus.unverified,
      );
    });

    test('dört durumun da Türkçe etiketi var', () {
      for (final status in IdentityStatus.values) {
        expect(status.label, contains('Kimlik'), reason: status.name);
      }
    });
  });
}
