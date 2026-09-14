import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/review_state_row.dart';
import 'package:provider/provider.dart';

import '../../../../../support/review_fixtures.dart';
import 'b_job_detail_test_harness.dart';

const _worker = {'id': 'worker-1', 'firstName': 'Ayşe', 'lastName': 'Yılmaz'};

const _employer = {
  'id': 'employer-1',
  'firstName': 'İşveren',
  'lastName': 'Kullanıcı',
  'email': 'isveren@example.com',
  'isEmployer': true,
};

Map<String, Object?> _assignment({
  required String status,
  Map<String, Object?>? myReview,
  bool? counterpartyReviewed,
}) => {
  ...assignmentJson,
  'status': status,
  'paymentStatus': status == 'COMPLETED'
      ? 'HELD_IN_ESCROW'
      : 'PENDING_COLLECTION',
  'worker': _worker,
  'actualCompletionDateTime': '2026-09-10T17:05:00Z',
  'myReview': ?myReview,
  'counterpartyReviewed': ?counterpartyReviewed,
};

final _row = find.byKey(const ValueKey('assignment-review'));
final _button = find.byKey(const ValueKey('assignment-review-button'));
final _badge = find.byKey(const ValueKey('review-counterparty-badge'));

/// Gerçek `ReviewPage` yerine sözleşmesi: `extra` bir [ReviewSubject].
GoRoute _stubReviewRoute(List<Object?> opened) => GoRoute(
  path: '/review',
  pageBuilder: (context, state) {
    opened.add(state.extra);
    return MaterialPage<void>(
      key: state.pageKey,
      child: const Scaffold(body: Text('değerlendirme ekranı')),
    );
  },
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'tamamlanan atamada "Çalışanı Değerlendirin" eylemi ve /review\'a '
      'ReviewSubject geçişi (${brightness.name})',
      (tester) async {
        final opened = <Object?>[];
        await pumpPage(
          tester,
          brightness: brightness,
          currentUser: _employer,
          assignments: [
            _assignment(
              status: 'COMPLETED',
              myReview: null,
              counterpartyReviewed: false,
            ),
          ],
          extraRoutes: [_stubReviewRoute(opened)],
        );

        await tester.scrollUntilVisible(_row, 200);
        expect(
          find.descendant(
            of: _row,
            matching: find.text('Çalışanı henüz değerlendirmediniz.'),
          ),
          findsOneWidget,
        );
        expect(_button, findsOneWidget);
        expect(_badge, findsNothing);

        await tester.tap(_button);
        await tester.pumpAndSettle();

        expect(find.text('değerlendirme ekranı'), findsOneWidget);
        final subject = opened.single as ReviewSubject;
        expect(subject.assignmentId, 'assignment-1');
        expect(subject.side, ReviewSide.employer);
        expect(subject.title, 'Ayşe Yılmaz');
        expect(subject.subtitle, 'Barista');
      },
    );

    // Sunucu "değerlendirdin" diyor (`myReview`): içerik oradan, düğme yok.
    // Sunucunun kaydı için ne diske ne `GET /users/{id}/reviews`e gidilir.
    testWidgets('myReview dolu: "Değerlendirdiniz: ★N · yorum", düğme yok '
        '(${brightness.name})', (tester) async {
      final harness = await pumpPage(
        tester,
        brightness: brightness,
        currentUser: _employer,
        assignments: [
          _assignment(
            status: 'COMPLETED',
            myReview: myReviewJson(rating: 4, comment: 'Dakik'),
          ),
        ],
      );

      await tester.scrollUntilVisible(_row, 200);
      expect(find.text('Değerlendirdiniz: ★4 · "Dakik"'), findsOneWidget);
      expect(_button, findsNothing);
      expect(harness.reviewApi.requests, isEmpty);
    });

    // Çalışan işvereni değerlendirdiyse yalnız varlığı çizilir: rozet var,
    // içerik ve yazar yok.
    testWidgets('counterpartyReviewed rozeti (${brightness.name})', (
      tester,
    ) async {
      await pumpPage(
        tester,
        brightness: brightness,
        currentUser: _employer,
        assignments: [
          _assignment(status: 'COMPLETED', counterpartyReviewed: true),
        ],
      );

      await tester.scrollUntilVisible(_row, 200);
      expect(_badge, findsOneWidget);
      expect(
        find.descendant(
          of: _badge,
          matching: find.text(ReviewStateRow.counterpartyBadgeText),
        ),
        findsOneWidget,
      );
      // Karşı tarafın kaydı gelmedi; işverenin kendi düğmesi durur.
      expect(_button, findsOneWidget);
    });
  }

  // Sunucu da aynı kapıyı `409 REVIEW_WORK_NOT_COMPLETED` ile tutuyor;
  // tamamlanmamış ve kapanmış atamada eylem hiç çizilmiyor.
  for (final status in ['CONFIRMED', 'IN_PROGRESS', 'CANCELLED', 'REJECTED']) {
    testWidgets('$status atamada değerlendirme satırı yok', (tester) async {
      await pumpPage(
        tester,
        currentUser: _employer,
        assignments: [_assignment(status: status)],
      );

      expect(_row, findsNothing);
      expect(_button, findsNothing);
    });
  }

  testWidgets('yorumsuz myReview yalnız yıldızla yazılır', (tester) async {
    await pumpPage(
      tester,
      currentUser: _employer,
      assignments: [
        _assignment(
          status: 'COMPLETED',
          myReview: myReviewJson(rating: 5, comment: null),
        ),
      ],
    );

    await tester.scrollUntilVisible(_row, 200);
    expect(find.text('Değerlendirdiniz: ★5'), findsOneWidget);
    expect(_button, findsNothing);
  });

  // Eski sunucu alanı göndermiyor: düğme görünür; başka cihazda yazılmış
  // kaydı sunucunun 409'u bildirir ve satır düğmesiz olur — içeriksiz.
  testWidgets('eski sunucu: düğme var, 409 ile "Değerlendirdiniz." olur', (
    tester,
  ) async {
    await pumpPage(
      tester,
      currentUser: _employer,
      assignments: [_assignment(status: 'COMPLETED')],
      reviewHandler: (_) => reviewAlreadyReviewedResponse(),
    );

    await tester.scrollUntilVisible(_row, 200);
    expect(_button, findsOneWidget);

    final provider = tester.element(_row).read<ReviewProvider>();
    // Sahte HTTP gerçek olay döngüsünde; test zamanında beklense tamamlanmaz.
    final sent = await tester.runAsync(
      () => provider.submitReview(assignmentId: 'assignment-1', rating: 3),
    );
    await tester.pumpAndSettle();

    expect(sent, isFalse);
    expect(find.text('Değerlendirdiniz.'), findsOneWidget);
    expect(_button, findsNothing);
  });

  // Liste eski (`myReview` yok) ama bu oturumda gönderildi: yanıtın içeriği
  // hemen yazılır, düğme kaybolur.
  testWidgets('az önce gönderilen kayıt listeden önce satıra düşer', (
    tester,
  ) async {
    await pumpPage(
      tester,
      currentUser: _employer,
      assignments: [_assignment(status: 'COMPLETED')],
      reviewHandler: (request) => reviewCreatedResponse(
        reviewDtoJson(
          rating: 5,
          comment: 'Harika',
          jobAssignmentId: 'assignment-1',
        ),
      ),
    );

    await tester.scrollUntilVisible(_row, 200);
    final provider = tester.element(_row).read<ReviewProvider>();
    final sent = await tester.runAsync(
      () => provider.submitReview(
        assignmentId: 'assignment-1',
        rating: 5,
        comment: 'Harika',
      ),
    );
    await tester.pumpAndSettle();

    expect(sent, isTrue);
    expect(find.text('Değerlendirdiniz: ★5 · "Harika"'), findsOneWidget);
    expect(_button, findsNothing);
  });
}
