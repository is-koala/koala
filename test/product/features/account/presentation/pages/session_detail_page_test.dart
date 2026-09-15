import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/features/account/presentation/pages/session_detail_page.dart';
import 'package:koala/product/models/session_detail.dart';
import 'package:koala/product/services/session_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/settings_hint.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';

const _detailJson = <String, dynamic>{
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
  'current': false,
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
};

/// `GET /users/me/sessions/{id}`, `PATCH /users/me/devices/{id}` ve
/// `DELETE /users/me/sessions/{id}` uçlarını karşılayan sahte sunucu.
class _Server {
  _Server({Map<String, dynamic>? detail})
    : detail = Map<String, dynamic>.of(detail ?? _detailJson);

  Map<String, dynamic> detail;
  FakeApiResponse? patchResponse;
  FakeApiResponse? deleteResponse;
  FakeApiResponse? getResponse;

  late final FakeApi api = FakeApi(handler: handle);

  FakeApiResponse handle(RequestOptions request) {
    if (request.method == 'PATCH' &&
        request.path == '/users/me/devices/dev-1') {
      final override = patchResponse;
      if (override != null) return override;
      final name = (request.data as Map<String, dynamic>)['name'] as String;
      detail = {...detail, 'deviceName': name, 'deviceCustomName': name};
      return const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {'id': 'dev-1'},
        },
      );
    }
    if (request.path == '/users/me/sessions/ses-1') {
      if (request.method == 'DELETE') {
        return deleteResponse ??
            const FakeApiResponse(statusCode: 200, body: {'success': true});
      }
      return getResponse ??
          FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': detail},
          );
    }
    return const FakeApiResponse(statusCode: 404, body: {'success': false});
  }

  Iterable<RequestOptions> requestsOf(String method) =>
      api.requests.where((request) => request.method == method);
}

