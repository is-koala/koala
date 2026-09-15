import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/worker_identity.dart';

void main() {
  group('WorkerIdentity.fromJson', () {
    test('tam yanıtı okur', () {
      final identity = WorkerIdentity.fromJson(const {
        'fullName': 'Ayşe Yılmaz',
        'tcIdentityNumber': '10000000146',
        'birthDate': '1994-05-17',
        'verifiedAt': '2026-09-01T09:30:00Z',
        'verificationMethod': 'CHIP',
      });

      expect(identity.fullName, 'Ayşe Yılmaz');
      expect(identity.tcIdentityNumber, '10000000146');
      expect(identity.birthDate, DateTime(1994, 5, 17));
      expect(identity.verifiedAt, DateTime.utc(2026, 9, 1, 9, 30));
      expect(identity.verificationMethod, IdentityVerificationMethod.chip);
    });

    test('isteğe bağlı alanlar eksikken de okunur, yöntem bilinmiyor olur', () {
      final identity = WorkerIdentity.fromJson(const {
        'tcIdentityNumber': '10000000146',
        'verificationMethod': 'BIOMETRIC',
      });

      expect(identity.fullName, '');
      expect(identity.birthDate, isNull);
      expect(identity.verifiedAt, isNull);
      expect(identity.verificationMethod, IdentityVerificationMethod.unknown);
      expect(identity.verificationMethod.displayName, isNull);
    });

    test('TCKN yoksa yanıt reddedilir', () {
      expect(
        () => WorkerIdentity.fromJson(const {'fullName': 'Ayşe Yılmaz'}),
        throwsFormatException,
      );
    });

    test('toString alanları sızdırmaz', () {
      final identity = WorkerIdentity.fromJson(const {
        'fullName': 'Ayşe Yılmaz',
        'tcIdentityNumber': '10000000146',
      });

      expect(identity.toString(), isNot(contains('10000000146')));
      expect(identity.toString(), isNot(contains('Ayşe')));
    });
  });
}
