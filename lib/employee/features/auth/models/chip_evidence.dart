/// Kimlik çipinden okunan kanıt (base64 alanlar); sunucu SOD'u CSCA'ya kadar
/// zincirleyip MRZ'yi beyanla eşleştiriyor.
///
/// **Bugün hiçbiri zorunlu değil:** `IDENTITY_PASSIVE_AUTH_ENABLED` kapalı ve
/// fazladan alanlar yok sayılıyor; akış bloke olmuyor. **DG2 kasıtlı olarak
/// yok:** yüz eşleştirmesi cihazda.
class ChipEvidence {
  const ChipEvidence({
    required this.sod,
    required this.dg1,
    this.dg11,
    this.dg14,
    this.dg15,
    this.challenge,
    this.activeAuthenticationSignature,
  });

  /// Kartın imzası; kanıtın omurgası.
  final String sod;

  /// MRZ'nin çipteki kopyası; sunucu beyanla karşılaştırıyor.
  final String dg1;

  /// Ad/soyadın ASCII'ye katlanmamış hâli: MRZ **ÇAĞRI**'yı **CAGRI** yazıyor.
  /// Yoksa `null`.
  final String? dg11;

  /// `SecurityInfos`; sunucu Active Authentication algoritmasını buradan
  /// okuyor. Yoksa `null`, sunucu geniş yelpaze dener.
  final String? dg14;

  /// Yoksa Active Authentication atlanır, akış yine tamamlanır.
  final String? dg15;

  /// Sunucunun verdiği tek kullanımlık sayı. `sod` ve `dg1` kart için sabit;
  /// tekrar gönderimi engelleyen tek şey bu imza.
  final String? challenge;

  /// Challenge'ın çipten hiç çıkmayan anahtarla imzası.
  final String? activeAuthenticationSignature;

  /// DG15'siz kartta `false`; akış yine tamamlanır.
  bool get provesChipPresence =>
      dg15 != null &&
      challenge != null &&
      activeAuthenticationSignature != null;

  /// Boş alanlar konmuyor: `""` `SOD_UNREADABLE` yolunu tetikleyebilir.
  Map<String, dynamic> toJson() {
    return {
      'sod': sod,
      'dg1': dg1,
      'dg11': ?dg11,
      'dg14': ?dg14,
      'dg15': ?dg15,
      'challenge': ?challenge,
      'activeAuthenticationSignature': ?activeAuthenticationSignature,
    };
  }
}
