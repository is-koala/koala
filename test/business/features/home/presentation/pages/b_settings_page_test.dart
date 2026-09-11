import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/pages/b_settings_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_job_templates_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:provider/provider.dart';

import '../../../../../support/notification_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'çıkış uzak çağrıdan önce bildirimleri temizler ve hata geri getirmez',
    (tester) async {
      final notifications = (await tester.runAsync(
        loadedNotificationProvider,
      ))!;
      var wasClearBeforeLogout = false;
      final router = GoRouter(
        initialLocation: '/business/settings',
        routes: [
          GoRoute(
            path: '/business/settings',
            builder: (context, state) => BSettingsPage(
              onLogout: () async {
                wasClearBeforeLogout = notifications.notifications.isEmpty;
                try {
                  throw StateError('uzak çıkış başarısız');
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
            ChangeNotifierProvider(create: (_) => BJobsProvider()),
            ChangeNotifierProvider(create: (_) => BCompanyProvider()),
            ChangeNotifierProvider(create: (_) => BJobTemplatesProvider()),
            ChangeNotifierProvider(create: (_) => BTalentPoolProvider()),
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
