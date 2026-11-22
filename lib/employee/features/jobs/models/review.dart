import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';

/// Değerlendirme: atamaya bırakılıyor, karşı **kişiye** yazılıyor. Anonimde
/// `author` gelmez; gizleme yalnız yanıt katmanında, kurallar anonimde de
/// işliyor.
class Review {
  const Review({
    required this.id,
    required this.rating,
    this.jobAssignmentId,
    this.author,
    this.isAnonymous = false,
    this.comment,
    this.createdAt,
  });

  /// `@Size(max = 2000)`.
  static const int maxCommentLength = 2000;

  final String id;

  /// Yalnız `POST` yanıtında dolu; herkese açık listede bilerek `null`, yoksa
  /// anonim yazar açığa çıkardı.
  final String? jobAssignmentId;

  /// Anonimde `null`; sahte "Anonim" kişi üretilmiyor.
  final JobCreator? author;

  /// "Yazar gizlendi" ile "yazar gelmedi" farklı.
  final bool isAnonymous;

  final int rating;

  final String? comment;

  final DateTime? createdAt;

  bool get hasComment => comment != null && comment!.trim().isNotEmpty;

  String get authorLabel => author?.fullName ?? 'Anonim';

  /// `★4 · "yorum"`.
  String get summaryLabel =>
      hasComment ? '★$rating · "${comment!.trim()}"' : '★$rating';

  /// `MyReviewDto` da aynı biçimde çözülüyor; orada yazar alanı gelmez.
  factory Review.fromJson(Map<String, dynamic> json) {
    final author = json['author'];

    return Review(
      id: '${json['id']}',
      jobAssignmentId: switch (json['jobAssignmentId']) {
        final String value when value.isNotEmpty => value,
        _ => null,
      },
      author: author is Map<String, dynamic>
          ? JobCreator.fromJson(author)
          : null,
      isAnonymous: json['anonymous'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      createdAt: switch (json['createdAt']) {
        final String value => DateTime.tryParse(value),
        _ => null,
      },
    );
  }
}

class ReviewPage {
  const ReviewPage({
    this.reviews = const [],
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<Review> reviews;
  final int page;
  final int totalElements;
  final bool last;

  factory ReviewPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return ReviewPage(
      reviews: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(Review.fromJson)
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }
}

enum ReviewSide { worker, employer }

/// Değerlendirme ekranının konusu; iki kabuk aynı ekranı açıyor, karşı tarafı
/// sunucu seçiyor.
class ReviewSubject {
  const ReviewSubject({
    required this.assignmentId,
    required this.side,
    required this.title,
    required this.subtitle,
    this.date,
  });

  /// Başvuru satırının atama kimliği yok; ekran `null`'ı karşılar.
  factory ReviewSubject.fromMyJob(MyJob job) => ReviewSubject(
    assignmentId: job.assignmentId,
    side: ReviewSide.worker,
    title: job.title,
    subtitle: job.company,
    date: job.assignment?.assignmentDateTime,
  );

  factory ReviewSubject.forWorker(Assignment assignment) => ReviewSubject(
    assignmentId: assignment.id,
    side: ReviewSide.employer,
    title: assignment.worker?.fullName.isNotEmpty == true
        ? assignment.worker!.fullName
        : 'Çalışan',
    subtitle: assignment.job.title,
    date: assignment.actualCompletionDateTime ?? assignment.assignmentDateTime,
  );

  final String? assignmentId;
  final ReviewSide side;
  final String title;
  final String subtitle;

  final DateTime? date;

  bool get isEmployer => side == ReviewSide.employer;
}
