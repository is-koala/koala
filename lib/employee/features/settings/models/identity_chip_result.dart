import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/chip_holder.dart';

/// Çip ekranının sonucu: kanıt ve ondan türeyen sahip, tek nesnede ve yalnız
/// [parse] ile. Böylece formdaki beş alan ile gönderilen kanıt ayrışamaz. Belge
/// no ve doğum tarihi taramadan değil DG1'den okunuyor.
class IdentityChipResult {
  const IdentityChipResult._({required this.evidence, required this.holder});

  final ChipEvidence evidence;

  final ChipHolder holder;

  /// Sahip çıkarılamıyorsa `null`; formu boş kilitlemek yerine okuma hatası.
  static IdentityChipResult? parse(ChipEvidence evidence) {
    final holder = ChipHolder.fromEvidence(evidence);
    if (holder == null) return null;
    return IdentityChipResult._(evidence: evidence, holder: holder);
  }
}
