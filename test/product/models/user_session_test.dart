import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/user_session.dart';

Map<String, dynamic> sessionBody({
  String deviceType = 'IOS',
  String? deviceName = 'iPhone 15',
  String? location = 'İstanbul, TR',
  bool current = false,
}) {
  return {
    'id': 'ses_1',
    'deviceId': 'dev_1',
    'deviceType': deviceType,
    'deviceName': deviceName,
    'ipAddress': '85.10.1.4',
    'location': location,
    'lastAccessedAt': '2026-08-30T09:15:00Z',
    'refreshExpiresAt': '2026-09-30T09:15:00Z',
    'current': current,
  };
}

void main() {
  group('UserSession', () {
    test('sunucu gövdesi modele çevrilir', () {
      final session = UserSession.fromJson(sessionBody(current: true));

      expect(session.id, 'ses_1');
      expect(session.deviceType, SessionDeviceType.ios);
      expect(session.displayName, 'iPhone 15');
      expect(session.location, 'İstanbul, TR');
      expect(session.isCurrent, isTrue);
      expect(session.lastAccessedAt, isNotNull);
    });

    // `current` sunucunun işaretlediği bayrak; kullanıcının kendi cihazını
    // yanlışlıkla kapatmaması buna bağlı, varsayılanı yanlış tarafa
    // düşmemeli.
    test('current alanı yoksa false', () {
      final body = sessionBody()..remove('current');

      expect(UserSession.fromJson(body).isCurrent, isFalse);
    });

    // Adsız cihazda boş satır kalmasın diye tür yazılıyor.
    test('cihaz adı yoksa tür gösterilir', () {
      expect(
        UserSession.fromJson(
          sessionBody(deviceType: 'ANDROID', deviceName: null),
        ).displayName,
        'Android',
      );
      expect(
        UserSession.fromJson(
          sessionBody(deviceType: 'WEB_BROWSER', deviceName: '   '),
        ).displayName,
        'Tarayıcı',
      );
    });

    test('tanınmayan cihaz türü bilinmeyene düşer', () {
      final session = UserSession.fromJson(
        sessionBody(deviceType: 'SMART_FRIDGE', deviceName: null),
      );

      expect(session.deviceType, SessionDeviceType.unknown);
      expect(session.displayName, 'Bilinmeyen cihaz');
    });
  });
}
