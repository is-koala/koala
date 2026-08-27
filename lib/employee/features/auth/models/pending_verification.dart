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
    this.message,
  });

  final String id;

  /// `EMAIL` ya da `PHONE`.
  final String type;

  /// Doğrulamanın gönderildiği yeni adres veya numara.
  final String? sentTo;

  /// Backend'in `Accept-Language: tr` ile döndürdüğü açıklama; arayüzde
  /// olduğu gibi gösterilebilir.
  final String? message;

  bool get isEmail => type == 'EMAIL';

  factory PendingVerification.fromJson(Map<String, dynamic> json) {
    return PendingVerification(
      id: '${json['id']}',
      type: json['type'] as String? ?? '',
      sentTo: json['sentTo'] as String?,
      message: json['message'] as String?,
    );
  }
}
