/// Çalışan kabuğunun birden çok yerden açılan rotaları; karşılığı
/// `BusinessRoutes`.
class EmployeeRoutes {
  const EmployeeRoutes._();

  /// Yönlendirme bekçisinin çalışan listesi bu önekle eşleşiyor.
  static const String publicProfilePrefix = '/public-profile';

  /// Herkese açık profil (#182). Kimlik yol parametresi ve tek kaynak; `extra`
  /// (`PublicProfileArgs`) yalnız kapağı önceden doldurur. İşveren kabuğunda
  /// yok, onun karşılığı `BusinessRoutes.userProfile`.
  static const String publicProfilePattern = '$publicProfilePrefix/:userId';

  static String publicProfile(String userId) =>
      '$publicProfilePrefix/${Uri.encodeComponent(userId)}';

  /// Kendi profil sekmesi; kendi kimliğiyle açılan profil buraya yönleniyor.
  static const String ownProfile = '/profile';

  static const String boardingPrefix = '/shuttle-boarding';

  /// İşçinin biniş QR'ı. Sorgu: `assignmentId`, `direction`.
  static const String boardingQr = '$boardingPrefix/qr';

  /// Sorgu isteğe bağlı: `assignmentId`, `direction`, `shuttleId`.
  static const String boardingScan = '$boardingPrefix/scan';

  static String boardingQrLocation(String assignmentId, String direction) =>
      Uri(
        path: boardingQr,
        queryParameters: {'assignmentId': assignmentId, 'direction': direction},
      ).toString();

  static String boardingScanLocation({
    String? assignmentId,
    String? direction,
    String? shuttleId,
  }) {
    final query = {
      'assignmentId': ?assignmentId,
      'direction': ?direction,
      'shuttleId': ?shuttleId,
    };
    return Uri(
      path: boardingScan,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }
}
