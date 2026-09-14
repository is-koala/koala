import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/models/review.dart';

import '../../../../support/backend_contract_root.dart';

Map<String, dynamic> reviewBody({
  int rating = 4,
  String? comment = 'Çok iyiydi',
  bool anonymous = false,
}) {
  return {
    'id': 'rev_1',
    'rating': rating,
    'comment': comment,
    'anonymous': anonymous,
    'createdAt': '2026-03-12T14:30:00Z',
    // Anonim değerlendirmede sunucu yazarı hiç doldurmuyor.
    if (!anonymous)
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
      expect(review.author?.fullName, 'Deniz Yıldız');
      expect(review.authorLabel, 'Deniz Yıldız');
      expect(review.isAnonymous, isFalse);
      expect(review.createdAt, isNotNull);
    });

    // Sunucu yazarı yalnızca yanıt katmanında gizliyor; sahte bir kullanıcı
    // uydurulmuyor, alan boş geliyor.
    test('anonim değerlendirmede yazar gelmiyor', () {
      final review = Review.fromJson(reviewBody(anonymous: true));

      expect(review.isAnonymous, isTrue);
      expect(review.author, isNull);
      expect(review.authorLabel, 'Anonim');
      // Puan yine sayılıyor: anonimlik yazarı gizlemek, puanı geçersiz
      // kılmak değil.
      expect(review.rating, 4);
    });

    test('anonim alanı hiç gelmezse false', () {
      final body = reviewBody()..remove('anonymous');

      expect(Review.fromJson(body).isAnonymous, isFalse);
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

  group('Review yerel kayıt', () {
    test('toJson → fromJson içeriği korur, yazar yazılmaz', () {
      final review = Review.fromJson(reviewBody(rating: 3));

      final restored = Review.fromJson(review.toJson());

      expect(restored.id, 'rev_1');
      expect(restored.rating, 3);
      expect(restored.comment, 'Çok iyiydi');
      expect(restored.createdAt, review.createdAt);
      expect(restored.author, isNull);
    });

    test('summaryLabel yorumu tırnak içinde, yorumsuzda yalnızca yıldız', () {
      expect(
        Review.fromJson(reviewBody(rating: 4)).summaryLabel,
        '★4 · "Çok iyiydi"',
      );
      expect(
        Review.fromJson(reviewBody(rating: 5, comment: '  ')).summaryLabel,
        '★5',
      );
    });

    // Sınır sözleşmenin karşı ucunda: `CreateReviewDto.comment`
    // `@Size(max = 2000)`. Backend checkout'u yanındaysa ikisi karşılaştırılıyor.
    test('maxCommentLength backend CreateReviewDto ile aynı', () {
      final Directory root;
      try {
        root = BackendContractRoot.resolve();
      } on StateError {
        markTestSkipped('backend checkout yok');
        return;
      }
      final dto = File(
        '${root.path}/src/main/java/com/exskylab/koala/core/dtos/review/'
        'request/CreateReviewDto.java',
      );
      if (!dto.existsSync()) {
        markTestSkipped('CreateReviewDto.java bulunamadı');
        return;
      }
      final match = RegExp(
        r'@Size\(max = (\d+)\)\s+private String comment;',
      ).firstMatch(dto.readAsStringSync());

      expect(
        match,
        isNotNull,
        reason: 'comment alanının @Size sınırı okunamadı',
      );
      expect(Review.maxCommentLength, int.parse(match!.group(1)!));
    });
  });

  group('ReviewSubject', () {
    final assignment = Assignment.fromJson({
      'id': 'asg_1',
      'status': 'COMPLETED',
      'paymentStatus': 'HELD_IN_ESCROW',
      'worker': {'id': 'w1', 'firstName': 'Ayşe', 'lastName': 'Yılmaz'},
      'actualCompletionDateTime': '2026-09-10T17:05:00Z',
      'job': {
        'id': 'job-1',
        'title': 'Barista',
        'category': {'id': 'c1', 'code': 'BARISTA', 'name': 'Barista'},
        'type': 'ONE_TIME',
        'employerType': 'INDIVIDUAL',
        'salaryType': 'DAILY',
        'salary': 1000,
        'status': 'OPEN',
        'startDateTime': '2026-09-10T09:00:00Z',
        'endDateTime': '2026-09-10T17:00:00Z',
      },
    });

    test('forWorker işveren tarafını çalışanın adıyla kurar', () {
      final subject = ReviewSubject.forWorker(assignment);

      expect(subject.assignmentId, 'asg_1');
      expect(subject.side, ReviewSide.employer);
      expect(subject.isEmployer, isTrue);
      expect(subject.title, 'Ayşe Yılmaz');
      expect(subject.subtitle, 'Barista');
      expect(subject.date, DateTime.parse('2026-09-10T17:05:00Z'));
    });

    test('fromMyJob çalışan tarafını satırdan kurar', () {
      final subject = ReviewSubject.fromMyJob(MyJob.fromAssignment(assignment));

      expect(subject.assignmentId, 'asg_1');
      expect(subject.side, ReviewSide.worker);
      expect(subject.title, 'Barista');
      expect(subject.subtitle, 'Bireysel İlan');
    });
  });
}
