import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_chip_page.dart';
import 'package:koala/employee/features/settings/services/chip_reader.dart';
import 'package:koala/employee/features/settings/services/mrz_camera_session.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/chip_fixtures.dart';
import '../../../../../support/fake_api.dart';

class _AvailableChipReader extends ChipReader {
  @override
  Future<NfcAvailability> availability() async => NfcAvailability.available;
}

/// Kartı okumuş gibi verilen kanıtı döndüren okuyucu; NFC yok.
class _ReadingChipReader extends _AvailableChipReader {
  _ReadingChipReader(this.evidence);

  final ChipEvidence evidence;

  @override
  Future<ChipEvidence> read({
    required MrzKey key,
    required String challenge,
    void Function(ChipReadStep step)? onStep,
  }) async => evidence;
}

class _LiveCameraSession implements MrzCameraSession {
  _LiveCameraSession({this.startCompleter});

  final StreamController<MrzFrameObservation> controller =
      StreamController<MrzFrameObservation>.broadcast();
  final Completer<void>? startCompleter;
  bool started = false;
  bool disposed = false;

  @override
  Widget buildPreview() => const ColoredBox(
    key: ValueKey('live-camera-preview'),
    color: Colors.black,
  );

  @override
  Stream<MrzFrameObservation> get observations => controller.stream;

  @override
  Size? get previewSize => const Size(720, 1280);

  @override
  Future<void> start() async {
    final pending = startCompleter;
    if (pending != null) await pending.future;
    started = true;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
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

  testWidgets('tarama uygulama içindeki canlı arka kamerayı açar', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': 'q83vEjRWeJA='},
      ),
    );
    final camera = _LiveCameraSession();

    await pumpPage(
      tester,
      page: IdentityChipPage(
        userService: UserService.withClient(api.client),
        chipReader: _AvailableChipReader(),
        mrzCamera: camera,
      ),
    );
    await tester.tap(find.text('Kartın Arka Yüzünü Tara'));
    await tester.pump();
    await tester.pump();

    expect(camera.started, isTrue);
    expect(find.byKey(const ValueKey('live-camera-preview')), findsOneWidget);
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

    final camera = _LiveCameraSession();
    await pumpPage(
      tester,
      page: IdentityChipPage(
        userService: UserService.withClient(api.client),
        chipReader: _AvailableChipReader(),
        mrzCamera: camera,
      ),
    );
    await tester.tap(find.text('Kartın Arka Yüzünü Tara'));
    await tester.pump();
    camera.controller.addError(
      const ChipReadException(ChipReadFailure.ocrModelUnavailable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Metin tanıma modeli hazırlanamadı'), findsOneWidget);
    expect(find.textContaining('Google Play Hizmetleri'), findsOneWidget);
    expect(find.text('Bilgileri Elle Doğrula'), findsOneWidget);
  });

  testWidgets('kamera açılırken hazırlık durumunu gösterir', (tester) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': 'q83vEjRWeJA='},
      ),
    );
    final pending = Completer<void>();
    final camera = _LiveCameraSession(startCompleter: pending);

    await pumpPage(
      tester,
      page: IdentityChipPage(
        userService: UserService.withClient(api.client),
        chipReader: _AvailableChipReader(),
        mrzCamera: camera,
      ),
    );
    await tester.tap(find.text('Kartın Arka Yüzünü Tara'));
    await tester.pump();

    expect(find.text('Kamera hazırlanıyor'), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('geç açılan kamera kapanmış sayfayı güncellemez', (tester) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': 'q83vEjRWeJA='},
      ),
    );
    final pending = Completer<void>();
    final camera = _LiveCameraSession(startCompleter: pending);
    final router = await pumpPage(
      tester,
      page: IdentityChipPage(
        userService: UserService.withClient(api.client),
        chipReader: _AvailableChipReader(),
        mrzCamera: camera,
      ),
    );

    await tester.tap(find.text('Kartın Arka Yüzünü Tara'));
    await tester.pump();
    router.pop();
    await tester.pumpAndSettle();

    pending.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(camera.disposed, isTrue);
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

  group('okunan kanıt', () {
    /// Kamerayı üç kararlı kareyle geçip çipe gider; sonucu formun aldığı
    /// `Future` üzerinden döndürür.
    Future<IdentityChipResult?> scanAndRead(
      WidgetTester tester, {
      required ChipEvidence evidence,
    }) async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': 'q83vEjRWeJA='},
        ),
      );
      final camera = _LiveCameraSession();
      IdentityChipResult? popped;

      // Başarı titreşimi platform kanalına gidiyor; testte karşılık veren
      // yerli taraf olmadığı için çağrı burada tamamlanıyor.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

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
            builder: (context, state) => IdentityChipPage(
              userService: UserService.withClient(api.client),
              chipReader: _ReadingChipReader(evidence),
              mrzCamera: camera,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: lightTheme, routerConfig: router),
      );
      unawaited(
        router.push<IdentityChipResult>('/identity-chip').then((result) {
          popped = result;
        }),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kartın Arka Yüzünü Tara'));
      await tester.pump();
      await tester.pump();
      final key = MrzKey.parseTd1(
        '$tckkMrzLine1\n$tckkMrzLine2\n$tckkMrzLine3',
      )!;
      for (var index = 0; index < 3; index++) {
        camera.controller.add(MrzFrameObservation.valid(key));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      return popped;
    }

    testWidgets('kimlik bilgileriyle birlikte forma dönüyor', (tester) async {
      // Form beş alanı bu sonuçtan okuyor; kanıt ile kart sahibi aynı
      // nesnede taşındığı için ayrı ayrı temizlenemez ya da değişemezler.
      final evidence = buildChipEvidence(
        dg11: encodeDg11(nameOfHolder: 'KAYA<<ÇAĞRI'),
      );

      final result = await scanAndRead(tester, evidence: evidence);

      expect(result, isNotNull);
      expect(identical(result!.evidence, evidence), isTrue);
      expect(result.holder.firstName, 'ÇAĞRI');
      expect(result.holder.documentNumber, 'A01B23456');
      expect(find.text('kimlik formu'), findsOneWidget);
    });

    testWidgets('kimlik bilgisi taşımıyorsa okuma hatası olarak kalıyor', (
      tester,
    ) async {
      // Kanıt var ama DG1 çözümlenemiyor: sunucu da reddedecekti. Formu
      // boş bir kanıtla kilitlemek yerine kullanıcıya ne yapacağı söyleniyor
      // ve elle giriş yolu açık kalıyor.
      final result = await scanAndRead(
        tester,
        evidence: buildChipEvidence(dg1: 'ZGcx'),
      );

      expect(result, isNull);
      expect(find.text('Kart bilgileri çözümlenemedi'), findsOneWidget);
      expect(find.text('Bilgileri Elle Doğrula'), findsOneWidget);
      expect(find.text('kimlik formu'), findsNothing);
    });
  });
}
