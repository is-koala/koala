import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_document_error.dart';
import 'package:koala/product/network/api_exception.dart';

/// Sunucunun `IdentityMessages` (belge/inceleme), `UserMessages`,
/// `StorageMessages`, `ImageMessages` ve `GlobalExceptionHandler`
/// üzerinden fotoğraflı inceleme uçlarında üretebildiği kodlar.
///
/// Liste elle duruyor: sunucuya yeni bir kod eklendiğinde bu test kırılıp
/// istemcinin karşılık yazması gerektiğini söylüyor. Kodların katalogda
/// gerçekten var olduğunu `test/support/backend_error_codes_test.dart`
/// `messages_tr.properties` üzerinden ayrıca doğruluyor.
const List<String> _serverCodes = [
  'IDENTITY_DOCUMENTS_REQUIRED',
  'IDENTITY_DOCUMENTS_ALREADY_PENDING',
  'IDENTITY_DOCUMENTS_NOT_FOUND',
  'IDENTITY_DOCUMENT_REVIEW_REQUIRED',
  'IDENTITY_REVIEW_ALREADY_DECIDED',
  'IDENTITY_REVIEW_NOT_FOUND',
  'USER_ALREADY_IDENTITY_VERIFIED',
  'TC_IDENTITY_NUMBER_ALREADY_IN_USE',
  'REQUEST_BODY_TOO_LARGE',
  'IMAGE_SIZE_ERROR',
  'STORAGE_UNSUPPORTED_TYPE',
  'STORAGE_IMAGE_TOO_LARGE',
  'IMAGE_UPLOAD_ERROR',
];

ApiException _error({String? code, int? statusCode}) => ApiException(
  message: 'sunucu metni',
  type: ApiErrorType.validation,
  statusCode: statusCode,
  errorCode: code,
);

void main() {
  group('IdentityDocumentError.fromErrorCode', () {
    test('istemci kodları sunucunun belge/inceleme kodlarıyla birebir', () {
      final clientCodes = IdentityDocumentError.values
          .map((error) => error.code)
          .toSet();

      expect(clientCodes, _serverCodes.toSet());
      for (final code in _serverCodes) {
        expect(
          IdentityDocumentError.fromErrorCode(code),
          isNotNull,
          reason: '$code için istemcide karşılık yok',
        );
      }
    });

    test('tanınmayan kodda null', () {
      expect(IdentityDocumentError.fromErrorCode('SOMETHING_ELSE'), isNull);
      expect(IdentityDocumentError.fromErrorCode(null), isNull);
    });
  });

  group('IdentityDocumentError.of', () {
    test('önce kod', () {
      expect(
        IdentityDocumentError.of(
          _error(code: 'IDENTITY_DOCUMENTS_ALREADY_PENDING', statusCode: 400),
        ),
        IdentityDocumentError.alreadyPending,
      );
    });

    test('zarfsız 413 boyut hatası sayılıyor', () {
      // Ara katman büyük gövdeyi uygulama sunucusuna ulaşmadan kesiyor ve
      // HTML bir sayfa döndürüyor; zarf yok, kod yok, yalnız durum var.
      expect(
        IdentityDocumentError.of(_error(statusCode: 413)),
        IdentityDocumentError.requestTooLarge,
      );
    });

    test('kodsuz başka durumda null', () {
      expect(IdentityDocumentError.of(_error(statusCode: 500)), isNull);
      expect(IdentityDocumentError.of(_error()), isNull);
    });
  });

  group('IdentityDocumentError eylemleri', () {
    test('her hata ne yapılacağını söyleyen dolu bir metin taşıyor', () {
      for (final error in IdentityDocumentError.values) {
        expect(error.message.trim(), isNotEmpty, reason: error.name);
        expect(error.message, isNot(contains(error.code)), reason: error.name);
      }
    });

    test('durum değişikliği gerektirenler ekranı duruma yolluyor', () {
      expect(
        IdentityDocumentError.alreadyPending.action,
        IdentityDocumentAction.showStatus,
      );
      expect(
        IdentityDocumentError.reviewAlreadyDecided.action,
        IdentityDocumentAction.showStatus,
      );
      expect(
        IdentityDocumentError.alreadyVerified.action,
        IdentityDocumentAction.alreadyVerified,
      );
      expect(
        IdentityDocumentError.numberAlreadyInUse.action,
        IdentityDocumentAction.contactSupport,
      );
    });

    test('boyut ve biçim hataları yeniden seçtiriyor', () {
      for (final error in const [
        IdentityDocumentError.requestTooLarge,
        IdentityDocumentError.photoTooLarge,
        IdentityDocumentError.unsupportedType,
        IdentityDocumentError.resolutionTooHigh,
        IdentityDocumentError.documentsRequired,
      ]) {
        expect(
          error.action,
          IdentityDocumentAction.reselectPhotos,
          reason: error.name,
        );
      }
    });
  });
}
