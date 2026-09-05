import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/settings/presentation/pages/change_password_page.dart';
import 'package:koala/product/constants/password_rule.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/fake_api.dart';

/// Testte kullanılan parolalar bilerek anlamsız; gerçek bir hesabın
/// parolası değil.
const String _currentPassword = 'EskiSifre1';
const String _newPassword = 'YeniSifre1';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    FakeApi api, {
    void Function()? onCompleted,
    Brightness brightness = Brightness.light,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        home: ChangePasswordPage(
          userService: UserService.withClient(api.client),
          onCompleted: onCompleted,
        ),
      ),
    );
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

  FakeApi successApi() {
    return FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );
  }

  testWidgets('kural sağlanmayan yeni şifrede sunucuya istek gitmiyor', (
    tester,
  ) async {
    final api = successApi();
    await pumpPage(tester, api);

    await enterField(tester, 'Mevcut Şifre', _currentPassword);
    await enterField(tester, 'Yeni Şifre', 'kisa1');
    await enterField(tester, 'Yeni Şifre Tekrar', 'kisa1');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();

    expect(api.requests, isEmpty);
    // Kural metni alanın altında zaten yazıyor; aranan şey kullanıcının
    // toast'la da uyarılmış olması.
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(PasswordRule.requirement),
      ),
      findsOneWidget,
    );
  });

  testWidgets('iki yeni şifre alanı uyuşmuyorsa hata gösteriliyor', (
    tester,
  ) async {
    final api = successApi();
    await pumpPage(tester, api);

    await enterField(tester, 'Mevcut Şifre', _currentPassword);
    await enterField(tester, 'Yeni Şifre', _newPassword);
    await enterField(tester, 'Yeni Şifre Tekrar', 'BaskaSifre1');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();

    expect(api.requests, isEmpty);
    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
  });

  testWidgets('boş alan varken sunucuya istek gitmiyor', (tester) async {
    final api = successApi();
    await pumpPage(tester, api);

    await enterField(tester, 'Yeni Şifre', _newPassword);
    await enterField(tester, 'Yeni Şifre Tekrar', _newPassword);
    await tester.tap(find.text('Kaydet'));
    await tester.pump();

    expect(api.requests, isEmpty);
  });

  testWidgets('yeni şifre mevcut şifreyle aynıysa sunucuya gidilmiyor', (
    tester,
  ) async {
    final api = successApi();
    await pumpPage(tester, api);

    await enterField(tester, 'Mevcut Şifre', _currentPassword);
    await enterField(tester, 'Yeni Şifre', _currentPassword);
    await enterField(tester, 'Yeni Şifre Tekrar', _currentPassword);
    await tester.tap(find.text('Kaydet'));
    await tester.pump();

    expect(api.requests, isEmpty);
    expect(
      find.text('Yeni şifren mevcut şifrenden farklı olmalı.'),
      findsOneWidget,
    );
  });

  testWidgets('geçerli girdilerde üç alan da parola ucuna gönderiliyor', (
    tester,
  ) async {
    final api = successApi();
    var completed = false;
    await pumpPage(tester, api, onCompleted: () => completed = true);

    await enterField(tester, 'Mevcut Şifre', _currentPassword);
    await enterField(tester, 'Yeni Şifre', _newPassword);
    await enterField(tester, 'Yeni Şifre Tekrar', _newPassword);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(api.requests.single.path, '/users/me/password');
    expect(api.requests.single.method, 'PUT');
    expect(api.requests.single.data, {
      'currentPassword': _currentPassword,
      'newPassword': _newPassword,
      'confirmNewPassword': _newPassword,
    });
    expect(completed, isTrue);
  });

  testWidgets('mevcut parola yanlışsa ekran kapanmıyor, sunucunun mesajı '
      'gösteriliyor', (tester) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 400,
        body: {'success': false, 'message': 'Mevcut parola hatalı'},
      ),
    );
    var completed = false;
    await pumpPage(tester, api, onCompleted: () => completed = true);

    await enterField(tester, 'Mevcut Şifre', 'YanlisSifre1');
    await enterField(tester, 'Yeni Şifre', _newPassword);
    await enterField(tester, 'Yeni Şifre Tekrar', _newPassword);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(completed, isFalse);
    expect(find.text('Mevcut parola hatalı'), findsOneWidget);
  });

  // Sunucu `401` belgeliyor ama `400` fırlatıyor; istemci ikisini de aynı
  // şekilde karşılamalı ve `401`'i oturum sonu sanmamalı.
  //
  // Not: `FakeApi` interceptor'sız bir `ApiClient` kuruyor, yani burada
  // `AuthInterceptor`'ın tazeleme adımı yok. Üretimde `401` bir kez tazeleyip
  // tekrar deniyor ve ikinci `401` yine buradaki gibi sayfaya ulaşıyor;
  // sınanan şey sayfanın hatayı nasıl karşıladığı.
  testWidgets('401 gelirse de kullanıcı ekranda kalıyor', (tester) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 401,
        body: {'success': false, 'message': 'Mevcut parola hatalı'},
      ),
    );
    var completed = false;
    await pumpPage(tester, api, onCompleted: () => completed = true);

    await enterField(tester, 'Mevcut Şifre', 'YanlisSifre1');
    await enterField(tester, 'Yeni Şifre', _newPassword);
    await enterField(tester, 'Yeni Şifre Tekrar', _newPassword);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(completed, isFalse);
    expect(find.text('Mevcut parola hatalı'), findsOneWidget);
  });

  // Ekran renklerini `context`'ten okuyor; iki temada da çizilebildiğini
  // doğrulamak projenin temel kuralı. Uyarı metninin kaydetmeden önce
  // görünmesi de burada sınanıyor.
  for (final brightness in Brightness.values) {
    testWidgets('diğer oturumların kapanacağı kaydetmeden önce yazıyor '
        '(${brightness.name})', (tester) async {
      await pumpPage(tester, successApi(), brightness: brightness);

      expect(
        find.textContaining('bu cihaz dışındaki bütün oturumların kapanacak'),
        findsOneWidget,
      );
    });
  }
}
