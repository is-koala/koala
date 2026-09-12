import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_verification_page.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/chip_fixtures.dart';
import '../../../../../support/fake_api.dart';

/// Kayıtta girilen ad-soyad kimliktekiyle **aynı değil**: çip okununca
/// hangisinin gönderildiği buradan ayırt ediliyor.
final CurrentUser _user = CurrentUser.fromJson(const {
  'id': 'user-1',
  'firstName': 'Cagri',
  'lastName': 'Kaya',
  'email': 'cagri@ornek.com',
  'birthDate': '1998-04-07',
  'isEmployer': false,
});

/// Çipten okunan karta göre ad **ÇAĞRI**; MRZ'de **CAGRI** yazıyor.
IdentityChipResult _chipResult({bool withChipProof = false}) {
  return buildChipResult(
    dg1: encodeDg1(line3: 'KAYA<<CAGRI<<<<<<<<<<<<<<<<<<<'),
    dg11: encodeDg11(nameOfHolder: 'KAYA<<ÇAĞRI'),
    withChipProof: withChipProof,
  );
}

/// Çip ekranının yerine geçen sahne: açılır açılmaz verilen sonuçla (ya da
/// vazgeçmiş gibi `null` ile) kapanıyor.
class _ChipStub extends StatefulWidget {
  const _ChipStub({required this.result});

  final IdentityChipResult? result;

  @override
  State<_ChipStub> createState() => _ChipStubState();
}

class _ChipStubState extends State<_ChipStub> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(widget.result);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('çip ekranı'));
}

