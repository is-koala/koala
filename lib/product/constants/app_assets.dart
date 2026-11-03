/// Asset dosya yolları.
///
/// Yol string'i hiçbir widget'ın içine yazılmaz; buradan okunur. Böylece bir
/// dosya yeniden adlandırıldığında tek yer değişir ve yanlış yazılmış bir yol
/// çalışma zamanında değil, derlemede yakalanır.
class AppAssets {
  static const String _images = 'assets/images';
  static const String _lottie = 'assets/lottie';

  // ----------------------------------------------------------------- Logo

  static const String koalaLogo = '$_images/koala_logo.png';
  static const String koalaLogoAlt = '$_images/koala_logo_1.png';

  /// Google ile giriş butonunun ikonu.
  static const String googleLogo = '$_images/google_logo.png';

  // --------------------------------------------------------------- Maskot

  /// Kayıt tipi seçiminde "çalışan" kartının görseli.
  static const String koalaWorker = '$_images/koala_worker.png';

  /// Kayıt tipi seçiminde "iş veren" kartının görseli.
  static const String koalaBusiness = '$_images/koala_business.png';

  /// Boş durum (empty state) görseli.
  static const String koalaEmpty = '$_images/culsuz_koala.png';

  /// Varsayılan profil fotoğrafı.
  static const String defaultProfilePicture =
      '$_images/koala_profile_picture.png';

  /// Profil rozetleri.
  static const String badgeGold = '$_images/koala_gezgin_altin.png';
  static const String badgeSilver = '$_images/koala_gezgin_gumus.png';
  static const String badgeSilverAlt = '$_images/koala_gezgin_gumus_1.png';

  // ----------------------------------------------------------- Onboarding

  static const String onboarding1 = '$_images/onboarding-1.png';
  static const String onboarding2 = '$_images/onboarding-2.png';
  static const String onboarding3 = '$_images/onboarding-3.png';

  // ---------------------------------------------------------------- Harita

  /// Harita yüklenene kadar arkada duran yer tutucu görsel.
  static const String backgroundMap = '$_images/background_map.png';

  // ---------------------------------------------------------------- Lottie

  /// E-posta doğrulama bekleme ekranının animasyonu.
  static const String emailVerificationPending =
      '$_lottie/email_verification_pending.json';
}
