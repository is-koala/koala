import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/models/session_detail.dart';
import 'package:koala/product/services/session_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/session_view.dart';

import '../../support/fake_api.dart';
import '../../support/finders.dart';

const _sessionsJson = <Map<String, dynamic>>[
  {
    'id': 'ses-1',
    'deviceType': 'IOS',
    'deviceName': 'iPhone 14 Pro Max · iOS 18.1 · Koala 1.1.0',
    'location': 'İstanbul, TR',
    'current': true,
  },
  {
    'id': 'ses-2',
    'deviceType': 'ANDROID',
    'deviceName': 'Android · Koala 1.0.9',
    'current': false,
  },
];

/// Oturum listesi ve ayrıntı uçlarını karşılayan sahte sunucu.
///
/// [detailStatus] `404` iken eski sunucu taklit ediliyor: ayrıntı ucu yok,
/// liste olduğu gibi duruyor.
class _Server {
  int detailStatus = 200;
  List<Map<String, dynamic>> sessions = List.of(_sessionsJson);

  late final FakeApi api = FakeApi(handler: handle);

  FakeApiResponse handle(RequestOptions request) {
    if (request.path == '/users/me/sessions' && request.method == 'GET') {
      return FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': sessions},
      );
    }
    final match = RegExp(
      r'^/users/me/sessions/([^/]+)$',
    ).firstMatch(request.path);
    if (match != null && request.method == 'GET') {
      if (detailStatus == 404) {
        return const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'message': 'Oturum bulunamadı',
            'errorCategory': 'RESOURCE_NOT_FOUND',
          },
        );
      }
      if (detailStatus != 200) {
        return FakeApiResponse(
          statusCode: detailStatus,
          body: const {
            'success': false,
            'message': 'Sunucu hatası',
            'errorCategory': 'INTERNAL_ERROR',
          },
        );
      }
      final row = sessions.firstWhere((row) => row['id'] == match.group(1));
      return FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            ...row,
            'deviceId': 'dev-${row['id']}',
            'ipAddress': '85.100.1.1',
            'logins': 2,
            'loginHistory': const [],
          },
        },
      );
    }
    return const FakeApiResponse(statusCode: 404, body: {'success': false});
  }

  Iterable<RequestOptions> get detailRequests => api.requests.where(
    (request) =>
        request.method == 'GET' &&
        request.path.startsWith('/users/me/sessions/'),
  );

  Iterable<RequestOptions> get listRequests => api.requests.where(
    (request) =>
        request.method == 'GET' && request.path == '/users/me/sessions',
  );
}

void main() {
  late _Server server;

  setUp(() => server = _Server());

  /// Liste `/`'de, ayrıntı rotası bir yer tutucu: sayfa `extra`'daki
  /// [SessionDetail]'i yazıyor ve [popResult] ile kapanıyor.
  Future<void> pumpView(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    bool? popResult,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SessionView(
              service: SessionService.withClient(server.api.client),
            ),
          ),
        ),
        GoRoute(
          path: AccountRoutes.sessionDetail,
          builder: (context, state) {
            final detail = state.extra! as SessionDetail;
            return Scaffold(
              body: Column(
                children: [
                  Text(
                    'ayrıntı: ${detail.session.id} / ${detail.session.deviceId}',
                  ),
                  TextButton(
                    onPressed: () => context.pop(popResult),
                    child: const Text('geri'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(ValueKey('session-$id'));

  for (final brightness in Brightness.values) {
    testWidgets('satıra dokununca ayrıntı çekilir ve sayfa açılır '
        '(${brightness.name})', (tester) async {
      await pumpView(tester, brightness: brightness);

      // Ayrıntı açılabiliyor: her satırda ok var.
      expect(findAppIcon(AppIcons.arrowRight), findsNWidgets(2));

      await tester.tap(row('ses-2'));
      await tester.pumpAndSettle();

      expect(server.detailRequests.single.path, '/users/me/sessions/ses-2');
      expect(find.text('ayrıntı: ses-2 / dev-ses-2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('kendi oturumu da açılır (adlandırma için)', (tester) async {
    await pumpView(tester);

    await tester.tap(row('ses-1'));
    await tester.pumpAndSettle();

    expect(find.text('ayrıntı: ses-1 / dev-ses-1'), findsOneWidget);
  });

  testWidgets('ayrıntıdan true ile dönülünce liste yeniden çekilir', (
    tester,
  ) async {
    await pumpView(tester, popResult: true);

    await tester.tap(row('ses-2'));
    await tester.pumpAndSettle();
    server.sessions = [_sessionsJson.first];
    await tester.tap(find.text('geri'));
    await tester.pumpAndSettle();

    expect(server.listRequests, hasLength(2));
    expect(row('ses-2'), findsNothing);
    expect(row('ses-1'), findsOneWidget);
  });

  testWidgets('ayrıntıdan sonuçsuz dönülünce liste yeniden çekilmez', (
    tester,
  ) async {
    await pumpView(tester);

    await tester.tap(row('ses-2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('geri'));
    await tester.pumpAndSettle();

    expect(server.listRequests, hasLength(1));
  });

  // Eski sunucu (0.9.28 öncesi) ayrıntı ucunu tanımıyor. Kullanıcı bir hata
  // görmemeli; satırlar bundan sonra düz satır.
  testWidgets('eski sunucu 404: toast yok, satırlar dokunulmaz olur', (
    tester,
  ) async {
    server.detailStatus = 404;
    await pumpView(tester);

    await tester.tap(row('ses-2'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('ayrıntı:'), findsNothing);
    expect(findAppIcon(AppIcons.arrowRight), findsNothing);
    // Liste sessizce tazelendi ve oturum hâlâ duruyor: uç yok sayıldı.
    expect(server.listRequests, hasLength(2));
    expect(row('ses-2'), findsOneWidget);

    await tester.tap(row('ses-1'));
    await tester.pumpAndSettle();

    expect(server.detailRequests, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
  });

  // Aynı `404` bu arada kapanmış bir oturum için de gelir: liste yenilenir,
  // oturum düşer ve ayrıntı desteği geri çekilmez.
  testWidgets('kapanmış oturumun 404ü ayrıntı desteğini kapatmaz', (
    tester,
  ) async {
    await pumpView(tester);

    server.detailStatus = 404;
    server.sessions = [_sessionsJson.first];
    await tester.tap(row('ses-2'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(row('ses-2'), findsNothing);
    expect(findAppIcon(AppIcons.arrowRight), findsOneWidget);
  });

  testWidgets('ayrıntı başka bir hatayla gelirse sunucu mesajı toast', (
    tester,
  ) async {
    server.detailStatus = 500;
    await pumpView(tester);

    await tester.tap(row('ses-2'));
    await tester.pumpAndSettle();

    expect(find.text('Sunucu hatası'), findsOneWidget);
    expect(findAppIcon(AppIcons.arrowRight), findsNWidgets(2));
  });
}
