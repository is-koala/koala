import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/features/account/presentation/pages/blocked_users_page.dart';
import 'package:koala/product/features/account/presentation/pages/reports_page.dart';
import 'package:koala/product/features/account/presentation/pages/sessions_page.dart';
import 'package:koala/product/features/account/presentation/widgets/account_list_clearance.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/widgets/blocked_users_view.dart';
import 'package:koala/product/widgets/report_view.dart';
import 'package:koala/product/widgets/session_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/pump.dart';

/// Silinen `b_*` ikizleriyle çalışan sayfaları arasındaki tek fark alt paydı:
/// işveren kabuğunda [AppSizes.navBarClearance], çalışanda standart. Ortak
/// sayfa bu farkı role bakarak korumalı — iki tarafın da eski davranışı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    SessionManager().resetForTest();
  });
  tearDown(() => SessionManager().resetForTest());

  Future<void> startSession({required bool isEmployer}) => SessionManager()
      .start(accessToken: 'a', refreshToken: 'r', isEmployer: isEmployer);

  test('işveren oturumunda navbar payı, çalışanda standart pay', () async {
    await startSession(isEmployer: true);
    expect(AccountListClearance.bottomPadding(), AppSizes.navBarClearance);

    await startSession(isEmployer: false);
    expect(AccountListClearance.bottomPadding(), AppSizes.space);
  });

  test('oturum okunmadıysa geniş pay varsayılmaz', () {
    expect(AccountListClearance.bottomPadding(), AppSizes.space);
  });

  for (final (isEmployer, expected) in [
    (true, AppSizes.navBarClearance),
    (false, AppSizes.space),
  ]) {
    final role = isEmployer ? 'işveren' : 'çalışan';
    testWidgets('$role kabuğunda üç liste sayfası payı görünüme geçirir', (
      tester,
    ) async {
      await startSession(isEmployer: isEmployer);

      await pumpInApp(tester, const SessionsPage());
      await tester.pumpAndSettle();
      expect(
        tester.widget<SessionView>(find.byType(SessionView)).bottomPadding,
        expected,
      );

      await pumpInApp(tester, const BlockedUsersPage());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BlockedUsersView>(find.byType(BlockedUsersView))
            .bottomPadding,
        expected,
      );

      await pumpInApp(tester, const ReportsPage());
      await tester.pumpAndSettle();
      expect(
        tester.widget<ReportView>(find.byType(ReportView)).bottomPadding,
        expected,
      );
      // Sayfalar gövdelerini gerçek servisle kuruyor; test bağlamında
      // istek 400 ile düşer ve hata durumu çizilir, bu testin konusu değil.
      expect(tester.takeException(), isNull);
    });
  }
}
