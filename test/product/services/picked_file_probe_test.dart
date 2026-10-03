import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/picked_file_probe.dart';

import '../../support/dispute_evidence_fixtures.dart';

void main() {
  group('PickedFileProbe.read', () {
    test('boyutu ve yalnızca ilk on iki baytı okur', () {
      final path = writeEvidenceFile(
        'a.bin',
        List<int>.generate(500, (i) => i % 256),
      );

      final probe = PickedFileProbe.read(path);

      expect(probe.bytes, 500);
      expect(probe.head, hasLength(PickedFileProbe.headLength));
      expect(probe.head, List<int>.generate(12, (i) => i));
    });

    test('on iki bayttan kısa dosyada hepsini verir', () {
      final path = writeEvidenceFile('kisa.bin', const [1, 2, 3]);

      final probe = PickedFileProbe.read(path);

      expect(probe.bytes, 3);
      expect(probe.head, const [1, 2, 3]);
    });

    test('boş dosya sıfır bayt ve boş başlık', () {
      final probe = PickedFileProbe.read(
        writeEvidenceFile('bos.bin', const []),
      );

      expect(probe.bytes, 0);
      expect(probe.head, isEmpty);
    });

    test('olmayan dosya FileSystemException fırlatır', () {
      expect(
        () => PickedFileProbe.read('/yok/boyle/bir/dosya'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
