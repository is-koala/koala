import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/models/review.dart';

Map<String, dynamic> reviewBody({
  int rating = 4,
  String? comment = 'Çok iyiydi',
}) {
  return {
    'id': 'rev_1',
    'rating': rating,
    'comment': comment,
    'createdAt': '2026-03-12T14:30:00Z',
    'author': {
      'id': 'usr_1',
      'firstName': 'Deniz',
      'lastName': 'Yıldız',
      'profilePictureUrl': 'https://cdn.local/deniz.png',
    },
  };
}

void main() {
  group('Review', () {
    test('sunucu gövdesi modele çevrilir', () {
      final review = Review.fromJson(reviewBody());

      expect(review.id, 'rev_1');
      expect(review.rating, 4);
      expect(review.author.fullName, 'Deniz Yıldız');
      expect(review.createdAt, isNotNull);
    });

    // Yorum isteğe bağlı; yalnızca puan verilmiş olabilir.
    test('yorumsuz değerlendirme hasComment false', () {
      expect(Review.fromJson(reviewBody(comment: null)).hasComment, isFalse);
      expect(Review.fromJson(reviewBody(comment: '   ')).hasComment, isFalse);
    });

    test('yorumu olan değerlendirme hasComment true', () {
      expect(Review.fromJson(reviewBody()).hasComment, isTrue);
    });
  });

  group('ReviewPage', () {
    test('içerik listesi ayrıştırılır', () {
      final page = ReviewPage.fromJson({
        'content': [reviewBody()],
        'totalElements': 1,
        'last': false,
      });

      expect(page.reviews, hasLength(1));
      expect(page.last, isFalse);
    });

    test('boş içerik hata değil', () {
      expect(ReviewPage.fromJson({'content': []}).reviews, isEmpty);
    });
  });

  group('RatingSummary', () {
    test('sunucu gövdesi modele çevrilir', () {
      final summary = RatingSummary.fromJson({
        'userId': 'usr_1',
        'reviewCount': 12,
        'averageRating': 4.5,
      });

      expect(summary.reviewCount, 12);
      expect(summary.averageRating, 4.5);
      expect(summary.hasRating, isTrue);
    });

    // Değerlendirmesi olmayan kişiye "0.0" yazmak onu kötü puanlı gösterirdi.
    test('değerlendirmesi olmayanda hasRating false', () {
      final summary = RatingSummary.fromJson({
        'userId': 'usr_1',
        'reviewCount': 0,
        'averageRating': 0,
      });

      expect(summary.hasRating, isFalse);
    });
  });
}
