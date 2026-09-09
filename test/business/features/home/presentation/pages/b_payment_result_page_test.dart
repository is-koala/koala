import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_payment_result_page.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

void main() {
  testWidgets('ödeme sonucu query yerine backend atama durumundan gösterilir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'id': 'asg_1',
            'status': 'CONFIRMED',
            'paymentStatus': 'HELD_IN_ESCROW',
            'job': {
              'id': 'job_1',
              'title': 'Barista',
              'salary': 1500,
              'category': {'id': 'cat_1', 'code': 'BARISTA', 'name': 'Barista'},
            },
          },
        },
      ),
    );

    await _pumpPaymentResult(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Ödeme Güvende'), findsOneWidget);
    expect(find.textContaining('başarısız'), findsNothing);
    expect(api.requests, hasLength(1));
    expect(api.requests.single.path, '/job-assignments/asg_1');
    expect(api.requests.single.method, 'GET');
    expect(api.requests.single.queryParameters, isEmpty);
  });

  testWidgets('kesin ret bekleme yerine yeniden deneme olarak gösterilir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'id': 'asg_1',
            'status': 'CONFIRMED',
            'paymentStatus': 'FAILED',
            'job': {
              'id': 'job_1',
              'title': 'Barista',
              'salary': 1500,
              'category': {'id': 'cat_1', 'code': 'BARISTA', 'name': 'Barista'},
            },
          },
        },
      ),
    );

    await _pumpPaymentResult(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Ödeme Başarısız'), findsOneWidget);
    expect(find.textContaining('yeniden deneyebilirsin'), findsOneWidget);
    expect(find.text('Ödeme Henüz Doğrulanmadı'), findsNothing);
  });

  for (final error in [
    (status: 404, message: 'İş kaydı bulunamadı.'),
    (status: 500, message: 'Sunucu geçici olarak kullanılamıyor.'),
  ]) {
    testWidgets('${error.status} hatası yeniden deneme yüzeyinde gösterilir', (
      tester,
    ) async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: error.status,
          body: {'success': false, 'message': error.message},
        ),
      );

      await _pumpPaymentResult(tester, api);
      await tester.pumpAndSettle();

      expect(find.text(error.message), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Ödeme Henüz Doğrulanmadı'), findsOneWidget);
      expect(find.text('TEKRAR KONTROL ET'), findsOneWidget);
      expect(find.text('İLANA DÖN'), findsNothing);
      expect(api.requests.single.path, '/job-assignments/asg_1');
    });
  }

  testWidgets('yanıt gelene kadar yükleniyor durumu korunuyor', (tester) async {
    final response = Completer<FakeApiResponse>();
    final api = FakeApi(handler: (_) => response.future);

    await _pumpPaymentResult(tester, api);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ödeme Güvende'), findsNothing);

    response.complete(
      const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'id': 'asg_1',
            'status': 'CONFIRMED',
            'paymentStatus': 'HELD_IN_ESCROW',
            'job': {
              'id': 'job_1',
              'title': 'Barista',
              'salary': 1500,
              'category': {'id': 'cat_1', 'code': 'BARISTA', 'name': 'Barista'},
            },
          },
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ödeme Güvende'), findsOneWidget);
  });

  testWidgets(
    'bekleyen ödeme bir aralıktan sonra backend sonucuyla kesinleşir',
    (tester) async {
      var requestCount = 0;
      final api = FakeApi(
        handler: (_) {
          requestCount++;
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'id': 'asg_1',
                'status': 'CONFIRMED',
                'paymentStatus': requestCount == 1
                    ? 'PENDING_COLLECTION'
                    : 'HELD_IN_ESCROW',
                'job': {
                  'id': 'job_1',
                  'title': 'Barista',
                  'salary': 1500,
                  'category': {
                    'id': 'cat_1',
                    'code': 'BARISTA',
                    'name': 'Barista',
                  },
                },
              },
            },
          );
        },
      );
      var now = DateTime.utc(2026, 9, 9, 9);
      final delayCompleted = Completer<void>();
      final delays = <Duration>[];

      await _pumpPaymentResult(
        tester,
        api,
        now: () => now,
        delay: (duration) {
          delays.add(duration);
          return delayCompleted.future;
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Ödeme Sonucu Kontrol Ediliyor'), findsOneWidget);
      expect(find.textContaining('yeni ödeme başlatma'), findsOneWidget);
      expect(delays, hasLength(1));
      expect(delays.single, greaterThan(Duration.zero));

      now = now.add(delays.single);
      delayCompleted.complete();
      await tester.pumpAndSettle();

      expect(find.text('Ödeme Güvende'), findsOneWidget);
      expect(api.requests, hasLength(2));
      expect(delays, hasLength(1));
    },
  );

  testWidgets('otomatik kontrol sonlu 1 2 4 saniye bütçesinde durur', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => _assignmentResponse('PENDING_COLLECTION'),
    );
    var now = DateTime.utc(2026, 9, 9, 9);
    final delays = <Duration>[];

    await _pumpPaymentResult(
      tester,
      api,
      now: () => now,
      delay: (duration) {
        delays.add(duration);
        now = now.add(duration);
        return Future<void>.value();
      },
    );
    await tester.pumpAndSettle();

    expect(delays, const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ]);
    expect(api.requests, hasLength(4));
    expect(find.text('Ödeme Henüz Doğrulanmadı'), findsOneWidget);
    expect(find.textContaining('Yeni ödeme başlatmadan önce'), findsOneWidget);

    await tester.tap(find.text('TEKRAR KONTROL ET'));
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(5));
    expect(delays, hasLength(3));

    await tester.pump(const Duration(minutes: 1));
    expect(api.requests, hasLength(5));
  });

  for (final terminal in [
    (status: 'HELD_IN_ESCROW', title: 'Ödeme Güvende'),
    (status: 'RELEASED_TO_WORKER', title: 'Ödeme Güvende'),
    (status: 'FAILED', title: 'Ödeme Başarısız'),
    (status: 'REFUNDED', title: 'Ödeme İade Edildi'),
  ]) {
    testWidgets(
      '${terminal.status} backend durumu otomatik kontrolü durdurur',
      (tester) async {
        final delays = <Duration>[];
        final api = FakeApi(
          handler: (_) => _assignmentResponse(terminal.status),
        );

        await _pumpPaymentResult(
          tester,
          api,
          delay: (duration) {
            delays.add(duration);
            return Completer<void>().future;
          },
        );
        await tester.pumpAndSettle();

        expect(find.text(terminal.title), findsOneWidget);
        expect(api.requests, hasLength(1));
        expect(delays, isEmpty);
      },
    );
  }

  testWidgets('manuel kontrol bekleyen otomatik gecikmeyi geçersiz kılar', (
    tester,
  ) async {
    var requestCount = 0;
    final api = FakeApi(
      handler: (_) => _assignmentResponse(
        ++requestCount == 1 ? 'PENDING_COLLECTION' : 'HELD_IN_ESCROW',
      ),
    );
    var now = DateTime.utc(2026, 9, 9, 9);
    final delayedPoll = Completer<void>();
    Duration? scheduledDelay;

    await _pumpPaymentResult(
      tester,
      api,
      now: () => now,
      delay: (duration) {
        scheduledDelay = duration;
        return delayedPoll.future;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('TEKRAR KONTROL ET'));
    await tester.pumpAndSettle();
    expect(find.text('Ödeme Güvende'), findsOneWidget);
    expect(api.requests, hasLength(2));

    now = now.add(scheduledDelay!);
    delayedPoll.complete();
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(2));
  });

  testWidgets('arka planda bekleyen kontrol dönüşte tek sorguyla yenilenir', (
    tester,
  ) async {
    var requestCount = 0;
    final api = FakeApi(
      handler: (_) => _assignmentResponse(
        ++requestCount == 1 ? 'PENDING_COLLECTION' : 'HELD_IN_ESCROW',
      ),
    );
    var now = DateTime.utc(2026, 9, 9, 9);
    final delayedPoll = Completer<void>();
    Duration? scheduledDelay;

    await _pumpPaymentResult(
      tester,
      api,
      now: () => now,
      delay: (duration) {
        scheduledDelay = duration;
        return delayedPoll.future;
      },
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(scheduledDelay!);
    delayedPoll.complete();
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(2));
    expect(find.text('Ödeme Güvende'), findsOneWidget);
  });

  testWidgets('ekran kapanınca bekleyen otomatik kontrol yeni istek atmaz', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => _assignmentResponse('PENDING_COLLECTION'),
    );
    var now = DateTime.utc(2026, 9, 9, 9);
    final delayedPoll = Completer<void>();
    Duration? scheduledDelay;

    await _pumpPaymentResult(
      tester,
      api,
      now: () => now,
      delay: (duration) {
        scheduledDelay = duration;
        return delayedPoll.future;
      },
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());

    now = now.add(scheduledDelay!);
    delayedPoll.complete();
    await tester.pumpAndSettle();

    expect(api.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uçan otomatik sorgu düğmeyi kilitler ve dispose sonrası susar', (
    tester,
  ) async {
    var requestCount = 0;
    final automaticResponse = Completer<FakeApiResponse>();
    final automaticRequestStarted = Completer<void>();
    final api = FakeApi(
      handler: (_) {
        requestCount++;
        if (requestCount == 1) {
          return _assignmentResponse('PENDING_COLLECTION');
        }
        automaticRequestStarted.complete();
        return automaticResponse.future;
      },
    );
    var now = DateTime.utc(2026, 9, 9, 9);
    final delayedPoll = Completer<void>();
    Duration? scheduledDelay;

    await _pumpPaymentResult(
      tester,
      api,
      now: () => now,
      delay: (duration) {
        scheduledDelay = duration;
        return delayedPoll.future;
      },
    );
    await tester.pumpAndSettle();

    now = now.add(scheduledDelay!);
    delayedPoll.complete();
    while (!automaticRequestStarted.isCompleted) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.pump();

    final retryButton = find.widgetWithText(
      ElevatedButton,
      'TEKRAR KONTROL ET',
    );
    expect(api.requests, hasLength(2));
    expect(tester.widget<ElevatedButton>(retryButton).onPressed, isNull);
    expect(find.text('Ödeme Sonucu Kontrol Ediliyor'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    automaticResponse.complete(_assignmentResponse('HELD_IN_ESCROW'));
    await tester.pumpAndSettle();

    expect(api.requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending sonrası geçici hata kalan bütçeyle kesinleşir', (
    tester,
  ) async {
    var requestCount = 0;
    final api = FakeApi(
      handler: (_) {
        requestCount++;
        if (requestCount == 2) {
          return const FakeApiResponse(
            statusCode: 500,
            body: {'success': false, 'message': 'Geçici bağlantı sorunu.'},
          );
        }
        return _assignmentResponse(
          requestCount == 1 ? 'PENDING_COLLECTION' : 'HELD_IN_ESCROW',
        );
      },
    );
    var now = DateTime.utc(2026, 9, 9, 9);
    final delays = <({Duration duration, Completer<void> completer})>[];

    await _pumpPaymentResult(
      tester,
      api,
      now: () => now,
      delay: (duration) {
        final completer = Completer<void>();
        delays.add((duration: duration, completer: completer));
        return completer.future;
      },
    );
    await tester.pumpAndSettle();

    now = now.add(delays[0].duration);
    delays[0].completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Geçici bağlantı sorunu.'), findsOneWidget);
    expect(delays, hasLength(2));

    now = now.add(delays[1].duration);
    delays[1].completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ödeme Güvende'), findsOneWidget);
    expect(api.requests, hasLength(3));
  });

  testWidgets('erken dönen gecikme sıkı sorgu döngüsü başlatmaz', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => _assignmentResponse('PENDING_COLLECTION'),
    );
    final delays = <Duration>[];
    final now = DateTime.utc(2026, 9, 9, 9);

    await _pumpPaymentResult(
      tester,
      api,
      now: () => now,
      delay: (duration) {
        delays.add(duration);
        return Future<void>.value();
      },
    );
    await tester.pumpAndSettle();

    expect(api.requests, hasLength(1));
    expect(delays, const [Duration(seconds: 1)]);
    expect(find.text('Ödeme Henüz Doğrulanmadı'), findsOneWidget);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('yükleme ve polling durumu canlı erişilebilir metin taşır '
        '(${brightness.name})', (tester) async {
      final semantics = tester.ensureSemantics();
      final response = Completer<FakeApiResponse>();
      final delayedPoll = Completer<void>();
      final api = FakeApi(handler: (_) => response.future);

      await _pumpPaymentResult(
        tester,
        api,
        brightness: brightness,
        delay: (_) => delayedPoll.future,
      );
      await tester.pump();

      const loadingLabel = 'Ödeme sonucu kontrol ediliyor.';
      expect(find.text(loadingLabel), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.label == loadingLabel && node.flagsCollection.isLiveRegion,
        ),
        findsOne,
      );

      response.complete(_assignmentResponse('PENDING_COLLECTION'));
      await tester.pumpAndSettle();

      const pollingLabel =
          'Ödeme Sonucu Kontrol Ediliyor. Sağlayıcı sonucu işliyor. '
          'Otomatik olarak tekrar kontrol ediyoruz; bu sırada yeni ödeme '
          'başlatma.';
      expect(find.text('Ödeme Sonucu Kontrol Ediliyor'), findsOneWidget);
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.label == pollingLabel && node.flagsCollection.isLiveRegion,
        ),
        findsOne,
      );
      expect(find.bySemanticsLabel('TEKRAR KONTROL ET'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(BPaymentResultPage))).brightness,
        brightness,
      );
      semantics.dispose();
    });
  }
}

Future<void> _pumpPaymentResult(
  WidgetTester tester,
  FakeApi api, {
  Brightness brightness = Brightness.light,
  DateTime Function()? now,
  Future<void> Function(Duration)? delay,
}) => pumpInApp(
  tester,
  BPaymentResultPage(
    assignmentId: 'asg_1',
    service: EmployerJobService.withClient(api.client),
    now: now,
    delay: delay,
  ),
  brightness: brightness,
);

FakeApiResponse _assignmentResponse(String paymentStatus) => FakeApiResponse(
  statusCode: 200,
  body: {
    'success': true,
    'data': {
      'id': 'asg_1',
      'status': 'CONFIRMED',
      'paymentStatus': paymentStatus,
      'job': {
        'id': 'job_1',
        'title': 'Barista',
        'salary': 1500,
        'category': {'id': 'cat_1', 'code': 'BARISTA', 'name': 'Barista'},
      },
    },
  },
);
