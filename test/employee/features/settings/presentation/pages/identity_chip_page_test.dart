import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_chip_page.dart';
import 'package:koala/product/theme/theme.dart';

/// Testte NFC eklentisinin yerli tarafı yok, yani `nfcAvailability` çağrısı
/// `MissingPluginException` ile düşüyor. [ChipReader] bunu bilerek "donanım
/// yok" sayıyor: sorulamayan bir NFC'yi varmış gibi kabul edip kullanıcıyı
/// hiç açılmayacak bir okumaya sokmak, elle girişe yollamaktan kötü.
///
/// Bu yüzden bu dosya kabul maddesinin tam karşılığını ölçüyor: **NFC'si
/// olmayan bir cihazda akış anlaşılır bir mesajla kapanıyor.**
void main() {
  Future<GoRouter> pumpPage(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    final router = GoRouter(
      initialLocation: '/identity-verification',
      routes: [
        GoRoute(
          path: '/identity-verification',
          builder: (context, state) =>
              const Scaffold(body: Text('kimlik formu')),
        ),
        GoRoute(
          path: '/identity-chip',
          builder: (context, state) => const IdentityChipPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    );

    router.push('/identity-chip');
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('NFC okunamayan cihazda ne olduğu ve ne yapılacağı yazıyor', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Bu telefon kimlik kartı okuyamıyor'), findsOneWidget);
    // "Bir hata oluştu" değil: kullanıcıya çıkış yolu gösteriliyor.
    expect(find.textContaining('elle girerek'), findsOneWidget);
  });

  testWidgets('çözümü olmayan hatada tekrar dene düğmesi çıkmıyor', (
    tester,
  ) async {
    // Donanım yokken tekrar denemek sonu olmayan bir döngü.
    await pumpPage(tester);

    expect(find.text('Tekrar Dene'), findsNothing);
    expect(find.text('Bilgileri Elle Doğrula'), findsOneWidget);
  });

  testWidgets('elle doğrulama kullanıcıyı beyan formuna geri bırakıyor', (
    tester,
  ) async {
    // Kabul maddesi: NFC'nin başarısızlığı kullanıcıyı akışın dışına
    // atmamalı. Ekran kanıtsız kapanıyor ve form eskisi gibi çalışıyor.
    await pumpPage(tester);

    await tester.tap(find.text('Bilgileri Elle Doğrula'));
    await tester.pumpAndSettle();

    expect(find.text('kimlik formu'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('ekran ${brightness.name} temada da çiziliyor', (tester) async {
      await pumpPage(tester, brightness: brightness);

      expect(tester.takeException(), isNull);
      expect(find.text('Kimlik Kartını Okut'), findsOneWidget);
    });
  }
}
