/// Parola kuralı ve hata metni; kayıt, şifre sıfırlama ve parola değiştirme
/// aynısını kullanıyor. Sunucu yalnız 8 karakter istiyor; buradaki kural
/// bilerek daha sıkı.
abstract final class PasswordRule {
  static const String requirement =
      'Şifre en az 8 karakter, büyük/küçük harf ve rakam içermeli.';

  static const int minLength = 8;

  static bool isSatisfiedBy(String password) {
    return password.length >= minLength &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }
}
