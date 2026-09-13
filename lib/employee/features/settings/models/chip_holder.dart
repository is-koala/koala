import 'dart:convert';

import 'package:dmrtd/dmrtd.dart';
import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/national_identity_number.dart';

/// Çipin söylediği kart sahibi: beyan formunun beş alanı, **yalnızca**
/// sunucuya gidecek veri gruplarından türetilmiş hâlde.
///
/// Girdi [ChipEvidence]'ın kendisi — yani gövdeye konacak base64 dizgileri.
/// Ayrı bir kaynak (MRZ taraması, kullanıcının yazdığı) yok; ekranda
/// gösterilen değer ile gönderilen kanıt aynı baytlardan çıkıyor. Kanıt
/// değişirse sahip de değişir, sahip kanıtsız var olamaz.
///
/// Kaynak seçimi sunucununkiyle (`PassiveAuthenticationVerifier`) aynı:
///
/// - **TCKN, doğum tarihi, belge numarası → DG1.** MRZ'nin çipteki kopyası;
///   TCKN birinci satırın isteğe bağlı veri alanında.
/// - **Ad, soyad → varsa DG11, yoksa DG1.** MRZ ulusal karakterleri ASCII'ye
///   katlıyor (**ÇAĞRI** → **CAGRI**) ve üçüncü satırı 30 karakterde
///   kesiyor; DG11 adı UTF-8 taşıyor ve SOD'da o da özetlendiği için daha
///   az güvenilir değil. DG11 yoksa ASCII ad **olduğu gibi** kalıyor —
///   `CAGRI`'nın `ÇAĞRI` mı `CAGRI` mı olduğu tahmin edilmez.
///
/// Harf büyüklüğü de karttaki gibi bırakılıyor: Türkçe için baş harf
/// büyütmek (`IŞIK` → `Işık` mı `Isık` mı) yine bir tahmin olurdu.
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

  /// TC kimlik numarası, on bir hane ([NationalIdentityNumber]).
  final String nationalIdentityNumber;

  final DateTime birthDate;

  /// Belge (seri) numarası; `<` dolgusu temizlenmiş.
  final String documentNumber;

  /// Kanıttan kart sahibini çıkarır; DG1 çözümlenemiyor ya da TCKN
  /// taşımıyorsa `null`.
  ///
  /// `null` dönmek kasıtlı: sunucu aynı durumda `MRZ_UNREADABLE` ile
  /// reddediyor. Eksik bir sahiple formu kilitlemek ya da kullanıcıya
  /// reddedilecek bir gidiş dönüş yaptırmak yerine okuma burada bitiyor.
  static ChipHolder? fromEvidence(ChipEvidence evidence) {
    final MRZ mrz;
    final String firstName;
    final String lastName;
    try {
      mrz = EfDG1.fromBytes(base64Decode(evidence.dg1)).mrz;
      // `dmrtd` ad alanlarını `late` tutuyor; `<<` ayracı olmayan bir MRZ'de
      // hiç atanmıyorlar ve okumak `LateInitializationError` fırlatıyor.
      firstName = mrz.firstName;
      lastName = mrz.lastName;
    } on Object {
      return null;
    }

    // Kural `MrzKey` ile ortak: dolgu (`<` ve boşluk) atılıp tam on bir hane
    // aranıyor. `dmrtd` yalnız sondaki `<`'leri temizlediği için ayırıcıyla
    // başlayan düzende (`<12345678950<<<`) alan `<12345678950` olarak
    // geliyor; yalnız kırpmak o kartı okunamaz sayardı.
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

  /// DG11'deki `(soyad, ad)`; DG11 yoksa, çözümlenemiyorsa ya da adı
  /// ICAO biçiminde (`SOYAD<<AD<İKİNCİ`) taşımıyorsa `null`.
  ///
  /// DG11'in çözümlenememesi okumayı **düşürmüyor**: kanıt olarak yine
  /// gidiyor, yalnız adın kaynağı DG1'de kalıyor. Sunucu da DG11'den ad
  /// çıkaramadığında isteğin adını esas alıyor.
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

  /// `<` ayraçlarını boşluğa çevirip fazla boşluğu toplar; sunucunun
  /// `AdditionalPersonalDetails.clean` adımıyla aynı.
  static String _clean(String value) =>
      value.replaceAll('<', ' ').trim().replaceAll(RegExp(r'\s+'), ' ');
}
