/// Kimlik kartının çipinden okunan ve sunucuya gönderilen kanıt.
///
/// `POST /users/me/identity-verification` gövdesine beş beyan alanının
/// yanına ekleniyor (`VerifyIdentityDto`). Alanların hepsi **base64**;
/// sunucu çözüp SOD imzasını CSCA köküne kadar zincirliyor, veri grubu
/// özetlerini karşılaştırıyor ve MRZ'yi beyanla eşleştiriyor.
///
/// **Bugün hiçbiri zorunlu değil.** Sunucudaki `IDENTITY_PASSIVE_AUTH_ENABLED`
/// `false` ve öyle kalıyor; bayrak kapalıyken `verifyChipEvidence` hemen
/// dönüyor ve gövdedeki fazladan alanlar yok sayılıyor. Yani kanıt gönderen
/// yol var ama akışı bloke etmiyor: bu sürüm tek başına yayına çıkabilir.
///
/// **DG2 kasıtlı olarak yok.** Sunucu istemiyor; yüz eşleştirmesi cihazda
/// kalıyor ve bu dilimin dışında.
class ChipEvidence {
  const ChipEvidence({
    required this.sod,
    required this.dg1,
    this.dg11,
    this.dg15,
    this.challenge,
    this.activeAuthenticationSignature,
  });

  /// Document Security Object. Kartın imzası burada; kanıtın omurgası.
  final String sod;

  /// MRZ'nin çipteki kopyası. Sunucu TCKN, doğum tarihi ve adı buradan
  /// okuyup istekteki beyanla karşılaştırıyor.
  final String dg1;

  /// Ad ve soyadın ASCII'ye katlanmamış hâli. DG1'deki MRZ **ÇAĞRI**'yı
  /// **CAGRI** yazıyor; DG11 de SOD'da özetlendiği için daha az güvenilir
  /// değil, yalnızca doğru. Kartta yoksa `null`.
  final String? dg11;

  /// Çipin açık anahtarı. Yoksa Active Authentication adımı atlanıyor ve
  /// akış yine tamamlanıyor — sunucu bugün bunu kabul ediyor.
  final String? dg15;

  /// Çipe imzalatılan tek kullanımlık sayı, sunucudan geldiği gibi.
  ///
  /// `sod` ve `dg1` bir kart için **sabit**; bir kez okuyan sonsuza dek
  /// tekrar gönderebilirdi. Tekrar deliğini kapatan tek şey bu imza.
  final String? challenge;

  /// `INTERNAL AUTHENTICATE` yanıtı: challenge'ın ham baytlarının çipin
  /// içinden hiç çıkmayan özel anahtarla imzalanmış hâli.
  final String? activeAuthenticationSignature;

  /// Çip varlığı kanıtlanabildi mi. DG15 taşımayan kartta `false` olur ve
  /// akış yine tamamlanır.
  bool get provesChipPresence =>
      dg15 != null &&
      challenge != null &&
      activeAuthenticationSignature != null;

  /// İstek gövdesine eklenecek alanlar.
  ///
  /// Boş olanlar hiç konmuyor: sunucu `null` ile `""` arasında ayrım
  /// yapıyor ve boş metin `SOD_UNREADABLE` yolunu tetikleyebilir.
  Map<String, dynamic> toJson() {
    return {
      'sod': sod,
      'dg1': dg1,
      'dg11': ?dg11,
      'dg15': ?dg15,
      'challenge': ?challenge,
      'activeAuthenticationSignature': ?activeAuthenticationSignature,
    };
  }
}
