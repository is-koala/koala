import 'package:koala/employee/features/settings/models/identity_declaration.dart';
import 'package:koala/employee/features/settings/models/identity_document_error.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/api_paths.dart';

typedef IdentityUploadProgress = void Function(int sent, int total);

/// Fotoğraflı inceleme uçları. Çip ucu kimliği hemen damgalıyor; bu yalnız
/// inceleme açıyor, kimlik onaya kadar doğrulanmamış kalır.
class IdentityDocumentService {
  IdentityDocumentService._(this._apiClient);

  static final IdentityDocumentService _instance = IdentityDocumentService._(
    ApiClient(),
  );

  factory IdentityDocumentService() => _instance;

  factory IdentityDocumentService.withClient(ApiClient apiClient) {
    return IdentityDocumentService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Dört fotoğrafı ve beyanı tek istekte gönderir. Eksik kare [ArgumentError]:
  /// ekran hatası ağ hatası kılığına girmesin. Beyan `identity` adlı JSON
  /// parçasında (`@RequestPart`).
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
      // Parça adı ve tip gerçek içerikten; sunucu uzantıya bakıyor.
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

  /// Hiç yükleme yoksa `null`; yalnız `IDENTITY_DOCUMENTS_NOT_FOUND` "yok"
  /// demek. Başka hatayı "göndermemiş" saymak `ALREADY_PENDING`'e çarptırırdı.
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