void main() {
  FakeApi okApi() {
    return FakeApi(
      handler: (options) {
        if (options.path == '/users/me') {
          return FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': _user.toJson()},
          );
        }
        return const FakeApiResponse(statusCode: 200, body: {'success': true});
      },
    );
  }

  Future<GoRouter> pumpPage(
    WidgetTester tester,
    FakeApi api, {
    Brightness brightness = Brightness.light,
    IdentityChipResult? Function()? chipResult,
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
          path: '/identity-verification',
          builder: (context, state) => IdentityVerificationPage(
            user: _user,
            userService: UserService.withClient(api.client),
          ),
        ),
        GoRoute(
          path: '/identity-chip',
          builder: (context, state) => _ChipStub(result: chipResult?.call()),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>(
        create: (_) =>
            UserProvider(userService: UserService.withClient(api.client)),
        child: MaterialApp.router(
          theme: brightness == Brightness.dark ? darkTheme : lightTheme,
          routerConfig: router,
        ),
      ),
    );

    router.push('/identity-verification');
    await tester.pumpAndSettle();
    return router;
  }

  Finder textFieldLabeled(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField("$label")',
  );

  Future<void> enterField(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    await tester.enterText(textFieldLabeled(label), value);
    await tester.pump();
  }

  Future<void> readChip(WidgetTester tester) async {
    // Metin girişi formu kaydırmış olabilir; düğme görünür değilse dokunuş
    // boşa gider.
    await tester.ensureVisible(find.text('Kartı Okut'));
    await tester.tap(find.text('Kartı Okut'));
    await tester.pumpAndSettle();
  }

  /// Gönderilen kimlik doğrulama gövdesi.
  Map<String, dynamic> verificationBody(FakeApi api) {
    final request = api.requests.firstWhere(
      (request) => request.path == '/users/me/identity-verification',
    );
    return request.data! as Map<String, dynamic>;
  }

  group('çip okunmadan', () {
    testWidgets('beş alan elle doldurulup kanıtsız gönderiliyor', (
      tester,
    ) async {
      // NFC'si olmayan cihazın yolu: beyan formu eskisi gibi çalışıyor ve
      // gövde fazladan tek bir alan bile taşımıyor.
      final api = okApi();
      await pumpPage(tester, api);

      await enterField(tester, 'Ad', 'Çağrı');
      await enterField(tester, 'TC Kimlik No', '12345678950');
      await enterField(tester, 'Seri No', 'A01B23456');
      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      final body = verificationBody(api);
      expect(body['firstName'], 'Çağrı');
      expect(body['lastName'], 'Kaya');
      expect(body['tcIdentityNumber'], '12345678950');
      expect(body['tcDocumentNumber'], 'A01B23456');
      expect(body['birthDate'], '1998-04-07');
      expect(body.keys, {
        'firstName',
        'lastName',
        'birthDate',
        'tcIdentityNumber',
        'tcDocumentNumber',
      });
    });

    testWidgets('çip ekranı kanıtsız kapanınca form olduğu gibi kalıyor', (
      tester,
    ) async {
      // NFC yok, kart okunamadı ya da kullanıcı vazgeçti: hepsi `null` ile
      // dönüyor ve elle düzenleme sürüyor.
      final api = okApi();
      await pumpPage(tester, api, chipResult: () => null);

      await enterField(tester, 'TC Kimlik No', '12345678950');
      await readChip(tester);

      expect(find.text('Kimlik kartını telefona okut'), findsOneWidget);
      final field = tester.widget<TextField>(textFieldLabeled('TC Kimlik No'));
      expect(field.enabled, isTrue);
      expect(field.controller?.text, '12345678950');
      expect(find.text('Okumayı Kaldır'), findsNothing);
    });
  });

  group('çip okunduktan sonra', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} temada beş alan çipten dolu ve salt '
          'okunur', (tester) async {
        final api = okApi();
        await pumpPage(
          tester,
          api,
          brightness: brightness,
          chipResult: _chipResult,
        );

        await readChip(tester);

        expect(tester.takeException(), isNull);
        // Ad DG11'den ulusal karakterlerle; kayıttaki "Cagri" değil.
        expect(find.text('ÇAĞRI'), findsOneWidget);
        expect(find.text('KAYA'), findsOneWidget);
        expect(find.text('12345678950'), findsOneWidget);
        expect(find.text('A01B23456'), findsOneWidget);
        expect(find.text('07.04.1998'), findsOneWidget);
        // Yazılabilir bir alan kalmıyor: beş değer de kanıtın görünümü.
        for (final label in const ['Ad', 'Soyad', 'TC Kimlik No', 'Seri No']) {
          expect(textFieldLabeled(label), findsNothing, reason: label);
        }
        expect(find.textContaining('okumayı kaldır'), findsWidgets);
      });
    }

    testWidgets('doğum tarihi seçiciye açılmıyor', (tester) async {
      final api = okApi();
      await pumpPage(tester, api, chipResult: _chipResult);
      await readChip(tester);

      await tester.tap(find.text('07.04.1998'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('gönderilen beyan ekrandaki çip değerleriyle birebir aynı', (
      tester,
    ) async {
      // Kabul maddesi: kanıt varken uyuşmaz beyan üretilemez. Okumadan önce
      // elle yazılan taslak ve kayıttaki ad, gövdeye **sızmıyor**.
      final api = okApi();
      final chip = _chipResult(withChipProof: true);
      await pumpPage(tester, api, chipResult: () => chip);

      await enterField(tester, 'Ad', 'Zeynep');
      await enterField(tester, 'TC Kimlik No', '99999999990');
      await readChip(tester);

      // Ekranda görünenler:
      for (final shown in const ['ÇAĞRI', 'KAYA', '12345678950', 'A01B23456']) {
        expect(find.text(shown), findsOneWidget, reason: shown);
      }

      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      final body = verificationBody(api);
      expect(body['firstName'], 'ÇAĞRI');
      expect(body['lastName'], 'KAYA');
      expect(body['tcIdentityNumber'], '12345678950');
      expect(body['tcDocumentNumber'], 'A01B23456');
      expect(body['birthDate'], '1998-04-07');
      expect(body['sod'], chip.evidence.sod);
      expect(body['dg1'], chip.evidence.dg1);
      expect(body['dg11'], chip.evidence.dg11);
      expect(body['dg15'], chip.evidence.dg15);
      expect(body['challenge'], chip.evidence.challenge);
      expect(
        body['activeAuthenticationSignature'],
        chip.evidence.activeAuthenticationSignature,
      );
      expect(body.values, isNot(contains('Zeynep')));
      expect(body.values, isNot(contains('Cagri')));
      expect(body.values, isNot(contains('99999999990')));
    });

    testWidgets('okumayı kaldırmak kanıtı ve türetilen alanları birlikte '
        'siliyor', (tester) async {
      // Tek durum geçişi: kanıt gitti, kilitli değerler de gitti; form
      // okuma öncesindeki taslağa dönüyor ve gövde kanıtsız gidiyor.
      final api = okApi();
      await pumpPage(tester, api, chipResult: _chipResult);
      await readChip(tester);

      await tester.ensureVisible(find.text('Okumayı Kaldır'));
      await tester.tap(find.text('Okumayı Kaldır'));
      await tester.pumpAndSettle();

      expect(find.text('Kimlik kartını telefona okut'), findsOneWidget);
      expect(find.text('ÇAĞRI'), findsNothing);
      expect(find.text('A01B23456'), findsNothing);
      for (final label in const ['Ad', 'Soyad', 'TC Kimlik No', 'Seri No']) {
        expect(
          tester.widget<TextField>(textFieldLabeled(label)).enabled,
          isTrue,
          reason: label,
        );
      }

      await enterField(tester, 'TC Kimlik No', '12345678950');
      await enterField(tester, 'Seri No', 'B02C34567');
      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      final body = verificationBody(api);
      expect(body['firstName'], 'Cagri');
      expect(body['tcDocumentNumber'], 'B02C34567');
      expect(body.containsKey('sod'), isFalse);
      expect(body.containsKey('dg1'), isFalse);
      expect(body.containsKey('dg11'), isFalse);
    });

    testWidgets('yeniden okutmadan vazgeçilirse eldeki kanıt duruyor', (
      tester,
    ) async {
      // Geçerli bir okumayı, ikinci denemeden vazgeçildi diye atmak
      // kullanıcıya kartı boşuna yeniden okutmak olurdu.
      final api = okApi();
      var reads = 0;
      await pumpPage(
        tester,
        api,
        chipResult: () => reads++ == 0 ? _chipResult() : null,
      );
      await readChip(tester);

      await tester.ensureVisible(find.text('Yeniden Oku'));
      await tester.tap(find.text('Yeniden Oku'));
      await tester.pumpAndSettle();

      expect(find.text('ÇAĞRI'), findsOneWidget);
      expect(textFieldLabeled('Ad'), findsNothing);
    });
  });
}
