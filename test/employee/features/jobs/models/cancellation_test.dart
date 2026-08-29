import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';

Map<String, dynamic> cancellationBody({
  String party = 'EMPLOYER',
  num feeRate = 0.5,
  num feeAmount = 750,
  num refundAmount = 750,
}) {
  return {
    'id': 'cnc_1',
    'jobAssignmentId': 'asg_1',
    'cancelledByParty': party,
    'reason': 'Etkinlik ertelendi',
    'noticeMinutes': 300,
    'feeRate': feeRate,
    'feeAmount': feeAmount,
    'refundAmount': refundAmount,
    'cancelledAt': '2026-03-09T12:00:00Z',
  };
}

void main() {
  group('Cancellation', () {
    test('sunucu gövdesi modele çevrilir', () {
      final cancellation = Cancellation.fromJson(cancellationBody());

      expect(cancellation.id, 'cnc_1');
      expect(cancellation.assignmentId, 'asg_1');
      expect(cancellation.cancelledByParty, CancellationParty.employer);
      expect(cancellation.noticeMinutes, 300);
      expect(cancellation.refundAmount, 750);
    });

    test('kesinti uygulandıysa hasFee true', () {
      expect(Cancellation.fromJson(cancellationBody()).hasFee, isTrue);
    });

    // Çalışanın iptalinde kesinti yok; işveren tam iade alıyor.
    test('kesintisiz iptalde hasFee false', () {
      final cancellation = Cancellation.fromJson(
        cancellationBody(party: 'WORKER', feeRate: 0, feeAmount: 0),
      );

      expect(cancellation.hasFee, isFalse);
      expect(cancellation.cancelledByParty, CancellationParty.worker);
    });

    // Kullanıcıya "%50 kesinti" diye yazmak için.
    test('oran yüzdeye çevrilir', () {
      expect(Cancellation.fromJson(cancellationBody()).feePercent, 50);
    });

    test('tanınmayan taraf Koala sayılır', () {
      expect(
        Cancellation.fromJson(
          cancellationBody(party: 'UZAYLI'),
        ).cancelledByParty,
        CancellationParty.admin,
      );
    });
  });
}
