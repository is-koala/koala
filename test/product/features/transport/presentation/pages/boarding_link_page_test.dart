import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/presentation/pages/boarding_link_page.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_result_panel.dart';

import '../../../../../support/boarding_fixtures.dart';
import '../../../../../support/pump.dart';

void main() {
  late List<BoardingToken> submitted;

  setUp(() => submitted = []);

  Future<void> pump(
    WidgetTester tester, {
    required String token,
    BoardingTokenKind accepted = BoardingTokenKind.shuttle,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpInApp(
      tester,
      BoardingLinkPage(
        token: token,
        acceptedKind: accepted,
        homeRoute: '/jobs',
        submit: (context, token, capturedAt) async {
          submitted.add(token);
          return const BoardingResultPanel(
            tone: BoardingResultTone.success,
            message: 'Binişiniz kaydedildi.',
          );
        },
      ),
      brightness: brightness,
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('doğru taraftaki bağlantı bir kez gönderilir '
        '(${brightness.name})', (tester) async {
      await pump(tester, token: shuttleTokenValue, brightness: brightness);

      expect(submitted.single.subjectId, shuttleUuid);
      expect(find.text('Binişiniz kaydedildi.'), findsOne);
    });
  }

  testWidgets('bozuk t gönderilmez, geçersiz denir', (tester) async {
    await pump(tester, token: 's1.bozuk');

    expect(submitted, isEmpty);
    expect(find.text(BoardingLinkPage.invalidMessage), findsOne);
  });

  testWidgets('çalışan QR\'ı işçi oturumunda gönderilmez', (tester) async {
    await pump(tester, token: workerTokenValue);

    expect(submitted, isEmpty);
    expect(
      find.text(BoardingLinkPage.wrongSideMessage(BoardingTokenKind.shuttle)),
      findsOne,
    );
  });

  testWidgets('servis QR\'ı işveren oturumunda gönderilmez', (tester) async {
    await pump(
      tester,
      token: shuttleTokenValue,
      accepted: BoardingTokenKind.worker,
    );

    expect(submitted, isEmpty);
    expect(
      find.text(BoardingLinkPage.wrongSideMessage(BoardingTokenKind.worker)),
      findsOne,
    );
  });
}
