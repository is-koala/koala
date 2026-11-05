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

  /// Servisin biniş listesi (is-koala/koala#217). Sorgu: `shuttleId`,
  /// isteğe bağlı `name` (başlık). `SHUTTLE_NOTICE_NOT_BOARDED` push'u da
  /// buraya iniyor; kimlik sorguda olduğu için `extra`'sız açılabiliyor.
  static const String shuttleBoardings = '/business/shuttle-boardings';

  /// Servisin biniş QR'ı (dönen / basılı, anahtar yenileme).
  static const String shuttleQr = '/business/shuttle-qr';

  /// Çalışanın kişisel QR'ını okutma ekranı.
  static const String shuttleScan = '/business/shuttle-scan';

  static String shuttleBoardingsLocation(String shuttleId, {String? name}) =>
      _withShuttle(shuttleBoardings, shuttleId, name);

  static String shuttleQrLocation(String shuttleId, {String? name}) =>
      _withShuttle(shuttleQr, shuttleId, name);

  static String shuttleScanLocation(String shuttleId, {String? name}) =>
      _withShuttle(shuttleScan, shuttleId, name);

  static String _withShuttle(String path, String shuttleId, String? name) {
    final trimmed = name?.trim();
    return Uri(
      path: path,
      queryParameters: {
        'shuttleId': shuttleId,
        if (trimmed != null && trimmed.isNotEmpty) 'name': trimmed,
      },
    ).toString();
  }
}
