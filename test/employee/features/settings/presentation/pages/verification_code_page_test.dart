import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/auth/services/verification_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/presentation/pages/verification_code_page.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';

const PendingVerification _emailVerification = PendingVerification(
  id: 'ver-1',
  type: 'EMAIL',
  sentTo: 'yeni@ornek.com',
  message: '{email.verification.message}',
);

const PendingVerification _phoneVerification = PendingVerification(
  id: 'ver-2',
  type: 'PHONE',
  sentTo: '5550000000',
  message: '{phone.verification.message}',
);

/// `/users/me` yanıtının en küçük geçerli hâli.
Map<String, dynamic> _userBody({String email = 'eski@ornek.com'}) => {
  'id': 'user-1',
  'firstName': 'Ada',
  'lastName': 'Kaya',
  'email': email,
  'isEmployer': false,
};

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    FakeApi api, {
    PendingVerification verification = _emailVerification,
    void Function(bool)? onFinished,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>(
        create: (_) =>
            UserProvider(userService: UserService.withClient(api.client)),
        child: MaterialApp(
          theme: brightness == Brightness.dark ? darkTheme : lightTheme,
          home: VerificationCodePage(
            verification: verification,
            verificationService: VerificationService.withClient(api.client),
            onFinished: onFinished,
          ),
        ),
      ),
    );
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField).first, code);
    await tester.pump();
  }

  testWidgets('e-postaya gönderilen kod için adres cümlesi gösteriliyor', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );

    await pumpPage(tester, api);

    expect(
      find.text('yeni@ornek.com adresine gönderdiğimiz 6 haneli kodu gir'),
      findsOneWidget,
    );
  });

  testWidgets('telefona gönderilen kod için numara cümlesi gösteriliyor', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );

    await pumpPage(tester, api, verification: _phoneVerification);

    expect(
      find.text('5550000000 numarasına gönderdiğimiz 6 haneli kodu gir'),
      findsOneWidget,
    );
  });

  // Sunucunun `message` alanı çözülmemiş bir i18n anahtarı taşıyor.
  testWidgets('sunucunun ham i18n anahtarı hiçbir yerde gösterilmiyor', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );

    await pumpPage(tester, api);

    expect(find.textContaining('{email.verification.message}'), findsNothing);
  });

  testWidgets('doğru kod confirm ucuna gönderiliyor ve ekran başarıyla '
      'kapanıyor', (tester) async {
    final api = FakeApi(
      handler: (options) => options.path.contains('/confirm')
          ? const FakeApiResponse(statusCode: 200, body: {'success': true})
          : FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': _userBody()},
            ),
    );
    bool? finished;

    await pumpPage(tester, api, onFinished: (value) => finished = value);
    await enterCode(tester, '123456');
    await tester.tap(find.text('Onayla'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final confirm = api.requests.first;
    expect(confirm.path, '/verifications/ver-1/confirm');
    expect(confirm.method, 'POST');
    expect(confirm.data, {'token': '123456'});
    expect(finished, isTrue);
    // Yeni değerin ekranda görünebilmesi için kullanıcı tazeleniyor.
    expect(api.requests.any((request) => request.path == '/users/me'), isTrue);
  });

  testWidgets('kod hatalıysa ekran kapanmıyor, sunucunun mesajı gösteriliyor '
      've alan temizleniyor', (tester) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 400,
        body: {'success': false, 'message': 'Doğrulama kodu geçersiz'},
      ),
    );
    bool? finished;

    await pumpPage(tester, api, onFinished: (value) => finished = value);
    await enterCode(tester, '000000');
    await tester.tap(find.text('Onayla'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(finished, isNull);
    expect(find.text('Doğrulama kodu geçersiz'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      isEmpty,
    );
  });

  // `403` başkasına ait kayıt, `404` hiç olmayan kayıt. İkisinde de kod
  // girmenin anlamı kalmıyor, ekran kapanmalı.
  for (final statusCode in [403, 404]) {
    testWidgets('$statusCode gelince ekran kapanıyor', (tester) async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: statusCode,
          body: const {'success': false, 'message': 'Doğrulama bulunamadı'},
        ),
      );
      bool? finished;

      await pumpPage(tester, api, onFinished: (value) => finished = value);
      await enterCode(tester, '123456');
      await tester.tap(find.text('Onayla'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(finished, isFalse);
      // Kullanıcıya ne yapması gerektiği söyleniyor; sunucunun ham mesajı
      // tek başına "peki şimdi ne olacak" sorusunu yanıtlamıyor.
      expect(
        find.text('Bu doğrulama artık geçerli değil. Değişikliği baştan yap.'),
        findsOneWidget,
      );
    });
  }

  testWidgets('kodu tekrar gönder aynı yeni değerle PATCH atıyor ve düğme '
      'kilitleniyor', (tester) async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'user': _userBody(),
            'pendingVerifications': [
              {
                'id': 'ver-9',
                'type': 'EMAIL',
                'sentTo': 'yeni@ornek.com',
                'message': '{email.verification.message}',
              },
            ],
          },
        },
      ),
    );

    await pumpPage(tester, api);

    // Ekran açıldığında kod yeni gönderilmiş oluyor; soğuma süresi o andan
    // başlıyor, yani düğme baştan kapalı.
    await tester.tap(find.text('Kodu tekrar gönder'), warnIfMissed: false);
    await tester.pump();
    expect(api.requests, isEmpty);

    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.text('Kodu tekrar gönder'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final patch = api.requests.single;
    expect(patch.path, '/users/me');
    expect(patch.method, 'PATCH');
    expect(patch.data, {'email': 'yeni@ornek.com'});

    // Arka arkaya SMS/e-posta gitmesin diye düğme yeniden kilitleniyor.
    await tester.tap(find.text('Kodu tekrar gönder'), warnIfMissed: false);
    await tester.pump();
    expect(api.requests, hasLength(1));
  });

  // Soğuma başarısız denemede de kurulmalı: istemcide zaman aşımına uğrayan
  // ya da `500` dönen bir `PATCH` sunucuda işlenmiş ve kod gönderilmiş
  // olabilir. Düğme aynı karede yeniden açılırsa kullanıcı arka arkaya basıp
  // pes peşe SMS ürettirebilir — soğumanın var olma sebebi tam olarak bu.
  testWidgets('tekrar gönderme başarısız olsa da düğme soğumaya giriyor', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Sunucu hatası'},
      ),
    );

    await pumpPage(tester, api);
    await tester.pump(const Duration(seconds: 61));

    await tester.tap(find.text('Kodu tekrar gönder'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(api.requests, hasLength(1));

    await tester.tap(find.text('Kodu tekrar gönder'), warnIfMissed: false);
    await tester.pump();
    expect(api.requests, hasLength(1));

    // Soğuma dolunca tekrar denenebiliyor: kilit kalıcı değil.
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.text('Kodu tekrar gönder'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(api.requests, hasLength(2));
  });

  // Soğuma süresi ancak istek dönünce kuruluyor; istek havadayken düğme
  // açık kalırsa iki `PATCH` gider, yani kullanıcıya iki SMS.
  testWidgets('istek havadayken ikinci kez basılamıyor', (tester) async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'user': _userBody(),
            'pendingVerifications': const <Map<String, dynamic>>[],
          },
        },
      ),
    );

    await pumpPage(tester, api, onFinished: (_) {});
    await tester.pump(const Duration(seconds: 61));

    // İki dokunuş arada kare çizilmeden: ilkinin isteği daha dönmemişken
    // ikincisi geliyor.
    await tester.tap(find.text('Kodu tekrar gönder'));
    await tester.tap(find.text('Kodu tekrar gönder'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(api.requests, hasLength(1));
  });

  // Sunucu aynı değere ikinci bir kod üretmiyor: gönderilen değer
  // kullanıcının mevcut değerine eşitse `pendingVerifications` boş dönüyor
  // (`UserManager.patchCurrentUser`). Elde yeni bir kimlik yokken "yeni kod
  // gönderildi" demek, kullanıcıyı hiç gelmeyecek bir kod için bekletir.
  testWidgets('yeni doğrulama dönmezse başarı bildirilmiyor, ekran kapanıyor', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'user': _userBody(),
            'pendingVerifications': const <Map<String, dynamic>>[],
          },
        },
      ),
    );
    bool? finished;

    await pumpPage(tester, api, onFinished: (value) => finished = value);
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.text('Kodu tekrar gönder'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Yeni kod gönderildi.'), findsNothing);
    expect(
      find.text('Bu doğrulama artık geçerli değil. Değişikliği baştan yap.'),
      findsOneWidget,
    );
    expect(finished, isFalse);
  });

  testWidgets('tekrar gönderilen kod eskisinin yerine geçiyor', (tester) async {
    final api = FakeApi(
      handler: (options) => options.method == 'PATCH'
          ? FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'user': _userBody(),
                  'pendingVerifications': [
                    {
                      'id': 'ver-9',
                      'type': 'EMAIL',
                      'sentTo': 'yeni@ornek.com',
                      'message': '{email.verification.message}',
                    },
                  ],
                },
              },
            )
          : const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );

    await pumpPage(tester, api, onFinished: (_) {});
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.text('Kodu tekrar gönder'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await enterCode(tester, '654321');
    await tester.tap(find.text('Onayla'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Eski `ver-1` değil, tekrar gönderimden dönen `ver-9` onaylanmalı.
    expect(
      api.requests.any(
        (request) => request.path == '/verifications/ver-9/confirm',
      ),
      isTrue,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('ekran iki temada da çiziliyor (${brightness.name})', (
      tester,
    ) async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await pumpPage(tester, api, brightness: brightness);

      expect(find.text('Onayla'), findsOneWidget);
      expect(find.text('Kodu tekrar gönder'), findsOneWidget);
    });
  }
}
