import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/widgets/b_worker_identity_card.dart';

import '../../../../../support/fake_api.dart';
import 'b_job_detail_test_harness.dart';

const _worker = {'id': 'worker-1', 'firstName': 'Ayşe', 'lastName': 'Yılmaz'};

const _identityJson = {
  'fullName': 'Ayşe Yılmaz',
  'tcIdentityNumber': '10000000146',
  'birthDate': '1994-05-17',
  'verifiedAt': '2026-09-01T09:30:00Z',
  'verificationMethod': 'CHIP',
};

Map<String, Object?> _assignment({
  String status = 'CONFIRMED',
  String id = 'assignment-1',
}) => {
  ...assignmentJson,
  'id': id,
  'status': status,
  'paymentStatus': status == 'COMPLETED'
      ? 'HELD_IN_ESCROW'
      : 'PENDING_COLLECTION',
  'worker': _worker,
};

final _button = find.byKey(const ValueKey('reveal-worker-identity'));
final _card = find.byKey(const ValueKey('worker-identity-card'));
final _tckn = find.byKey(const ValueKey('worker-identity-tckn'));
final _dialogAction = find.widgetWithText(TextButton, 'Göster');

/// İşveren servisinin sahte ucu: atama listesi varsayılan, kimlik ucu
/// [identity] ile yanıtlanıyor. [revealRequests] her `worker-identity`
/// çağrısını sayıyor — onay verilmeden istek çıkmamalı.
FakeApiResponse Function(RequestOptions) _employerHandler(
  List<Map<String, Object?>> assignments, {
  required FakeApiResponse identity,
  required List<RequestOptions> revealRequests,
}) {
  return (request) {
    if (request.path.endsWith('/worker-identity')) {
      revealRequests.add(request);
      return identity;
    }
    return FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'content': assignments},
      },
    );
  };
}

FakeApiResponse _error(int status, {String? code, String? message}) =>
    FakeApiResponse(
      statusCode: status,
      body: {
        'success': false,
        'message': message ?? 'Hata',
        'errorCode': ?code,
      },
    );

Future<void> _revealAndConfirm(WidgetTester tester) async {
  await tester.scrollUntilVisible(_button, 200);
  await tester.tap(_button);
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  await tester.tap(_dialogAction);
  await tester.pumpAndSettle();
}

