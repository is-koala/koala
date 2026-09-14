import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';

/// Bir iş üzerine bırakılan değerlendirme.
///
/// Backend `ReviewDto` karşılığı. Değerlendirme **atamaya** bırakılıyor
/// (`POST /job-assignments/{assignmentId}/reviews`) ama karşı **kişiye**
/// yazılıyor; listeleme bu yüzden kişi üzerinden gidiyor
/// (`GET /users/{userId}/reviews`).
///
/// Anonim değerlendirmede `author` **gelmiyor**: sunucu yazarı yalnızca
/// yanıt katmanında gizliyor, veritabanında `author_id` dolu kalıyor. Yani
/// tekillik kuralı, tek değerlendirme sınırı ve kötüye kullanım incelemesi
/// anonim kayıtta da işliyor.
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

  /// Yorumun üst sınırı; backend `CreateReviewDto.comment` `@Size(max = 2000)`.
  static const int maxCommentLength = 2000;

  final String id;

  /// Değerlendirmenin yazıldığı atama.
  ///
  /// Yalnızca `POST /job-assignments/{id}/reviews` yanıtında dolu; herkese
  /// açık listede (`GET /users/{id}/reviews`) sunucu bilerek `null`
  /// gönderiyor — iki profilde aynı atama kimliği anonim yazarı açığa
  /// çıkarırdı. [ReviewProvider] gönderilen kaydı bu kimlikle anahtarlıyor.
  final String? jobAssignmentId;

  /// Değerlendirmeyi yazan. Backend `SafeUserDto` döndürüyor; Dart karşılığı
  /// [JobCreator] olarak zaten var, ikinci bir kopya çıkarılmadı.
  ///
  /// Anonim değerlendirmede `null` — sunucu alanı hiç doldurmuyor. Sahte bir
  /// "Anonim Kullanıcı" kaydı üretilmedi; olmayan bir kişiyi var göstermek
  /// her okuyan yerde ayıklanmak zorunda kalırdı.
  final JobCreator? author;

  /// Yazar gizli mi. [author] zaten `null` oluyor ama bayrak ayrıca
  /// taşınıyor: "yazar gizlendi" ile "yazar gelmedi" farklı şeyler.
  final bool isAnonymous;

  /// 1 ile 5 arası. Sunucu aralık dışını `400` ile reddediyor.
  final int rating;

  /// Yorum isteğe bağlı; yalnızca puan verilmiş olabilir.
  final String? comment;

  final DateTime? createdAt;

  /// Yorumu olan değerlendirme. Boş yorumlar listede satır kaplamamalı.
  bool get hasComment => comment != null && comment!.trim().isNotEmpty;

  /// Listede gösterilecek yazar adı.
  String get authorLabel => author?.fullName ?? 'Anonim';

  /// Kartta tek satır: `★4 · "yorum"`; yorum yoksa yalnızca yıldız.
  String get summaryLabel =>
      hasComment ? '★$rating · "${comment!.trim()}"' : '★$rating';

  /// `ReviewDto`'yu okur. `MyAssignmentDto.myReview` (`MyReviewDto`: kimlik,
  /// puan, yorum, tarih) de aynı biçimde çözülüyor; orada yazar zaten
  /// görüntüleyenin kendisi, alan hiç gelmiyor.
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

/// Sayfalı değerlendirme yanıtı.
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

/// Değerlendirilecek işin hangi tarafından bakıldığı; ekran metinleri buna
/// göre değişiyor.
enum ReviewSide {
  /// Çalışan işvereni değerlendiriyor.
  worker,

  /// İşveren çalışanı değerlendiriyor.
  employer,
}

/// `ReviewPage`'in konusu: hangi atamaya, kimin adına, hangi kartla.
///
/// İki kabuk aynı ekranı açıyor; çalışan `İşlerim` satırından
/// ([ReviewSubject.fromMyJob]), işveren ilan detayındaki atamadan
/// ([ReviewSubject.forWorker]). Yazma isteği her iki tarafta da aynı:
/// `POST /job-assignments/{id}/reviews`, karşı tarafı sunucu seçiyor.
class ReviewSubject {
  const ReviewSubject({
    required this.assignmentId,
    required this.side,
    required this.title,
    required this.subtitle,
    this.date,
  });

  /// Çalışanın satırından. Başvurudan gelen satırın atama kimliği yok; o
  /// satırlarda "Değerlendir" zaten çıkmıyor, ekran yine de `null`'ı
  /// kendisi karşılıyor.
  factory ReviewSubject.fromMyJob(MyJob job) => ReviewSubject(
    assignmentId: job.assignmentId,
    side: ReviewSide.worker,
    title: job.title,
    subtitle: job.company,
    date: job.assignment?.assignmentDateTime,
  );

  /// İşverenin atamasından: kart çalışanın adını taşıyor, ilan başlığı altta.
  factory ReviewSubject.forWorker(Assignment assignment) => ReviewSubject(
    assignmentId: assignment.id,
    side: ReviewSide.employer,
    title: assignment.worker?.fullName.isNotEmpty == true
        ? assignment.worker!.fullName
        : 'Çalışan',
    subtitle: assignment.job.title,
    date: assignment.actualCompletionDateTime ?? assignment.assignmentDateTime,
  );

  /// Başvurudan gelen satırda yok; yalnızca atama değerlendirilebiliyor.
  final String? assignmentId;
  final ReviewSide side;
  final String title;
  final String subtitle;

  /// Kartta gösterilecek tarih; biçimlemeyi ekran yapıyor.
  final DateTime? date;

  bool get isEmployer => side == ReviewSide.employer;
}
