import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_error.dart';

/// Sunucunun `IdentityMessages` sabitlerinden türeyen kodların tamamı.
///
/// Sunucuda mesaj anahtarı koda dönüşüyor (`{identity.sod.unreadable}` →
/// `IDENTITY_SOD_UNREADABLE`, `KoalaException.deriveErrorCode`). Liste
/// burada elle duruyor çünkü asıl amacı **ayrışmayı yakalamak**: sunucuya
/// yeni bir kod eklendiğinde bu test kırılıp istemcinin de karşılık yazması
/// gerektiğini söylüyor.
const List<String> _serverCodes = [
  'IDENTITY_EVIDENCE_REQUIRED',
  'IDENTITY_NO_TRUST_ANCHORS',
  'IDENTITY_SOD_UNREADABLE',
  'IDENTITY_SIGNATURE_INVALID',
  'IDENTITY_UNTRUSTED_DOCUMENT_SIGNER',
  'IDENTITY_DATA_GROUP_TAMPERED',
  'IDENTITY_MRZ_UNREADABLE',
  'IDENTITY_NUMBER_MISMATCH',
  'IDENTITY_BIRTH_DATE_MISMATCH',
  'IDENTITY_NAME_MISMATCH',
  'IDENTITY_CHIP_NOT_PRESENT',
  'IDENTITY_CHIP_KEY_UNREADABLE',
  'IDENTITY_CHIP_KEY_UNSIGNED',
  'IDENTITY_CHALLENGE_INVALID',
  'IDENTITY_ACTIVE_AUTHENTICATION_REQUIRED',
  'TC_IDENTITY_NUMBER_ALREADY_IN_USE',
];

void main() {
  group('IdentityError.fromErrorCode', () {
    test('istemci kodları sunucunun açık kimlik kodu kümesiyle birebir', () {
      final clientCodes = IdentityError.values
          .map((error) => error.code)
          .toSet();

      expect(
        clientCodes,
        _serverCodes.toSet(),
        reason: 'Sunucu ve istemci kimlik hata kodları ayrıştı',
      );

      for (final code in _serverCodes) {
        expect(
          IdentityError.fromErrorCode(code),
          isNotNull,
          reason: '$code için istemcide karşılık yok',
        );
      }
    });

    test('tanınmayan kodda null döner', () {
      // Karşılık uydurmak yerine sunucunun kendi mesajı gösteriliyor.
      expect(IdentityError.fromErrorCode('SOMETHING_ELSE'), isNull);
      expect(IdentityError.fromErrorCode(null), isNull);
    });
  });

  group('IdentityError mesajları', () {
    test('her hata ne yapılacağını söyleyen dolu bir metin taşıyor', () {
      for (final error in IdentityError.values) {
        expect(error.message.trim(), isNotEmpty, reason: error.name);
      }
    });

    test('iki hata aynı kodu paylaşmıyor', () {
      final codes = IdentityError.values.map((error) => error.code).toSet();

      expect(codes.length, IdentityError.values.length);
    });
  });

  group('IdentityError yönlendirmesi', () {
    test('süresi dolan oturum yeni bir challenge istiyor', () {
      // Elde tutulan kanıt artık geçersiz; aynısını tekrar göndermek aynı
      // hatayı verir, kart baştan okunmalı.
      final expired = IdentityError.fromErrorCode('IDENTITY_CHALLENGE_INVALID');

      expect(expired, IdentityError.challengeInvalid);
      expect(expired!.needsFreshChallenge, isTrue);
      expect(expired.retryFromChip, isTrue);
    });

    test('eşleşmeyen beyan kullanıcıyı tekrar okumaya yollamıyor', () {
      // Düzeltilecek şey kart değil, forma yazılan değer.
      for (final code in const [
        'IDENTITY_NUMBER_MISMATCH',
        'IDENTITY_BIRTH_DATE_MISMATCH',
        'IDENTITY_NAME_MISMATCH',
      ]) {
        expect(
          IdentityError.fromErrorCode(code)!.retryFromChip,
          isFalse,
          reason: code,
        );
      }
    });

    test('tanınmayan imzalayan makam için tekrar okumak çözüm değil', () {
      expect(IdentityError.untrustedDocumentSigner.retryFromChip, isFalse);
    });

    test(
      'imzasız çip anahtarı güvenli biçimde yeniden okutmaya yönlendirir',
      () {
        final unsigned = IdentityError.fromErrorCode(
          'IDENTITY_CHIP_KEY_UNSIGNED',
        );

        expect(unsigned, isNotNull);
        if (unsigned == null) return;

        expect(
          unsigned.message,
          'Karttan okunan doğrulama anahtarı güvenlik imzasıyla doğrulanamadı. '
          'Doğrulama tamamlanmadı; kartını yeniden okut. Sorun sürerse destek '
          'ekibimizle iletişime geç.',
        );
        expect(unsigned.retryFromChip, isTrue);
        expect(unsigned.needsFreshChallenge, isFalse);
      },
    );

    test('challenge dışındaki hiçbir hata yeni sayı istemiyor', () {
      final needing = IdentityError.values
          .where((error) => error.needsFreshChallenge)
          .toList();

      expect(needing, [IdentityError.challengeInvalid]);
    });
  });
}
