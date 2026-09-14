import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_create_page.dart';
import 'package:koala/business/features/home/presentation/widgets/b_pricing_breakdown_card.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

Finder priceField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField && widget.decoration?.labelText == 'Ücret (₺) *',
);

Future<void> pumpPage(WidgetTester tester, FakeApi quoteApi) async {
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
          'companies': [],
        },
      },
    ),
  );
  final userProvider = UserProvider(
    userService: UserService.withClient(userApi.client),
  );
  await tester.runAsync(userProvider.load);

  final categoryApi = FakeApi(
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
            service: JobCategoryService.withClient(categoryApi.client),
          ),
        ),
      ],
      child: BCreatePage(
        paymentService: BPaymentService.withClient(quoteApi.client),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> enterPriceAndBlur(WidgetTester tester, String price) async {
  await tester.enterText(priceField(), price);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  testWidgets('ücret odağı kaybedince backend dökümünü aynen gösterir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'pricingVersion': 'v1',
            'currency': 'TRY',
            'workerPayout': '1000.10',
            'serviceFeeRate': '0.075',
            'serviceFeeAmount': '75.01',
            'employerTotal': '1075.11',
          },
        },
      ),
    );
    await pumpPage(tester, api);

    await enterPriceAndBlur(tester, '1000.10');

    expect(api.requests.single.data, {'workerPayout': '1000.10'});
    expect(find.text('Çalışan Ücreti'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BPricingBreakdownCard),
        matching: find.text('1.000,10 ₺'),
      ),
      findsOneWidget,
    );
    expect(find.text('Koala Hizmet Bedeli'), findsOneWidget);
    expect(find.text('(%7,5)'), findsOneWidget);
    expect(find.text('75,01 ₺'), findsOneWidget);
    expect(find.text('İşveren Toplamı'), findsOneWidget);
    expect(find.text('1.075,11 ₺'), findsOneWidget);
  });

  testWidgets('döküm alınamazsa not gösterir ve yayınlama açık kalır', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Döküm alınamadı.'},
      ),
    );
    await pumpPage(tester, api);

    await enterPriceAndBlur(tester, '1000.10');

    expect(
      find.text(
        'Fiyat dökümü şu an alınamadı. İlanı yine de yayınlayabilirsin.',
      ),
      findsOneWidget,
    );
    final publish = tester.widget<MyButton>(
      find.widgetWithText(MyButton, 'İlanı Yayınla'),
    );
    expect(publish.onPressed, isNotNull);
  });

  testWidgets('bir liranın altındaki hassas ondalığı teklif ucuna göndermez', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': {}},
      ),
    );
    await pumpPage(tester, api);

    await enterPriceAndBlur(tester, '0.99999999999999999');

    expect(api.requests, isEmpty);
  });
}
