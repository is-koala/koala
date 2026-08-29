import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/dispute.dart';

Map<String, dynamic> disputeBody({String status = 'OPEN', String? resolution}) {
  return {
    'id': 'dsp_1',
    'jobAssignmentId': 'asg_1',
    'status': status,
    'reason': 'İş tarif edildiği gibi değildi',
    'resolution': resolution,
    'createdAt': '2026-03-11T08:00:00Z',
    'openedBy': {'id': 'usr_1', 'firstName': 'Ada', 'lastName': 'Kaya'},
  };
}

void main() {
  group('Dispute', () {
    test('sunucu gövdesi modele çevrilir', () {
      final dispute = Dispute.fromJson(disputeBody());

      expect(dispute.id, 'dsp_1');
      expect(dispute.status, DisputeStatus.open);
      expect(dispute.openedBy?.fullName, 'Ada Kaya');
      expect(dispute.resolution, isNull);
    });

    // Açık uyuşmazlık emanetteki parayı donduruyor ve ikinci bir uyuşmazlığı
    // engelliyor; bu ayrım butonların açık olup olmadığını belirliyor.
    test('sonuçlanmamış uyuşmazlık açık sayılır', () {
      expect(Dispute.fromJson(disputeBody()).isOpen, isTrue);
      expect(
        Dispute.fromJson(disputeBody(status: 'UNDER_REVIEW')).isOpen,
        isTrue,
      );
    });

    test('sonuçlanan uyuşmazlık kapalı sayılır', () {
      final dispute = Dispute.fromJson(
        disputeBody(status: 'RESOLVED', resolution: 'RELEASE_TO_WORKER'),
      );

      expect(dispute.isOpen, isFalse);
      expect(dispute.resolution, DisputeResolution.releaseToWorker);
    });

    test('tanınmayan sonuç null kalır', () {
      expect(
        Dispute.fromJson(disputeBody(resolution: 'UZAYLI')).resolution,
        isNull,
      );
    });

    test('açan taraf gelmezse null kalır', () {
      final body = disputeBody()..remove('openedBy');

      expect(Dispute.fromJson(body).openedBy, isNull);
    });
  });
}
