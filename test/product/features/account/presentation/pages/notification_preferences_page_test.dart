import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/account/presentation/pages/notification_preferences_page.dart';
import 'package:koala/product/features/account/services/notification_preference_service.dart';
import 'package:koala/product/widgets/empty_state.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

Map<String, dynamic> _row(
  String category,
  String channel, {
  String kind = 'ALERT',
  bool enabled = true,
  bool editable = true,
}) => {
  'category': category,
  'kind': kind,
  'channel': channel,
  'enabled': enabled,
  'editable': editable,
};

/// `GET`/`PUT /users/me/notification-preferences` uçlarını karşılayan sahte
/// sunucu. `PUT` gövdedeki kararı tabloya işleyip tamamını döndürüyor —
/// gerçek uç da böyle davranıyor.
class _Server {
  _Server({List<Map<String, dynamic>>? rows})
    : rows =
          rows ??
          [
            _row(
              'ACCOUNT_SECURITY',
              'EMAIL',
              kind: 'TRANSACTIONAL',
              editable: false,
            ),
            _row('JOB_ALERTS', 'EMAIL'),
            _row('JOB_ALERTS', 'PUSH'),
            _row('NEWSLETTER', 'EMAIL', kind: 'COMMERCIAL', enabled: false),
          ];

  final List<Map<String, dynamic>> rows;
  FakeApiResponse? getResponse;
  FakeApiResponse? putResponse;

  late final FakeApi api = FakeApi(handler: handle);

  FakeApiResponse handle(RequestOptions request) {
    if (request.path != '/users/me/notification-preferences') {
      return const FakeApiResponse(statusCode: 404, body: {'success': false});
    }
    if (request.method == 'GET') {
      return getResponse ??
          FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': rows},
          );
    }
    final override = putResponse;
    if (override != null) return override;

    final body = putBody(request);
    for (final change in body['preferences'] as List) {
      final entry = change as Map<String, dynamic>;
      for (final row in rows) {
        if (row['category'] == entry['category'] &&
            row['channel'] == entry['channel']) {
          row['enabled'] = entry['enabled'];
        }
      }
    }
    return FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': rows},
    );
  }

  static Map<String, dynamic> putBody(RequestOptions request) {
    final data = request.data;
    return data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;
  }

  Iterable<RequestOptions> get puts =>
      api.requests.where((request) => request.method == 'PUT');
}

void main() {
  late _Server server;

  setUp(() => server = _Server());

  Future<void> pumpPage(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    await pumpInApp(
      tester,
      NotificationPreferencesPage(
        service: NotificationPreferenceService.withClient(server.api.client),
      ),
      brightness: brightness,
    );
    await tester.pumpAndSettle();
  }

  Finder switchFor(String category, String channel) =>
      find.byKey(ValueKey('preference-$category-$channel'));

  for (final brightness in Brightness.values) {
    testWidgets('tablo kategori kartları ve kanal anahtarları olarak çizilir '
        '(${brightness.name})', (tester) async {
      await pumpPage(tester, brightness: brightness);

      expect(find.text('Hesap güvenliği'), findsOneWidget);
      expect(find.text('İş alarmları'), findsOneWidget);
      expect(find.text('Bülten'), findsOneWidget);
      // Kanal sırası ekranın: PUSH, EMAIL — sunucu EMAIL'i önce gönderdi.
      final pushTop = tester.getTopLeft(switchFor('JOB_ALERTS', 'PUSH')).dy;
      final emailTop = tester.getTopLeft(switchFor('JOB_ALERTS', 'EMAIL')).dy;
      expect(pushTop, lessThan(emailTop));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('anahtar çevrilince yalnız o karar PUT edilir', (tester) async {
    await pumpPage(tester);

    await tester.tap(switchFor('NEWSLETTER', 'EMAIL'));
    await tester.pumpAndSettle();

    final put = server.puts.single;
    expect(_Server.putBody(put), {
      'preferences': [
        {'category': 'NEWSLETTER', 'channel': 'EMAIL', 'enabled': true},
      ],
    });
    final toggled = tester.widget<Switch>(switchFor('NEWSLETTER', 'EMAIL'));
    expect(toggled.value, isTrue);
  });

  // İşlemsel satırı kapatmak sunucuda `400`; anahtar en baştan kilitli
  // olmalı ki kullanıcı deneyip hata görmesin.
  testWidgets('işlemsel kategori kilitli çizilir ve istek göndermez', (
    tester,
  ) async {
    await pumpPage(tester);

    final locked = tester.widget<Switch>(
      switchFor('ACCOUNT_SECURITY', 'EMAIL'),
    );
    expect(locked.onChanged, isNull);
    expect(locked.value, isTrue);

    await tester.tap(switchFor('ACCOUNT_SECURITY', 'EMAIL'));
    await tester.pumpAndSettle();
    expect(server.puts, isEmpty);
    expect(find.textContaining('kapatılamaz'), findsOneWidget);
  });

  testWidgets('sunucu kararı reddederse anahtar yerinde kalır ve mesaj çıkar', (
    tester,
  ) async {
    server.putResponse = const FakeApiResponse(
      statusCode: 400,
      body: {
        'success': false,
        'message': 'Bu bildirim kapatılamaz.',
        'errorCode': 'NOTIFICATION_PREFERENCE_NOT_OPTIONAL',
        'errorCategory': 'VALIDATION_FAILED',
      },
    );
    await pumpPage(tester);

    await tester.tap(switchFor('JOB_ALERTS', 'PUSH'));
    await tester.pumpAndSettle();

    expect(find.text('Bu bildirim kapatılamaz.'), findsOneWidget);
    expect(
      tester.widget<Switch>(switchFor('JOB_ALERTS', 'PUSH')).value,
      isTrue,
    );
  });

  testWidgets('liste alınamazsa hata ve tekrar dene görünür', (tester) async {
    server.getResponse = const FakeApiResponse(
      statusCode: 500,
      body: {'success': false, 'message': 'Sunucu hatası'},
    );
    await pumpPage(tester);

    expect(find.text('Tercihler açılamadı'), findsOneWidget);
    expect(find.text('Sunucu hatası'), findsOneWidget);

    server.getResponse = null;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();

    expect(find.text('İş alarmları'), findsOneWidget);
  });

  testWidgets('boş tablo boş durumla çizilir', (tester) async {
    server = _Server(rows: []);
    await pumpPage(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Tercih bulunamadı'), findsOneWidget);
  });
}
