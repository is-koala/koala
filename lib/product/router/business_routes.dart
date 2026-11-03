/// İşveren kabuğunun birden çok yerden açılan rotaları.
///
/// Yol dizgesi tek yerde dursun diye: aynı rota başvuran kartından, yetenek
/// havuzundan ve grup sohbetinin katılımcı listesinden açılıyor.
/// `RouterManager` rotayı buradan kuruyor; çağıranlar `context.push` ile
/// buraya gidiyor.
class BusinessRoutes {
  const BusinessRoutes._();

  /// Bir adayın profili. `extra`: `JobApplicant` ya da kullanıcı kimliği
  /// (`String`) — `BUserProfilePage.fromExtra` ikisini de kabul ediyor.
  static const String userProfile = '/business/user-profile';

  /// İlanlar arası başvuru gelen kutusu (is-koala/koala#213). Üst düzey: navbar'ın
  /// üstünü kaplıyor; parametre almıyor, süzgeçler ekranın kendi durumu.
  static const String applications = '/business/applications';

  /// Ulaşım planı düzenleyicisi (is-koala/koala#197). `extra`:
  /// `BTransportPlanArgs`; ilan modunda `TransportPlan`, taslak modunda
  /// `TransportPlanDraft` ile kapanır.
  static const String transportPlan = '/business/transport-plan';

  /// Tek servisin düzenleyicisi; `extra`: `BShuttleEditorArgs`, `ShuttleDraft`
  /// ile kapanır.
  static const String transportShuttle = '/business/transport-shuttle';

  /// Tek durağın düzenleyicisi; `extra`: `BStopEditorArgs`, `StopDraft` ile
  /// kapanır.
  static const String transportStop = '/business/transport-stop';
}
