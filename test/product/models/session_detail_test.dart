import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/session_detail.dart';
import 'package:koala/product/models/user_session.dart';

void main() {
  group('SessionDetail.fromJson', () {
    test('dolu ayrıntı alanlarıyla çözülür', () {
      final detail = SessionDetail.fromJson({
        'id': 'ses-1',
        'deviceId': 'dev-1',
        'deviceType': 'IOS',
        'deviceName': 'iPhone 14 Pro Max · iOS 18.1 · Koala 1.1.0',
        'deviceCustomName': null,
        'createdAt': '2026-09-01T10:00:00Z',
        'lastAccessedAt': '2026-09-14T08:30:00Z',
        'refreshExpiresAt': '2026-10-14T08:30:00Z',
        'ipAddress': '85.100.1.1',
        'location': 'İstanbul, TR',
        'current': true,
        'logins': 7,
        'loginHistory': [
          {
            'at': '2026-09-14T08:30:00Z',
            'ipAddress': '85.100.1.1',
            'location': 'İstanbul, TR',
            'success': true,
          },
          {
            'at': '2026-09-13T22:10:00Z',
            'ipAddress': '5.5.5.5',
            'location': null,
            'success': false,
          },
        ],
      });

      expect(detail.session.id, 'ses-1');
      expect(detail.session.deviceId, 'dev-1');
      expect(detail.session.deviceType, SessionDeviceType.ios);
      expect(
        detail.session.displayName,
        'iPhone 14 Pro Max · iOS 18.1 · Koala 1.1.0',
      );
      expect(detail.deviceCustomName, isNull);
      expect(detail.createdAt, DateTime.utc(2026, 9, 1, 10));
      expect(detail.session.lastAccessedAt, DateTime.utc(2026, 9, 14, 8, 30));
      expect(
        detail.session.refreshExpiresAt,
        DateTime.utc(2026, 10, 14, 8, 30),
      );
      expect(detail.session.ipAddress, '85.100.1.1');
      expect(detail.session.location, 'İstanbul, TR');
      expect(detail.session.isCurrent, isTrue);
      expect(detail.logins, 7);
      expect(detail.loginHistory, hasLength(2));
      expect(detail.loginHistory.first.successful, isTrue);
      expect(detail.loginHistory.last.successful, isFalse);
      expect(detail.loginHistory.last.location, isNull);
      expect(detail.loginHistory.last.at, DateTime.utc(2026, 9, 13, 22, 10));
    });

    // Sunucu bilmediğini `null` yazıyor; hiçbir alan zorunlu değil.
    test('boş alanlar çökertmez, varsayılanlar devreye girer', () {
      final detail = SessionDetail.fromJson({
        'id': 'ses-2',
        'deviceType': 'BILINMEYEN',
        'current': null,
        'logins': null,
        'loginHistory': null,
      });

      expect(detail.session.deviceId, isNull);
      expect(detail.session.deviceType, SessionDeviceType.unknown);
      expect(detail.session.displayName, 'Bilinmeyen cihaz');
      expect(detail.session.ipAddress, isNull);
      expect(detail.session.location, isNull);
      expect(detail.createdAt, isNull);
      expect(detail.session.isCurrent, isFalse);
      expect(detail.logins, 0);
      expect(detail.loginHistory, isEmpty);
    });

    test('özel ad verildiyse deviceName onu taşıyor', () {
      final detail = SessionDetail.fromJson({
        'id': 'ses-3',
        'deviceType': 'ANDROID',
        'deviceName': 'İş telefonum',
        'deviceCustomName': 'İş telefonum',
        'current': false,
      });

      expect(detail.session.displayName, 'İş telefonum');
      expect(detail.deviceCustomName, 'İş telefonum');
    });
  });

  group('LoginHistoryEntry.fromJson', () {
    test('success alanı eksikse başarısız sayılır', () {
      final entry = LoginHistoryEntry.fromJson({'at': 'geçersiz'});

      expect(entry.successful, isFalse);
      expect(entry.at, isNull);
    });
  });
}
