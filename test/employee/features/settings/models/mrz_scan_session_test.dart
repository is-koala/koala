import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';

void main() {
  test('aynı geçerli MRZ üç ardışık karede görülmeden hazır olmaz', () {
    final session = MrzScanSession(requiredStableFrames: 3);
    final key = MrzKey.manual(
      documentNumber: 'A01B23456',
      birthDate: DateTime(1998, 4, 7),
      expiryDate: DateTime(2030, 1, 1),
    );

    final first = session.observe(MrzFrameObservation.valid(key));
    final second = session.observe(MrzFrameObservation.valid(key));
    final third = session.observe(MrzFrameObservation.valid(key));

    expect(first.isReady, isFalse);
    expect(second.isReady, isFalse);
    expect(third.isReady, isTrue);
    expect(third.key?.documentNumber, 'A01B23456');
    expect(third.message, 'MRZ geçerli, çip okumaya hazır');
  });

  test('geçersiz kare kararlı okuma sayacını sıfırlar', () {
    final session = MrzScanSession(requiredStableFrames: 3);
    final key = MrzKey.manual(
      documentNumber: 'A01B23456',
      birthDate: DateTime(1998, 4, 7),
      expiryDate: DateTime(2030, 1, 1),
    );

    session.observe(MrzFrameObservation.valid(key));
    session.observe(MrzFrameObservation.valid(key));
    final invalid = session.observe(
      const MrzFrameObservation.invalid(MrzScanGuidance.holdSteady),
    );
    final afterReset = session.observe(MrzFrameObservation.valid(key));
    final stillWaiting = session.observe(MrzFrameObservation.valid(key));

    expect(invalid.message, 'Telefonu sabit tut');
    expect(afterReset.isReady, isFalse);
    expect(stillWaiting.isReady, isFalse);
  });
}
