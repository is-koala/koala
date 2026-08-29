/// İptali kimin yaptığı. Backend `CancellationParty` karşılığı.
enum CancellationParty {
  worker('WORKER', 'Çalışan'),
  employer('EMPLOYER', 'İşveren'),

  /// Koala'nın kendi iptali; destek tarafından yapılıyor.
  admin('ADMIN', 'Koala');

  const CancellationParty(this.code, this.displayName);

  final String code;
  final String displayName;

  static CancellationParty fromCode(Object? value) {
    return CancellationParty.values.firstWhere(
      (party) => party.code == value,
      orElse: () => CancellationParty.admin,
    );
  }
}

/// Bir atamanın iptal kaydı.
///
/// Backend `CancellationDto` karşılığı. Atama başına **tek** kayıt açılıyor;
/// ikinci iptal `409` alıyor.
///
/// Kesinti kuralı sunucuda: çalışan iptal ederse kesinti yok ve işveren tam
/// iade alıyor. İşveren cezasız pencere içinde iptal ederse yine kesinti yok,
/// pencere dışında geç iptal ücreti kesiliyor, iş başladıktan sonra iade
/// yapılmıyor. Oranlar sunucu ayarından geliyor ve **istemciye açık bir uç
/// yok** — bu yüzden iptal öncesi tutar gösterilemiyor, ancak kayıt döndükten
/// sonra buradan okunuyor.
class Cancellation {
  const Cancellation({
    required this.id,
    required this.assignmentId,
    required this.cancelledByParty,
    this.reason,
    this.noticeMinutes = 0,
    this.feeRate = 0,
    this.feeAmount = 0,
    this.refundAmount = 0,
    this.cancelledAt,
  });

  final String id;

  final String assignmentId;

  final CancellationParty cancelledByParty;

  /// İptal gerekçesi; sunucu zorunlu tutuyor, en fazla 1000 karakter.
  final String? reason;

  /// İşin başlamasına kalan süre, dakika. Kesinti oranı buna göre belirlendi.
  final int noticeMinutes;

  /// Uygulanan kesinti oranı, 0 ile 1 arasında.
  final double feeRate;

  /// Kesilen tutar.
  final double feeAmount;

  /// İşverene iade edilen tutar.
  final double refundAmount;

  final DateTime? cancelledAt;

  /// Kesinti uygulandı mı.
  bool get hasFee => feeAmount > 0;

  /// Kesinti oranının yüzde karşılığı; "%50" diye yazmak için.
  int get feePercent => (feeRate * 100).round();

  factory Cancellation.fromJson(Map<String, dynamic> json) {
    return Cancellation(
      id: '${json['id']}',
      assignmentId: '${json['jobAssignmentId']}',
      cancelledByParty: CancellationParty.fromCode(json['cancelledByParty']),
      reason: json['reason'] as String?,
      noticeMinutes: (json['noticeMinutes'] as num?)?.toInt() ?? 0,
      feeRate: (json['feeRate'] as num?)?.toDouble() ?? 0,
      feeAmount: (json['feeAmount'] as num?)?.toDouble() ?? 0,
      refundAmount: (json['refundAmount'] as num?)?.toDouble() ?? 0,
      cancelledAt: switch (json['cancelledAt']) {
        final String value => DateTime.tryParse(value),
        _ => null,
      },
    );
  }
}
