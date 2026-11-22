import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/employee/features/profile/models/followed_company.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Şirket okuma ve takip; iki uygulama kullanıyor. Yazma uçları
/// `b_company_service`'te.
class CompanyService {
  CompanyService._(this._apiClient);

  static final CompanyService _instance = CompanyService._(ApiClient());

  factory CompanyService() => _instance;

  @visibleForTesting
  factory CompanyService.withClient(ApiClient apiClient) {
    return CompanyService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Herkese açık; galeri ve takip durumu da yanıtta.
  Future<Company> fetchCompany(String companyId) {
    return _apiClient.get<Company>(
      ApiPaths.company(companyId),
      parse: (data) => Company.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İdempotent. Takip edilen şirket ilan açınca bildirim gider.
  Future<void> follow(String companyId) {
    return _apiClient.postWithoutData(ApiPaths.companyFollow(companyId));
  }

  /// Takip edilmeyende sessizce geçer.
  Future<void> unfollow(String companyId) {
    return _apiClient.deleteWithoutData(ApiPaths.companyFollow(companyId));
  }

  /// Kırpılmış özetler; ayrıntı için `fetchCompany`.
  Future<FollowedCompanyPage> fetchFollowedCompanies({
    int page = 0,
    int size = 20,
  }) {
    return _apiClient.get<FollowedCompanyPage>(
      ApiPaths.followedCompanies,
      queryParameters: {'page': page, 'size': size},
      parse: (data) =>
          FollowedCompanyPage.fromJson(data! as Map<String, dynamic>),
    );
  }
}
