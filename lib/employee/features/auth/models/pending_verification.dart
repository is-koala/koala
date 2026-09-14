/// `PATCH /users/me` sonrası doğrulanmayı bekleyen alan.
///
/// E-posta ya da telefon değiştirildiğinde backend değeri hemen yazmıyor;
/// yeni adrese/numaraya bir doğrulama gönderip bunu döndürüyor. Yani
/// güncelleme yanıtındaki kullanıcı eski e-postayı taşımaya devam eder ve
/// arayüzün koşulsuz "kaydedildi" demesi yanıltıcı olur.
class PendingVerification {
  const PendingVerification({
    required this.id,
    required this.type,
    this.sentTo,
    this.expiresAt,
  });

  final String id;

  /// `EMAIL` ya da `PHONE`.
  final String type;

  /// Doğrulamanın gönderildiği yeni adres veya numara.
  final String? sentTo;

  /// Kodun sunucudaki son kullanma anı.
  ///
  /// Alan eski sunucu sürümlerinde bulunmadığı için nullable tutulur.
  final DateTime? expiresAt;

  bool get isEmail => type == 'EMAIL';

  /// Kod ekranında gösterilen yönerge.
  ///
  /// Cümle hedefin e-posta mı telefon mu olduğuna göre uygulamada kuruluyor.
  String get instruction {
    final target = sentTo;
    // `sentTo` sözleşmede zorunlu değil; boşsa hedefi adlandırmadan söyle.
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
