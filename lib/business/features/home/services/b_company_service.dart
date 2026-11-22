import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/business/features/home/models/employer_stats.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/models/canonical_address.dart';

/// İşverenin şirketini **yazma** uçları; okuma iki uygulamanın ortak
/// `company_service.dart`'ında.
class BCompanyService {
  BCompanyService._(this._apiClient);

  static final BCompanyService _instance = BCompanyService._(ApiClient());

  factory BCompanyService() => _instance;

  @visibleForTesting
  factory BCompanyService.withClient(ApiClient apiClient) {
    return BCompanyService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Çağıran sunucuda ADMIN yetkilisi olur.
  Future<Company> createCompany({
    required String name,
    required String email,
    required String phoneNumber,
    required String taxNumber,
    required CompanyType type,
    required AddressWrite address,
    String? website,
    String? description,
    String? logoPath,
  }) {
    return _apiClient.postMultipartJson<Company>(
      ApiPaths.companies,
      jsonFieldName: 'company',
      jsonBody: {
        'name': name,
        'email': email,
        'phoneNumber': phoneNumber,
        'taxNumber': taxNumber,
        'type': type.code,
        'address': address.toJson(),
        'website': ?website,
        'description': ?description,
      },
      fileFieldName: logoPath == null ? null : 'logo',
      filePath: logoPath,
      parse: (data) => Company.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Şirketi günceller. Vergi numarası, tür ve logo buradan değişmez;
  /// verilmeyen alan gövdeye konmaz, boş metin alanı silerdi. [address] yeni
  /// bir adres kaydı açar. Yalnız `ADMIN`.
  Future<Company> updateCompany(
    String companyId, {
    String? name,
    String? email,
    String? phoneNumber,
    String? website,
    String? description,
    AddressWrite? address,
  }) {
    return _apiClient.patch<Company>(
      ApiPaths.company(companyId),
      body: {
        'name': ?name,
        'email': ?email,
        'phoneNumber': ?phoneNumber,
        'website': ?website,
        'description': ?description,
        'address': ?address?.toJson(),
      },
      parse: (data) => Company.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Parça adı **`logo`**; yalnız `ADMIN`. Yanıt şirketin yeni hâli.
  Future<Company> updateLogo(String companyId, String filePath) {
    return _apiClient.putFile<Company>(
      ApiPaths.companyLogo(companyId),
      fieldName: 'logo',
      filePath: filePath,
      parse: (data) => Company.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Yalnız bağlantı düşer, depodaki nesne kalır.
  Future<Company> removeLogo(String companyId) {
    return _apiClient.delete<Company>(
      ApiPaths.companyLogo(companyId),
      parse: (data) => Company.fromJson(data! as Map<String, dynamic>),
    );
  }

  // ----------------------------------------------------------------- Galeri

  /// Galeriye görsel ekler; parça adı **`image`**, JSON parçası yok. Kapağı
  /// sunucu belirler. Galeri doluysa `409`. Dosya istekten önce okunduğu için
  /// okunamazsa `FileSystemException` fırlar.
  Future<List<GalleryImage>> addCompanyImage(
    String companyId,
    String filePath,
  ) {
    return _apiClient.postFile<List<GalleryImage>>(
      ApiPaths.companyImages(companyId),
      fieldName: 'image',
      filePath: filePath,
      parse: _gallery,
    );
  }

  /// Galeriyi toptan değiştirir (sıra ve kapak). **[images] galerinin tamamı
  /// olmalı**: listede olmayan görsel düşer.
  Future<List<GalleryImage>> replaceCompanyGallery(
    String companyId,
    List<GalleryImage> images,
  ) {
    return _apiClient.put<List<GalleryImage>>(
      ApiPaths.companyImages(companyId),
      body: {
        'images': [
          for (final (index, image) in images.indexed)
            image.toEntryJson(sortOrder: index),
        ],
      },
      parse: _gallery,
    );
  }

  /// Kapak silinirse sunucu kalanların ilkini kapak yapar.
  Future<List<GalleryImage>> removeCompanyImage(
    String companyId,
    String imageId,
  ) {
    return _apiClient.delete<List<GalleryImage>>(
      ApiPaths.companyImage(companyId, imageId),
      parse: _gallery,
    );
  }

  static List<GalleryImage> _gallery(Object? data) =>
      GalleryImage.listFromJson(data);

  Future<EmployerStats> fetchEmployerStats(String userId) {
    return _apiClient.get<EmployerStats>(
      ApiPaths.employerStats(userId),
      parse: (data) => EmployerStats.fromJson(data! as Map<String, dynamic>),
    );
  }
}
