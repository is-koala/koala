import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Değerlendirme uçları: yazma atama, okuma kişi üzerinden.
class ReviewService {
  ReviewService._(this._apiClient);

  static final ReviewService _instance = ReviewService._(ApiClient());

  factory ReviewService() => _instance;

  @visibleForTesting
  factory ReviewService.withClient(ApiClient apiClient) {
    return ReviewService._(apiClient);
  }

  final ApiClient _apiClient;

  /// [rating] 1-5, [comment] ≤2000. Tamamlanmamış ya da zaten değerlendirilmiş
  /// işte `409`. [anonymous] yazarı yanıtlarda gizler; sonradan değişmez.
  Future<Review> leaveReview({
    required String assignmentId,
    required int rating,
    String? comment,
    bool anonymous = false,
  }) {
    return _apiClient.post<Review>(
      ApiPaths.assignmentReviews(assignmentId),
      body: {'rating': rating, 'comment': ?comment, 'anonymous': anonymous},
      parse: (data) => Review.fromJson(data! as Map<String, dynamic>),
    );
  }

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

  /// Hiç değerlendirilmemişte `null`; "puanı yok" ile "düşük" ayrılabilsin.
  Future<RatingSummary?> fetchRatingSummary(String userId) {
    return _apiClient.get<RatingSummary?>(
      ApiPaths.userRatingSummary(userId),
      parse: (data) =>
          data is Map<String, dynamic> ? RatingSummary.fromJson(data) : null,
    );
  }
}
