import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/extensions/date_extensions.dart';

import '../../../../../support/fake_api.dart';
import 'b_job_detail_test_harness.dart';

const _worker = {'id': 'worker-1', 'firstName': 'Ayşe', 'lastName': 'Yılmaz'};

final Map<String, Object?> _timelineAssignment = {
  ...assignmentJson,
  'status': 'COMPLETED',
  'paymentStatus': 'HELD_IN_ESCROW',
  'worker': _worker,
  'actualCompletionDateTime': '2026-09-10T17:05:00Z',
  'application': {
    'id': 'application-1',
    'applicationDateTime': '2026-09-08T10:00:00Z',
    'answeredDateTime': '2026-09-09T12:00:00Z',
  },
  'confirmedAt': '2026-09-09T13:00:00Z',
  'paymentSecuredAt': '2026-09-09T14:00:00Z',
};

const _acceptedApplicant = {
  'id': 'application-1',
  'status': 'ACCEPTED',
  'applicationDateTime': '2026-09-08T10:00:00Z',
  'answeredDateTime': '2026-09-09T12:00:00Z',
  'assignmentId': 'assignment-1',
  'cvUrl': 'https://api.example/files/cv-1',
  'applicant': _worker,
};

String _local(String iso) => DateTime.parse(iso).toLocal().asShortDateTime;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'atama panelinde başvuru, kabul, ödeme ve tamamlanma satırını çizer '
      '(${brightness.name})',
      (tester) async {
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [_timelineAssignment],
        );

        final row = find.byKey(const ValueKey('assignment-timeline'));
        expect(row, findsOneWidget);
        final text = tester.widget<Text>(row).data!;
        expect(text, contains('Başvuru: ${_local('2026-09-08T10:00:00Z')}'));
        expect(text, contains('Kabul: ${_local('2026-09-09T12:00:00Z')}'));
        expect(
          text,
          contains(
            'Ödeme: Emanette (emanete alındı: '
            '${_local('2026-09-09T14:00:00Z')})',
          ),
        );
        expect(text, contains('Tamamlandı: ${_local('2026-09-10T17:05:00Z')}'));
      },
    );
  }

  // Bu alanları göndermeyen sunucuda satır yine var: hangi bilginin
  // beklendiği okunuyor, değer yerine "—".
  testWidgets('damga göndermeyen sunucuda satırı tire ile çizer', (
    tester,
  ) async {
    await pumpPage(tester);

    final row = find.byKey(const ValueKey('assignment-timeline'));
    final text = tester.widget<Text>(row).data!;
    expect(
      text,
      'Başvuru: — · Kabul: — · Ödeme: Tahsilat Bekleniyor · Tamamlandı: —',
    );
  });

  testWidgets('para çalışana geçtiyse hesaba geçme anını yazar', (
    tester,
  ) async {
    await pumpPage(
      tester,
      assignments: [
        {
          ..._timelineAssignment,
          'paymentStatus': 'RELEASED_TO_WORKER',
          'payout': {
            'id': 'payout-1',
            'status': 'COMPLETED',
            'completedAt': '2026-09-12T09:00:00Z',
          },
        },
      ],
    );

    final row = find.byKey(const ValueKey('assignment-timeline'));
    final text = tester.widget<Text>(row).data!;
    expect(
      text,
      contains(
        'Ödeme: Ödendi (hesaba geçti: ${_local('2026-09-12T09:00:00Z')})',
      ),
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'aday kartında yanıt tarihi ve özgeçmiş bağlantısı (${brightness.name})',
      (tester) async {
        final opened = <Uri>[];
        await pumpPage(
          tester,
          brightness: brightness,
          assignments: [_timelineAssignment],
          applicants: const [_acceptedApplicant],
          openExternalUrl: (url) async {
            opened.add(url);
            return true;
          },
        );

        final answered = find.byKey(
          const ValueKey('applicant-answered-application-1'),
        );
        expect(answered, findsOneWidget);
        expect(
          tester.widget<Text>(answered).data,
          'Kabul: ${DateTime.parse('2026-09-09T12:00:00Z').toLocal().asShortDate}',
        );

        final cv = find.byKey(const ValueKey('applicant-cv-application-1'));
        await tester.ensureVisible(cv);
        await tester.tap(cv);
        await tester.pump();

        expect(opened, [Uri.parse('https://api.example/files/cv-1')]);
      },
    );
  }

  // Özgeçmişi olmayan ya da yanıtı gelmemiş adayda ne bağlantı ne tarih
  // satırı çizilir; boş bir düğme adayın özgeçmişi varmış gibi olurdu.
  testWidgets('özgeçmişsiz ve yanıtsız başvuruda satırlar çizilmez', (
    tester,
  ) async {
    await pumpPage(
      tester,
      assignments: const [],
      applicants: const [
        {
          'id': 'application-2',
          'status': 'APPLIED',
          'applicationDateTime': '2026-09-08T10:00:00Z',
          'applicant': _worker,
        },
      ],
    );

    expect(
      find.byKey(const ValueKey('applicant-answered-application-2')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('applicant-cv-application-2')),
      findsNothing,
    );
  });

  testWidgets('özgeçmiş açılamazsa kullanıcıya söyler', (tester) async {
    await pumpPage(
      tester,
      assignments: [_timelineAssignment],
      applicants: const [_acceptedApplicant],
      openExternalUrl: (_) async => false,
    );

    final cv = find.byKey(const ValueKey('applicant-cv-application-1'));
    await tester.ensureVisible(cv);
    await tester.tap(cv);
    await tester.pump();

    expect(find.text('Özgeçmiş açılamadı'), findsOneWidget);
  });

  testWidgets('ilan başına atama ucunu kullanır', (tester) async {
    final harness = await pumpPage(tester);

    expect(
      harness.employerApi.requests.map((request) => request.path),
      contains('/jobs/job-1/assignments'),
    );
    expect(
      harness.employerApi.requests.map((request) => request.path),
      isNot(contains('/users/me/assignments')),
    );
  });

  // Ucu tanımayan eski sunucuda panel yine doluyor: tarama yoluna düşülüyor.
  testWidgets('ucu tanımayan sunucuda taramaya düşer ve paneli çizer', (
    tester,
  ) async {
    final harness = await pumpPage(
      tester,
      employerHandler: (request) {
        if (request.path == '/jobs/job-1/assignments') {
          return const FakeApiResponse(
            statusCode: 404,
            body: {
              'success': false,
              'message': 'Uç bulunamadı.',
              'errorCode': 'ENDPOINT_NOT_FOUND',
              'errorCategory': 'ENDPOINT_NOT_FOUND',
            },
          );
        }
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [assignmentJson],
            },
          },
        );
      },
    );

    expect(find.text('İş Takibi'), findsOneWidget);
    expect(find.byKey(const ValueKey('assignment-timeline')), findsOneWidget);
    expect(find.byKey(const ValueKey('assignment-load-error')), findsNothing);
    expect(
      harness.employerApi.requests.map((request) => request.path).toList(),
      containsAllInOrder(['/jobs/job-1/assignments', '/users/me/assignments']),
    );
  });
}
