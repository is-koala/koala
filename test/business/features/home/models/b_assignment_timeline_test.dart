import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/b_assignment_timeline.dart';

void main() {
  const base = {
    'id': 'asg-1',
    'status': 'COMPLETED',
    'paymentStatus': 'RELEASED_TO_WORKER',
    'job': {
      'id': 'job-1',
      'title': 'Garson',
      'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garson'},
      'salary': 1500,
    },
  };

  group('BAssignmentTimeline', () {
    test('koala-backend#282 damgalarını okur', () {
      final entry = BEmployerAssignment.fromJson({
        ...base,
        'application': {
          'id': 'app-1',
          'applicationDateTime': '2026-09-10T08:00:00Z',
          'answeredDateTime': '2026-09-10T09:30:00Z',
        },
        'createdAt': '2026-09-10T09:30:01Z',
        'confirmedAt': '2026-09-10T10:00:00Z',
        'paymentSecuredAt': '2026-09-10T11:00:00Z',
        'expectedCompletionDateTime': '2026-09-12T18:00:00Z',
        'payout': {
          'id': 'payout-1',
          'status': 'COMPLETED',
          'completedAt': '2026-09-13T12:00:00Z',
        },
      });

      expect(entry.assignment.id, 'asg-1');
      final timeline = entry.timeline;
      expect(timeline.appliedAt, DateTime.utc(2026, 9, 10, 8));
      expect(timeline.acceptedAt, DateTime.utc(2026, 9, 10, 9, 30));
      expect(timeline.createdAt, DateTime.utc(2026, 9, 10, 9, 30, 1));
      expect(timeline.confirmedAt, DateTime.utc(2026, 9, 10, 10));
      expect(timeline.paymentSecuredAt, DateTime.utc(2026, 9, 10, 11));
      expect(timeline.expectedCompletionAt, DateTime.utc(2026, 9, 12, 18));
      expect(timeline.payout?.id, 'payout-1');
      expect(timeline.payout?.status, 'COMPLETED');
      expect(timeline.payout?.completedAt, DateTime.utc(2026, 9, 13, 12));
    });

    // Eski sunucu bu alanları göndermiyor; atama yine okunmalı, damgalar boş.
    test('alanlar yokken boş kalır, atama yine okunur', () {
      final entry = BEmployerAssignment.fromJson(base);

      expect(entry.assignment.id, 'asg-1');
      expect(entry.timeline.appliedAt, isNull);
      expect(entry.timeline.acceptedAt, isNull);
      expect(entry.timeline.confirmedAt, isNull);
      expect(entry.timeline.paymentSecuredAt, isNull);
      expect(entry.timeline.payout, isNull);
    });

    test('application ve payout açıkça null gelince de boş kalır', () {
      final entry = BEmployerAssignment.fromJson({
        ...base,
        'application': null,
        'confirmedAt': null,
        'paymentSecuredAt': null,
        'payout': null,
      });

      expect(entry.timeline.appliedAt, isNull);
      expect(entry.timeline.payout, isNull);
    });
  });

  group('BEmployerAssignmentPage', () {
    test('sayfayı ve içeriği okur', () {
      final page = BEmployerAssignmentPage.fromJson({
        'content': [base],
        'page': 2,
        'totalElements': 41,
        'last': false,
      });

      expect(page.entries.single.assignment.id, 'asg-1');
      expect(page.page, 2);
      expect(page.totalElements, 41);
      expect(page.last, isFalse);
    });

    test('içerik yoksa boş ve son sayfa sayılır', () {
      final page = BEmployerAssignmentPage.fromJson(const {});

      expect(page.entries, isEmpty);
      expect(page.last, isTrue);
    });
  });
}
