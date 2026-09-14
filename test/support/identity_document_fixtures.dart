import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';

import 'fake_api.dart';

/// Hiç fotoğraf gönderilmemiş: `GET /users/me/identity-documents` `404`.
const FakeApiResponse noIdentityReviewResponse = FakeApiResponse(
  statusCode: 404,
  body: {
    'success': false,
    'message': 'Henüz TCKK fotoğrafı göndermediniz.',
    'errorCode': 'IDENTITY_DOCUMENTS_NOT_FOUND',
    'errorCategory': 'RESOURCE_NOT_FOUND',
  },
);

/// Sunucunun `IdentityReviewDto` gövdesi; durum ve gerekçe testin verdiği
/// hâlde, geri kalanı sabit.
Map<String, dynamic> identityReviewJson({
  required String status,
  String? rejectionReason,
  String? rejectedAt,
  String createdAt = '2026-09-13T11:05:00Z',
}) {
  return {
    'id': 'review-1',
    'userId': 'user-1',
    'status': status,
    'rejectionReason': ?rejectionReason,
    'rejectedAt': ?rejectedAt,
    'createdAt': createdAt,
  };
}

/// Başarılı inceleme zarfı.
FakeApiResponse identityReviewResponse({
  required String status,
  String? rejectionReason,
  String? rejectedAt,
  int statusCode = 200,
}) {
  return FakeApiResponse(
    statusCode: statusCode,
    body: {
      'success': true,
      'data': identityReviewJson(
        status: status,
        rejectionReason: rejectionReason,
        rejectedAt: rejectedAt,
      ),
    },
  );
}

/// Bir pikselli geçerli PNG: önizleme `Image.file` ile çizildiğinde çözülsün,
/// hata yerine gerçek bir görsel yolu ölçülsün.
final List<int> onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Dört kare için diskte gerçek dosyalar; `MultipartFile.fromFile` yolu
/// açıyor, o yüzden yalnız ad yetmiyor. Test bitince siliniyor. İçerik
/// [onePixelPng]; uzantı sınır kontrolünün baktığı şey, o yüzden ayrı.
Map<IdentityPhotoSlot, IdentityPhoto> writeIdentityPhotos({
  String extension = 'jpg',
}) {
  final directory = Directory.systemTemp.createTempSync('koala-identity-');
  addTearDown(() => directory.deleteSync(recursive: true));

  return {
    for (final slot in IdentityPhotoSlot.values)
      slot: () {
        final file = File('${directory.path}/${slot.name}.$extension')
          ..writeAsBytesSync(onePixelPng);
        return IdentityPhoto(
          slot: slot,
          path: file.path,
          bytes: onePixelPng.length,
        );
      }(),
  };
}
