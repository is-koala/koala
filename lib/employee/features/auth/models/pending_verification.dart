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

  /// Backend'in doldurduğu açıklama alanı — **arayüzde gösterilmemeli.**
  ///
  /// İki sebeple: `VerificationInfoDto` bu alana ham i18n anahtarını yazıyor
  /// (`{email.verification.message}` / `{phone.verification.message}`) ve
  /// anahtarları çözen `MessageResolvingAdvice` yalnızca yanıt zarfının en
  /// üstündeki `message` alanına bakıyor, iç içe DTO alanlarına dokunmuyor.
  /// Çözülse bile karşılığı `E-posta doğrulama kodunuz: {0}` — doldurulmamış
  /// bir yer tutucu taşıyor.
  ///
  /// Kullanıcıya gösterilecek cümle uygulamada yazılıyor; [type] ve [sentTo]
  /// bunun için yeterli.
  final String? message;

  bool get isEmail => type == 'EMAIL';

  /// Kod ekranında gösterilen yönerge.
  ///
  /// Cümle uygulamada kuruluyor: [message] kullanılamıyor ve hedefin
  /// e-posta mı telefon mu olduğuna göre ifade değişiyor.
  String get instruction {
    final target = sentTo;
    // `sentTo` sözleşmede zorunlu değil; boşsa hedefi adlandırmadan söyle.
    if (target == null || target.isEmpty) {
      return 'Sana gönderdiğimiz 6 haneli kodu gir';
    }
    return isEmail
        ? '$target adresine gönderdiğimiz 6 haneli kodu gir'
        : '$target numarasına gönderdiğimiz 6 haneli kodu gir';
  }

  factory PendingVerification.fromJson(Map<String, dynamic> json) {
    return PendingVerification(
      id: '${json['id']}',
      type: json['type'] as String? ?? '',
      sentTo: json['sentTo'] as String?,
      message: json['message'] as String?,
    );
  }
}
