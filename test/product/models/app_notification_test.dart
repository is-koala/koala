import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/app_notification.dart';

Map<String, dynamic> notificationBody({
  String channel = 'IN_APP',
  String category = 'APPLICATION_UPDATES',
  String status = 'SENT',
  String? subject = 'Garson aranıyor',
  String? body = 'Başvurunuz kabul edildi',
  String? targetType = 'JOB_ASSIGNMENT',
  String? targetId = 'asg_1',
  String? readAt,
}) {
  return {
    'id': 'ntf_1',
    'channel': channel,
    'category': category,
    'status': status,
    'subject': subject,
    'body': body,
    'targetType': targetType,
    'targetId': targetId,
    'sentAt': '2026-08-30T09:15:00Z',
    'readAt': readAt,
  };
}

Map<String, dynamic> feedBody({
  List<Map<String, dynamic>>? content,
  int unreadCount = 2,
}) {
  return {
    'notifications': {
      'content': content ?? [notificationBody()],
      'page': 0,
      'size': 20,
      'totalElements': 1,
      'totalPages': 1,
      'first': true,
      'last': true,
    },
    'unreadCount': unreadCount,
  };
}

void main() {
  group('AppNotification', () {
    test('sunucu gövdesi modele çevrilir', () {
      final notification = AppNotification.fromJson(notificationBody());

      expect(notification.id, 'ntf_1');
      expect(notification.channel, NotificationChannel.inApp);
      expect(notification.category, NotificationCategory.applicationUpdates);
      expect(notification.status, NotificationStatus.sent);
      expect(notification.subject, 'Garson aranıyor');
      expect(notification.body, 'Başvurunuz kabul edildi');
      expect(notification.targetType, NotificationTargetType.jobAssignment);
      expect(notification.targetId, 'asg_1');
      expect(notification.hasTarget, isTrue);
      expect(notification.sentAt, isNotNull);
    });

    // Okundu bilgisi gönderim durumundan değil, `readAt` alanından geliyor:
    // "gönderildi" ile "okundu" farklı şeyler.
    test('readAt yoksa okunmamış sayılır', () {
      expect(AppNotification.fromJson(notificationBody()).isRead, isFalse);

      final read = AppNotification.fromJson(
        notificationBody(readAt: '2026-08-30T10:00:00Z'),
      );
      expect(read.isRead, isTrue);
      expect(read.readAt, isNotNull);
    });

    // Gönderimi tamamlanmış olması okunduğu anlamına gelmiyor.
    test('OPENED durumu tek başına okundu demek değil', () {
      final notification = AppNotification.fromJson(
        notificationBody(status: 'OPENED'),
      );

      expect(notification.status, NotificationStatus.opened);
      expect(notification.isRead, isFalse);
    });

    // Bilinmeyen değer var olan bir değere yamanmıyor; öyle olsaydı akış
    // sessizce yanlış bilgi gösterirdi.
    test('tanınmayan kod bilinmeyene düşer', () {
      final notification = AppNotification.fromJson(
        notificationBody(channel: 'CARRIER_PIGEON', category: 'WEATHER'),
      );

      expect(notification.channel, NotificationChannel.unknown);
      expect(notification.category, NotificationCategory.other);
      expect(notification.category.displayName, 'Diğer');
    });

    test('boş konu hasSubject false', () {
      expect(
        AppNotification.fromJson(notificationBody(subject: null)).hasSubject,
        isFalse,
      );
      expect(
        AppNotification.fromJson(notificationBody(subject: '   ')).hasSubject,
        isFalse,
      );
      expect(AppNotification.fromJson(notificationBody()).hasSubject, isTrue);
    });
  });

  group('NotificationFeed', () {
    test('sayfa ve okunmamış sayısı birlikte ayrıştırılır', () {
      final feed = NotificationFeed.fromJson(feedBody());

      expect(feed.notifications, hasLength(1));
      expect(feed.unreadCount, 2);
      expect(feed.hasUnread, isTrue);
      expect(feed.last, isTrue);
      expect(feed.totalElements, 1);
    });

    // Rozetteki sayı sayfadan türetilmiyor: ilk sayfada okunmamış
    // görünmese bile toplam okunmamış olabilir.
    test('okunmamış sayısı sayfadaki kayıtlardan bağımsız', () {
      final feed = NotificationFeed.fromJson(
        feedBody(
          content: [notificationBody(readAt: '2026-08-30T10:00:00Z')],
          unreadCount: 7,
        ),
      );

      expect(feed.notifications.single.isRead, isTrue);
      expect(feed.unreadCount, 7);
    });

    test('boş içerik hata değil', () {
      final feed = NotificationFeed.fromJson(
        feedBody(content: [], unreadCount: 0),
      );

      expect(feed.notifications, isEmpty);
      expect(feed.hasUnread, isFalse);
    });

    // Sayfa hiç gelmezse okunmamış sayısı yine okunabilmeli.
    test('sayfa alanı eksikse boş akış döner', () {
      final feed = NotificationFeed.fromJson({'unreadCount': 3});

      expect(feed.notifications, isEmpty);
      expect(feed.unreadCount, 3);
    });
  });

  group('AppNotification metinleri', () {
    // Başlık ilanın adı, alt satır olayın kendisi.
    test('konu başlığa, gövde ayrıntıya gider', () {
      final notification = AppNotification.fromJson(notificationBody());

      expect(notification.title, 'Garson aranıyor');
      expect(notification.detail, 'Başvurunuz kabul edildi');
    });

    // Kimlik doğrulama gibi bildirimlerde ilan yok; gövde başlığa çıkıyor
    // ve altında tekrarlanmıyor.
    test('konu yoksa gövde başlığa çıkar', () {
      final notification = AppNotification.fromJson(
        notificationBody(subject: null, body: 'Kimliğiniz doğrulandı'),
      );

      expect(notification.title, 'Kimliğiniz doğrulandı');
      expect(notification.detail, isNull);
    });

    test('ikisi de yoksa kategori adı kalır', () {
      final notification = AppNotification.fromJson(
        notificationBody(subject: null, body: null),
      );

      expect(notification.title, 'Başvurular');
      expect(notification.detail, isNull);
    });
  });

  group('AppNotification hedefi', () {
    // Hiçbir yere gitmeyen satır tıklanabilir görünmemeli.
    test('hedefsiz bildirim dokunulamaz', () {
      final notification = AppNotification.fromJson(
        notificationBody(targetType: null, targetId: null),
      );

      expect(notification.targetType, NotificationTargetType.none);
      expect(notification.hasTarget, isFalse);
    });

    test('kimlik yoksa hedef sayılmaz', () {
      final notification = AppNotification.fromJson(
        notificationBody(targetId: null),
      );

      expect(notification.targetType, NotificationTargetType.jobAssignment);
      expect(notification.hasTarget, isFalse);
    });

    test('tanınmayan hedef türü yok sayılır', () {
      final notification = AppNotification.fromJson(
        notificationBody(targetType: 'INVOICE'),
      );

      expect(notification.targetType, NotificationTargetType.none);
      expect(notification.hasTarget, isFalse);
    });
  });

  group('copyWithRead', () {
    test('yalnızca okunma anını değiştirir', () {
      final notification = AppNotification.fromJson(notificationBody());
      final read = notification.copyWithRead(DateTime(2026, 9, 4));

      expect(read.isRead, isTrue);
      expect(read.id, notification.id);
      expect(read.body, notification.body);
      expect(read.targetId, notification.targetId);
    });
  });
}
