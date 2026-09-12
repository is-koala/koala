import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/presentation/pages/employer_type_page.dart';
import 'package:koala/employee/features/auth/presentation/registration_routes.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/identity_gate_test_support.dart';

const _companyFormTitle = 'Şirket formu';

/// Kayıt sonrası tür seçimini gerçek rotalarla sürer; şirket formu ve kimlik
/// ekranı yerine sözleşmelerini taşıyan sahte sayfalar var.
class _RegistrationHarness {
  _RegistrationHarness({required bool identityVerified})
    : _identityVerified = identityVerified;

  bool _identityVerified;

  late final FakeApi api = FakeApi(
    handler: (_) => FakeApiResponse(
      statusCode: 200,
      body: employerMeResponse(identityVerified: _identityVerified),
    ),
  );

  late final UserProvider userProvider = UserProvider(
    userService: UserService.withClient(api.client),
  );

  void markVerified() => _identityVerified = true;

  int get meRequestCount =>
      api.requests.where((request) => request.path == '/users/me').length;

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: RegistrationRoutes.employerType,
      routes: [
        GoRoute(
          path: RegistrationRoutes.employerType,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const EmployerTypePage(),
          ),
        ),
        GoRoute(
          path: RegistrationRoutes.companyInformations,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const Scaffold(body: Text(_companyFormTitle)),
          ),
        ),
        stubIdentityVerificationRoute(),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: userProvider,
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _chooseCompany(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('employer-type-company')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('işveren bireysel veya şirket olarak devam edebilir', (
    tester,
  ) async {
    var selection = '';

    await tester.pumpWidget(
      MaterialApp(
        home: EmployerTypePage(
          onIndividualSelected: () => selection = 'individual',
          onCompanySelected: () => selection = 'company',
        ),
      ),
    );

    expect(find.text('Bireysel İşveren'), findsOneWidget);
    expect(find.text('Şirket Olarak Devam Et'), findsOneWidget);

    await tester.tap(find.text('Bireysel İşveren'));
    expect(selection, 'individual');

    await tester.tap(find.text('Şirket Olarak Devam Et'));
    expect(selection, 'company');
  });

  group('şirket türü kimlik kapısı', () {
    testWidgets('doğrulanmamış işveren şirket formundan önce kimlik ekranına '
        'gider', (tester) async {
      final harness = _RegistrationHarness(identityVerified: false);
      await harness.pump(tester);

      await _chooseCompany(tester);

      expect(
        find.text(_companyFormTitle),
        findsNothing,
        reason:
            'Sunucu doğrulanmamış kullanıcının şirketini reddediyor; form '
            'açılmamalı.',
      );
      expect(find.text('Kimlik doğrulaması gerekli'), findsOneWidget);

      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      expect(find.text(identityStubTitle), findsOneWidget);
    });

    testWidgets('doğrulama bitince /users/me tazelenir ve şirket formuna '
        'geçilir', (tester) async {
      final harness = _RegistrationHarness(identityVerified: false);
      await harness.pump(tester);

      await _chooseCompany(tester);
      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();
      final requestsBeforeVerification = harness.meRequestCount;

      harness.markVerified();
      await tester.tap(find.byKey(identityVerifiedKey));
      await tester.pumpAndSettle();

      expect(harness.meRequestCount, requestsBeforeVerification + 1);
      expect(harness.userProvider.user?.identityVerified, isTrue);
      expect(find.text(_companyFormTitle), findsOneWidget);
      expect(find.text('Nasıl iş vermek istersin?'), findsNothing);
    });

    testWidgets('doğrulanmış işveren doğrudan şirket formuna gider', (
      tester,
    ) async {
      final harness = _RegistrationHarness(identityVerified: true);
      await harness.pump(tester);

      await _chooseCompany(tester);

      expect(find.text('Kimlik doğrulaması gerekli'), findsNothing);
      expect(find.text(identityStubTitle), findsNothing);
      expect(find.text(_companyFormTitle), findsOneWidget);
    });

    testWidgets('kutuda vazgeçen işveren tür seçiminde kalır', (tester) async {
      final harness = _RegistrationHarness(identityVerified: false);
      await harness.pump(tester);

      await _chooseCompany(tester);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(find.text('Nasıl iş vermek istersin?'), findsOneWidget);
      expect(find.text(_companyFormTitle), findsNothing);
      expect(find.text(identityStubTitle), findsNothing);
    });
  });
}
