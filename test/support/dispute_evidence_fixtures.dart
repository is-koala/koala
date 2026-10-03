import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/features/dispute/services/evidence_picker.dart';

import 'fake_api.dart';

export 'identity_document_fixtures.dart'
    show heicSignatureBytes, jpegSignatureBytes, onePixelPng;

/// `%PDF-1.4` ile başlayan en küçük PDF benzeri içerik; biçim tanıma için baş
/// baytlar yeter.
final List<int> pdfBytes = [
  ...'%PDF-1.4\n'.codeUnits,
  ...List<int>.filled(32, 0),
];

/// `GET /job-assignments/{id}/disputes` satırı (`DisputeDto`).
Map<String, dynamic> disputeJson(
  String id, {
  String assignmentId = 'assignment-1',
  String status = 'OPEN',
  String reason = 'Ücret eksik ödendi',
  String createdAt = '2026-09-20T09:00:00Z',
  String openedByFirstName = 'Ayşe',
  String? resolution,
  String? resolutionNote,
}) {
  return {
    'id': id,
    'jobAssignmentId': assignmentId,
    'openedBy': {
      'id': 'worker-1',
      'firstName': openedByFirstName,
      'lastName': 'Yılmaz',
    },
    'openedBySide': 'WORKER',
    'status': status,
    'reason': reason,
    'resolution': resolution,
    'resolutionNote': resolutionNote,
    'createdAt': createdAt,
  };
}

/// `DisputeEvidenceDto`.
Map<String, dynamic> evidenceJson(
  String id, {
  String disputeId = 'dispute-1',
  String fileName = 'vardiya.jpg',
  String contentType = 'image/jpeg',
  int fileSize = 120 * 1024,
  String uploader = 'Ayşe',
  String createdAt = '2026-09-20T10:00:00Z',
}) {
  return {
    'id': id,
    'disputeId': disputeId,
    'uploadedBy': {
      'id': 'worker-1',
      'firstName': uploader,
      'lastName': 'Yılmaz',
    },
    'fileName': fileName,
    'contentType': contentType,
    'fileSize': fileSize,
    'checksumSha256': 'abc123',
    'createdAt': createdAt,
  };
}

FakeApiResponse dataResponse(Object data, {int statusCode = 200}) =>
    FakeApiResponse(
      statusCode: statusCode,
      body: {'success': true, 'data': data},
    );

/// Hata zarfı: sunucunun `errorCode`'u ve kategorisiyle.
FakeApiResponse errorResponse(
  int statusCode,
  String errorCode, {
  String message = 'Sunucu mesajı',
  String? category,
}) {
  return FakeApiResponse(
    statusCode: statusCode,
    body: {
      'success': false,
      'message': message,
      'errorCode': errorCode,
      'errorCategory': ?category,
    },
  );
}

/// Diskte gerçek bir dosya yazar (`MultipartFile.fromFileSync` yolu açıyor);
/// test bitince silinir.
String writeEvidenceFile(String name, List<int> content) {
  final directory = Directory.systemTemp.createTempSync('koala-evidence-');
  addTearDown(() => directory.deleteSync(recursive: true));
  final file = File('${directory.path}/$name')..writeAsBytesSync(content);
  return file.path;
}

/// Belge seçicisinin vereceği aday: dosya diskte, boyut ve baş baytlar
/// içerikten; ad kullanıcının dosyasının adı (ya da [displayName]).
EvidenceCandidate candidateFrom(
  String name,
  List<int> content, {
  String? displayName,
}) {
  final path = writeEvidenceFile(name, content);
  return EvidencePicker.candidateFor(path, displayName: displayName ?? name);
}

/// Kamera ya da galerinin vereceği aday: **adı yok** — seçicinin geçici adı
/// taşınmıyor, ad yükleme anında üretiliyor.
EvidenceCandidate photoCandidate(String name, List<int> content) {
  final path = writeEvidenceFile(name, content);
  return EvidencePicker.candidateFor(path);
}

/// Kamera/galeri/belge seçicisinin yerine geçer: sırayla verilen adayları
/// döndürür; `null` kullanıcının vazgeçtiği anlamına geliyor.
class FakeEvidencePicker implements EvidencePicker {
  FakeEvidencePicker(this._queue, {this.error});

  final List<EvidenceCandidate?> _queue;

  /// Doluysa `pick` bunu fırlatır (izin reddi gibi).
  final Object? error;

  final List<EvidenceSource> sources = [];

  @override
  Future<EvidenceCandidate?> pick(EvidenceSource source) async {
    sources.add(source);
    final failure = error;
    if (failure != null) throw failure;
    return _queue.isEmpty ? null : _queue.removeAt(0);
  }
}
