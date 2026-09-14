import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/widgets/messaging_gate_note.dart';

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

const _acceptedApplicant = {
  'id': 'application-1',
  'status': 'ACCEPTED',
  'applicationDateTime': '2026-09-08T10:00:00Z',
  'applicant': _worker,
};

// Reddedilen başvuran detay sayfasında hiç listelenmiyor
// (`BJobPost.unansweredApplicants`); işverenin listede gördüğü kapalı kayıt
// geri çekilen başvuru.
const _withdrawnApplicant = {
  'id': 'application-3',
  'status': 'WITHDRAWN',
  'applicationDateTime': '2026-09-08T12:00:00Z',
  'applicant': {'id': 'worker-3', 'firstName': 'Zeynep', 'lastName': 'Demir'},
};

const _pendingApplicant = {
  'id': 'application-2',
  'status': 'APPLIED',
  'applicationDateTime': '2026-09-08T11:00:00Z',
  'applicant': {'id': 'worker-2', 'firstName': 'Mehmet', 'lastName': 'Kaya'},
};

/// Adayın bu ilandaki ataması; kapı alanları isteğe bağlı ki eski sunucu
/// (alanlar yok) da denenebilsin.
Map<String, Object?> assignmentFor({
  required String paymentStatus,
  String status = 'CONFIRMED',
  bool? messagingAvailable,
  String? messagingAvailableReason,
}) => {
  ...assignmentJson,
  'status': status,
  'paymentStatus': paymentStatus,
  'worker': _worker,
  'messagingAvailable': ?messagingAvailable,
  'messagingAvailableReason': ?messagingAvailableReason,
};

final _chatButton = find.byKey(const ValueKey('applicant-chat-worker-1'));
final _chatNote = find.byKey(const ValueKey('applicant-chat-note-worker-1'));
final _payShortcut = find.byKey(const ValueKey('applicant-pay-worker-1'));

