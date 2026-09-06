import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';

/// Çip okuma ekranının döndürdüğü sonuç.
///
/// Kanıtın yanında **hangi anahtarla** okunduğu da taşınıyor, çünkü
/// kanıttan daha fazlasını söylüyor: BAC/PACE oturumu ancak belge numarası,
/// doğum tarihi ve son geçerlilik tarihi kartın çipindekiyle birebir
/// tutarsa açılıyor. Yani oturum açıldıysa bu üç alan **kanıtlanmış**
/// demektir ve form onları artık kullanıcıya yeniden yazdırmamalı.
class IdentityChipResult {
  const IdentityChipResult({required this.evidence, required this.key});

  final ChipEvidence evidence;

  /// Çipi açan anahtar. Elle girilmiş de olabilir, MRZ'den taranmış da —
  /// ikisi de aynı ölçüde kanıtlanmış, çünkü kanıtı oturumun açılması
  /// veriyor, girişin nasıl yapıldığı değil.
  final MrzKey key;
}
