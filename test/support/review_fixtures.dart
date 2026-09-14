import 'package:dio/dio.dart';

import 'fake_api.dart';

/// Değerlendirme uçlarının sabit gövdeleri; provider, sayfa ve işveren paneli
/// testleri aynı zarfları paylaşıyor.

/// Backend `ReviewDto` karşılığı. Yazar verilmezse anonim kayıt gibi
/// `author` alanı hiç yazılmıyor.
Map<String, Object?> reviewDtoJson({
  String id = 'rev_1',
  int rating = 4,
  String? comment,
  String? authorId = 'u1',
  String? createdAt,
  bool anonymous = false,
}) => {
  'id': id,
  'rating': rating,
  'comment': ?comment,
  'anonymous': anonymous,
  if (authorId != null)
    'author': {'id': authorId, 'firstName': 'Ada', 'lastName': 'Kaya'},
  'createdAt': ?createdAt,
};

/// `POST /job-assignments/{id}/reviews` başarılı yanıtı (`201`).
FakeApiResponse reviewCreatedResponse(Map<String, Object?> review) =>
    FakeApiResponse(statusCode: 201, body: {'success': true, 'data': review});

/// `GET /users/{id}/reviews` sayfalı yanıtı.
FakeApiResponse reviewsPageResponse(List<Map<String, Object?>> reviews) =>
    FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'content': reviews, 'last': true},
      },
    );

/// Sunucunun `ReviewManager.leaveReview` içinden dönen iki reddi de aynı
/// `ConflictException`, yani aynı durum kodu **ve** aynı kategori. Tek fark
/// `errorCode`: `KoalaException` onu mesaj anahtarından türetiyor.
FakeApiResponse reviewConflictResponse({
  required String errorCode,
  required String message,
}) => FakeApiResponse(
  statusCode: 409,
  body: {
    'success': false,
    'message': message,
    'errorCode': errorCode,
    'errorCategory': 'DATA_CONFLICT',
  },
);

/// `{review.already.reviewed}` → `REVIEW_ALREADY_REVIEWED`; metin
/// `messages_tr.properties`'ten.
FakeApiResponse reviewAlreadyReviewedResponse() => reviewConflictResponse(
  errorCode: 'REVIEW_ALREADY_REVIEWED',
  message: 'Bu iş için zaten değerlendirme yaptınız.',
);

/// `{review.work.not.completed}` → `REVIEW_WORK_NOT_COMPLETED`.
FakeApiResponse reviewWorkNotCompletedResponse() => reviewConflictResponse(
  errorCode: 'REVIEW_WORK_NOT_COMPLETED',
  message: 'İş tamamlanmadan değerlendirme yapılamaz.',
);

/// Yazma isteğine 201, okuma isteğine [reviews] sayfası dönen sahte sunucu.
FakeApi reviewApi({
  List<Map<String, Object?>> reviews = const [],
  FakeApiResponse Function(RequestOptions request)? onPost,
}) => FakeApi(
  handler: (request) {
    if (request.method == 'GET') return reviewsPageResponse(reviews);
    if (onPost != null) return onPost(request);
    final body = request.data as Map<String, dynamic>;
    return reviewCreatedResponse(
      reviewDtoJson(
        rating: body['rating'] as int,
        comment: body['comment'] as String?,
      ),
    );
  },
);