void main() {
  for (final brightness in Brightness.values) {
    group('işveren başvuran kartı / ${brightness.name}', () {
      testWidgets('AVAILABLE: Mesaj Gönder düğmesi çizilir', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          applicants: const [_acceptedApplicant],
          assignments: [
            assignmentFor(
              paymentStatus: 'HELD_IN_ESCROW',
              messagingAvailable: true,
              messagingAvailableReason: 'AVAILABLE',
            ),
          ],
        );

        expect(_chatButton, findsOneWidget);
        expect(find.text('Mesaj Gönder'), findsOneWidget);
        expect(_chatNote, findsNothing);
      });

      testWidgets('PAYMENT_REQUIRED: düğme yerine açıklama ve ödeme kısayolu', (
        tester,
      ) async {
        await pumpPage(
          tester,
          brightness: brightness,
          applicants: const [_acceptedApplicant],
          assignments: [
            assignmentFor(
              paymentStatus: 'PENDING_COLLECTION',
              messagingAvailable: false,
              messagingAvailableReason: 'PAYMENT_REQUIRED',
            ),
          ],
        );

        expect(_chatButton, findsNothing);
        expect(_chatNote, findsOneWidget);
        expect(
          find.text('Ödemeyi tamamlayınca ekip sohbeti açılır.'),
          findsOneWidget,
        );
        expect(_payShortcut, findsOneWidget);
        expect(find.text('Ödemeye Git'), findsOneWidget);
      });

      testWidgets('CLOSED: "Bu sohbet kapandı", kısayol yok', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          applicants: const [_acceptedApplicant],
          assignments: [
            assignmentFor(
              status: 'CANCELLED',
              paymentStatus: 'REFUNDED',
              messagingAvailable: false,
              messagingAvailableReason: 'CLOSED',
            ),
          ],
        );

        expect(_chatButton, findsNothing);
        expect(find.text('Bu sohbet kapandı'), findsOneWidget);
        expect(_payShortcut, findsNothing);
      });

      // Backend PR 261 öncesi sunucu alanları göndermiyor; düğme yine gizli.
      testWidgets('eski sunucu (alan yok): düğme gizli, açıklama var', (
        tester,
      ) async {
        await pumpPage(
          tester,
          brightness: brightness,
          applicants: const [_acceptedApplicant],
          assignments: [assignmentFor(paymentStatus: 'HELD_IN_ESCROW')],
        );

        expect(_chatButton, findsNothing);
        expect(
          find.text('Ödemeyi tamamlayınca ekip sohbeti açılır.'),
          findsOneWidget,
        );
        // Para emanette: ödenecek bir şey yok, kısayol da yok.
        expect(_payShortcut, findsNothing);
      });

      // Ataması olmayan başvuranla mesajlaşma yolu yok; "ödemeyi
      // tamamlayınca açılır" demek ödenecek bir şey varmış gibi olurdu.
      testWidgets('bekleyen başvuranda ne düğme ne not', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          applicants: const [_pendingApplicant],
          assignments: const [],
        );

        expect(find.text('Mehmet Kaya'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('applicant-chat-worker-2')),
          findsNothing,
        );
        expect(find.text('Mesaj Gönder'), findsNothing);
        expect(
          find.text('Ödemeyi tamamlayınca ekip sohbeti açılır.'),
          findsNothing,
        );
        expect(find.byType(MessagingGateNote), findsNothing);
      });

      testWidgets('geri çeken başvuranda ne düğme ne not', (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          applicants: const [_withdrawnApplicant],
          assignments: const [],
        );

        expect(find.text('Zeynep Demir'), findsOneWidget);
        expect(find.text('Geri Çekildi'), findsOneWidget);
        expect(find.byType(MessagingGateNote), findsNothing);
        expect(find.text('Mesaj Gönder'), findsNothing);
      });

      testWidgets(
        'kabul edilmiş ve ödenmemiş atama: not + Ödemeye Git; geri çeken '
        'kartta hiçbiri',
        (tester) async {
          await pumpPage(
            tester,
            brightness: brightness,
            applicants: const [_acceptedApplicant, _withdrawnApplicant],
            assignments: [
              assignmentFor(
                paymentStatus: 'PENDING_COLLECTION',
                messagingAvailable: false,
                messagingAvailableReason: 'PAYMENT_REQUIRED',
              ),
            ],
          );

          expect(find.byType(MessagingGateNote), findsOneWidget);
          expect(_chatNote, findsOneWidget);
          expect(_payShortcut, findsOneWidget);
          expect(
            find.byKey(const ValueKey('applicant-chat-note-worker-3')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('applicant-pay-worker-3')),
            findsNothing,
          );
        },
      );
    });
  }

  testWidgets('ödeme kısayolu ödeme onayını açar', (tester) async {
    await pumpPage(
      tester,
      applicants: const [_acceptedApplicant],
      assignments: [
        assignmentFor(
          paymentStatus: 'PENDING_COLLECTION',
          messagingAvailable: false,
          messagingAvailableReason: 'PAYMENT_REQUIRED',
        ),
      ],
    );

    await tester.ensureVisible(_payShortcut);
    await tester.tap(_payShortcut);
    // Onay kutusu açıkken ödeme düğmesindeki bekleme halkası dönüyor;
    // `pumpAndSettle` hiç bitmez.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ödemeyi Onayla'), findsOneWidget);
  });

  // Düğme görünürken sunucu 403 derse: aynı cümle, çökme yok, atama yenilenir.
  testWidgets('403 MESSAGING_PAYMENT_REQUIRED metni gösterir ve atamayı '
      'yeniler', (tester) async {
    var assignmentFetches = 0;
    final harness = await pumpPage(
      tester,
      currentUser: _employer,
      applicants: const [_acceptedApplicant],
      employerHandler: (request) {
        if (request.method == 'GET') assignmentFetches++;
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                assignmentFor(
                  paymentStatus: 'HELD_IN_ESCROW',
                  messagingAvailable: true,
                  messagingAvailableReason: 'AVAILABLE',
                ),
              ],
            },
          },
        );
      },
      chatHandler: (_) => const FakeApiResponse(
        statusCode: 403,
        body: {
          'success': false,
          'message': 'Mesajlaşma, işveren ödemeyi tamamladığında açılır.',
          'errorCode': 'MESSAGING_PAYMENT_REQUIRED',
          'errorCategory': 'ACCESS_DENIED',
        },
      ),
    );
    final fetchesBefore = assignmentFetches;
    expect(fetchesBefore, greaterThan(0));

    await tester.ensureVisible(_chatButton);
    await tester.tap(_chatButton);
    await tester.pumpAndSettle();

    expect(
      harness.chatApi.requests.map((r) => r.path),
      contains('/jobs/job-1/conversation'),
    );
    expect(
      find.text('Ödemeyi tamamlayınca ekip sohbeti açılır.'),
      findsWidgets,
    );
    expect(assignmentFetches, greaterThan(fetchesBefore));
  });

  testWidgets('409 MESSAGING_WINDOW_CLOSED "Bu sohbet kapandı" der', (
    tester,
  ) async {
    await pumpPage(
      tester,
      currentUser: _employer,
      applicants: const [_acceptedApplicant],
      assignments: [
        assignmentFor(
          paymentStatus: 'HELD_IN_ESCROW',
          messagingAvailable: true,
          messagingAvailableReason: 'AVAILABLE',
        ),
      ],
      chatHandler: (_) => const FakeApiResponse(
        statusCode: 409,
        body: {
          'success': false,
          'message': 'Bu iş için mesajlaşma süresi doldu.',
          'errorCode': 'MESSAGING_WINDOW_CLOSED',
          'errorCategory': 'DATA_CONFLICT',
        },
      ),
    );

    await tester.ensureVisible(_chatButton);
    await tester.tap(_chatButton);
    await tester.pumpAndSettle();

    expect(find.text('Bu sohbet kapandı'), findsOneWidget);
    expect(find.text('Bu iş için mesajlaşma süresi doldu.'), findsNothing);
  });
}
