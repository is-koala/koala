import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/app_notification.dart';
import 'package:koala/product/services/notification_service.dart';

import '../../support/fake_api.dart';

void main() {
  group('NotificationService.fetchFeed', () {
    test('sayfa parametreleriyle akışı çeker', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'notifications': {
                'content': [
                  {
                    'id': 'ntf_1',
                    'channel': 'EMAIL',
                    'category': 'APPLICATION_UPDATES',
                    'status': 'SENT',
                    'subject': 'Başvurunuz kabul edildi',
                    'sentAt': '2026-08-30T09:15:00Z',
                  },
                ],
                'page': 1,
                'totalElements': 42,
                'last': false,
              },
              'unreadCount': 5,
            },
          },
        ),
      );

      final feed = await NotificationService.withClient(
        api.client,
      ).fetchFeed(page: 1, size: 20);

      final request = api.requests.single;
      expect(request.path, '/users/me/notifications');
      expect(request.method, 'GET');
      expect(request.queryParameters, {'page': 1, 'size': 20});
      expect(feed.notifications.single.channel, NotificationChannel.email);
      expect(feed.unreadCount, 5);
      expect(feed.last, isFalse);
    });

    test('boş akış hata değil', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'notifications': {'content': []},
              'unreadCount': 0,
            },
          },
        ),
      );

      final feed = await NotificationService.withClient(api.client).fetchFeed();

      expect(feed.notifications, isEmpty);
      expect(feed.hasUnread, isFalse);
    });
  });

  group('NotificationService.markRead', () {
    test('bildirim kimliği yola eklenir', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await NotificationService.withClient(api.client).markRead('ntf_1');

      final request = api.requests.single;
      expect(request.path, '/users/me/notifications/ntf_1/read');
      expect(request.method, 'POST');
    });
  });

  group('NotificationService.markAllRead', () {
    test('işaretlenen sayıyı döndürür', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': 3},
        ),
      );

      final marked = await NotificationService.withClient(
        api.client,
      ).markAllRead();

      final request = api.requests.single;
      expect(request.path, '/users/me/notifications/read');
      expect(request.method, 'POST');
      expect(marked, 3);
    });

    // Hepsi zaten okunmuşsa sunucu sıfır dönüyor; bu bir hata değil.
    test('işaretlenecek bildirim yoksa sıfır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': 0},
        ),
      );

      expect(await NotificationService.withClient(api.client).markAllRead(), 0);
    });
  });
}
