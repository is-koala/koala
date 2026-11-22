/// `PATCH /users/me` sonrası doğrulama bekleyen alan. Backend e-posta/telefonu
/// hemen yazmıyor; koşulsuz "kaydedildi" yanıltıcı olurdu.
class PendingVerification {
  const PendingVerification({
    required this.id,
    required this.type,
    this.sentTo,
    this.expiresAt,
  });

  final String id;

  final String type;

  final String? sentTo;

  /// Eski sunucuda yok, o yüzden nullable.
  final DateTime? expiresAt;

  bool get isEmail => type == 'EMAIL';

  String get instruction {
    final target = sentTo;
    // `sentTo` zorunlu değil; boşsa hedef adlandırılmaz.
    if (target == null || target.isEmpty) {
      return 'Size gönderdiğimiz 6 haneli kodu girin';
    }
    return isEmail
        ? '$target adresine gönderdiğimiz 6 haneli kodu girin'
        : '$target numarasına gönderdiğimiz 6 haneli kodu girin';
  }

  factory PendingVerification.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['expiresAt'];
    return PendingVerification(
      id: '${json['id']}',
      type: json['type'] as String? ?? '',
      sentTo: json['sentTo'] as String?,
      expiresAt: expiresAt is String ? DateTime.tryParse(expiresAt) : null,
    );
  }
}
