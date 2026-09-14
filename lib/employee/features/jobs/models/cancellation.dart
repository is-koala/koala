import 'package:koala/product/network/json_field.dart';

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
    this.feeRate = '0',
    this.feeAmount = '0',
    this.refundAmount = '0',
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
  final String feeRate;

  /// Kesilen tutar.
  final String feeAmount;

  /// İşverene iade edilen tutar.
  final String refundAmount;

  final DateTime? cancelledAt;

  /// Kesinti uygulandı mı.
  bool get hasFee => _isPositiveDecimal(feeAmount);

  /// Kesinti oranının yüzde karşılığı; "%50" diye yazmak için.
  int get feePercent => _roundedPercent(feeRate);

  /// `GET .../cancellation` tam kaydı, `MyAssignmentDto.cancellation`
  /// (koala-backend#282) ise kimliksiz bir özeti gönderiyor; kimlikler bu
  /// yüzden eksik olabiliyor ve boş dizeye düşüyor.
  factory Cancellation.fromJson(Map<String, dynamic> json) {
    return Cancellation(
      id: '${json['id'] ?? ''}',
      assignmentId: '${json['jobAssignmentId'] ?? ''}',
      cancelledByParty: CancellationParty.fromCode(json['cancelledByParty']),
      reason: json['reason'] as String?,
      noticeMinutes: (json['noticeMinutes'] as num?)?.toInt() ?? 0,
      feeRate: JsonField.rollingDecimalString(json['feeRate'], 'feeRate'),
      feeAmount: JsonField.rollingDecimalString(json['feeAmount'], 'feeAmount'),
      refundAmount: JsonField.rollingDecimalString(
        json['refundAmount'],
        'refundAmount',
      ),
      cancelledAt: switch (json['cancelledAt']) {
        final String value => DateTime.tryParse(value),
        _ => null,
      },
    );
  }
}

/// İptal edilmeden önce hesaplanan kesinti.
///
/// `GET /job-assignments/{id}/cancellation-preview` yanıtı. Hiçbir kayıt
/// oluşturmuyor; iptal kutusu açılırken çağrılıyor ki kullanıcı ne
/// kaybedeceğini bilerek karar versin.
///
/// **Bağlayıcı değil.** Kesinti işin başlamasına kalan süreye bağlı; kutu
/// açık dururken cezasız pencere kapanırsa gerçek kesinti bundan yüksek
/// çıkabilir. Sunucu iptalde yeniden hesaplıyor.
class CancellationPreview {
  const CancellationPreview({
    this.feeRate = '0',
    this.feeAmount = '0',
    this.refundAmount = '0',
    this.noticeMinutes = 0,
    this.cancellableNow = false,
  });

  /// Uygulanacak kesinti oranı, 0 ile 1 arasında.
  final String feeRate;

  /// Kesilecek tutar.
  final String feeAmount;

  /// İşverene iade edilecek tutar.
  final String refundAmount;

  /// İşin başlamasına kalan süre, dakika. Negatif olabiliyor: iş başlamış.
  final int noticeMinutes;

  /// Şu an iptal edilebilir mi.
  ///
  /// Atama iptale kapalı bir durumdaysa ya da zaten iptal edilmişse `false`.
  /// Sunucu burada `409` atmak yerine bunu döndürüyor; buton hata beklemeden
  /// kapatılabiliyor.
  final bool cancellableNow;

  /// Kesinti uygulanacak mı.
  bool get hasFee => _isPositiveDecimal(feeAmount);

  /// Kesinti oranının yüzde karşılığı.
  int get feePercent => _roundedPercent(feeRate);

  /// İş başladı mı. Başlamışsa iade yapılmıyor.
  bool get hasStarted => noticeMinutes <= 0;

  factory CancellationPreview.fromJson(Map<String, dynamic> json) {
    return CancellationPreview(
      feeRate: JsonField.rollingDecimalString(json['feeRate'], 'feeRate'),
      feeAmount: JsonField.rollingDecimalString(json['feeAmount'], 'feeAmount'),
      refundAmount: JsonField.rollingDecimalString(
        json['refundAmount'],
        'refundAmount',
      ),
      noticeMinutes: (json['noticeMinutes'] as num?)?.toInt() ?? 0,
      cancellableNow: json['cancellableNow'] as bool? ?? false,
    );
  }
}

bool _isPositiveDecimal(String value) {
  if (value.startsWith('-')) return false;
  return value.runes.any((digit) => digit >= 49 && digit <= 57);
}

int _roundedPercent(String value) {
  final negative = value.startsWith('-');
  final unsigned = value.startsWith(RegExp(r'[+-]'))
      ? value.substring(1)
      : value;
  final parts = unsigned.split('.');
  final fraction = parts.length == 2 ? parts[1] : '';
  final denominator = BigInt.from(10).pow(fraction.length);
  final numerator = BigInt.parse('${parts[0]}$fraction');
  final scaled = numerator * BigInt.from(100);
  var rounded = scaled ~/ denominator;
  if ((scaled.remainder(denominator) * BigInt.two) >= denominator) {
    rounded += BigInt.one;
  }
  return (negative ? -rounded : rounded).toInt();
}
