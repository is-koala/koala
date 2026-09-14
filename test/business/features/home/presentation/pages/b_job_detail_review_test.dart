import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import 'b_job_detail_test_harness.dart';

const _worker = {'id': 'worker-1', 'firstName': 'Ayşe', 'lastName': 'Yılmaz'};

const _employer = {
  'id': 'employer-1',
  'firstName': 'İşveren',
  'lastName': 'Kullanıcı',
  'email': 'isveren@example.com',
  'isEmployer': true,
};

Map<String, Object?> _assignment({required String status}) => {
  ...assignmentJson,
  'status': status,
  'paymentStatus': status == 'COMPLETED'
      ? 'HELD_IN_ESCROW'
      : 'PENDING_COLLECTION',
  'worker': _worker,
  'actualCompletionDateTime': '2026-09-10T17:05:00Z',
};

Map<String, Object?> _review({
  required String id,
  required String authorId,
  required int rating,
  String? comment,
  required String createdAt,
}) => {
  'id': id,
  'rating': rating,
  'comment': ?comment,
  'author': {'id': authorId, 'firstName': 'X', 'lastName': 'Y'},
  'createdAt': createdAt,
};

final _row = find.byKey(const ValueKey('assignment-review'));
final _button = find.byKey(const ValueKey('assignment-review-button'));

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
      'tamamlanan atamada "İşçiyi Değerlendirin" eylemi ve /review\'a '
      'ReviewSubject geçişi (${brightness.name})',
      (tester) async {
        final opened = <Object?>[];
        await pumpPage(
          tester,
          brightness: brightness,
          currentUser: _employer,
          assignments: [_assignment(status: 'COMPLETED')],
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

  testWidgets('bu cihazda yazılmış değerlendirme içeriğiyle gösterilir', (
    tester,
  ) async {
    await pumpPage(
      tester,
      currentUser: _employer,
      assignments: [_assignment(status: 'COMPLETED')],
      reviewedAssignmentIds: const ['assignment-1'],
      reviewedAssignmentDetails:
          '{"assignment-1":{"id":"rev_1","rating":4,"comment":"Dakik"}}',
    );

    await tester.scrollUntilVisible(_row, 200);
    expect(find.text('Değerlendirdiniz: ★4 · "Dakik"'), findsOneWidget);
    expect(_button, findsNothing);
  });

  // Başka cihazda yazılmış (409'dan öğrenilmiş) kayıt: içerik sunucudan,
  // `GET /users/{worker}/reviews` içinde yazarı biz olan kayıttan tamamlanıyor.
  testWidgets('içeriği bilinmeyen değerlendirme sunucudan tamamlanır', (
    tester,
  ) async {
    final paths = <String>[];
    final harness = await pumpPage(
      tester,
      currentUser: _employer,
      assignments: [_assignment(status: 'COMPLETED')],
      reviewedAssignmentIds: const ['assignment-1'],
      reviewHandler: (request) {
        paths.add(request.path);
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                _review(
                  id: 'rev_other',
                  authorId: 'someone-else',
                  rating: 1,
                  createdAt: '2026-09-11T09:00:00Z',
                ),
                _review(
                  id: 'rev_mine',
                  authorId: 'employer-1',
                  rating: 5,
                  comment: 'Harika',
                  createdAt: '2026-09-11T10:00:00Z',
                ),
              ],
              'last': true,
            },
          },
        );
      },
    );

    await tester.scrollUntilVisible(_row, 200);
    expect(paths, contains('/users/worker-1/reviews'));
    expect(find.text('Değerlendirdiniz: ★5 · "Harika"'), findsOneWidget);
    expect(_button, findsNothing);
    expect(
      harness.reviewApi.requests.where((r) => r.method == 'POST'),
      isEmpty,
    );
  });

  // Arama değerlendirilmişliğe karar vermiyor: işaretsiz atamada sunucuya
  // gidilmiyor ve düğme duruyor — aynı kişiyle ikinci iş yanlış kapanmasın.
  testWidgets('işaretsiz atamada kendi kaydı aranmaz, düğme durur', (
    tester,
  ) async {
    final paths = <String>[];
    await pumpPage(
      tester,
      currentUser: _employer,
      assignments: [_assignment(status: 'COMPLETED')],
      reviewHandler: (request) {
        paths.add(request.path);
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                _review(
                  id: 'rev_mine',
                  authorId: 'employer-1',
                  rating: 5,
                  createdAt: '2026-09-11T10:00:00Z',
                ),
              ],
              'last': true,
            },
          },
        );
      },
    );

    await tester.scrollUntilVisible(_row, 200);
    expect(paths, isEmpty);
    expect(_button, findsOneWidget);
  });

  // Sunucunun 409'u (başka cihazda yazılmış) sayfaya döner dönmez satırı
  // düğmesiz hâle getiriyor; ekranın kendisi burada değil, provider'ın
  // işareti ölçülüyor.
  testWidgets('409 ile işaretlenince satır "Değerlendirdiniz." olur', (
    tester,
  ) async {
    await pumpPage(
      tester,
      currentUser: _employer,
      assignments: [_assignment(status: 'COMPLETED')],
      reviewHandler: (request) => request.method == 'POST'
          ? const FakeApiResponse(
              statusCode: 409,
              body: {
                'success': false,
                'message': 'Bu iş için zaten değerlendirme yaptınız.',
                'errorCode': 'REVIEW_ALREADY_REVIEWED',
                'errorCategory': 'DATA_CONFLICT',
              },
            )
          : const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'content': [], 'last': true},
              },
            ),
    );

    await tester.scrollUntilVisible(_row, 200);
    final provider = tester.element(_row).read<ReviewProvider>();
    // Sahte HTTP ve disk yazımı gerçek olay döngüsünde; test zamanında
    // beklense tamamlanmaz.
    final sent = await tester.runAsync(
      () => provider.submitReview(assignmentId: 'assignment-1', rating: 3),
    );
    await tester.pumpAndSettle();

    expect(sent, isFalse);
    expect(find.text('Değerlendirdiniz.'), findsOneWidget);
    expect(_button, findsNothing);
  });
}
