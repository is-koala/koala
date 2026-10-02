/// Çalışan kabuğunun birden çok yerden açılan rotaları.
///
/// Yol dizgesi tek yerde dursun diye: aynı rota grup sohbetinin katılımcı
/// listesinden ve iş detayındaki bireysel işveren kartından açılıyor.
/// `RouterManager` rotayı ve yönlendirme bekçisinin çalışan listesini buradan
/// kuruyor; çağıranlar `context.push` ile buraya gidiyor. İşveren kabuğunun
/// karşılığı `BusinessRoutes`.
class EmployeeRoutes {
  const EmployeeRoutes._();

  /// Başka bir kullanıcının herkese açık profilinin yol öneki; yönlendirme
  /// bekçisinin çalışan listesi bu önekle eşleşiyor. Rotanın kendisi
  /// [publicProfilePattern], açılan adres [publicProfile].
  static const String publicProfilePrefix = '/public-profile';

  /// Herkese açık profil rotasının kalıbı (is-koala/koala#182). **Kimlik yol
  /// parametresi** ve tek doğru kaynak; `extra` yalnızca çağıranın bildiği ad,
  /// fotoğraf ve rolle kapağı önceden doldurmak için (`PublicProfileArgs`),
  /// verilmese ya da yanlış olsa da sayfa açılıyor.
  ///
  /// İşveren kabuğunda bu rota yok: orada aynı iş `BusinessRoutes.userProfile`
  /// ile görülüyor ve yönlendirme bekçisi işvereni bu yoldan geri çeviriyor.
  static const String publicProfilePattern = '$publicProfilePrefix/:userId';

  /// [userId]'nin herkese açık profilinin adresi; `context.push` bunu alır.
  static String publicProfile(String userId) =>
      '$publicProfilePrefix/${Uri.encodeComponent(userId)}';

  /// Oturum sahibinin kendi profil sekmesi. Kendi kimliğiyle açılan herkese
  /// açık profil ve sohbetteki kendi satırın buraya yönleniyor: kendi
  /// profilinin "başkasının gözüyle" görünümü ayrı bir ekran değil.
  ///
  /// Yönlendirme bekçisi, shell rotası ve yönlendirenler aynı sabiti
  /// okuyor; yol değişirse hiçbiri sessizce ayrışmıyor.
  static const String ownProfile = '/profile';
}
