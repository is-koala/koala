import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/product/features/account/presentation/pages/account_info_page.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/locked_field.dart';
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

/// Şirketsiz işveren: aynı ekranı kendi ayarlarından açıyor.
final CurrentUser _employer = CurrentUser.fromJson(const {
  'id': 'employer-1',
  'firstName': 'Ayşe',
  'lastName': 'İşveren',
  'email': 'ayse@ornek.com',
  'phoneNumber': '5551112233',
  'jobTitle': 'Eski meslek',
  'isEmployer': true,
});

/// Kimliği çipten doğrulanmış çalışan: ad ve soyad artık değiştirilemiyor.
final CurrentUser _verifiedUser = CurrentUser.fromJson(const {
  'id': 'user-2',
  'firstName': 'ÇAĞRI',
  'lastName': 'YILMAZ',
  'email': 'cagri@ornek.com',
  'identityVerified': true,
  'isEmployer': false,
});

Map<String, dynamic> _patchResponse(
  List<Map<String, dynamic>> pending, {
  bool isEmployer = false,
}) => {
  'success': true,
  'data': {
    'user': {
      'id': 'user-1',
      'firstName': 'Ada',
      'lastName': 'Kaya',
      'email': 'eski@ornek.com',
      'isEmployer': isEmployer,
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
    CurrentUser? user,
  }) async {
    final pageUser = user ?? _user;
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
          builder: (context, state) => AccountInfoPage(user: pageUser),
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

    router.push('/account-info', extra: pageUser);
    await tester.pumpAndSettle();
    return router;
  }

  Finder fieldLabelled(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

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

    expect(find.text('Profiliniz güncellendi.'), findsOneWidget);
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

  // İşveren aynı ekranı kendi ayarlarından açıyor; çalışan profilinin
  // alanları orada ne çiziliyor ne gövdeye giriyor.
  testWidgets('işverende çalışan alanları çizilmez ve PATCH gövdesine girmez', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: _patchResponse([], isEmployer: true),
      ),
    );

    await pumpPage(tester, api, user: _employer);

    for (final label in [
      'Meslek',
      'IBAN',
      'Hakkımda',
      'Yetkinlikler',
      'İlgi alanları',
    ]) {
      expect(fieldLabelled(label), findsNothing, reason: '$label çizildi');
    }
    for (final label in ['Ad', 'Soyad', 'Telefon', 'E-posta']) {
      expect(fieldLabelled(label), findsOneWidget, reason: '$label yok');
    }
    expect(find.byKey(const ValueKey('account-address-row')), findsOneWidget);

    await enterField(tester, 'Telefon', '5559998877');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final body = api.requests.single.data as Map<String, dynamic>;
    expect(body, {'phoneNumber': '5559998877'});
    expect(find.text('Profiliniz güncellendi.'), findsOneWidget);
  });

  // #151: çipten gelen ad-soyad kilitli. Kapalı bir metin kutusu değil,
  // kimlik ekranındakiyle aynı kilitli satır çiziliyor ve gövdeye girmiyor.
  testWidgets('kimliği doğrulanmış kullanıcıda ad ve soyad kilitli satır', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) =>
          FakeApiResponse(statusCode: 200, body: _patchResponse([])),
    );

    await pumpPage(tester, api, user: _verifiedUser);

    expect(fieldLabelled('Ad'), findsNothing);
    expect(fieldLabelled('Soyad'), findsNothing);
    final locked = tester.widgetList<LockedField>(find.byType(LockedField));
    expect(locked.map((field) => field.value), ['ÇAĞRI', 'YILMAZ']);
    expect(find.textContaining('ad ve soyad değiştirilemiyor'), findsOneWidget);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final body = api.requests.single.data as Map<String, dynamic>;
    expect(body.containsKey('firstName'), isFalse);
    expect(body.containsKey('lastName'), isFalse);
  });
}
