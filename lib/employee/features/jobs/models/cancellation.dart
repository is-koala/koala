import 'package:koala/product/network/json_field.dart';

enum CancellationParty {
  worker('WORKER', 'Çalışan'),
  employer('EMPLOYER', 'İşveren'),

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

/// İptal kaydı; atama başına **tek** (ikincisi `409`). Kesinti kuralı sunucuda:
/// çalışan iptalinde kesinti yok; işveren cezasız pencere dışında geç iptal
/// ücreti öder, iş başladıysa iade yok.
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

  /// Zorunlu, en fazla 1000 karakter.
  final String? reason;

  /// Kesinti oranı buna göre belirlendi.
  final int noticeMinutes;

  /// 0-1 arası.
  final String feeRate;

  final String feeAmount;

  final String refundAmount;

  final DateTime? cancelledAt;

  bool get hasFee => _isPositiveDecimal(feeAmount);

  int get feePercent => _roundedPercent(feeRate);

  /// Liste özeti kimliksiz geliyor; kimlikler boş dizeye düşebilir.
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

/// İptal öncesi hesaplanan kesinti; kayıt oluşturmaz. **Bağlayıcı değil:** kutu
/// açıkken cezasız pencere kapanabilir, sunucu yeniden hesaplar.
class CancellationPreview {
  const CancellationPreview({
    this.feeRate = '0',
    this.feeAmount = '0',
    this.refundAmount = '0',
    this.noticeMinutes = 0,
    this.cancellableNow = false,
  });

  /// 0-1 arası.
  final String feeRate;

  final String feeAmount;

  final String refundAmount;

  /// Negatifse iş başlamış.
  final int noticeMinutes;

  /// İptale kapalıysa `409` yerine `false`; buton hata beklemeden kapanır.
  final bool cancellableNow;

  bool get hasFee => _isPositiveDecimal(feeAmount);

  int get feePercent => _roundedPercent(feeRate);

  /// Başladıysa iade yok.
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
