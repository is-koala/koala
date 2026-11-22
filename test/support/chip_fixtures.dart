import 'dart:convert';
import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';

/// Kontrol haneleri hesaplanmış gerçek düzende TD1 satırları (`mrz_key_test`
/// ile aynı kart).
const String tckkMrzLine1 = 'I<TURA01B23456612345678950<<<<';
const String tckkMrzLine2 = '9804072F3001019TUR<<<<<<<<<<<8';
const String tckkMrzLine3 = 'KAYA<<ADA<<<<<<<<<<<<<<<<<<<<<';

/// Ayırıcıyla **başlayan** düzen: `<12345678950<<<`. `dmrtd` baştaki ayırıcıyı
/// bırakıyor; ayıklamayan ayrıştırıcı kartı okunamaz sayardı.
const String tckkMrzLine1SeparatorFirst = 'I<TURA01B234566<12345678950<<<';

/// Bileşik hane birinci satıra bağlı olduğu için hesaplanıyor; tutmayan MRZ DG1
/// olarak çözülmez ve "TCKN okunamadı" ile karışırdı.
String tckkMrzLine2For(String line1) {
  const stem = '9804072F3001019TUR<<<<<<<<<<<';
  final composite =
      line1.substring(5, 30) +
      stem.substring(0, 7) +
      stem.substring(8, 15) +
      stem.substring(18, 29);
  return '$stem${MrzKey.checkDigit(composite)}';
}

/// Gerçek `EF.DG1` yapısı; ayrıştırıcı ancak bununla ölçülür.
String encodeDg1({
  String line1 = tckkMrzLine1,
  String line2 = tckkMrzLine2,
  String line3 = tckkMrzLine3,
}) {
  final mrz = Uint8List.fromList(ascii.encode('$line1$line2$line3'));
  return base64Encode(TLV.encode(EfDG1.TAG.value, TLV.encode(0x5F1F, mrz)));
}

/// `EF.DG11`; ad ICAO biçiminde ve UTF-8, ulusal karakterler kalıyor.
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

/// Gerçek DG1 (ve DG11) taşıyan kanıt; SOD sahte. [withChipProof] canlı
/// doğrulama üçlüsünü ekler.
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
