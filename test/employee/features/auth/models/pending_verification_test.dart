import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';

void main() {
  group('PendingVerification.instruction', () {
    // Sunucunun `message` alanı çözülmemiş bir i18n anahtarı taşıyor
    // (`{email.verification.message}`), o yüzden cümle uygulamada kuruluyor.
    test('e-posta doğrulamasında adres cümlesi kuruluyor', () {
      const verification = PendingVerification(
        id: 'ver-1',
        type: 'EMAIL',
        sentTo: 'yeni@ornek.com',
        message: '{email.verification.message}',
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
        message: '{phone.verification.message}',
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

    test('cümle hiçbir zaman sunucunun ham anahtarını taşımıyor', () {
      const verification = PendingVerification(
        id: 'ver-3',
        type: 'EMAIL',
        sentTo: 'yeni@ornek.com',
        message: '{email.verification.message}',
      );

      expect(verification.instruction, isNot(contains('{')));
    });
  });
}
