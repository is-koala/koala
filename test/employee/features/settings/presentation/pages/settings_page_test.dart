import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/job_alerts_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/presentation/pages/settings_page.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/notification_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kazançlarım satırı kazanç ekranını açar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/earnings',
          builder: (context, state) => const Text('Kazanç hedefi'),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kazançlarım'));
    await tester.pumpAndSettle();

    expect(find.text('Kazanç hedefi'), findsOneWidget);
  });

  testWidgets(
    'çıkış uzak çağrıdan önce bildirimleri temizler ve hata geri getirmez',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notifications = (await tester.runAsync(
        loadedNotificationProvider,
      ))!;
      final logoutError = StateError('uzak çıkış başarısız');
      var wasClearBeforeLogout = false;
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => SettingsPage(
              onLogout: () async {
                wasClearBeforeLogout = notifications.notifications.isEmpty;
                try {
                  throw logoutError;
                } on StateError {
                  // AuthService uzak API hatasını yutup yerel çıkışı sürdürür.
                }
              },
            ),
          ),
          GoRoute(
            path: '/auth',
            builder: (context, state) => const Text('Giriş hedefi'),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider.value(value: notifications),
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => AvailabilityProvider()),
            ChangeNotifierProvider(create: (_) => ApplyProvider()),
            ChangeNotifierProvider(create: (_) => SavedJobsProvider()),
            ChangeNotifierProvider(create: (_) => JobAlertsProvider()),
            ChangeNotifierProvider(create: (_) => ReviewProvider()),
          ],
          child: MaterialApp.router(theme: lightTheme, routerConfig: router),
        ),
      );

      await tester.ensureVisible(find.text('Çıkış Yap'));
      await tester.tap(find.text('Çıkış Yap'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(wasClearBeforeLogout, isTrue);
      expect(notifications.notifications, isEmpty);
      expect(notifications.unreadCount, 0);
      expect(find.text('Giriş hedefi'), findsOneWidget);
    },
  );
}
