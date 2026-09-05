import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/widgets/report_sheet.dart';

import '../../support/pump.dart';

/// Gönder düğmesinin o anki hâli.
VoidCallback? sendButton(WidgetTester tester) =>
    tester.widget<MyButton>(find.byType(MyButton)).onPressed;

void main() {
  group('ReportSheet', () {
    testWidgets('gerekçe seçilmeden gönder düğmesi kapalıdır', (tester) async {
      await pumpInApp(
        tester,
        ReportSheet(
          target: ReportTarget.user(userId: 'u1', name: 'Ayşe'),
        ),
      );

      // Sunucu gerekçesiz şikayeti `400` ile reddediyor; istemci gönderime
      // hiç izin vermemeli.
      expect(sendButton(tester), isNull);
    });

    testWidgets('gerekçe seçilince gönder düğmesi açılır', (tester) async {
      await pumpInApp(
        tester,
        ReportSheet(target: ReportTarget.user(userId: 'u1')),
      );

      await tester.tap(find.text(ReportReason.spam.displayName));
      await tester.pump();

      expect(sendButton(tester), isNotNull);
    });

    testWidgets('bilinmeyen gerekçe listede yer almaz', (tester) async {
      await pumpInApp(
        tester,
        ReportSheet(target: ReportTarget.user(userId: 'u1')),
      );

      expect(find.text(ReportReason.unknown.displayName), findsNothing);
      expect(find.text(ReportReason.other.displayName), findsOneWidget);
    });

    testWidgets('açıklama 2000 karakterle sınırlıdır', (tester) async {
      await pumpInApp(
        tester,
        ReportSheet(
          target: ReportTarget.job(jobId: 'j1', title: 'Garson'),
        ),
      );

      final field = tester.widget<MyTextfield>(find.byType(MyTextfield));
      final limit = field.inputFormatters!
          .whereType<LengthLimitingTextInputFormatter>()
          .single;

      expect(limit.maxLength, 2000);
    });

    testWidgets('hedefe göre başlık ve açıklama değişir', (tester) async {
      await pumpInApp(
        tester,
        ReportSheet(target: ReportTarget.message(messageId: 'm1')),
      );

      expect(find.text('Mesajı Şikayet Et'), findsOneWidget);
    });

    testWidgets('her iki temada da hatasız çizilir', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpInApp(
          tester,
          ReportSheet(target: ReportTarget.user(userId: 'u1')),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull, reason: '$brightness patladı');
        expect(find.byType(MyButton), findsOneWidget);
      }
    });
  });
}
