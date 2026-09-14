import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/jobs/presentation/pages/apply_page.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/fixtures.dart';
import '../../../../../support/keyboard.dart';

/// Başvuru formu: ön yazı yazılırken alt çubuk klavyenin üstünde kalıyor ve
/// boş alana dokunmak klavyeyi kapatıyor (is-koala/koala#190).
Future<void> _pumpApply(WidgetTester tester, Brightness brightness) async {
  final api = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': []},
    ),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ApplyProvider(
            service: JobApplicationService.withClient(api.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              UserProvider(userService: UserService.withClient(api.client)),
        ),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        home: ApplyPage(job: buildJob()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} tema: alt çubuk klavyenin üstüne çıkar, boş alana '
      'dokununca ön yazı odağı düşer',
      (tester) async {
        await _pumpApply(tester, brightness);
        await showKeyboard(tester);

        await expectAboveKeyboard(tester, findBottomBarButton());
        await expectTapOutsideDropsFocus(tester, find.byType(TextField));
      },
    );
  }
}
