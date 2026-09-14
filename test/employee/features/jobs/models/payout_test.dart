import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';

/// `PayoutDto` (koala-backend#294): hesap ve zaman alanları dolu.
Map<String, dynamic> payoutBody({
  String status = 'COMPLETED',
  Object? maskedIban = 'TR18***2315',
  Object? providerReference = 'IYZ-77',
  Object? settledAt = '2026-09-11T09:00:00Z',
  Object? completedAt = '2026-09-11T09:00:00Z',
}) => {
  'id': 'payout-1',
  'jobAssignmentId': 'assignment-1',
  'jobTitle': 'Barista',
  'companyName': 'Koala Cafe',
  'maskedIban': maskedIban,
  'bankAccountId': 'bank-1',
  'providerReference': providerReference,
  'amount': '950.00',
  'currency': 'TRY',
  'status': status,
  'releasedAt': '2026-09-10T18:00:00Z',
  'settledAt': settledAt,
  'completedAt': completedAt,
  'createdAt': '2026-09-10T18:00:00Z',
};

void main() {
  group('Payout.fromJson', () {
    test('dolu gövde: hesap, referans ve zamanlar okunur', () {
      final payout = Payout.fromJson(payoutBody());

      expect(payout.jobTitle, 'Barista');
      expect(payout.companyName, 'Koala Cafe');
      expect(payout.maskedIban, 'TR18***2315');
      expect(payout.ibanTail, '2315');
      expect(payout.bankAccountId, 'bank-1');
      expect(payout.providerReference, 'IYZ-77');
      expect(payout.releasedAt, DateTime.utc(2026, 9, 10, 18));
      expect(payout.settledAt, DateTime.utc(2026, 9, 11, 9));
      expect(payout.releasedAtOrCreated, DateTime.utc(2026, 9, 10, 18));
      expect(payout.settledAtOrCompleted, DateTime.utc(2026, 9, 11, 9));
    });

    // Hesap silinmişse ya da sağlayıcı referans dönmediyse sunucu `null`
    // gönderiyor; boş dize de aynı kapıya çıkıyor.
    test('null ve boş hesap alanları null kalır', () {
      final payout = Payout.fromJson(
        payoutBody(
          status: 'PENDING',
          maskedIban: null,
          providerReference: '',
          settledAt: null,
          completedAt: null,
        ),
      );

      expect(payout.maskedIban, isNull);
      expect(payout.ibanTail, isNull);
      expect(payout.providerReference, isNull);
      expect(payout.settledAt, isNull);
      expect(payout.settledAtOrCompleted, isNull);
    });

    // Eski sunucu yeni alanların hiçbirini göndermiyor; kayıt yine çözülür,
    // çıkış anı `createdAt`'ten, mutabakat `COMPLETED` kaydın `completedAt`'i.
    test('eski sunucu gövdesi: yeni alanlar yok, yedekler devrede', () {
      final payout = Payout.fromJson({
        'id': 'payout-1',
        'jobAssignmentId': 'assignment-1',
        'amount': '950.00',
        'currency': 'TRY',
        'status': 'COMPLETED',
        'completedAt': '2026-09-11T09:00:00Z',
        'createdAt': '2026-09-10T18:00:00Z',
      });

      expect(payout.jobTitle, isNull);
      expect(payout.companyName, isNull);
      expect(payout.maskedIban, isNull);
      expect(payout.bankAccountId, isNull);
      expect(payout.providerReference, isNull);
      expect(payout.releasedAt, isNull);
      expect(payout.settledAt, isNull);
      expect(payout.releasedAtOrCreated, DateTime.utc(2026, 9, 10, 18));
      expect(payout.settledAtOrCompleted, DateTime.utc(2026, 9, 11, 9));
    });

    // Kesin ifade yalnız `COMPLETED`'da: tamamlanmamış kaydın `completedAt`i
    // gelse bile mutabakat yok sayılır.
    test('tamamlanmamış çıkışta mutabakat anı yok', () {
      final payout = Payout.fromJson(
        payoutBody(status: 'PROCESSING', settledAt: null),
      );

      expect(payout.settledAtOrCompleted, isNull);
    });
  });

  group('PayoutStatus sözlüğü', () {
    test('dört durumun açıklaması sunucu sözlüğüyle aynı', () {
      expect(
        PayoutStatus.pending.description,
        'Çıkışa alındı — sağlayıcı onayı bekleniyor',
      );
      expect(
        PayoutStatus.processing.description,
        'Onaylandı — banka transferi yolda',
      );
      expect(
        PayoutStatus.completed.description,
        'Hesabınıza geçti (ekstre ile doğrulandı)',
      );
      expect(PayoutStatus.failed.description, 'Çıkış başarısız');
    });

    // "Hesabınıza geçti" gibi kesin ifade yalnız COMPLETED'da; öteki üç
    // durumun hiçbir metni parayı hesapta göstermiyor.
    test('kesin ifade yalnız COMPLETED metinlerinde', () {
      for (final status in PayoutStatus.values) {
        final texts = '${status.displayName} ${status.description}';
        final definitive = texts.contains('Hesabınıza geçti');

        expect(definitive, status.isSettled, reason: status.code);
      }
    });

    test('tanınmayan kod PENDING sayılır', () {
      expect(PayoutStatus.fromCode('SOMETHING'), PayoutStatus.pending);
    });
  });
}
