import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/chip_evidence.dart';

/// Kanıtın istek gövdesine nasıl döküldüğü sözleşmenin kendisi: sunucu
/// (`VerifyIdentityDto`) alan adlarını birebir bekliyor ve `null` ile boş
/// metni ayırıyor.
void main() {
  group('ChipEvidence.toJson', () {
    test('DG14 okunduysa gövdeye `dg14` olarak giriyor', () {
      // Sunucu Active Authentication imzasını hangi algoritmayla
      // doğrulayacağını buradan öğreniyor; alan adı sunucuyla ortak
      // (is-koala/koala-backend#253).
      const evidence = ChipEvidence(
        sod: 'c29k',
        dg1: 'ZGcx',
        dg14: 'ZGcxNA==',
        dg15: 'ZGcxNQ==',
        challenge: 'Y2hhbGxlbmdl',
        activeAuthenticationSignature: 'c2ln',
      );

      final json = evidence.toJson();

      expect(json['dg14'], 'ZGcxNA==');
      expect(json.keys, {
        'sod',
        'dg1',
        'dg14',
        'dg15',
        'challenge',
        'activeAuthenticationSignature',
      });
    });

    test('DG14 yoksa anahtar gövdeye hiç konmuyor', () {
      // `null` göndermek yerine alanı atlıyoruz: sunucu yokluğu "algoritma
      // yelpazesini geniş tut" olarak okuyor, boş metni ise çözmeye
      // çalışırdı.
      const evidence = ChipEvidence(sod: 'c29k', dg1: 'ZGcx');

      final json = evidence.toJson();

      expect(json.containsKey('dg14'), isFalse);
      expect(json.keys, {'sod', 'dg1'});
    });

    test('bütün isteğe bağlı gruplar birlikte tam gövdeyi kuruyor', () {
      const evidence = ChipEvidence(
        sod: 'c29k',
        dg1: 'ZGcx',
        dg11: 'ZGcxMQ==',
        dg14: 'ZGcxNA==',
        dg15: 'ZGcxNQ==',
        challenge: 'Y2hhbGxlbmdl',
        activeAuthenticationSignature: 'c2ln',
      );

      expect(evidence.toJson(), {
        'sod': 'c29k',
        'dg1': 'ZGcx',
        'dg11': 'ZGcxMQ==',
        'dg14': 'ZGcxNA==',
        'dg15': 'ZGcxNQ==',
        'challenge': 'Y2hhbGxlbmdl',
        'activeAuthenticationSignature': 'c2ln',
      });
    });
  });

  group('ChipEvidence.provesChipPresence', () {
    test('DG14 tek başına çip varlığını kanıtlamıyor', () {
      // DG14 algoritma bilgisi; imzanın kendisi değil. Çipin canlı olduğunu
      // yalnız DG15 + challenge + imza üçlüsü söylüyor.
      const evidence = ChipEvidence(sod: 'c29k', dg1: 'ZGcx', dg14: 'ZGcxNA==');

      expect(evidence.provesChipPresence, isFalse);
    });

    test('DG14 olmadan da imza üçlüsü çip varlığını kanıtlıyor', () {
      const evidence = ChipEvidence(
        sod: 'c29k',
        dg1: 'ZGcx',
        dg15: 'ZGcxNQ==',
        challenge: 'Y2hhbGxlbmdl',
        activeAuthenticationSignature: 'c2ln',
      );

      expect(evidence.provesChipPresence, isTrue);
    });
  });
}
