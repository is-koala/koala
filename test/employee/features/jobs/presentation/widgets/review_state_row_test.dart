import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/review_state_row.dart';

import '../../../../../support/pump.dart';

const _button = ValueKey('row-button');
final _badge = find.byKey(const ValueKey('review-counterparty-badge'));

Future<void> pumpRow(
  WidgetTester tester, {
  required Brightness brightness,
  Review? ownReview,
  bool hasReviewed = false,
  bool counterpartyReviewed = false,
  VoidCallback? onReview,
}) => pumpInApp(
  tester,
  ReviewStateRow(
    ownReview: ownReview,
    hasReviewed: hasReviewed,
    counterpartyReviewed: counterpartyReviewed,
    pendingText: 'Henüz değerlendirmediniz.',
    buttonLabel: 'Değerlendir',
    buttonKey: _button,
    onReview: onReview,
  ),
  brightness: brightness,
);

void main() {
  for (final brightness in Brightness.values) {
    group('ReviewStateRow / ${brightness.name}', () {
      testWidgets('değerlendirilmemiş: cümle ve düğme', (tester) async {
        var tapped = 0;
        await pumpRow(tester, brightness: brightness, onReview: () => tapped++);

        expect(find.text('Henüz değerlendirmediniz.'), findsOneWidget);
        await tester.tap(find.byKey(_button));
        expect(tapped, 1);
        expect(_badge, findsNothing);
      });

      testWidgets('içerikli: "Değerlendirdiniz: ★N · yorum", düğme yok', (
        tester,
      ) async {
        await pumpRow(
          tester,
          brightness: brightness,
          ownReview: const Review(id: 'rev_1', rating: 4, comment: 'İyi'),
        );

        expect(find.text('Değerlendirdiniz: ★4 · "İyi"'), findsOneWidget);
        expect(find.byKey(_button), findsNothing);
      });

      // Eski sunucunun 409'u: değerlendirilmiş ama içerik bilinmiyor.
      testWidgets('içeriksiz işaret: "Değerlendirdiniz."', (tester) async {
        await pumpRow(tester, brightness: brightness, hasReviewed: true);

        expect(find.text('Değerlendirdiniz.'), findsOneWidget);
        expect(find.byKey(_button), findsNothing);
      });

      testWidgets('karşı taraf rozeti yalnız varlığı söyler', (tester) async {
        await pumpRow(
          tester,
          brightness: brightness,
          counterpartyReviewed: true,
          onReview: () {},
        );

        expect(_badge, findsOneWidget);
        expect(find.text('Karşı taraf sizi değerlendirdi'), findsOneWidget);
        // Karşı tarafın puanı gelmiyor; yıldız sayısı yazılmıyor.
        expect(find.textContaining('★'), findsNothing);
        expect(find.byKey(_button), findsOneWidget);
      });

      testWidgets('onReview null ise düğme devre dışı', (tester) async {
        await pumpRow(tester, brightness: brightness);

        final button = tester.widget<TextButton>(find.byKey(_button));
        expect(button.onPressed, isNull);
      });
    });
  }
}
