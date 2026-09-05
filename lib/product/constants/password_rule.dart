/// Uygulamanın parola kuralı ve kullanıcıya söylediği tek cümle.
///
/// Kural üç ekranda geçiyor: kayıt akışının parola adımı
/// (`creating_password_pagemodel.dart`), "Şifremi unuttum" akışının son adımı
/// (`reset_password_pagemodel.dart`) ve ayarlardaki parola değiştirme ekranı.
/// Üçünün farklı kural uygulaması kullanıcıyı şaşırtacağı için kural da hata
/// metni de burada, tek yerde duruyor.
///
/// Sunucu yalnızca **en az 8 karakter** istiyor (`ChangePasswordDto`,
/// `@Size(min = 8)`); buradaki kural bilerek daha sıkı. Yani bu kuralı geçen
/// her parola sunucuyu da geçer, tersi geçerli değil.
abstract final class PasswordRule {
  /// Kuralı karşılamayan parola için kullanıcıya gösterilen metin.
  static const String requirement =
      'Şifre en az 8 karakter, büyük/küçük harf ve rakam içermeli.';

  /// En kısa parola uzunluğu. Sunucunun alt sınırıyla aynı.
  static const int minLength = 8;

  /// [password] kuralı karşılıyor mu.
  static bool isSatisfiedBy(String password) {
    return password.length >= minLength &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }
}
