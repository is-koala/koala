import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/pages/b_settings_page.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/presentation/pages/settings_page.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/identity_gate_test_support.dart';

/// Ayarlar menüsünün satırı → açılan rota. İki kabuğun aynı satırı aynı
/// rotaya götürdüğü bu tabloyla kanıtlanıyor.
const _tileRoutes = {
  'Hesabı Düzenle': AccountRoutes.accountInfo,
  'Adresim': AccountRoutes.address,
  'Şifreyi Değiştir': AccountRoutes.changePassword,
  'Oturumlar': AccountRoutes.sessions,
  'Bildirim Tercihleri': AccountRoutes.notificationPreferences,
  'Şikayetlerim': AccountRoutes.reports,
  'Engellediklerim': AccountRoutes.blockedUsers,
  'Hesabı Sil': AccountRoutes.accountDeletion,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Menüyü, hesap rotalarının yerine geçen sahnelerle birlikte kurar.
  /// Her sahne açılışını ve aldığı `extra`'yı [opened]'a yazıyor.
  Future<GoRouter> pumpMenu(
    WidgetTester tester, {
    required Widget menu,
    required String menuLocation,
    required FakeApi api,
    required List<(String, Object?)> opened,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: menuLocation,
      routes: [
        GoRoute(
          path: menuLocation,
          pageBuilder: (context, state) =>
              MaterialPage<void>(key: state.pageKey, child: menu),
        ),
        for (final route in _tileRoutes.values)
          GoRoute(
            path: route,
            pageBuilder: (context, state) {
              opened.add((route, state.extra));
              return MaterialPage<void>(
                key: state.pageKey,
                child: Scaffold(body: Text('sahne $route')),
              );
            },
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(
            create: (_) =>
                UserProvider(userService: UserService.withClient(api.client)),
          ),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapTile(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title));
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  for (final shell in [
    (name: 'çalışan', menu: const SettingsPage(), location: '/settings'),
    (
      name: 'işveren',
      menu: const BSettingsPage(),
      location: '/business/settings',
    ),
  ]) {
    testWidgets(
      '${shell.name} ayarlarındaki her hesap satırı ortak rotaya gider',
      (tester) async {
        final api = FakeApi(
          handler: (_) => FakeApiResponse(
            statusCode: 200,
            body: employerMeResponse(identityVerified: false),
          ),
        );
        final opened = <(String, Object?)>[];

        final router = await pumpMenu(
          tester,
          menu: shell.menu,
          menuLocation: shell.location,
          api: api,
          opened: opened,
        );

        for (final entry in _tileRoutes.entries) {
          await tapTile(tester, entry.key);
          expect(
            find.text('sahne ${entry.value}'),
            findsOneWidget,
            reason: '${entry.key} ${entry.value} rotasını açmadı',
          );
          expect(opened.last.$1, entry.value);
          // Sahneyi kapatıp menüye dön.
          router.pop();
          await tester.pumpAndSettle();
        }

        // Hesap bilgileri ve adres `extra` olarak kullanıcıyı ister; menü
        // profil yüklenmemişken önce `/users/me`'yi getirip öyle geçiyor.
        for (final route in [
          AccountRoutes.accountInfo,
          AccountRoutes.address,
        ]) {
          final extra = opened.firstWhere((item) => item.$1 == route).$2;
          expect(
            extra,
            isA<CurrentUser>(),
            reason: '$route kullanıcısız açıldı',
          );
        }
        expect(
          api.requests.where((request) => request.path == '/users/me'),
          hasLength(1),
          reason: 'kullanıcı bir kez yüklenip sağlayıcıda tutulmalı',
        );
      },
    );
  }

  testWidgets('profil alınamazsa adres ekranı açılmaz ve sebep söylenir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Sunucu hatası'},
      ),
    );
    final opened = <(String, Object?)>[];

    await pumpMenu(
      tester,
      menu: const BSettingsPage(),
      menuLocation: '/business/settings',
      api: api,
      opened: opened,
    );
    await tapTile(tester, 'Adresim');

    expect(opened, isEmpty);
    expect(find.text('Sunucu hatası'), findsOneWidget);
  });
}
