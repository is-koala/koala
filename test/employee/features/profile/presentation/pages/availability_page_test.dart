import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/pages/availability_page.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/services/availability_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';

const _userResponse = FakeApiResponse(
  statusCode: 200,
  body: {
    'success': true,
    'data': {
      'id': 'user-1',
      'firstName': 'Yakup',
      'lastName': 'Kahraman',
      'email': 'a@b.com',
      'isEmployer': false,
    },
  },
);

Future<void> pumpPage(
  WidgetTester tester, {
  required UserProvider userProvider,
  required AvailabilityProvider availabilityProvider,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: availabilityProvider),
      ],
      child: MaterialApp(theme: lightTheme, home: const AvailabilityPage()),
    ),
  );
  await tester.pump();
}

void expectMutationsHidden() {
  expect(find.text('Haftalık Şablonu Kaydet'), findsNothing);
  expect(find.text('Aralık Ekle'), findsNothing);
  expect(find.byTooltip('Tarih istisnası ekle'), findsNothing);
}

void main() {
  testWidgets('geciken kullanıcı yüklenirken düzenleme eylemleri gizlidir', (
    tester,
  ) async {
    final userApi = FakeApi(
      handler: (_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return _userResponse;
      },
    );
    final availabilityApi = FakeApi(
      handler: (_) => const FakeApiResponse(statusCode: 500),
    );
    final userProvider = UserProvider(
      userService: UserService.withClient(userApi.client),
    );
    final availabilityProvider = AvailabilityProvider(
      service: AvailabilityService.withClient(availabilityApi.client),
    );

    await pumpPage(
      tester,
      userProvider: userProvider,
      availabilityProvider: availabilityProvider,
    );

    expectMutationsHidden();
    expect(availabilityApi.requests, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'geciken müsaitlik yüklenirken boş haftayı PUT etmek erişilemez',
    (tester) async {
      final userApi = FakeApi(handler: (_) => _userResponse);
      final availabilityApi = FakeApi(
        handler: (request) async {
          if (request.method == 'GET') {
            await Future<void>.delayed(const Duration(seconds: 1));
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'slots': [], 'exceptions': []},
              },
            );
          }
          return const FakeApiResponse(statusCode: 500);
        },
      );
      final userProvider = UserProvider(
        userService: UserService.withClient(userApi.client),
      );
      await tester.runAsync(userProvider.load);
      final availabilityProvider = AvailabilityProvider(
        service: AvailabilityService.withClient(availabilityApi.client),
      );

      await pumpPage(
        tester,
        userProvider: userProvider,
        availabilityProvider: availabilityProvider,
      );

      expectMutationsHidden();
      expect(await availabilityProvider.saveWeekly('user-1'), isFalse);
      expect(
        availabilityApi.requests.where((request) => request.method == 'PUT'),
        isEmpty,
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();

      expect(availabilityProvider.isLoadedFor('user-1'), isTrue);
      expect(find.text('Aralık Ekle'), findsWidgets);
    },
  );
}
