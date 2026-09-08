import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';

void main() {
  group('PendingVerification.fromJson', () {
    test('sunucunun son kullanma anını okuyor', () {
      final verification = PendingVerification.fromJson({
        'id': 'ver-1',
        'type': 'EMAIL',
        'sentTo': 'yeni@ornek.com',
        'expiresAt': '2026-09-09T20:15:00Z',
      });

      expect(verification.expiresAt, DateTime.utc(2026, 9, 9, 20, 15));
    });

    test('eski sunucu son kullanma anını göndermezse boş bırakıyor', () {
      final verification = PendingVerification.fromJson({
        'id': 'ver-2',
        'type': 'PHONE',
        'sentTo': '5550000000',
      });

      expect(verification.expiresAt, isNull);
    });
  });

  group('PendingVerification.instruction', () {
    test('e-posta doğrulamasında adres cümlesi kuruluyor', () {
      const verification = PendingVerification(
        id: 'ver-1',
        type: 'EMAIL',
        sentTo: 'yeni@ornek.com',
      );

      expect(
        verification.instruction,
        'yeni@ornek.com adresine gönderdiğimiz 6 haneli kodu gir',
      );
    });

    test('telefon doğrulamasında numara cümlesi kuruluyor', () {
      const verification = PendingVerification(
        id: 'ver-2',
        type: 'PHONE',
        sentTo: '5550000000',
      );

      expect(
        verification.instruction,
        '5550000000 numarasına gönderdiğimiz 6 haneli kodu gir',
      );
    });

    // `sentTo` sözleşmede zorunlu değil. Boş gelirse cümle baştaki boşlukla
    // ("  adresine ...") başlamamalı.
    test('hedef boşsa cümle genel hâline düşüyor', () {
      const verification = PendingVerification(id: 'ver-4', type: 'EMAIL');

      expect(verification.instruction, 'Sana gönderdiğimiz 6 haneli kodu gir');
    });
  });
}
