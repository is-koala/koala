import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/employee/features/profile/models/followed_company.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Şirketin okunması ve takip edilmesi.
///
/// **İki uygulama da kullanıyor:** çalışan tarafı şirket detayını, işveren
/// tarafı kendi şirketini buradan okuyor. İşverene özel yazma uçları
/// (güncelleme, logo) `b_company_service`'te kalıyor — yetki de orada ayrı.
class CompanyService {
  CompanyService._(this._apiClient);

  static final CompanyService _instance = CompanyService._(ApiClient());

  factory CompanyService() => _instance;

  @visibleForTesting
  factory CompanyService.withClient(ApiClient apiClient) {
    return CompanyService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Şirketin tam hâli.
  ///
  /// Uç herkese açık. Galeri, takipçi sayısı ve oturum sahibinin takip
  /// durumu da yanıtın içinde; galeriyi ayrıca çekmeye gerek yok.
  Future<Company> fetchCompany(String companyId) {
    return _apiClient.get<Company>(
      ApiPaths.company(companyId),
      parse: (data) => Company.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Şirketi takip eder.
  ///
  /// İdempotent: ikinci istek yeni kayıt açmıyor. Takip edilen şirket ilan
  /// açtığında kullanıcıya bildirim gidiyor.
  Future<void> follow(String companyId) {
    return _apiClient.postWithoutData(ApiPaths.companyFollow(companyId));
  }

  /// Şirket takibini bırakır. Takip edilmeyen şirkette sessizce geçiyor.
  Future<void> unfollow(String companyId) {
    return _apiClient.deleteWithoutData(ApiPaths.companyFollow(companyId));
  }

  /// Oturum sahibinin takip ettiği şirketler, yeniden eskiye.
  ///
  /// Kayıtlar şirketin tam hâli değil, liste için kırpılmış özetler —
  /// ayrıntı için `fetchCompany` gerekiyor.
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