void main() {
  late _Server server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Server();
  });

  /// Sayfa `/session-detail`'e `push` ile açılıyor ve `pop(true)` ile
  /// kapanabiliyor; sonucu ana rota yakalıyor.
  Future<bool? Function()> pumpPage(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Map<String, dynamic>? detail,
  }) async {
    bool? popped;
    var pushed = false;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) {
                if (!pushed) {
                  pushed = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    popped = await context.push<bool>(
                      AccountRoutes.sessionDetail,
                    );
                  });
                }
                return const Text('liste');
              },
            ),
          ),
        ),
        GoRoute(
          path: AccountRoutes.sessionDetail,
          builder: (context, state) => SessionDetailPage(
            initial: SessionDetail.fromJson(detail ?? server.detail),
            service: SessionService.withClient(server.api.client),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    );
    return () => popped;
  }

  final renameButton = find.byKey(const ValueKey('session-rename'));
  final revokeButton = find.byKey(const ValueKey('session-revoke'));

  for (final brightness in Brightness.values) {
    testWidgets('dolu ayrıntı: cihaz, IP, konum, zamanlar, giriş geçmişi '
        '(${brightness.name})', (tester) async {
      await pumpPage(tester, brightness: brightness);
      await tester.pumpAndSettle();

      expect(
        find.text('iPhone 14 Pro Max · iOS 18.1 · Koala 1.1.0'),
        findsOneWidget,
      );
      expect(find.text('85.100.1.1'), findsNWidgets(1));
      expect(find.text('Yaklaşık: İstanbul, TR'), findsOneWidget);
      expect(find.text('Toplam giriş'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Giriş geçmişi'), findsOneWidget);
      expect(find.text('Başarılı'), findsOneWidget);
      expect(find.text('Başarısız'), findsOneWidget);
      expect(find.text('5.5.5.5 · —'), findsOneWidget);
      expect(find.text('Bu cihaz'), findsNothing);
      expect(renameButton, findsOneWidget);
      expect(revokeButton, findsOneWidget);
      expect(find.text(SessionDetailPage.emptyHistoryNote), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('kendi oturumu: "Bu cihaz" rozeti var, kapatma düğmesi yok', (
    tester,
  ) async {
    await pumpPage(tester, detail: {..._detailJson, 'current': true});
    await tester.pumpAndSettle();

    expect(find.text('Bu cihaz'), findsOneWidget);
    expect(revokeButton, findsNothing);
    expect(renameButton, findsOneWidget);
  });

  // Sunucu girişleri 0.9.28'den beri kaydediyor; eski girişler listede
  // olmadığı için boş liste "hiç giriş yok" değil.
  testWidgets('boş geçmiş ve boş konum: not ve tire', (tester) async {
    await pumpPage(
      tester,
      detail: {
        ..._detailJson,
        'location': null,
        'ipAddress': null,
        'createdAt': null,
        'loginHistory': [],
        'logins': 0,
      },
    );
    await tester.pumpAndSettle();

    expect(find.text(SessionDetailPage.emptyHistoryNote), findsOneWidget);
    expect(find.byType(SettingsHint), findsOneWidget);
    expect(find.text('Başarılı'), findsNothing);
    // IP, konum ve oluşturulma satırlarının üçü de tire.
    expect(find.text(SessionDetailPage.missing), findsNWidgets(3));
    expect(find.text('Yaklaşık:'), findsNothing);
  });

  testWidgets('adlandırma 200: PATCH gider, ad ekranda yenilenir', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(renameButton);
    await tester.pumpAndSettle();

    // Kutu sunucunun türettiği adla değil boş açılıyor: özel ad yok.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
    expect(find.text('Cihazı adlandır'), findsNWidgets(2));
    final save = find.widgetWithText(TextButton, 'Kaydet');
    expect(tester.widget<TextButton>(save).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'İş telefonum');
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final patch = server.requestsOf('PATCH').single;
    expect(patch.path, '/users/me/devices/dev-1');
    expect(patch.data, {'name': 'İş telefonum'});
    expect(server.requestsOf('GET'), hasLength(1));
    expect(find.text('İş telefonum'), findsOneWidget);
    expect(find.text('Cihaz adı kaydedildi'), findsOneWidget);
  });

  testWidgets('adlandırma kutusu 60 karakterde durur', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(renameButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a' * 80);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text.length, 60);
  });

  testWidgets('adlandırma 400: sunucu mesajı toast, ad değişmez', (
    tester,
  ) async {
    server.patchResponse = const FakeApiResponse(
      statusCode: 400,
      body: {
        'success': false,
        'message': 'Cihaz adı en fazla 60 karakter olabilir',
        'errorCategory': 'VALIDATION_FAILED',
      },
    );
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(renameButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'yeni ad');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Kaydet'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cihaz adı en fazla 60 karakter olabilir'),
      findsOneWidget,
    );
    expect(
      find.text('iPhone 14 Pro Max · iOS 18.1 · Koala 1.1.0'),
      findsOneWidget,
    );
    expect(find.text('yeni ad'), findsNothing);
    expect(server.requestsOf('GET'), isEmpty);
  });

  testWidgets('cihaz kimliği yoksa adlandırma düğmesi çizilmez', (
    tester,
  ) async {
    await pumpPage(tester, detail: {..._detailJson, 'deviceId': null});
    await tester.pumpAndSettle();

    expect(renameButton, findsNothing);
    expect(revokeButton, findsOneWidget);
  });

  testWidgets('oturumu kapat: onay → DELETE → sayfa true ile kapanır', (
    tester,
  ) async {
    final result = await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(revokeButton);
    await tester.pumpAndSettle();
    expect(find.text('Oturumu kapat'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(TextButton, 'Kapat'));
    await tester.pumpAndSettle();

    final delete = server.requestsOf('DELETE').single;
    expect(delete.path, '/users/me/sessions/ses-1');
    expect(result(), isTrue);
    expect(find.text('liste'), findsOneWidget);
  });

  testWidgets('kapatma vazgeçilirse istek çıkmaz', (tester) async {
    final result = await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(revokeButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
    await tester.pumpAndSettle();

    expect(server.requestsOf('DELETE'), isEmpty);
    expect(result(), isNull);
    expect(revokeButton, findsOneWidget);
  });

  // İzin yok: sunucu başkasının oturumunu "yok" diye dönüyor. Sayfa
  // kapanmaz, kullanıcı mesajı görür.
  testWidgets('kapatma 404: toast, sayfa açık kalır', (tester) async {
    server.deleteResponse = const FakeApiResponse(
      statusCode: 404,
      body: {
        'success': false,
        'message': 'Oturum bulunamadı',
        'errorCategory': 'RESOURCE_NOT_FOUND',
      },
    );
    final result = await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(revokeButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Kapat'));
    await tester.pumpAndSettle();

    expect(find.text('Oturum bulunamadı'), findsOneWidget);
    expect(result(), isNull);
    expect(revokeButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(revokeButton).onPressed, isNotNull);
  });

  testWidgets('yenilemede 404: oturum kapanmış, sayfa true ile kapanır', (
    tester,
  ) async {
    server.getResponse = const FakeApiResponse(
      statusCode: 404,
      body: {
        'success': false,
        'message': 'Oturum bulunamadı',
        'errorCategory': 'RESOURCE_NOT_FOUND',
      },
    );
    final result = await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(server.requestsOf('GET'), hasLength(1));
    expect(result(), isTrue);
    expect(find.text('liste'), findsOneWidget);
  });

  testWidgets('kullanıcıya dönük metinler "siz" diliyle', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(renameButton);
    await tester.pumpAndSettle();

    String dialogText() => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data ?? '')
        .join(' ');

    expect(dialogText(), contains('sizin'));
    expect(dialogText(), isNot(matches(RegExp(r'\b(sen|senin|seni)\b'))));

    await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
    await tester.pumpAndSettle();
    await tester.tap(revokeButton);
    await tester.pumpAndSettle();

    expect(dialogText(), isNot(matches(RegExp(r'\b(sen|senin|seni)\b'))));
  });
}
