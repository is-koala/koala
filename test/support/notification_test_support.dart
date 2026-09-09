import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/services/notification_service.dart';

import 'fake_api.dart';

/// Oturum sınırı widget testleri için A hesabına ait dolu bir akış.
Future<NotificationProvider> loadedNotificationProvider() async {
  final api = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'notifications': {
            'content': [
              {
                'id': 'hesap_a',
                'channel': 'IN_APP',
                'category': 'APPLICATION_UPDATES',
                'status': 'SENT',
                'sentAt': '2026-08-30T09:15:00Z',
              },
            ],
            'page': 0,
            'last': true,
          },
          'unreadCount': 1,
        },
      },
    ),
  );
  final provider = NotificationProvider(
    service: NotificationService.withClient(api.client),
  );
  await provider.load();
  return provider;
}
