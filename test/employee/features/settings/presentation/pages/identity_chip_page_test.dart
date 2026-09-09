import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_chip_page.dart';
import 'package:koala/employee/features/settings/services/chip_reader.dart';
import 'package:koala/employee/features/settings/services/mrz_scanner.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/fake_api.dart';

class _AvailableChipReader extends ChipReader {
  @override
  Future<NfcAvailability> availability() async => NfcAvailability.available;
}

class _UnavailableModelScanner extends MrzScanner {
  @override
  Future<MrzKey?> scanCardBack() async {
    throw const ChipReadException(ChipReadFailure.ocrModelUnavailable);
  }

  @override
  Future<void> dispose() async {}
}

class _PendingModelScanner extends MrzScanner {
  final Completer<MrzKey?> pending = Completer<MrzKey?>();

  @override
  Future<MrzKey?> scanCardBack() => pending.future;

  @override
  Future<void> dispose() async {}
}

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
    IdentityChipPage page = const IdentityChipPage(),
  }) async {
    final router = GoRouter(
      initialLocation: '/identity-verification',
      routes: [
        GoRoute(
          path: '/identity-verification',
          builder: (context, state) =>
              const Scaffold(body: Text('kimlik formu')),
        ),
        GoRoute(path: '/identity-chip', builder: (context, state) => page),
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

  testWidgets('ilk taramada modelin internetten hazırlanabileceğini anlatır', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': 'q83vEjRWeJA='},
      ),
    );

    await pumpPage(
      tester,
      page: IdentityChipPage(
        userService: UserService.withClient(api.client),
        chipReader: _AvailableChipReader(),
      ),
    );

    expect(find.textContaining('ilk taramada'), findsOneWidget);
    expect(find.textContaining('internet'), findsOneWidget);
    expect(find.textContaining('elle girebilirsin'), findsOneWidget);
  });

  testWidgets('model hazırlanamazsa nedenini ve elle giriş yolunu gösterir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': 'q83vEjRWeJA='},
      ),
    );

    await pumpPage(
      tester,
      page: IdentityChipPage(
        userService: UserService.withClient(api.client),
        chipReader: _AvailableChipReader(),
        mrzScanner: _UnavailableModelScanner(),
      ),
    );
    await tester.tap(find.text('Kartın Arka Yüzünü Tara'));
    await tester.pumpAndSettle();

    expect(find.text('Metin tanıma modeli hazırlanamadı'), findsOneWidget);
    expect(find.textContaining('Google Play Hizmetleri'), findsOneWidget);
    expect(find.text('Bilgileri Elle Doğrula'), findsOneWidget);
  });

  testWidgets('OCR sürerken modelin hazırlandığını gösterir', (tester) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': 'q83vEjRWeJA='},
      ),
    );
    final scanner = _PendingModelScanner();

    await pumpPage(
      tester,
      page: IdentityChipPage(
        userService: UserService.withClient(api.client),
        chipReader: _AvailableChipReader(),
        mrzScanner: scanner,
      ),
    );
    await tester.tap(find.text('Kartın Arka Yüzünü Tara'));
    await tester.pump();

    expect(find.text('Metin tanıma modeli hazırlanıyor'), findsOneWidget);
    expect(find.textContaining('internet bağlantını açık tut'), findsOneWidget);

    scanner.pending.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('geç tamamlanan tarama kapanmış sayfayı güncellemez', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': 'q83vEjRWeJA='},
      ),
    );
    final scanner = _PendingModelScanner();
    final router = await pumpPage(
      tester,
      page: IdentityChipPage(
        userService: UserService.withClient(api.client),
        chipReader: _AvailableChipReader(),
        mrzScanner: scanner,
      ),
    );

    await tester.tap(find.text('Kartın Arka Yüzünü Tara'));
    await tester.pump();
    router.pop();
    await tester.pumpAndSettle();

    scanner.pending.complete(
      MrzKey.manual(
        documentNumber: 'A12B34567',
        birthDate: DateTime(1990, 1, 1),
        expiryDate: DateTime(2030, 1, 1),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('kimlik formu'), findsOneWidget);
  });

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
