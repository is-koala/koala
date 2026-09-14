import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/employee/features/settings/services/identity_photo_picker.dart';

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

/// JPEG imzası (`FF D8 FF E0` + JFIF) ve arkasında dolgu; çözülebilir bir
/// görsel değil, biçim tanıma için baş baytlar yeter.
final List<int> jpegSignatureBytes = [
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, //
  ...List<int>.filled(32, 0),
];

/// HEIF kapsayıcısı: `....ftypheic` kutusu; iPhone'un varsayılan biçimi.
final List<int> heicSignatureBytes = [
  0x00, 0x00, 0x00, 0x18, ...'ftypheic'.codeUnits, //
  ...List<int>.filled(32, 0),
];

/// Dört kare için diskte gerçek dosyalar; `MultipartFile.fromFileSync` yolu
/// açıyor, o yüzden yalnız ad yetmiyor. Test bitince siliniyor. İçerik
/// varsayılan olarak [onePixelPng]; [content] ile değiştirilebilir ve
/// [extension] içerikten bağımsız — biçim uzantıdan değil baş baytlardan
/// tanınıyor, ikisi bilerek ayrı.
Map<IdentityPhotoSlot, String> writeIdentityPhotoFiles({
  String extension = 'jpg',
  List<int>? content,
}) {
  final directory = Directory.systemTemp.createTempSync('koala-identity-');
  addTearDown(() => directory.deleteSync(recursive: true));
  final bytes = content ?? onePixelPng;

  return {
    for (final slot in IdentityPhotoSlot.values)
      slot: (File(
        '${directory.path}/${slot.name}.$extension',
      )..writeAsBytesSync(bytes)).path,
  };
}

/// Seçicinin vereceği adaylar: dosyalar diskte, boyut ve baş baytlar okunmuş.
Map<IdentityPhotoSlot, IdentityPhotoCandidate> writeIdentityPhotoCandidates({
  String extension = 'jpg',
  List<int>? content,
}) {
  final files = writeIdentityPhotoFiles(extension: extension, content: content);
  return {
    for (final entry in files.entries)
      entry.key: IdentityPhotoPicker.candidateFor(entry.key, entry.value),
  };
}

/// Kabul edilmiş dört kare; servis testleri doğrudan bunları gönderiyor.
Map<IdentityPhotoSlot, IdentityPhoto> writeIdentityPhotos({
  String extension = 'jpg',
  List<int>? content,
}) {
  final candidates = writeIdentityPhotoCandidates(
    extension: extension,
    content: content,
  );
  return {
    for (final entry in candidates.entries)
      entry.key: IdentityPhotoPolicy.accept(entry.value).photo!,
  };
}
