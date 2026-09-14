import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/presentation/pages/account_info_page.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';

final CurrentUser _user = CurrentUser.fromJson(const {
  'id': 'user-1',
  'firstName': 'Ada',
  'lastName': 'Kaya',
  'email': 'eski@ornek.com',
  'phoneNumber': '5550000000',
  'isEmployer': false,
});

Map<String, dynamic> _patchResponse(List<Map<String, dynamic>> pending) => {
  'success': true,
  'data': {
    'user': {
      'id': 'user-1',
      'firstName': 'Ada',
      'lastName': 'Kaya',
      'email': 'eski@ornek.com',
      'isEmployer': false,
    },
    'pendingVerifications': pending,
  },
};

/// Gerçek doğrulama ekranının yerine geçen sahne: hangi doğrulamanın
/// açıldığını bildiriyor, kullanıcıyı tazeliyor ve "onaylandı" diyerek
/// kapanıyor — yani gerçek ekranın çağırana karşı davranışını taklit ediyor.
class _VerificationStub extends StatefulWidget {
  const _VerificationStub({required this.onOpened, required this.autoConfirm});

  final VoidCallback onOpened;

  /// Kapanırken `true` mü dönsün. `false` ise ekran açık kalıyor.
  final bool autoConfirm;

  @override
  State<_VerificationStub> createState() => _VerificationStubState();
}

class _VerificationStubState extends State<_VerificationStub> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.onOpened();
      if (!widget.autoConfirm) return;
      await context.read<UserProvider>().load(silent: true);
      if (context.mounted) context.pop(true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('doğrulama ekranı'));
}

