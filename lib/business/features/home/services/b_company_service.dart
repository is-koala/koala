import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/business/features/home/models/employer_stats.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/models/canonical_address.dart';

/// İşverenin şirketini **yazma** uçları ve istatistikleri.
///
/// Okuma burada değil: şirketi çekmek iki uygulamada da aynı uç ve
/// `employee/features/company_detail/services/company_service.dart`'ta
/// duruyor. Burada yalnızca işverene özel, yetki isteyen işlemler var —
/// `b_` öneki de o ayrımı taşıyor.
class BCompanyService {
  BCompanyService._(this._apiClient);

  static final BCompanyService _instance = BCompanyService._(ApiClient());

  factory BCompanyService() => _instance;

  @visibleForTesting
  factory BCompanyService.withClient(ApiClient apiClient) {
    return BCompanyService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Yeni şirket oluşturur; çağıran kullanıcı sunucuda ADMIN yetkilisi olur.
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

  /// Şirketi günceller ve yeni hâlini döndürür.
  ///
  /// Sunucu yalnızca bu beş alanı kabul ediyor (`UpdateCompanyRequestDto`):
  /// vergi numarası, adres, tür ve logo kurulduktan sonra değiştirilemiyor.
  /// Verilmeyen alan gövdeye hiç konmuyor; boş metin göndermek alanı
  /// silmek anlamına gelirdi.
  Future<Company> updateCompany(
    String companyId, {
    String? name,
    String? email,
    String? phoneNumber,
    String? website,
    String? description,
  }) {
    return _apiClient.patch<Company>(
      ApiPaths.company(companyId),
      body: {
        'name': ?name,
        'email': ?email,
        'phoneNumber': ?phoneNumber,
        'website': ?website,
        'description': ?description,
      },
      parse: (data) => Company.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Şirketin logosunu değiştirir.
  ///
  /// Sunucu `multipart/form-data` bekliyor ve parçanın adı **`logo`**.
  /// Yalnızca şirketin `ADMIN` yetkilisi çağırabiliyor; görselin metadata'sı
  /// temizlenerek depoya yazılıyor. Yanıt şirketin yeni hâli.
  Future<Company> updateLogo(String companyId, String filePath) {
    return _apiClient.putFile<Company>(
      ApiPaths.companyLogo(companyId),
      fieldName: 'logo',
      filePath: filePath,
      parse: (data) => Company.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Şirketin logosunu kaldırır.
  ///
  /// Yalnızca bağlantı düşüyor, depodaki nesne silinmiyor.
  Future<Company> removeLogo(String companyId) {
    return _apiClient.delete<Company>(
      ApiPaths.companyLogo(companyId),
      parse: (data) => Company.fromJson(data! as Map<String, dynamic>),
    );
  }

  // ----------------------------------------------------------------- Galeri

  /// Galeriye bir görsel ekler ve galerinin yeni hâlini döndürür.
  ///
  /// Sunucu `multipart/form-data` bekliyor, parçanın adı **`image`** ve
  /// yanına konacak bir JSON parçası yok. Yanıt `201` ve galerinin tamamı;
  /// kapak sunucuda belirleniyor (ilk yüklenen görsel kapak oluyor), istemci
  /// hesaplamıyor. Galeri doluysa `409` geliyor.
  ///
  /// [filePath] okunamıyorsa `ApiException` değil `FileSystemException`
  /// fırlıyor: dosya istekten **önce** okunuyor.
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

  /// Galeriyi toptan değiştirir: sıralama ve kapak seçimi buradan geçiyor.
  ///
  /// **[images] galerinin tamamı olmalı.** Sunucu gövdedeki listede olmayan
  /// kaydı galeriden düşürüyor; yalnız değişen satırı göndermek diğerlerini
  /// silerdi. Sıra listedeki konumdan yazılıyor, galeride bulunmayan bir
  /// görsel gönderilirse `404` geliyor.
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

  /// Görseli galeriden çıkarır ve galerinin yeni hâlini döndürür.
  ///
  /// Kapak silinirse sunucu kalanların ilkini kapak yapıyor.
  Future<List<GalleryImage>> removeCompanyImage(
    String companyId,
    String imageId,
  ) {
    return _apiClient.delete<List<GalleryImage>>(
      ApiPaths.companyImage(companyId, imageId),
      parse: _gallery,
    );
  }

  /// Dört galeri ucunun da döndürdüğü `List<GalleryImageDto>`.
  static List<GalleryImage> _gallery(Object? data) =>
      GalleryImage.listFromJson(data);

  /// İşverenin özet sayıları.
  Future<EmployerStats> fetchEmployerStats(String userId) {
    return _apiClient.get<EmployerStats>(
      ApiPaths.employerStats(userId),
      parse: (data) => EmployerStats.fromJson(data! as Map<String, dynamic>),
    );
  }
}
