import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İş arayanın ödeme çıkışlarını okur.
class PayoutService {
  PayoutService._(this._apiClient);

  static final PayoutService _instance = PayoutService._(ApiClient());

  factory PayoutService() => _instance;

  @visibleForTesting
  factory PayoutService.withClient(ApiClient apiClient) {
    return PayoutService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Oturum sahibinin bütün ödeme çıkışları, yeniden eskiye.
  Future<List<Payout>> fetchMyPayouts() {
    return _apiClient.get<List<Payout>>(
      ApiPaths.currentUserPayouts,
      parse: (data) {
        if (data is! List) return const [];

        final payouts = data
            .whereType<Map<String, dynamic>>()
            .map(Payout.fromJson)
            .toList();
        payouts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return payouts;
      },
    );
  }
}
