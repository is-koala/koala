import 'package:flutter/foundation.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Şikayet uçları; iki uygulama kullanıyor.
class ReportService {
  ReportService._(this._apiClient);

  static final ReportService _instance = ReportService._(ApiClient());

  factory ReportService() => _instance;

  @visibleForTesting
  factory ReportService.withClient(ApiClient apiClient) {
    return ReportService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Şikayet açar. En az bir hedef dolu olmalı ([ReportTarget] bunu yapısal
  /// olarak sağlıyor); verilmeyen hedef gövdeye konmuyor. Kendini şikayet
  /// `400`; sunucunun mesajı olduğu gibi gösterilir.
  Future<Report> createReport({
    String? reportedUserId,
    String? jobId,
    String? messageId,
    String? imageId,
    required ReportReason reason,
    String? description,
  }) {
    final body = <String, dynamic>{
      'reportedUserId': ?reportedUserId,
      'jobId': ?jobId,
      'messageId': ?messageId,
      'imageId': ?imageId,
      'reason': reason.code,
      'description': ?description,
    };

    return _apiClient.post<Report>(
      ApiPaths.reports,
      body: body,
      parse: (data) => Report.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Yeniden eskiye; sayfa boyutu sunucuda (20).
  Future<ReportPage> fetchMyReports({int page = 0}) {
    return _apiClient.get<ReportPage>(
      ApiPaths.myReports,
      queryParameters: {'page': page},
      parse: (data) => ReportPage.fromJson(data! as Map<String, dynamic>),
    );
  }
}
