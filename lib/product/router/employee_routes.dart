/// Çalışan kabuğunun birden çok yerden açılan rotaları.
///
/// Yol dizgesi tek yerde dursun diye: aynı rota grup sohbetinin katılımcı
/// listesinden ve iş detayındaki bireysel işveren kartından açılıyor.
/// `RouterManager` rotayı ve yönlendirme bekçisinin çalışan listesini buradan
/// kuruyor; çağıranlar `context.push` ile buraya gidiyor. İşveren kabuğunun
/// karşılığı `BusinessRoutes`.
class EmployeeRoutes {
  const EmployeeRoutes._();

  /// Başka bir kullanıcının herkese açık profili (is-koala/koala#182).
  /// `extra`: `PublicProfileArgs` ya da kullanıcı kimliği (`String`) —
  /// `PublicProfilePage.fromExtra` ikisini de kabul ediyor.
  ///
  /// İşveren kabuğunda bu rota yok: orada aynı iş `BusinessRoutes.userProfile`
  /// ile görülüyor ve yönlendirme bekçisi işvereni bu yoldan geri çeviriyor.
  static const String publicProfile = '/public-profile';

  /// Oturum sahibinin kendi profil sekmesi. Kendi kimliğiyle açılan herkese
  /// açık profil buraya yönleniyor: kendi profilinin "başkasının gözüyle"
  /// görünümü ayrı bir ekran değil.
  static const String ownProfile = '/profile';
}
