import 'package:flutter/foundation.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Şikayet uçları.
///
/// Servis `product/` altında çünkü iki uygulama da kullanıyor: çalışan
/// sohbetteki işvereni, işveren de aday profilinden çalışanı şikayet
/// edebiliyor. Uçlar hesap düzeyinde, tarafa göre değişmiyor.
class ReportService {
  ReportService._(this._apiClient);

  static final ReportService _instance = ReportService._(ApiClient());

  factory ReportService() => _instance;

  @visibleForTesting
  factory ReportService.withClient(ApiClient apiClient) {
    return ReportService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Şikayet açar ve oluşan kaydı döndürür.
  ///
  /// Dört hedef alanından **en az biri** dolu olmalı; hepsi boşsa sunucu
  /// `400` döndürüyor (`CreateReportDto.isPointingAtSomething()`). Arayüz
  /// tarafında bu kural [ReportTarget] ile yapısal olarak sağlanıyor.
  ///
  /// Verilmeyen hedefler gövdeye **hiç konmuyor**: `null` göndermek ile
  /// alanı hiç göndermemek sunucuda aynı sayılsa da, gövdeyi hedefine göre
  /// okumak günlüklerde ve hata ayıklamada işi kolaylaştırıyor.
  ///
  /// [imageId] bilerek duruyor ama hiçbir ekran doldurmuyor: şirket
  /// galerisi mobilde yönetilmiyor.
  ///
  /// Kendini şikayet etmek `400` — sunucunun Türkçe mesajı olduğu gibi
  /// gösterilmeli.
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

  /// Oturum sahibinin açtığı şikayetler, yeniden eskiye.
  ///
  /// Sayfa boyutunu sunucu belirliyor (varsayılan 20); istemcinin ayrıca
  /// geçmesine gerek yok.
  Future<ReportPage> fetchMyReports({int page = 0}) {
    return _apiClient.get<ReportPage>(
      ApiPaths.myReports,
      queryParameters: {'page': page},
      parse: (data) => ReportPage.fromJson(data! as Map<String, dynamic>),
    );
  }
}
