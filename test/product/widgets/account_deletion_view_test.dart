import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/account_deletion_view.dart';

import '../../support/pump.dart';

void main() {
  testWidgets('silme isteğini açık onaydan sonra gerekçesiyle gönderir', (
    tester,
  ) async {
    String? sentReason;
    final requestCompleter = Completer<void>();

    await pumpInApp(
      tester,
      AccountDeletionView(
        requestDeletion: ({reason}) {
          sentReason = reason;
          return requestCompleter.future;
        },
      ),
    );

    expect(find.text('Hesap silme talebi'), findsOneWidget);
    expect(find.textContaining('geri alınamaz'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Artık kullanmıyorum');
    await tester.tap(find.text('Silme Talebi Oluştur'));
    await tester.pumpAndSettle();

    expect(sentReason, isNull);
    expect(find.text('Hesabımı Sil'), findsOneWidget);

    await tester.tap(find.text('Hesabımı Sil'));
    await tester.pump();

    expect(sentReason, 'Artık kullanmıyorum');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    requestCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('Talebin alındı'), findsOneWidget);
    expect(find.text('Silme Talebi Oluştur'), findsNothing);
  });

  testWidgets('sunucu engelini kullanıcıya gösterir ve yeniden denetir', (
    tester,
  ) async {
    var callCount = 0;

    await pumpInApp(
      tester,
      AccountDeletionView(
        requestDeletion: ({reason}) async {
          callCount++;
          throw const ApiException(
            message: 'Devam eden işiniz bulunduğu için talep alınamadı.',
            type: ApiErrorType.conflict,
          );
        },
      ),
    );

    await tester.tap(find.text('Silme Talebi Oluştur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hesabımı Sil'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(
      find.text('Devam eden işiniz bulunduğu için talep alınamadı.'),
      findsOneWidget,
    );
    expect(find.text('Silme Talebi Oluştur'), findsOneWidget);
  });

  testWidgets('açık ve koyu temada çizilir', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpInApp(
        tester,
        AccountDeletionView(requestDeletion: ({reason}) async {}),
        brightness: brightness,
      );

      expect(tester.takeException(), isNull, reason: '$brightness patladı');
      expect(find.text('Hesap silme talebi'), findsOneWidget);
    }
  });
}
