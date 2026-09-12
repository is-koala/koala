import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/presentation/company_identity_gate.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../support/fake_api.dart';
import '../../../../support/identity_gate_test_support.dart';

const _triggerKey = ValueKey('gate-trigger');
const _rejectionKey = ValueKey('gate-rejection');

/// Kapıyı sürüp sonucunu dışarı veren tek düğmelik ekran; kapı bir widget
/// değil, `context` isteyen bir fonksiyon.
class _GateHarness {
  _GateHarness({required bool identityVerified})
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

  /// Kapının son döndürdüğü değer; hiç dönmediyse `null`.
  bool? result;

  CurrentUser? openedWith;

  /// Sunucu "artık doğrulandı" desin.
  void markVerified() => _identityVerified = true;

  int get meRequestCount =>
      api.requests.where((request) => request.path == '/users/me').length;

  Future<void> pump(WidgetTester tester, {bool preloadUser = true}) async {
    if (preloadUser) await tester.runAsync(userProvider.load);

    final router = GoRouter(
      initialLocation: '/trigger',
      routes: [
        GoRoute(
          path: '/trigger',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: Scaffold(
              // Kapı sayfanın kendi `context`'iyle çağrılıyor; rota kurucunun
              // bağlamı Navigator'ın üstünde kalıyor ve kutu açamıyor.
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    key: _triggerKey,
                    onPressed: () async {
                      result = await CompanyIdentityGate.ensureVerified(
                        context,
                      );
                    },
                    child: const Text('Kapıyı dene'),
                  ),
                ),
              ),
              bottomNavigationBar: Builder(
                builder: (context) => TextButton(
                  key: _rejectionKey,
                  onPressed: () async {
                    result = await CompanyIdentityGate.startVerification(
                      context,
                    );
                  },
                  child: const Text('Sunucu reddetti'),
                ),
              ),
            ),
          ),
        ),
        stubIdentityVerificationRoute(onOpened: (user) => openedWith = user),
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

Future<void> _tapTrigger(WidgetTester tester) async {
  await tester.tap(find.byKey(_triggerKey));
  await tester.pumpAndSettle();
}

void main() {
  group('CompanyIdentityGate.isIdentityRequired', () {
    ApiException error({String? errorCode, String message = 'hata'}) {
      return ApiException(
        message: message,
        type: ApiErrorType.validation,
        statusCode: 400,
        errorCode: errorCode,
      );
    }

    test('yalnız USER_MUST_VERIFY_IDENTITY kodunda doğru', () {
      expect(
        CompanyIdentityGate.isIdentityRequired(
          error(errorCode: 'USER_MUST_VERIFY_IDENTITY'),
        ),
        isTrue,
      );
      expect(
        CompanyIdentityGate.isIdentityRequired(
          error(errorCode: 'INVALID_COMPANY_TYPE'),
        ),
        isFalse,
      );
      expect(CompanyIdentityGate.isIdentityRequired(error()), isFalse);
    });

    test('mesaj metnine bakmaz', () {
      expect(
        CompanyIdentityGate.isIdentityRequired(
          error(
            errorCode: 'VALIDATION_FAILED',
            message: 'Bu işlem için kimliğinizi doğrulamanız gerekiyor.',
          ),
        ),
        isFalse,
        reason: 'Yönlendirme errorCode ile karar verir; metin yerelleşebilir.',
      );
    });
  });

  group('CompanyIdentityGate.ensureVerified', () {
    testWidgets('doğrulanmış kullanıcıda kutu açmadan geçer', (tester) async {
      final harness = _GateHarness(identityVerified: true);
      await harness.pump(tester);

      await _tapTrigger(tester);

      expect(harness.result, isTrue);
      expect(find.text('Kimlik doğrulaması gerekli'), findsNothing);
      expect(find.text(identityStubTitle), findsNothing);
    });

    testWidgets('kullanıcı henüz yüklenmemişse önce /users/me okur', (
      tester,
    ) async {
      final harness = _GateHarness(identityVerified: true);
      await harness.pump(tester, preloadUser: false);
      expect(harness.userProvider.user, isNull);

      await _tapTrigger(tester);

      expect(harness.meRequestCount, 1);
      expect(harness.result, isTrue);
    });

    testWidgets('doğrulanmamış kullanıcıyı kimlik ekranına götürür ve dönüşte '
        '/users/me tazeleyip geçirir', (tester) async {
      final harness = _GateHarness(identityVerified: false);
      await harness.pump(tester);
      expect(harness.meRequestCount, 1);

      await _tapTrigger(tester);

      expect(find.text('Kimlik doğrulaması gerekli'), findsOneWidget);
      expect(find.text(identityStubTitle), findsNothing);

      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      expect(find.text(identityStubTitle), findsOneWidget);
      expect(harness.openedWith?.id, 'employer-1');
      expect(harness.result, isNull, reason: 'Kapı ekran kapanana dek bekler.');

      harness.markVerified();
      await tester.tap(find.byKey(identityVerifiedKey));
      await tester.pumpAndSettle();

      expect(harness.meRequestCount, 2);
      expect(harness.userProvider.user?.identityVerified, isTrue);
      expect(harness.result, isTrue);
    });

    testWidgets('kutuda vazgeçen kullanıcı için kimlik ekranı açılmaz', (
      tester,
    ) async {
      final harness = _GateHarness(identityVerified: false);
      await harness.pump(tester);

      await _tapTrigger(tester);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(find.text(identityStubTitle), findsNothing);
      expect(harness.openedWith, isNull);
      expect(harness.result, isFalse);
    });

    testWidgets(
      'sunucu reddettiğinde yerel bayrak doğrulanmış olsa da akış açılır',
      (tester) async {
        // `/users/me` kopyası eski: bayrak doğrulanmış diyor, sunucu değil.
        final harness = _GateHarness(identityVerified: true);
        await harness.pump(tester);
        expect(harness.userProvider.user?.identityVerified, isTrue);

        await tester.tap(find.byKey(_rejectionKey));
        await tester.pumpAndSettle();

        expect(
          find.text('Kimlik doğrulaması gerekli'),
          findsOneWidget,
          reason:
              'Bayrağa güvenilseydi kullanıcı hatasız ama çıkışsız '
              'kalırdı; sunucunun reddi son söz.',
        );

        await tester.tap(find.text('Doğrula'));
        await tester.pumpAndSettle();
        expect(find.text(identityStubTitle), findsOneWidget);

        await tester.tap(find.byKey(identityVerifiedKey));
        await tester.pumpAndSettle();

        expect(harness.meRequestCount, 2);
        expect(harness.result, isTrue);
      },
    );

    testWidgets('kimlik ekranından geri dönen kullanıcı geçemez', (
      tester,
    ) async {
      final harness = _GateHarness(identityVerified: false);
      await harness.pump(tester);

      await _tapTrigger(tester);
      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();
      expect(find.text(identityStubTitle), findsOneWidget);

      // Ekran `true` vermeden kapanıyor: kullanıcı geri okuna bastı.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(harness.result, isFalse);
      expect(harness.meRequestCount, 1, reason: 'Vazgeçişte tazeleme yok.');
    });
  });
}
