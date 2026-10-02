import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence.dart';

import '../../../../support/dispute_evidence_fixtures.dart';

void main() {
  group('DisputeEvidence.fromJson', () {
    test('DisputeEvidenceDto alanlarını okur', () {
      final evidence = DisputeEvidence.fromJson(evidenceJson('ev-1'));

      expect(evidence.id, 'ev-1');
      expect(evidence.disputeId, 'dispute-1');
      expect(evidence.fileName, 'vardiya.jpg');
      expect(evidence.contentType, 'image/jpeg');
      expect(evidence.fileSize, 120 * 1024);
      expect(evidence.createdAt, DateTime.utc(2026, 9, 20, 10));
      expect(evidence.uploaderName, 'Ayşe Yılmaz');
      expect(evidence.kind, EvidenceKind.image);
    });

    test('eksik alanlar çökertmez', () {
      final evidence = DisputeEvidence.fromJson({'id': 'ev-2'});

      expect(evidence.fileName, 'Kanıt dosyası');
      expect(evidence.contentType, 'application/octet-stream');
      expect(evidence.fileSize, 0);
      expect(evidence.uploadedBy, isNull);
      expect(evidence.uploaderName, 'Kullanıcı');
      expect(evidence.createdAt, isNull);
      expect(evidence.kind, EvidenceKind.other);
    });

    test('yükleyenin adı yoksa kullanıcı adına düşer', () {
      final evidence = DisputeEvidence.fromJson({
        ...evidenceJson('ev-3'),
        'uploadedBy': {'id': 'u', 'username': 'ayse'},
      });

      expect(evidence.uploaderName, 'ayse');
    });

    test('negatif ya da sayı olmayan boyut sıfır olur', () {
      expect(
        DisputeEvidence.fromJson({
          ...evidenceJson('a'),
          'fileSize': -5,
        }).fileSize,
        0,
      );
      expect(
        DisputeEvidence.fromJson({
          ...evidenceJson('a'),
          'fileSize': 'x',
        }).fileSize,
        0,
      );
    });
  });

  group('EvidenceKind.of', () {
    test('türü sunucunun içerik tipinden alır', () {
      expect(
        EvidenceKind.of(contentType: 'application/pdf', name: 'a'),
        EvidenceKind.pdf,
      );
      expect(
        EvidenceKind.of(contentType: 'image/webp', name: 'a'),
        EvidenceKind.image,
      );
    });

    test('içerik tipi belirsizse uzantıya bakar', () {
      expect(
        EvidenceKind.of(contentType: 'application/octet-stream', name: 'x.PDF'),
        EvidenceKind.pdf,
      );
      expect(
        EvidenceKind.of(
          contentType: 'application/octet-stream',
          name: 'x.jpeg',
        ),
        EvidenceKind.image,
      );
      expect(
        EvidenceKind.of(contentType: 'application/octet-stream', name: 'x.zip'),
        EvidenceKind.other,
      );
    });
  });

  group('formatFileSize', () {
    test('birimi ve Türkçe ondalık ayracını seçer', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(842), '842 B');
      expect(formatFileSize(1024), '1 KB');
      expect(formatFileSize(1536), '1,5 KB');
      expect(formatFileSize(1024 * 1024), '1 MB');
      expect(formatFileSize((1.4 * 1024 * 1024).round()), '1,4 MB');
      expect(formatFileSize(10 * 1024 * 1024), '10 MB');
    });
  });
}
