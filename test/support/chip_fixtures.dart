import 'dart:convert';
import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';

/// Gerçek bir TCKK düzeninde, kontrol haneleri hesaplanmış TD1 MRZ satırları.
///
/// `mrz_key_test.dart` ile aynı kart: belge no `A01B23456`, TCKN
/// `12345678950`, doğum 07.04.1998, son geçerlilik 01.01.2030, ad-soyad
/// `ADA KAYA`. Üçüncü satır bileşik kontrol hanesine girmiyor; ad
/// değiştirilirken ilk iki satıra dokunmak gerekmiyor.
const String tckkMrzLine1 = 'I<TURA01B23456612345678950<<<<';
const String tckkMrzLine2 = '9804072F3001019TUR<<<<<<<<<<<8';
const String tckkMrzLine3 = 'KAYA<<ADA<<<<<<<<<<<<<<<<<<<<<';

/// Aynı kartın birinci satırı, isteğe bağlı veri alanı ayırıcı `<` ile
/// **başlayan** düzende: `<12345678950<<<`.
///
/// TCKK sahada iki düzenle geliyor ve sunucu ikisini de kabul ediyor
/// (`MachineReadableZone.nationalIdentityNumber` bütün `<`'leri atıp on bir
/// hane arıyor). `dmrtd` yalnız **sondaki** dolguyu temizlediği için bu
/// düzende `optionalData` `<12345678950` olarak kalıyor; ayırıcıyı atmayan
/// bir ayrıştırıcı kartı okunamaz sayardı. İkinci satırı [tckkMrzLine2For]
/// veriyor — bileşik kontrol hanesi birinci satıra bağlı.
const String tckkMrzLine1SeparatorFirst = 'I<TURA01B234566<12345678950<<<';

/// [line1] ile tutarlı ikinci satır: bileşik kontrol hanesi **hesaplanmış**.
///
/// Bileşik hane birinci satırın 6-30. konumlarını da kapsıyor, yani birinci
/// satırı değiştiren her test ikinci satırın son hanesini de değiştirmek
/// zorunda. Elle yazmak yerine `MrzKey.checkDigit` ile hesaplanıyor; `dmrtd`
/// aynı haneyi doğruluyor ve tutmayan bir MRZ DG1 olarak hiç çözülmüyor,
/// yani yanlış hane "TCKN okunamadı" ile karışırdı.
String tckkMrzLine2For(String line1) {
  const stem = '9804072F3001019TUR<<<<<<<<<<<';
  final composite =
      line1.substring(5, 30) +
      stem.substring(0, 7) +
      stem.substring(8, 15) +
      stem.substring(18, 29);
  return '$stem${MrzKey.checkDigit(composite)}';
}

/// `EF.DG1` dosyasının base64 hâli: `61 { 5F1F { 90 baytlık MRZ } }`.
///
/// Çipin yazdığı şeyin birebir aynı yapısı. Testler böylece sahte bir
/// "dg1" dizgisi değil, `dmrtd`'nin gerçekten çözdüğü bir veri grubu
/// gönderiyor — ayrıştırıcının ne yaptığı ancak bununla ölçülüyor.
String encodeDg1({
  String line1 = tckkMrzLine1,
  String line2 = tckkMrzLine2,
  String line3 = tckkMrzLine3,
}) {
  final mrz = Uint8List.fromList(ascii.encode('$line1$line2$line3'));
  return base64Encode(TLV.encode(EfDG1.TAG.value, TLV.encode(0x5F1F, mrz)));
}

/// `EF.DG11` dosyasının base64 hâli: `6B { 5C etiket listesi, 5F0E ad, ... }`.
///
/// [nameOfHolder] ICAO biçiminde: soyad, `<<`, ad; ad bileşenleri `<` ile.
/// UTF-8 yazılıyor, yani ulusal karakterler olduğu gibi kalıyor — DG11'in
/// var olma sebebi bu.
String encodeDg11({required String nameOfHolder, String? personalNumber}) {
  final tags = <int>[
    0x5F,
    0x0E,
    if (personalNumber != null) ...[0x5F, 0x10],
  ];
  final content = <int>[
    ...TLV.encode(EfDG11.TAG_LIST_TAG, Uint8List.fromList(tags)),
    ...TLV.encode(
      EfDG11.FULL_NAME_TAG,
      Uint8List.fromList(utf8.encode(nameOfHolder)),
    ),
    if (personalNumber != null)
      ...TLV.encode(
        EfDG11.PERSONAL_NUMBER_TAG,
        Uint8List.fromList(utf8.encode(personalNumber)),
      ),
  ];
  return base64Encode(
    TLV.encode(EfDG11.TAG.value, Uint8List.fromList(content)),
  );
}

/// Gerçek DG1 (ve isteğe bağlı DG11) taşıyan kanıt.
///
/// SOD sahte: imza zinciri cihaz ve sunucu işi, burada yalnız veri
/// gruplarının ayrıştırılması ölçülüyor. [withChipProof] DG15 + challenge +
/// imza üçlüsünü ekleyip "çip canlı doğrulandı" hâlini üretiyor.
ChipEvidence buildChipEvidence({
  String? dg1,
  String? dg11,
  bool withChipProof = false,
}) {
  return ChipEvidence(
    sod: 'c29k',
    dg1: dg1 ?? encodeDg1(),
    dg11: dg11,
    dg15: withChipProof ? 'ZGcxNQ==' : null,
    challenge: withChipProof ? 'Y2hhbGxlbmdl' : null,
    activeAuthenticationSignature: withChipProof ? 'c2ln' : null,
  );
}

/// Çip ekranının döndürdüğü sonuç; kimlik bilgileri kanıttan türetilmiş.
IdentityChipResult buildChipResult({
  String? dg1,
  String? dg11,
  bool withChipProof = false,
}) {
  final evidence = buildChipEvidence(
    dg1: dg1,
    dg11: dg11,
    withChipProof: withChipProof,
  );
  return IdentityChipResult.parse(evidence)!;
}
