import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/b_payment_attempt.dart';
import 'package:koala/business/features/home/models/b_pricing_breakdown.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İşverenin fiyat önizleme ve ödeme denemesi uçları.
class BPaymentService {
  BPaymentService._(this._apiClient);

  static final BPaymentService _instance = BPaymentService._(ApiClient());

  factory BPaymentService() => _instance;

  @visibleForTesting
  factory BPaymentService.withClient(ApiClient apiClient) {
    return BPaymentService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Çalışan ücreti için backend'in fiyat dökümünü getirir.
  Future<BPricingBreakdown> quote(String workerPayout) {
    return _apiClient.post<BPricingBreakdown>(
      ApiPaths.paymentQuotes,
      body: {'workerPayout': workerPayout},
      parse: (data) =>
          BPricingBreakdown.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Atamanın bütün ödeme denemeleri, yeniden eskiye.
  Future<List<BPaymentAttempt>> fetchAttempts(String assignmentId) {
    return _apiClient.get<List<BPaymentAttempt>>(
      ApiPaths.assignmentPayments(assignmentId),
      parse: (data) {
        if (data is! List) return const [];

        final attempts = data
            .whereType<Map<String, dynamic>>()
            .map(BPaymentAttempt.fromJson)
            .toList();
        attempts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return attempts;
      },
    );
  }
}
