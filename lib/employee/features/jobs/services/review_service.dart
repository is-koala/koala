import 'package:koala/employee/features/jobs/models/review.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final List<Review> _reviews = [];

  List<Review> get reviews => List.unmodifiable(_reviews);

  Future<void> submitReview(Review review) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _reviews.add(review);
  }

  bool hasReviewed(String jobId) {
    return _reviews.any((r) => r.jobId == jobId);
  }
}
