import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/chip_holder.dart';

/// Çip okuma ekranının döndürdüğü sonuç: kanıt ve ondan türeyen kart sahibi.
///
/// İkisi **tek nesnede** ve yalnızca [parse] üzerinden üretiliyor; kanıtı
/// ve sahibi ayrı ayrı veren bir kurucu yok. Böylece formun gösterdiği beş
/// alan ile gönderdiği base64 dizgileri birbirinden ayrışamıyor: sahip,
/// kanıtın baytlarından başka bir şeyden çıkmıyor ve kanıt gittiğinde sahip
/// de gidiyor.
///
/// Belge numarası ve doğum tarihi çipi açan anahtardan **değil** DG1'den
/// okunuyor. BAC/PACE oturumu ancak ikisi karttakiyle tutarsa açıldığı için
/// pratikte aynılar; ama ekrandakinin kaynağı kanıt olmalı, tarama değil.
class IdentityChipResult {
  const IdentityChipResult._({required this.evidence, required this.holder});

  /// Sunucuya gidecek kanıt.
  final ChipEvidence evidence;

  /// Kanıtın söylediği kart sahibi; formun beş alanı buradan.
  final ChipHolder holder;

  /// Kanıttan sonuç üretir; kart sahibi çıkarılamıyorsa `null`.
  ///
  /// `null` çip ekranında okuma hatası olarak gösteriliyor: kanıt olup
  /// sahip olmayan bir sonuç, formu boş kilitlemek olurdu.
  static IdentityChipResult? parse(ChipEvidence evidence) {
    final holder = ChipHolder.fromEvidence(evidence);
    if (holder == null) return null;
    return IdentityChipResult._(evidence: evidence, holder: holder);
  }
}
