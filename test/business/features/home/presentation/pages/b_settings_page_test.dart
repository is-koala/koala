import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/pages/b_settings_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_job_templates_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/notification_test_support.dart';
import '../../../../../support/review_fixtures.dart';
import '../../../../../support/work_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'çıkış uzak çağrıdan önce bildirimleri temizler ve hata geri getirmez',
    (tester) async {
      final notifications = (await tester.runAsync(
        loadedNotificationProvider,
      ))!;
      // İşveren de değerlendirme bırakıyor (#185): çıkışta oturum belleği
      // de silinmeli, yoksa aynı cihazdaki sonraki hesap öncekinin "az önce
      // gönderdim" kaydını görürdü.
      final reviews = ReviewProvider(
        service: ReviewService.withClient(reviewApi().client),
      );
      await tester.runAsync(
        () => reviews.submitReview(
          assignmentId: 'assignment-1',
          rating: 4,
          comment: 'Sonraki hesap görmesin',
        ),
      );
      final assignment = Assignment.fromJson(
        assignmentJson(status: 'COMPLETED'),
      );
      expect(reviews.hasReviewed(assignment), isTrue);
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
            ChangeNotifierProvider(create: (_) => IdentityReviewProvider()),
            ChangeNotifierProvider(create: (_) => AvailabilityProvider()),
            ChangeNotifierProvider(create: (_) => BJobsProvider()),
            ChangeNotifierProvider(create: (_) => BCompanyProvider()),
            ChangeNotifierProvider(create: (_) => BJobTemplatesProvider()),
            ChangeNotifierProvider(create: (_) => BTalentPoolProvider()),
            ChangeNotifierProvider.value(value: reviews),
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
      expect(reviews.hasReviewed(assignment), isFalse);
      expect(reviews.ownReviewFor(assignment), isNull);
    },
  );
}
