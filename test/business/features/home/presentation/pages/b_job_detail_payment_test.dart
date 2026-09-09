import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/fake_api.dart';
import 'b_job_detail_test_harness.dart';

void main() {
  testWidgets('başarısız ödeme denemesini güvenli açıklamayla gösterir', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);

    expect(find.text('Ödeme Denemeleri'), findsOneWidget);
    expect(find.text('Başarısız'), findsOneWidget);
    expect(find.text('1.050,11 ₺'), findsOneWidget);
    expect(
      find.text('Ödeme tamamlanamadı. Lütfen tekrar dene.'),
      findsOneWidget,
    );
    expect(find.text('Kart reddedildi.'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape('Kart reddedildi.'))),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('Iyzico yalnız backend dökümü açıkça onaylanınca açılır', (
    tester,
  ) async {
    final harness = await pumpPage(tester);
    final button = find.text('Güvenli Ödemeyi Tamamla');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ödemeyi Onayla'), findsOneWidget);
    expect(find.text('Çalışan Ücreti'), findsOneWidget);
    expect(find.text('Koala Hizmet Bedeli'), findsOneWidget);
    expect(find.text('(%5)'), findsOneWidget);
    expect(find.text('İşveren Toplamı'), findsOneWidget);
    expect(find.text('1.000,10 ₺'), findsOneWidget);
    expect(find.text('50,01 ₺'), findsOneWidget);
    expect(find.text('1.050,11 ₺'), findsWidgets);
    expect(
      harness.paymentApi.requests.where(
        (request) => request.path == '/payment-quotes',
      ),
      isEmpty,
    );
    expect(
      harness.employerApi.requests.where((request) => request.method == 'POST'),
      isEmpty,
    );
    expect(harness.launches(), 0);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(
      harness.employerApi.requests.where((request) => request.method == 'POST'),
      isEmpty,
    );

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ödemeye geç'));
    await tester.pumpAndSettle();

    expect(
      harness.employerApi.requests.where((request) => request.method == 'POST'),
      hasLength(1),
    );
    expect(harness.launches(), 1);
  });

  testWidgets(
    'ödeme onayı açıkken yenilenen deneme eski onayı geçersiz kılar',
    (tester) async {
      var paymentFetchCount = 0;
      final harness = await pumpPage(
        tester,
        paymentHandler: (_) {
          paymentFetchCount++;
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [
                {
                  'id': 'attempt-$paymentFetchCount',
                  'status': paymentFetchCount == 1 ? 'FAILED' : 'IN_REVIEW',
                  'currency': 'TRY',
                  'workerPayout': '1000.10',
                  'commissionAmount': '50.01',
                  'commissionRate': '0.050',
                  'totalCharged': '1050.11',
                  'createdAt': '2026-09-09T12:00:00Z',
                },
              ],
            },
          );
        },
      );

      final button = find.text('Güvenli Ödemeyi Tamamla');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Ödemeyi Onayla'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (var index = 0; index < 20; index++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.tap(find.text('Ödemeye geç'));
      for (var index = 0; index < 20; index++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(
        harness.employerApi.requests.where(
          (request) => request.method == 'POST',
        ),
        isEmpty,
      );
      expect(harness.launches(), 0);
    },
  );

  testWidgets('bilinen güvenli hata anahtarını kullanıcıya açıklar', (
    tester,
  ) async {
    await pumpPage(tester, failureReason: '{payment.3ds.verification.failed}');

    expect(
      find.text('3D Secure doğrulaması tamamlanamadı. Lütfen tekrar dene.'),
      findsOneWidget,
    );
    expect(find.text('{payment.3ds.verification.failed}'), findsNothing);
  });

  testWidgets(
    'checkout dönüşünde yeni aktif deneme görünür ve yeniden ödeme kapanır',
    (tester) async {
      final harness = await pumpPage(tester, progressiveAttempt: true);

      expect(find.text('Başarısız'), findsOneWidget);
      expect(find.text('Kart reddedildi.'), findsNothing);

      final button = find.text('Güvenli Ödemeyi Tamamla');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Ödemeye geç'));
      await tester.pumpAndSettle();

      expect(harness.launches(), 1);
      expect(find.text('Başarısız'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Başlatıldı'), findsOneWidget);
      expect(find.text('Ödeme sonucu doğrulanıyor.'), findsOneWidget);
      expect(find.text('Güvenli Ödemeyi Tamamla'), findsNothing);
      expect(find.text('Kart reddedildi.'), findsNothing);
    },
  );

  testWidgets('doğrulanan aktif deneme yeni checkout düğmesini kapatır', (
    tester,
  ) async {
    final harness = await pumpPage(
      tester,
      activeAttemptStatus: 'VERIFY_PENDING',
    );

    expect(find.text('Sonuç doğrulanıyor'), findsWidgets);
    expect(find.text('Ödeme sonucu doğrulanıyor.'), findsOneWidget);
    expect(find.text('Güvenli Ödemeyi Tamamla'), findsNothing);
    expect(harness.launches(), 0);
  });
}
