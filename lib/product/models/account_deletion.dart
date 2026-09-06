/// Hesap silme yaşam döngüsünün backend'deki durumu.
enum AccountDeletionStatus {
  requested('REQUESTED'),
  anonymized('ANONYMIZED'),
  rejected('REJECTED'),
  unknown('');

  const AccountDeletionStatus(this.code);

  final String code;

  static AccountDeletionStatus fromCode(Object? value) {
    return AccountDeletionStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => AccountDeletionStatus.unknown,
    );
  }
}

/// Hesap silme talebinin sunucuda kaydedilmiş görünümü.
class AccountDeletion {
  const AccountDeletion({
    required this.status,
    this.id,
    this.requestedAt,
    this.processedAt,
    this.blockedReason,
  });

  final String? id;
  final AccountDeletionStatus status;
  final DateTime? requestedAt;
  final DateTime? processedAt;

  /// Talep kabul edilmiş olsa bile anonimleştirmeyi bekleten açık iş,
  /// ödeme, emanet hesap veya uyuşmazlığın kullanıcıya çevrilmiş açıklaması.
  final String? blockedReason;

  bool get isBlocked => blockedReason?.trim().isNotEmpty ?? false;

  factory AccountDeletion.fromJson(Map<String, dynamic> json) {
    return AccountDeletion(
      id: json['id'] as String?,
      status: AccountDeletionStatus.fromCode(json['status']),
      requestedAt: _readDate(json['requestedAt']),
      processedAt: _readDate(json['processedAt']),
      blockedReason: json['blockedReason'] as String?,
    );
  }

  static DateTime? _readDate(Object? value) {
    return value is String ? DateTime.tryParse(value) : null;
  }
}
