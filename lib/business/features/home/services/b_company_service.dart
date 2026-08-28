import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/b_company.dart';
import 'package:koala/business/features/home/models/employer_stats.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İşverenin şirketi ve istatistikleri.
///
/// Adı `b_` önekli çünkü çalışan tarafında da bir `CompanyService` var; o
/// sahte şirket detayını besliyor ve alan adları backend'inkiyle uyuşmuyor.
class BCompanyService {
  BCompanyService._(this._apiClient);

  static final BCompanyService _instance = BCompanyService._(ApiClient());

  factory BCompanyService() => _instance;

  @visibleForTesting
  factory BCompanyService.withClient(ApiClient apiClient) {
    return BCompanyService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Şirketin tam hâli. Uç herkese açık; takip sayısı ve oturum sahibinin
  /// takip durumu da yanıtta.
  Future<BCompany> fetchCompany(String companyId) {
    return _apiClient.get<BCompany>(
      ApiPaths.company(companyId),
      parse: (data) => BCompany.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Şirketi günceller ve yeni hâlini döndürür.
  ///
  /// Sunucu yalnızca bu beş alanı kabul ediyor (`UpdateCompanyRequestDto`):
  /// vergi numarası, adres, tür ve logo kurulduktan sonra değiştirilemiyor.
  /// Verilmeyen alan gövdeye hiç konmuyor; boş metin göndermek alanı
  /// silmek anlamına gelirdi.
  Future<BCompany> updateCompany(
    String companyId, {
    String? name,
    String? email,
    String? phoneNumber,
    String? website,
    String? description,
  }) {
    return _apiClient.patch<BCompany>(
      ApiPaths.company(companyId),
      body: {
        'name': ?name,
        'email': ?email,
        'phoneNumber': ?phoneNumber,
        'website': ?website,
        'description': ?description,
      },
      parse: (data) => BCompany.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İşverenin özet sayıları.
  Future<EmployerStats> fetchEmployerStats(String userId) {
    return _apiClient.get<EmployerStats>(
      ApiPaths.employerStats(userId),
      parse: (data) => EmployerStats.fromJson(data! as Map<String, dynamic>),
    );
  }
}
