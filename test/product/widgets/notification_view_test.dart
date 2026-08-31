import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/services/notification_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/notification_view.dart';
import 'package:provider/provider.dart';

import '../../support/fake_api.dart';
import '../../support/pump.dart';

const Map<String, dynamic> _feedBody = {
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
      'page': 0,
      'last': true,
      'totalElements': 1,
    },
    'unreadCount': 1,
  },
};

Future<void> pumpFeed(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Map<String, dynamic> body = _feedBody,
}) async {
  final api = FakeApi(
    handler: (_) => FakeApiResponse(statusCode: 200, body: body),
  );

  await pumpInApp(
    tester,
    ChangeNotifierProvider(
      create: (_) => NotificationProvider(
        service: NotificationService.withClient(api.client),
      ),
      child: const NotificationView(),
    ),
    brightness: brightness,
  );

  await tester.pumpAndSettle();
}

void main() {
  // Hizası verilmeyen `Container` çocuğuna tight constraint geçiriyor ve
  // `AppIcon` kendi ölçüsünü isteyemeden kutuyu dolduruyordu. İkonun kutuya
  // oturması bu ölçüye bağlı.
  testWidgets('kategori ikonu kutuya gerilmiyor', (tester) async {
    await pumpFeed(tester);

    final icon = tester.widget<AppIcon>(find.byType(AppIcon));
    expect(icon.size, 24);

    final rendered = tester.getSize(find.byType(AppIcon));
    expect(rendered, const Size(24, 24));
  });

  testWidgets('bildirim konusu ve alt satırı çizilir', (tester) async {
    await pumpFeed(tester);

    expect(find.text('Başvurunuz kabul edildi'), findsOneWidget);
    expect(find.textContaining('Başvurular'), findsOneWidget);
  });

  // Konu boş gelebiliyor; satır o zaman hiç değilse kategoriyi göstermeli.
  testWidgets('konusu olmayan bildirimde kategori başlığa geçer', (
    tester,
  ) async {
    await pumpFeed(
      tester,
      body: const {
        'success': true,
        'data': {
          'notifications': {
            'content': [
              {
                'id': 'ntf_1',
                'channel': 'EMAIL',
                'category': 'ACCOUNT_SECURITY',
                'status': 'SENT',
                'subject': '   ',
              },
            ],
            'page': 0,
            'last': true,
          },
          'unreadCount': 0,
        },
      },
    );

    expect(find.text('Hesap Güvenliği'), findsOneWidget);
  });

  testWidgets('bildirim yokken boş durum çizilir', (tester) async {
    await pumpFeed(
      tester,
      body: const {
        'success': true,
        'data': {
          'notifications': {'content': []},
          'unreadCount': 0,
        },
      },
    );

    expect(find.text('Bildirim yok'), findsOneWidget);
  });

  // Proje kuralı: ürün widget'ları iki temada da doğrulanıyor.
  testWidgets('koyu temada da çizilir', (tester) async {
    await pumpFeed(tester, brightness: Brightness.dark);

    expect(find.text('Başvurunuz kabul edildi'), findsOneWidget);
  });
}
