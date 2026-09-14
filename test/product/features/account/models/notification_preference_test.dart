import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/account/models/notification_preference.dart';

void main() {
  NotificationPreference row(
    String category,
    String channel, {
    String kind = 'ALERT',
    bool enabled = true,
    bool editable = true,
  }) => NotificationPreference(
    category: category,
    kind: kind,
    channel: channel,
    enabled: enabled,
    editable: editable,
  );

  group('NotificationPreference.fromJson', () {
    test('sunucu satırını okur', () {
      final parsed = NotificationPreference.fromJson(const {
        'category': 'JOB_ALERTS',
        'kind': 'ALERT',
        'channel': 'PUSH',
        'enabled': true,
        'editable': true,
      });

      expect(parsed.category, 'JOB_ALERTS');
      expect(parsed.channel, 'PUSH');
      expect(parsed.enabled, isTrue);
      expect(parsed.editable, isTrue);
      expect(parsed.isCommercial, isFalse);
    });

    // Eski sunucu ya da eksik alan: kapalı ve kilitli varsaymak, açık ve
    // düzenlenebilir varsaymaktan güvenli — kullanıcı olmayan bir izni
    // "açık" görmemeli.
    test('eksik alanlar kapalı ve kilitli sayılır', () {
      final parsed = NotificationPreference.fromJson(const {
        'category': 'NEWSLETTER',
      });

      expect(parsed.enabled, isFalse);
      expect(parsed.editable, isFalse);
    });
  });

  group('NotificationPreferenceWrite', () {
    test('PUT satırı kategori, kanal ve kararı taşır', () {
      const write = NotificationPreferenceWrite(
        category: 'MARKETINGS',
        channel: 'EMAIL',
        enabled: false,
      );

      expect(write.toJson(), {
        'category': 'MARKETINGS',
        'channel': 'EMAIL',
        'enabled': false,
      });
    });
  });

  group('NotificationPreferenceGroup.groupAll', () {
    test('kategorileri sunucu sırasıyla, kanalları ekran sırasıyla dizer', () {
      final groups = NotificationPreferenceGroup.groupAll([
        row('JOB_ALERTS', 'EMAIL'),
        row('ACCOUNT_SECURITY', 'SMS', kind: 'TRANSACTIONAL', editable: false),
        row('JOB_ALERTS', 'PUSH'),
        row('ACCOUNT_SECURITY', 'PUSH', kind: 'TRANSACTIONAL', editable: false),
      ]);

      expect(groups.map((group) => group.category), [
        'JOB_ALERTS',
        'ACCOUNT_SECURITY',
      ]);
      expect(groups.first.channels.map((row) => row.channel), [
        'PUSH',
        'EMAIL',
      ]);
      expect(groups.first.title, 'İş alarmları');
    });

    test('işlemsel kategori kapatılamayacağını söyler', () {
      final group = NotificationPreferenceGroup.groupAll([
        row(
          'ACCOUNT_SECURITY',
          'EMAIL',
          kind: 'TRANSACTIONAL',
          editable: false,
        ),
      ]).single;

      expect(group.hint, contains('kapatılamaz'));
    });

    test('ticari kategori rıza kaydını söyler', () {
      final group = NotificationPreferenceGroup.groupAll([
        row('NEWSLETTER', 'EMAIL', kind: 'COMMERCIAL', enabled: false),
      ]).single;

      expect(group.hint, contains('Ticari ileti'));
    });

    test('alarm kategorisinin ipucu yok', () {
      final group = NotificationPreferenceGroup.groupAll([
        row('JOB_ALERTS', 'PUSH'),
      ]).single;

      expect(group.hint, isNull);
    });
  });

  group('etiketler', () {
    test('bilinen kategori ve kanal Türkçe', () {
      expect(
        NotificationCategoryLabels.of('MARKETINGS'),
        'Kampanya ve duyurular',
      );
      expect(NotificationChannelLabels.of('IN_APP'), 'Uygulama içi');
    });

    // Backend 0.9.19 sohbet mesajlarını `MESSAGES` kategorisinde push'luyor
    // (is-koala/koala-backend#268); satır İngilizce enum adıyla değil
    // Türkçe etiketle görünmeli.
    test('MESSAGES kategorisi Mesajlar', () {
      expect(NotificationCategoryLabels.of('MESSAGES'), 'Mesajlar');
    });

    // Sunucu yeni bir kategori eklerse uygulama patlamamalı; İngilizce enum
    // adı yerine genel Türkçe etiket görünmeli.
    test('bilinmeyen kod genel etikete düşer', () {
      expect(NotificationCategoryLabels.of('PAYOUT_UPDATES'), 'Diğer');
      expect(NotificationChannelLabels.of('FAX'), 'Diğer');
      expect(
        NotificationChannelLabels.rank('FAX'),
        NotificationChannelLabels.order.length,
      );
    });
  });
}
