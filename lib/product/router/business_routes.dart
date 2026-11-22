/// İşveren kabuğunun birden çok yerden açılan rotaları.
class BusinessRoutes {
  const BusinessRoutes._();

  /// `extra`: `JobApplicant` ya da kullanıcı kimliği.
  static const String userProfile = '/business/user-profile';

  /// İlanlar arası başvuru kutusu; navbar'ın üstünü kaplar.
  static const String applications = '/business/applications';

  /// Ulaşım planı (#197). `extra`: `BTransportPlanArgs`.
  static const String transportPlan = '/business/transport-plan';

  /// `extra`: `BShuttleEditorArgs`; `ShuttleDraft` ile kapanır.
  static const String transportShuttle = '/business/transport-shuttle';

  /// `extra`: `BStopEditorArgs`; `StopDraft` ile kapanır.
  static const String transportStop = '/business/transport-stop';

  /// Servisin biniş listesi. Sorgu: `shuttleId`, isteğe bağlı `name`; push'tan
  /// `extra`'sız açılabiliyor.
  static const String shuttleBoardings = '/business/shuttle-boardings';

  static const String shuttleQr = '/business/shuttle-qr';

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