void main() {
  Future<GoRouter> pumpPage(
    WidgetTester tester,
    FakeApi api, {
    ValueChanged<String>? onVerificationOpened,
  }) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Text('profil ekranı')),
        ),
        GoRoute(
          path: '/account-info',
          builder: (context, state) => AccountInfoPage(user: _user),
        ),
        GoRoute(
          path: '/verification',
          builder: (context, state) {
            final verification = state.extra! as PendingVerification;
            return _VerificationStub(
              onOpened: () => onVerificationOpened?.call(verification.id),
              autoConfirm: onVerificationOpened != null,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>(
            create: (_) =>
                UserProvider(userService: UserService.withClient(api.client)),
          ),
          // Kimlik satırı inceleme durumunu buradan okuyor; sahte sunucu
          // bu uca "yok" diyor, satır bayrağa göre çiziliyor.
          ChangeNotifierProvider<IdentityReviewProvider>(
            create: (_) => IdentityReviewProvider(
              service: IdentityDocumentService.withClient(api.client),
            ),
          ),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );

    router.push('/account-info');
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> enterField(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      ),
      value,
    );
  }

  testWidgets('hesap ekranında e-posta alanı var ve kayıtlı adresle açılıyor', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) =>
          FakeApiResponse(statusCode: 200, body: _patchResponse([])),
    );

    await pumpPage(tester, api);

    final field = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'E-posta',
      ),
    );
    expect(field.controller?.text, 'eski@ornek.com');
  });

  testWidgets('değişen e-posta PATCH gövdesine konuyor', (tester) async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: _patchResponse(const [
          {
            'id': 'ver-1',
            'type': 'EMAIL',
            'sentTo': 'yeni@ornek.com',
            'expiresAt': '2026-09-09T20:15:00Z',
          },
        ]),
      ),
    );

    await pumpPage(tester, api);
    await enterField(tester, 'E-posta', 'yeni@ornek.com');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final body = api.requests.single.data as Map<String, dynamic>;
    expect(body['email'], 'yeni@ornek.com');
  });

  testWidgets('değişmeyen e-posta gövdeye hiç konmuyor', (tester) async {
    final api = FakeApi(
      handler: (_) =>
          FakeApiResponse(statusCode: 200, body: _patchResponse([])),
    );

    await pumpPage(tester, api);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final body = api.requests.single.data as Map<String, dynamic>;
    expect(body.containsKey('email'), isFalse);
  });

  testWidgets('doğrulama bekleyen alan varsa kod ekranına geçiliyor', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: _patchResponse(const [
          {
            'id': 'ver-1',
            'type': 'PHONE',
            'sentTo': '5551112233',
            'expiresAt': '2026-09-09T20:15:00Z',
          },
        ]),
      ),
    );

    await pumpPage(tester, api);
    await enterField(tester, 'Telefon', '5551112233');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('doğrulama ekranı'), findsOneWidget);
  });

  // Doğrulama gerekmeyen bir kayıtta eski davranış korunuyor: bildir ve kapan.
  testWidgets('doğrulama beklenmiyorsa ekran kapanıyor ve bildirim çıkıyor', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) =>
          FakeApiResponse(statusCode: 200, body: _patchResponse([])),
    );

    await pumpPage(tester, api);
    await enterField(tester, 'Meslek', 'Barista');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Profilin güncellendi.'), findsOneWidget);
    expect(find.text('profil ekranı'), findsOneWidget);
    expect(find.text('doğrulama ekranı'), findsNothing);
  });

  // Tek `PATCH` hem telefonu hem e-postayı değiştirebiliyor; ikisi de
  // listeye giriyor ve sırayla sorulmalı.
  testWidgets('iki doğrulama bekliyorsa sırayla isteniyor', (tester) async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: _patchResponse(const [
          {'id': 'ver-1', 'type': 'PHONE', 'sentTo': '5551112233'},
          {'id': 'ver-2', 'type': 'EMAIL', 'sentTo': 'yeni@ornek.com'},
        ]),
      ),
    );
    final opened = <String>[];

    await pumpPage(tester, api, onVerificationOpened: opened.add);
    await enterField(tester, 'Telefon', '5551112233');
    await enterField(tester, 'E-posta', 'yeni@ornek.com');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(opened, ['ver-1', 'ver-2']);
  });

  // Doğrulama sonrası alanlar tazelenen kullanıcıyla güncelleniyor. Kaydet'e
  // ikinci kez basıldığında bu değerler "değişmiş" sayılmamalı, yoksa aynı
  // e-posta yeniden gönderilir ve gereksiz bir doğrulama daha başlar.
  testWidgets('tazelenen değer ikinci kaydetmede yeniden gönderilmiyor', (
    tester,
  ) async {
    var patchCount = 0;
    final api = FakeApi(
      handler: (options) {
        if (options.method == 'PATCH') {
          patchCount++;
          return FakeApiResponse(
            statusCode: 200,
            body: _patchResponse(const [
              {'id': 'ver-1', 'type': 'EMAIL', 'sentTo': 'yeni@ornek.com'},
            ]),
          );
        }
        // `/users/me` tazelemesi: sunucu artık yeni e-postayı döndürüyor.
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'user-1',
              'firstName': 'Ada',
              'lastName': 'Kaya',
              'email': 'yeni@ornek.com',
              'isEmployer': false,
            },
          },
        );
      },
    );

    await pumpPage(tester, api, onVerificationOpened: (_) {});
    await enterField(tester, 'E-posta', 'yeni@ornek.com');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(patchCount, 1);

    // Kullanıcı doğrulamayı tamamladı, alanlar tazelendi. Hiçbir şey
    // değiştirmeden tekrar kaydediliyor.
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final lastPatch = api.requests.lastWhere(
      (request) => request.method == 'PATCH',
    );
    expect(
      (lastPatch.data as Map<String, dynamic>).containsKey('email'),
      isFalse,
    );
  });

  testWidgets(
    'e-posta başka hesapta kayıtlıysa sunucunun mesajı gösteriliyor',
    (tester) async {
      // Sunucu bu durumu `409` belgeliyor ama `ValidationException`
      // fırlattığı için gerçekte `400` dönüyor; ekran ikisini de aynı
      // şekilde karşılamalı.
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Bu e-posta adresi başka bir hesapta kayıtlı',
          },
        ),
      );

      await pumpPage(tester, api);
      await enterField(tester, 'E-posta', 'baskasi@ornek.com');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(
        find.text('Bu e-posta adresi başka bir hesapta kayıtlı'),
        findsOneWidget,
      );
      expect(find.text('doğrulama ekranı'), findsNothing);
    },
  );
}
