import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_create_page.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/widgets/keyboard_done_bar.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/keyboard.dart';
import '../../../../../support/pump.dart';

/// İlan formu: alt çubuk klavyenin üstüne çıkıyor, boş alan odağı düşürüyor
/// ve iOS'ta ücret / yaş alanlarının tuş takımı "Bitti" şeridi alıyor
/// (is-koala/koala#190).
Future<void> _pumpCreate(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  final userApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'id': 'employer-1',
          'firstName': 'Ayşe',
          'lastName': 'İşveren',
          'email': 'ayse@example.com',
          'isEmployer': true,
          'identityVerified': true,
          'companies': [
            {
              'companyId': 'company-1',
              'companyName': 'Koala A.Ş.',
              'approved': true,
              'role': 'OWNER',
            },
          ],
        },
      },
    ),
  );
  final userProvider = UserProvider(
    userService: UserService.withClient(userApi.client),
  );
  await tester.runAsync(userProvider.load);

  final emptyApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': []},
    ),
  );

  await pumpInApp(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(
          create: (_) => JobCategoryProvider(
            service: JobCategoryService.withClient(emptyApi.client),
          ),
        ),
      ],
      child: BCreatePage(
        paymentService: BPaymentService.withClient(emptyApi.client),
      ),
    ),
    brightness: brightness,
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} tema: İlanı Yayınla çubuğu klavyenin üstüne çıkar, '
      'boş alana dokununca odak düşer',
      (tester) async {
        await _pumpCreate(tester, brightness: brightness);
        await showKeyboard(tester);

        await expectAboveKeyboard(tester, findBottomBarButton());
        await expectTapOutsideDropsFocus(tester, _field('İlan Başlığı *'));
      },
    );
  }

  testWidgets(
    'iOS: ücret ve yaş alanları odaklanınca klavyenin üstünde Bitti çıkar',
    (tester) async {
      await _pumpCreate(tester);
      await showKeyboard(tester);

      for (final label in ['Ücret (₺) *', 'Min Yaş *']) {
        await tester.ensureVisible(_field(label));
        await tester.pump();
        await tester.tap(_field(label));
        await tester.pump();

        expect(
          find.text(KeyboardDoneBar.label),
          findsOneWidget,
          reason: '$label alanında şerit yok',
        );
      }

      await tester.tap(find.text(KeyboardDoneBar.label));
      await tester.pump();

      expect(anyFieldFocused(tester), isFalse);
      expect(find.byType(KeyboardDoneBar), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