void main() {
  group('durum kapısı', () {
    for (final status in ['CONFIRMED', 'IN_PROGRESS', 'COMPLETED']) {
      testWidgets('$status atamada düğme çizilir', (tester) async {
        await pumpPage(tester, assignments: [_assignment(status: status)]);

        await tester.scrollUntilVisible(_button, 200);
        expect(_button, findsOneWidget);
        expect(
          find.text('Kimlik bilgilerini göster (sigorta için)'),
          findsOneWidget,
        );
        expect(_card, findsNothing);
      });
    }

    for (final status in ['PENDING_CONFIRMATION', 'REJECTED', 'CANCELLED']) {
      testWidgets('$status atamada düğme yok', (tester) async {
        await pumpPage(tester, assignments: [_assignment(status: status)]);

        expect(_button, findsNothing);
        expect(_card, findsNothing);
      });
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'onay → GET → alanlar maskesiz gösterilir; vazgeçince istek çıkmaz '
      '(${brightness.name})',
      (tester) async {
        final requests = <RequestOptions>[];
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [_assignment()],
          employerHandler: _employerHandler(
            [_assignment()],
            identity: const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': _identityJson},
            ),
            revealRequests: requests,
          ),
        );

        await tester.scrollUntilVisible(_button, 200);
        await tester.tap(_button);
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'Görüntülemeniz kayda geçer ve çalışana '
            'bildirilir',
          ),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(_card, findsNothing);

        await _revealAndConfirm(tester);

        expect(requests, hasLength(1));
        expect(requests.single.method, 'GET');
        expect(
          requests.single.path,
          '/job-assignments/assignment-1/worker-identity',
        );
        expect(_card, findsOneWidget);
        expect(_button, findsNothing);
        expect(tester.widget<Text>(_tckn).data, '10000000146');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('worker-identity-name')))
              .data,
          'Ayşe Yılmaz',
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('worker-identity-birth-date')),
              )
              .data,
          '17.05.1994',
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('worker-identity-verification')),
              )
              .data,
          contains('Çipli kimlik'),
        );
        expect(
          find.descendant(
            of: _card,
            matching: find.textContaining('bir dakika sonra'),
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('60 saniye sonra kart kalkar ve düğme geri gelir', (
    tester,
  ) async {
    await pumpPage(
      tester,
      assignments: [_assignment()],
      employerHandler: _employerHandler(
        [_assignment()],
        identity: const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _identityJson},
        ),
        revealRequests: [],
      ),
    );

    await _revealAndConfirm(tester);
    expect(_card, findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(_card, findsOneWidget);
    expect(find.text('10000000146'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(_card, findsNothing);
    expect(find.text('10000000146'), findsNothing);
    expect(_button, findsOneWidget);
  });

  testWidgets('"Gizle" süre dolmadan kartı kaldırır', (tester) async {
    await pumpPage(
      tester,
      assignments: [_assignment()],
      employerHandler: _employerHandler(
        [_assignment()],
        identity: const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _identityJson},
        ),
        revealRequests: [],
      ),
    );

    await _revealAndConfirm(tester);
    await tester.tap(find.byKey(const ValueKey('worker-identity-hide')));
    await tester.pump();

    expect(_card, findsNothing);
    expect(find.text('10000000146'), findsNothing);
    expect(_button, findsOneWidget);
  });

  testWidgets('sayfa kapanınca zamanlayıcı ve değer temizlenir', (
    tester,
  ) async {
    await pumpPage(
      tester,
      assignments: [_assignment()],
      employerHandler: _employerHandler(
        [_assignment()],
        identity: const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _identityJson},
        ),
        revealRequests: [],
      ),
    );

    await _revealAndConfirm(tester);
    expect(_card, findsOneWidget);

    // Sayfa sökülüyor; bekleyen zamanlayıcı kalsaydı test "pending timer"
    // ile kırmızıya düşerdi.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 60));
    expect(find.byType(BWorkerIdentityCard), findsNothing);
  });

  testWidgets('TCKN panoya kopyalanır', (tester) async {
    final copied = <String?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String?);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpPage(
      tester,
      assignments: [_assignment()],
      employerHandler: _employerHandler(
        [_assignment()],
        identity: const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _identityJson},
        ),
        revealRequests: [],
      ),
    );

    await _revealAndConfirm(tester);
    await tester.tap(find.byKey(const ValueKey('worker-identity-copy')));
    await tester.pump();

    expect(copied, ['10000000146']);
    expect(find.text('TCKN kopyalandı'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  group('sunucu kapıları', () {
    testWidgets('409 WORKER_IDENTITY_NOT_VERIFIED → doğrulanmamış toast\'ı', (
      tester,
    ) async {
      await pumpPage(
        tester,
        assignments: [_assignment()],
        employerHandler: _employerHandler(
          [_assignment()],
          identity: _error(
            409,
            code: 'WORKER_IDENTITY_NOT_VERIFIED',
            message: 'İşçinin kimliği henüz doğrulanmamış.',
          ),
          revealRequests: [],
        ),
      );

      await _revealAndConfirm(tester);

      expect(find.text('Çalışanın kimliği doğrulanmamış'), findsOneWidget);
      expect(_card, findsNothing);
      expect(_button, findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('429 → "çok sık görüntülendi" toast\'ı, düğme kalır', (
      tester,
    ) async {
      await pumpPage(
        tester,
        assignments: [_assignment()],
        employerHandler: _employerHandler(
          [_assignment()],
          identity: _error(
            429,
            code: 'IDENTITY_REVEAL_TOO_MANY_REQUESTS',
            message: 'Saatlik sınıra ulaştınız.',
          ),
          revealRequests: [],
        ),
      );

      await _revealAndConfirm(tester);

      expect(
        find.text('Çok sık görüntülendi, biraz sonra deneyin'),
        findsOneWidget,
      );
      expect(_card, findsNothing);
      expect(_button, findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('404 → düğme bu atama için kalkar', (tester) async {
      await pumpPage(
        tester,
        assignments: [_assignment()],
        employerHandler: _employerHandler(
          [_assignment()],
          identity: _error(
            404,
            code: 'JOB_ASSIGNMENT_NOT_FOUND',
            message: 'Atama bulunamadı.',
          ),
          revealRequests: [],
        ),
      );

      await _revealAndConfirm(tester);

      expect(_card, findsNothing);
      expect(_button, findsNothing);
      expect(
        find.text('Kimlik bilgileri bu atama için görüntülenemiyor'),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('bilinmeyen hata sunucunun mesajıyla toast', (tester) async {
      await pumpPage(
        tester,
        assignments: [_assignment()],
        employerHandler: _employerHandler(
          [_assignment()],
          identity: _error(500, message: 'Beklenmeyen bir hata oluştu.'),
          revealRequests: [],
        ),
      );

      await _revealAndConfirm(tester);

      expect(find.text('Beklenmeyen bir hata oluştu.'), findsOneWidget);
      expect(_button, findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  testWidgets('kullanıcıya dönük metinler "siz" diliyle', (tester) async {
    await pumpPage(
      tester,
      assignments: [_assignment()],
      employerHandler: _employerHandler(
        [_assignment()],
        identity: const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _identityJson},
        ),
        revealRequests: [],
      ),
    );

    await tester.scrollUntilVisible(_button, 200);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    final dialogText = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data ?? '')
        .join(' ');
    expect(dialogText, contains('Görüntülemeniz'));
    expect(dialogText, isNot(matches(RegExp(r'\b(sen|senin|seni)\b'))));
    expect(dialogText, isNot(contains('görüntülemen ')));

    await tester.tap(_dialogAction);
    await tester.pumpAndSettle();
    final cardText = tester
        .widgetList<Text>(
          find.descendant(of: _card, matching: find.byType(Text)),
        )
        .map((text) => text.data ?? '')
        .join(' ');
    expect(cardText, isNot(matches(RegExp(r'\b(sen|senin|seni)\b'))));
  });
}
