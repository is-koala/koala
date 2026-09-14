import 'package:koala/employee/features/settings/models/identity_declaration.dart';
import 'package:koala/employee/features/settings/models/identity_document_error.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';

/// Gönderim ilerlemesi: kaç bayt gitti, toplam kaç bayt.
typedef IdentityUploadProgress = void Function(int sent, int total);

/// `/users/me/identity-documents` uçlarının sarmalayıcısı.
///
/// Çip yolu [UserService]'te (`/users/me/identity-verification`); bu uç
/// **ayrı** çünkü sonucu da ayrı: çip ucu başarıda kimliği hemen
/// damgalıyor, burası yalnız bir inceleme kaydı açıyor ve kimlik personel
/// onayına kadar doğrulanmamış kalıyor.
class IdentityDocumentService {
  IdentityDocumentService._(this._apiClient);

  static final IdentityDocumentService _instance = IdentityDocumentService._(
    ApiClient(),
  );

  factory IdentityDocumentService() => _instance;

  /// Verilen istemciyle kurulu örnek; testler sahte sunucuya bağlıyor.
  factory IdentityDocumentService.withClient(ApiClient apiClient) {
    return IdentityDocumentService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Dört fotoğrafı ve beyanı tek istekte gönderir, açılan incelemeyi döner.
  ///
  /// [photos] dört karenin hepsini taşımalı; eksik kare sunucuda
  /// `IDENTITY_DOCUMENTS_REQUIRED` ile düşer, o yüzden burada
  /// [ArgumentError] — bir ekran hatası, ağ hatası kılığına girmesin.
  /// Beyan `identity` adlı `application/json` parçasında gidiyor: Spring'in
  /// `@RequestPart` çözümlemesi düz form alanı kabul etmiyor.
  Future<IdentityReview> submit({
    required IdentityDeclaration identity,
    required Map<IdentityPhotoSlot, IdentityPhoto> photos,
    IdentityUploadProgress? onProgress,
  }) async {
    final birthDate = identity.birthDate;
    if (birthDate == null) {
      throw ArgumentError.notNull('identity.birthDate');
    }
    for (final slot in IdentityPhotoSlot.values) {
      if (!photos.containsKey(slot)) {
        throw ArgumentError.value(photos, 'photos', '${slot.name} eksik');
      }
    }

    return await _apiClient.postMultipartJsonFiles<IdentityReview>(
      ApiPaths.currentUserIdentityDocuments,
      jsonFieldName: 'identity',
      jsonBody: {
        'firstName': identity.firstName,
        'lastName': identity.lastName,
        'birthDate': birthDate.asLocalDate,
        'tcIdentityNumber': identity.tcIdentityNumber,
        'tcDocumentNumber': identity.tcDocumentNumber,
      },
      // Parça adı ve içerik tipi gerçek içerikten: Android seçicisi
      // `.heic` adlı bir JPEG verebiliyor ve sunucu uzantıya bakıyor.
      files: {
        for (final slot in IdentityPhotoSlot.values)
          slot.fieldName: UploadFile(
            photos[slot]!.path,
            filename: photos[slot]!.uploadName,
            contentType: photos[slot]!.format.mimeType,
          ),
      },
      onSendProgress: onProgress,
      parse: _parseReview,
    );
  }

  /// Oturum sahibinin son incelemesi; hiç yükleme yoksa `null`.
  ///
  /// `404` yalnız `IDENTITY_DOCUMENTS_NOT_FOUND` koduyla "yok" demek. Başka
  /// bir `404` (ör. uç taşındı) ya da başka bir hata olduğu gibi fırlıyor:
  /// ağ hatasını "hiç göndermemiş" diye yorumlamak kullanıcıya yeni bir
  /// yükleme yaptırıp `ALREADY_PENDING` ile geri çevirtirdi.
  Future<IdentityReview?> fetchCurrent() async {
    try {
      return await _apiClient.get<IdentityReview?>(
        ApiPaths.currentUserIdentityDocuments,
        parse: (data) => data == null ? null : _parseReview(data),
      );
    } on ApiException catch (error) {
      if (error.type == ApiErrorType.notFound &&
          error.errorCode == IdentityDocumentError.documentsNotFound.code) {
        return null;
      }
      rethrow;
    }
  }

  static IdentityReview _parseReview(Object? data) {
    final review = IdentityReview.fromJson(data! as Map<String, dynamic>);
    if (review == null) {
      throw const ApiException(
        message: 'Sunucudan beklenmeyen bir yanıt geldi.',
        type: ApiErrorType.unknown,
      );
    }
    return review;
  }
}
