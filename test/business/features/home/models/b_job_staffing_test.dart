import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/b_job_staffing.dart';

void main() {
  group('BJobStaffing', () {
    test('kontenjan ve dolan sayısını okur', () {
      final staffing = BJobStaffing.fromJson(const {
        'headcount': 3,
        'hiredCount': 2,
      });

      expect(staffing.isKnown, isTrue);
      expect(staffing.isFull, isFalse);
      expect(staffing.label, '2/3 dolu');
    });

    test('kontenjan dolunca isFull', () {
      final staffing = BJobStaffing.fromJson(const {
        'headcount': 2,
        'hiredCount': 2,
      });

      expect(staffing.isFull, isTrue);
      expect(staffing.label, '2/2 dolu');
    });

    // Alanı göndermeyen sunucuda kontenjan bilinmiyor; kart "0/— dolu"
    // yazmamalı ve dolu olmayan ilanı dolu göstermemeli.
    test('alanlar yokken bilinmiyor sayılır', () {
      final staffing = BJobStaffing.fromJson(const {});

      expect(staffing.isKnown, isFalse);
      expect(staffing.isFull, isFalse);
      expect(staffing.label, isNull);
      expect(staffing.hiredCount, 0);
    });
  });

  group('BJobListPage', () {
    test('ilan özetini ve kontenjanı aynı satırdan okur', () {
      final page = BJobListPage.fromJson(const {
        'content': [
          {
            'id': 'job-1',
            'title': 'Garson',
            'salary': 800,
            'status': 'OPEN',
            'headcount': 4,
            'hiredCount': 1,
            'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garson'},
          },
        ],
        'page': 0,
        'totalElements': 1,
        'last': true,
      });

      final entry = page.entries.single;
      expect(entry.job.id, 'job-1');
      expect(entry.staffing.label, '1/4 dolu');
      expect(page.jobs.single.id, 'job-1');
      expect(page.last, isTrue);
    });
  });
}
