import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_declaration.dart';
import 'package:koala/employee/features/settings/models/identity_document_error.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';
import '../../../../support/identity_document_fixtures.dart';

const _declaration = ManualDeclaration(
  firstName: 'Çağrı',
  lastName: 'Kaya',
  tcIdentityNumber: '12345678950',
  tcDocumentNumber: 'A01B23456',
  birthDate: null,
);

ManualDeclaration _complete() => ManualDeclaration(
  firstName: _declaration.firstName,
  lastName: _declaration.lastName,
  tcIdentityNumber: _declaration.tcIdentityNumber,
  tcDocumentNumber: _declaration.tcDocumentNumber,
  birthDate: DateTime(1998, 4, 7),
);

/// Multipart parçasının gövdesini okur; dio gövdeyi bir kez akıttığı için
/// kopyasından.
Future<String> _partBody(MultipartFile part) async {
  final bytes = await part.clone().finalize().fold<List<int>>(
    <int>[],
    (all, chunk) => all..addAll(chunk),
  );
  return utf8.decode(bytes);
}

void main() {
  group('IdentityDocumentService.submit', () {
    test('beyanı JSON parçası, dört kareyi kendi parçalarıyla tek istekte '
        'gönderiyor', () async {
      final api = FakeApi(
        handler: (_) =>
            identityReviewResponse(status: 'PENDING', statusCode: 201),
      );
      final photos = writeIdentityPhotos();

      final review = await IdentityDocumentService.withClient(
        api.client,
      ).submit(identity: _complete(), photos: photos);

      final request = api.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/users/me/identity-documents');
      expect(request.contentType, startsWith('multipart/form-data'));

      final form = request.data as FormData;
      expect(form.fields, isEmpty, reason: 'düz form alanı yok, hepsi parça');
      final keys = form.files.map((part) => part.key).toList();
      expect(keys, ['identity', 'front', 'back', 'selfie', 'together']);

      final identityPart = form.files
          .singleWhere((part) => part.key == 'identity')
          .value;
      expect(
        identityPart.contentType.toString(),
        startsWith('application/json'),
      );
      final identity =
          jsonDecode(await _partBody(identityPart)) as Map<String, dynamic>;
      expect(identity, {
        'firstName': 'Çağrı',
        'lastName': 'Kaya',
        'birthDate': '1998-04-07',
        'tcIdentityNumber': '12345678950',
        'tcDocumentNumber': 'A01B23456',
      });

      for (final slot in IdentityPhotoSlot.values) {
        final part = form.files
            .singleWhere((entry) => entry.key == slot.fieldName)
            .value;
        // Ad ve içerik tipi dosyanın `.jpg` adından değil PNG içeriğinden:
        // sunucu uzantıya bakıyor, uzantı da gerçeği söylemeli.
        expect(part.filename, '${slot.fieldName}.png', reason: slot.name);
        expect(part.contentType?.mimeType, 'image/png', reason: slot.name);
      }

      expect(review.status, IdentityReviewStatus.pending);
      expect(review.id, 'review-1');
    });

    test('eksik kare sunucuya gitmeden ArgumentError', () async {
      final api = FakeApi(
        handler: (_) => identityReviewResponse(status: 'PENDING'),
      );
      final photos = writeIdentityPhotos()..remove(IdentityPhotoSlot.together);

      await expectLater(
        IdentityDocumentService.withClient(
          api.client,
        ).submit(identity: _complete(), photos: photos),
        throwsArgumentError,
      );
      expect(api.requests, isEmpty);
    });

    test(
      'doğum tarihi olmayan beyan sunucuya gitmeden ArgumentError',
      () async {
        final api = FakeApi(
          handler: (_) => identityReviewResponse(status: 'PENDING'),
        );

        await expectLater(
          IdentityDocumentService.withClient(
            api.client,
          ).submit(identity: _declaration, photos: writeIdentityPhotos()),
          throwsArgumentError,
        );
        expect(api.requests, isEmpty);
      },
    );

    group('sunucu reddi', () {
      Future<ApiException> submitAgainst(FakeApiResponse response) async {
        final api = FakeApi(handler: (_) => response);
        try {
          await IdentityDocumentService.withClient(
            api.client,
          ).submit(identity: _complete(), photos: writeIdentityPhotos());
        } on ApiException catch (error) {
          return error;
        }
        fail('istek reddedilmeliydi');
      }

      test('413 zarfıyla: kod ve durum olduğu gibi taşınıyor', () async {
        final error = await submitAgainst(
          const FakeApiResponse(
            statusCode: 413,
            body: {
              'success': false,
              'message': 'İstek gövdesi izin verilen boyutu aşıyor.',
              'errorCode': 'REQUEST_BODY_TOO_LARGE',
              'errorCategory': 'REQUEST_MALFORMED',
            },
          ),
        );

        expect(error.statusCode, 413);
        expect(error.errorCode, 'REQUEST_BODY_TOO_LARGE');
        expect(
          IdentityDocumentError.of(error),
          IdentityDocumentError.requestTooLarge,
        );
      });

      test(
        '413 zarfsız (ara katman): yine boyut hatası olarak tanınıyor',
        () async {
          final error = await submitAgainst(
            const FakeApiResponse.raw(
              statusCode: 413,
              body: '<html>413 Request Entity Too Large</html>',
            ),
          );

          expect(error.statusCode, 413);
          expect(error.errorCode, isNull);
          expect(
            IdentityDocumentError.of(error),
            IdentityDocumentError.requestTooLarge,
          );
        },
      );

      test('400 bekleyen inceleme: kod taşınıyor', () async {
        final error = await submitAgainst(
          const FakeApiResponse(
            statusCode: 400,
            body: {
              'success': false,
              'message': 'Bekleyen bir TCKK incelemeniz var.',
              'errorCode': 'IDENTITY_DOCUMENTS_ALREADY_PENDING',
              'errorCategory': 'VALIDATION_FAILED',
            },
          ),
        );

        expect(error.statusCode, 400);
        expect(error.type, ApiErrorType.validation);
        expect(
          IdentityDocumentError.of(error),
          IdentityDocumentError.alreadyPending,
        );
      });

      test('409 kimlik numarası başka hesapta: kod taşınıyor', () async {
        final error = await submitAgainst(
          const FakeApiResponse(
            statusCode: 409,
            body: {
              'success': false,
              'message': 'Bu kimlik numarası başka bir hesapta kayıtlı.',
              'errorCode': 'TC_IDENTITY_NUMBER_ALREADY_IN_USE',
              'errorCategory': 'DATA_CONFLICT',
            },
          ),
        );

        expect(error.statusCode, 409);
        expect(
          IdentityDocumentError.of(error),
          IdentityDocumentError.numberAlreadyInUse,
        );
      });
    });
  });

  group('IdentityDocumentService.fetchCurrent', () {
    test('son incelemeyi döndürüyor', () async {
      final api = FakeApi(
        handler: (_) => identityReviewResponse(
          status: 'REJECTED',
          rejectionReason: 'Arka yüz bulanık',
          rejectedAt: '2026-09-13T12:00:00Z',
        ),
      );

      final review = await IdentityDocumentService.withClient(
        api.client,
      ).fetchCurrent();

      expect(api.requests.single.method, 'GET');
      expect(api.requests.single.path, '/users/me/identity-documents');
      expect(review, isNotNull);
      expect(review!.status, IdentityReviewStatus.rejected);
      expect(review.rejectionReason, 'Arka yüz bulanık');
      expect(review.rejectedAt, isNotNull);
    });

    test('IDENTITY_DOCUMENTS_NOT_FOUND ile 404 "yok" demek: null', () async {
      final api = FakeApi(handler: (_) => noIdentityReviewResponse);

      final review = await IdentityDocumentService.withClient(
        api.client,
      ).fetchCurrent();

      expect(review, isNull);
    });

    test('başka bir 404 yutulmuyor', () async {
      // Uç taşınmış ya da başka bir kayıt yok: "hiç göndermemiş" değil.
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'errorCode': 'ENDPOINT_NOT_FOUND',
            'errorCategory': 'ENDPOINT_NOT_FOUND',
          },
        ),
      );

      await expectLater(
        IdentityDocumentService.withClient(api.client).fetchCurrent(),
        throwsA(isA<ApiException>()),
      );
    });

    test('ağ hatası yutulmuyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse.connectionError(),
      );

      await expectLater(
        IdentityDocumentService.withClient(api.client).fetchCurrent(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.network,
          ),
        ),
      );
    });

    test('tanınmayan durum beklenmeyen yanıt hatası', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'id': 'review-1', 'status': 'SOMETHING_NEW'},
          },
        ),
      );

      await expectLater(
        IdentityDocumentService.withClient(api.client).fetchCurrent(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.unknown,
          ),
        ),
      );
    });
  });
}
