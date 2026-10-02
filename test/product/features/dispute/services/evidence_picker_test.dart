import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/features/dispute/services/evidence_picker.dart';

import '../../../../support/dispute_evidence_fixtures.dart';

void main() {
  group('EvidencePicker.candidateFor', () {
    test('boyutu ve yalnızca ilk on iki baytı okur', () {
      final path = writeEvidenceFile('a.pdf', [
        ...pdfBytes,
        ...List.filled(500, 7),
      ]);

      final candidate = EvidencePicker.candidateFor(
        path,
        displayName: 'tutanak',
      );

      expect(candidate.path, path);
      expect(candidate.bytes, pdfBytes.length + 500);
      expect(candidate.head, hasLength(EvidenceFormat.signatureLength));
      expect(EvidenceFormat.detect(candidate.head), EvidenceFormat.pdf);
      expect(candidate.displayName, 'tutanak');
    });

    test('boş dosya sıfır bayt ve boş başlık', () {
      final path = writeEvidenceFile('bos.pdf', const []);

      final candidate = EvidencePicker.candidateFor(path, displayName: 'bos');

      expect(candidate.bytes, 0);
      expect(candidate.head, isEmpty);
      expect(
        DisputeEvidencePolicy.accept(candidate).rejection,
        EvidenceRejection.empty,
      );
    });
  });

  group('EvidencePicker.photoName', () {
    test('çekim anından saniyeye kadar ad üretir', () {
      expect(
        EvidencePicker.photoName(DateTime(2026, 10, 3, 9, 5, 7)),
        'foto-20261003-090507',
      );
    });

    test('aynı dakikadaki iki fotoğraf ayırt edilir', () {
      expect(
        EvidencePicker.photoName(DateTime(2026, 10, 3, 9, 5, 7)),
        isNot(EvidencePicker.photoName(DateTime(2026, 10, 3, 9, 5, 8))),
      );
    });
  });

  test('üç kaynak: kamera, galeri, belge', () {
    expect(EvidenceSource.values, [
      EvidenceSource.camera,
      EvidenceSource.gallery,
      EvidenceSource.document,
    ]);
  });
}
