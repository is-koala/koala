import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewService _reviewService = ReviewService();

  List<Review> get reviews => _reviewService.reviews;

  bool hasReviewed(String jobId) => _reviewService.hasReviewed(jobId);

  Future<void> submitReview(Review review) async {
    await _reviewService.submitReview(review);
    notifyListeners();
  }
}
