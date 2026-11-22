import 'dart:convert';

import 'package:dmrtd/dmrtd.dart';
import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/national_identity_number.dart';

/// Çipin söylediği kart sahibi; yalnız gönderilecek veri gruplarından türüyor,
/// ekrandaki değer ile kanıt aynı baytlardan çıkıyor.
///
/// Kaynak sunucununkiyle aynı:
/// - **TCKN, doğum tarihi, belge no → DG1.**
/// - **Ad, soyad → DG11, yoksa DG1.** MRZ ulusal karakterleri ASCII'ye katlıyor
///   (**ÇAĞRI** → **CAGRI**); DG11 yoksa ad olduğu gibi kalır, tahmin yapılmaz.
///
/// Harf büyüklüğü de karttaki gibi (`IŞIK` → `Işık` mı `Isık` mı tahmin olur).
class ChipHolder {
  const ChipHolder({
    required this.firstName,
    required this.lastName,
    required this.nationalIdentityNumber,
    required this.birthDate,
    required this.documentNumber,
  });

  final String firstName;

  final String lastName;

  final String nationalIdentityNumber;

  final DateTime birthDate;

  /// `<` dolgusu temizlenmiş.
  final String documentNumber;

  /// DG1 çözümlenemiyor ya da TCKN yoksa `null`: sunucu da `MRZ_UNREADABLE` ile
  /// reddederdi.
  static ChipHolder? fromEvidence(ChipEvidence evidence) {
    final MRZ mrz;
    final String firstName;
    final String lastName;
    try {
      mrz = EfDG1.fromBytes(base64Decode(evidence.dg1)).mrz;
      // `dmrtd` ad alanlarını `late` tutuyor; `<<`'siz MRZ'de okumak fırlatır.
      firstName = mrz.firstName;
      lastName = mrz.lastName;
    } on Object {
      return null;
    }

    // `MrzKey` ile ortak kural: dolgu atılıp on bir hane aranır. `dmrtd` yalnız
    // sondaki `<`'leri temizlediği için `<12345678950` gibi alanlar da okunsun.
    final identityNumber = NationalIdentityNumber.fromMrzOptionalData(
      mrz.optionalData,
    );
    if (identityNumber == null) return null;

    final documentNumber = mrz.documentNumber.trim();
    if (documentNumber.isEmpty) return null;

    final national = _nationalName(evidence.dg11);

    return ChipHolder(
      firstName: national?.$2 ?? _clean(firstName),
      lastName: national?.$1 ?? _clean(lastName),
      nationalIdentityNumber: identityNumber,
      birthDate: mrz.dateOfBirth,
      documentNumber: documentNumber,
    );
  }

  /// DG11'deki `(soyad, ad)`; yoksa ya da ICAO biçiminde değilse `null`. DG11
  /// çözümlenemese de okuma düşmez, ad DG1'den gelir.
  static (String, String)? _nationalName(String? dg11) {
    if (dg11 == null) return null;

    final String? nameOfHolder;
    try {
      nameOfHolder = EfDG11.fromBytes(base64Decode(dg11)).nameOfHolder;
    } on Object {
      return null;
    }
    if (nameOfHolder == null) return null;

    final separator = nameOfHolder.indexOf('<<');
    if (separator < 0) return null;

    final surname = _clean(nameOfHolder.substring(0, separator));
    final givenNames = _clean(nameOfHolder.substring(separator + 2));
    if (surname.isEmpty || givenNames.isEmpty) return null;

    return (surname, givenNames);
  }

  /// Sunucunun `AdditionalPersonalDetails.clean` adımıyla aynı.
  static String _clean(String value) =>
      value.replaceAll('<', ' ').trim().replaceAll(RegExp(r'\s+'), ' ');
}
