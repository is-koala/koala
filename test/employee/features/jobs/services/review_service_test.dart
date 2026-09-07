import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('ReviewService.leaveReview', () {
    test('puan ve yorum atama yoluna gider', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {
              'id': 'rev_1',
              'rating': 5,
              'comment': 'Harikaydı',
              'author': {'id': 'u1', 'firstName': 'Ada', 'lastName': 'Kaya'},
            },
          },
        ),
      );

      final review = await ReviewService.withClient(
        api.client,
      ).leaveReview(assignmentId: 'asg_1', rating: 5, comment: 'Harikaydı');

      final request = api.requests.single;
      expect(request.path, '/job-assignments/asg_1/reviews');
      expect(request.method, 'POST');
      expect(request.data, {
        'rating': 5,
        'comment': 'Harikaydı',
        'anonymous': false,
      });
      expect(review.rating, 5);
    });

    // Yorum isteğe bağlı: boş gövde alanı hiç gönderilmiyor.
    test('yorumsuz gönderimde comment alanı yok', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {
              'id': 'rev_1',
              'rating': 3,
              'author': {'id': 'u1', 'firstName': 'Ada', 'lastName': 'Kaya'},
            },
          },
        ),
      );

      await ReviewService.withClient(
        api.client,
      ).leaveReview(assignmentId: 'asg_1', rating: 3);

      expect(api.requests.single.data, {'rating': 3, 'anonymous': false});
    });

    // Anonim işareti gövdede her zaman gidiyor; sunucu alanı opsiyonel
    // tanımlamış ama açıkça `false` göndermek niyeti belirsiz bırakmıyor.
    test('anonim işaretlenince gövdeye true gider', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {'id': 'rev_1', 'rating': 4, 'anonymous': true},
          },
        ),
      );

      final review = await ReviewService.withClient(
        api.client,
      ).leaveReview(assignmentId: 'asg_1', rating: 4, anonymous: true);

      final body = api.requests.single.data as Map<String, dynamic>;
      expect(body['anonymous'], isTrue);
      expect(review.isAnonymous, isTrue);
      expect(review.author, isNull);
    });

    test('ikinci değerlendirme 409 yükseltir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {'success': false, 'message': 'Bu iş zaten değerlendirilmiş'},
        ),
      );

      await expectLater(
        ReviewService.withClient(
          api.client,
        ).leaveReview(assignmentId: 'asg_1', rating: 5),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.dataConflict,
          ),
        ),
      );
    });
  });

  group('ReviewService.fetchRatingSummary', () {
    test('özet modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'userId': 'usr_1', 'reviewCount': 7, 'averageRating': 4.2},
          },
        ),
      );

      final summary = await ReviewService.withClient(
        api.client,
      ).fetchRatingSummary('usr_1');

      expect(api.requests.single.path, '/users/usr_1/rating-summary');
      expect(summary?.averageRating, 4.2);
    });

    // Hiç değerlendirilmemiş kullanıcıda uç `data: null` döndürüyor; sıfırlı
    // bir özet uydurmak "puanı 0" demek olurdu.
    test('değerlendirmesi olmayanda null döner', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': null},
        ),
      );

      final summary = await ReviewService.withClient(
        api.client,
      ).fetchRatingSummary('usr_1');

      expect(summary, isNull);
    });
  });

  group('ReviewService.fetchReviewsAbout', () {
    test('sayfalı yanıt modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {
                  'id': 'rev_1',
                  'rating': 5,
                  'author': {
                    'id': 'u1',
                    'firstName': 'Ada',
                    'lastName': 'Kaya',
                  },
                },
              ],
              'totalElements': 1,
              'last': true,
            },
          },
        ),
      );

      final page = await ReviewService.withClient(
        api.client,
      ).fetchReviewsAbout('usr_1');

      expect(api.requests.single.path, '/users/usr_1/reviews');
      expect(page.reviews.single.rating, 5);
    });
  });
}
