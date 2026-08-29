import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Değerlendirme uçları.
///
/// Yazma atama üzerinden, okuma kişi üzerinden yapılıyor: değerlendirme bir
/// işe bırakılıyor ama o işin karşı tarafındaki kişiye yazılıyor.
class ReviewService {
  ReviewService._(this._apiClient);

  static final ReviewService _instance = ReviewService._(ApiClient());

  factory ReviewService() => _instance;

  @visibleForTesting
  factory ReviewService.withClient(ApiClient apiClient) {
    return ReviewService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Tamamlanmış bir işi değerlendirir.
  ///
  /// [rating] 1 ile 5 arasında olmalı; dışına çıkarsa sunucu `400` döndürüyor.
  /// [comment] isteğe bağlı, en fazla 2000 karakter. İş tamamlanmamışsa ya da
  /// kullanıcı bu işi zaten değerlendirmişse `409` geliyor — ikisi de
  /// çağıranın kullanıcıya göstermesi gereken durumlar.
  Future<Review> leaveReview({
    required String assignmentId,
    required int rating,
    String? comment,
  }) {
    return _apiClient.post<Review>(
      ApiPaths.assignmentReviews(assignmentId),
      body: {'rating': rating, 'comment': ?comment},
      parse: (data) => Review.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Bir kullanıcı hakkında yazılmış değerlendirmeler, yeniden eskiye.
  Future<ReviewPage> fetchReviewsAbout(
    String userId, {
    int page = 0,
    int size = 20,
  }) {
    return _apiClient.get<ReviewPage>(
      ApiPaths.userReviews(userId),
      queryParameters: {'page': page, 'size': size},
      parse: (data) => ReviewPage.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Bir kullanıcının puan özeti.
  ///
  /// Hiç değerlendirilmemiş kullanıcıda uç `data: null` döndürüyor; burada
  /// sıfırlı bir özet uydurulmuyor, `null` olduğu gibi geçiyor. Çağıran
  /// "puanı yok" ile "puanı düşük"ü ayırt edebilmeli.
  Future<RatingSummary?> fetchRatingSummary(String userId) {
    return _apiClient.get<RatingSummary?>(
      ApiPaths.userRatingSummary(userId),
      parse: (data) =>
          data is Map<String, dynamic> ? RatingSummary.fromJson(data) : null,
    );
  }
}
