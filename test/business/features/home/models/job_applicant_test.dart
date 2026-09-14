import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

void main() {
  const base = {
    'id': 'app-1',
    'status': 'ACCEPTED',
    'applicationDateTime': '2026-09-08T10:00:00Z',
    'applicant': {'id': 'worker-1', 'firstName': 'Ayşe', 'lastName': 'Yılmaz'},
    'cvUrl': 'https://api.example/files/cv-1',
  };

  group('JobApplicant', () {
    test('koala-backend#282 alanlarını okur', () {
      final applicant = JobApplicant.fromJson(const {
        ...base,
        'answeredDateTime': '2026-09-09T12:00:00Z',
        'assignmentId': 'asg-1',
      });

      expect(applicant.status, ApplicationStatus.accepted);
      expect(applicant.answeredDateTime, DateTime.utc(2026, 9, 9, 12));
      expect(applicant.assignmentId, 'asg-1');
      expect(applicant.hasCv, isTrue);
    });

    test('reddedilmiş başvuruda atama kimliği yok', () {
      final applicant = JobApplicant.fromJson({
        ...base,
        'status': 'REJECTED',
        'answeredDateTime': '2026-09-09T12:00:00Z',
        'assignmentId': null,
      });

      expect(applicant.answeredDateTime, DateTime.utc(2026, 9, 9, 12));
      expect(applicant.assignmentId, isNull);
    });

    // Eski sunucu alanları göndermiyor; kart yanıt satırını çizmiyor.
    test('alanlar yokken null kalır', () {
      final applicant = JobApplicant.fromJson(const {...base});

      expect(applicant.answeredDateTime, isNull);
      expect(applicant.assignmentId, isNull);
    });

    test('boş özgeçmiş adresi yok sayılır', () {
      final applicant = JobApplicant.fromJson({...base, 'cvUrl': ''});

      expect(applicant.hasCv, isFalse);
    });
  });
}
