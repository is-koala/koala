import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/received_application.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

/// `ReceivedApplicationDto` — koala-backend#233, canlı OpenAPI'deki alanlar.
const _dto = {
  'id': 'app-1',
  'status': 'APPLIED',
  'applicationDateTime': '2026-09-15T08:00:00Z',
  'answeredDateTime': null,
  'notes': 'Hafta sonu çalışabilirim',
  'applicant': {
    'id': 'worker-1',
    'firstName': 'Ayşe',
    'lastName': 'Yılmaz',
    'username': 'ayse',
    'profilePictureUrl': 'https://cdn.example/ayse.jpg',
  },
  'jobId': 'job-1',
  'postingTitle': 'Barista',
  'jobStatus': 'OPEN',
  'companyId': 'company-1',
  'companyName': 'Kahve Evi',
  'assignmentId': null,
};

void main() {
  group('ReceivedApplication.fromJson', () {
    test('bütün alanları okur', () {
      final application = ReceivedApplication.fromJson(_dto);

      expect(application.id, 'app-1');
      expect(application.status, ApplicationStatus.applied);
      expect(application.applicant.id, 'worker-1');
      expect(application.fullName, 'Ayşe Yılmaz');
      expect(application.applicant.profilePictureUrl, contains('ayse.jpg'));
      expect(application.jobId, 'job-1');
      expect(application.postingTitle, 'Barista');
      expect(application.jobStatus, JobStatus.open);
      expect(application.applicationDateTime, DateTime.utc(2026, 9, 15, 8));
      expect(application.answeredDateTime, isNull);
      expect(application.notes, 'Hafta sonu çalışabilirim');
      expect(application.companyId, 'company-1');
      expect(application.companyName, 'Kahve Evi');
      expect(application.assignmentId, isNull);
    });

    test('bireysel ilanda şirket alanları yok', () {
      final application = ReceivedApplication.fromJson({
        ..._dto,
        'companyId': null,
        'companyName': null,
      });

      expect(application.companyId, isNull);
      expect(application.companyName, isNull);
    });

    test('boş not ve boş şirket adı yok sayılır', () {
      final application = ReceivedApplication.fromJson({
        ..._dto,
        'notes': '   ',
        'companyName': '',
      });

      expect(application.notes, isNull);
      expect(application.companyName, isNull);
    });

    test('kabul edilmiş başvuru yanıt anını ve atamayı taşır', () {
      final application = ReceivedApplication.fromJson({
        ..._dto,
        'status': 'ACCEPTED',
        'answeredDateTime': '2026-09-16T09:30:00Z',
        'assignmentId': 'asg-1',
      });

      expect(application.status, ApplicationStatus.accepted);
      expect(application.answeredDateTime, DateTime.utc(2026, 9, 16, 9, 30));
      expect(application.assignmentId, 'asg-1');
    });

    // Backend enum'una yeni değer eklemek sürüm atlatmıyor: tanınmayan durum
    // kendi adıyla kalmalı, "bekliyor"a benzetilmemeli (ApplicationStatus).
    test('tanınmayan durum unknown olur, bekleyen sayılmaz', () {
      final application = ReceivedApplication.fromJson({
        ..._dto,
        'status': 'EXPIRED',
      });

      expect(application.status, ApplicationStatus.unknown);
      expect(application.status.isPending, isFalse);
    });

    test('ilan başlığı boşsa "İlan" yazar', () {
      final application = ReceivedApplication.fromJson({
        ..._dto,
        'postingTitle': '  ',
      });

      expect(application.postingTitle, 'İlan');
    });

    test('başvuran yoksa boş kimlik, ad kullanıcı adına düşer', () {
      final withoutApplicant = ReceivedApplication.fromJson({
        ..._dto,
        'applicant': null,
      });
      expect(withoutApplicant.applicant.id, '');
      expect(withoutApplicant.fullName, '');

      final withoutName = ReceivedApplication.fromJson({
        ..._dto,
        'applicant': {'id': 'worker-1', 'username': 'ayse'},
      });
      expect(withoutName.fullName, 'ayse');
    });

    test('kapalı ve iptal edilmiş ilan işaretlenir', () {
      expect(ReceivedApplication.fromJson(_dto).isJobClosed, isFalse);
      expect(
        ReceivedApplication.fromJson({
          ..._dto,
          'jobStatus': 'CLOSED',
        }).isJobClosed,
        isTrue,
      );
      expect(
        ReceivedApplication.fromJson({
          ..._dto,
          'jobStatus': 'CANCELLED',
        }).jobStatus,
        JobStatus.cancelled,
      );
    });

    test('tarihler çözümlenemezse null kalır, satır düşmez', () {
      final application = ReceivedApplication.fromJson({
        ..._dto,
        'applicationDateTime': 'dün',
      });

      expect(application.applicationDateTime, isNull);
    });
  });

  group('ReceivedApplication.toJobApplicant', () {
    // BUserProfilePage başvuranı JobApplicant olarak alıyor; kapak, ön yazı ve
    // tarih bununla çiziliyor.
    test('profil ekranının ihtiyaç duyduğu alanları taşır', () {
      final applicant = ReceivedApplication.fromJson({
        ..._dto,
        'status': 'ACCEPTED',
        'answeredDateTime': '2026-09-16T09:30:00Z',
        'assignmentId': 'asg-1',
      }).toJobApplicant();

      expect(applicant.id, 'app-1');
      expect(applicant.user.id, 'worker-1');
      expect(applicant.fullName, 'Ayşe Yılmaz');
      expect(applicant.status, ApplicationStatus.accepted);
      expect(applicant.notes, 'Hafta sonu çalışabilirim');
      expect(applicant.applicationDateTime, DateTime.utc(2026, 9, 15, 8));
      expect(applicant.answeredDateTime, DateTime.utc(2026, 9, 16, 9, 30));
      expect(applicant.assignmentId, 'asg-1');
      // Satır meslek ve özgeçmiş taşımıyor; profil bunları `GET /users/{id}`'den
      // dolduruyor.
      expect(applicant.jobTitle, isNull);
      expect(applicant.hasCv, isFalse);
    });
  });

  group('ReceivedApplicationPage.fromJson', () {
    test('sayfa üstverisini ve satırları okur', () {
      final page = ReceivedApplicationPage.fromJson(const {
        'content': [_dto],
        'page': 2,
        'size': 20,
        'totalElements': 41,
        'totalPages': 3,
        'first': false,
        'last': true,
      });

      expect(page.applications, hasLength(1));
      expect(page.page, 2);
      expect(page.size, 20);
      expect(page.totalElements, 41);
      expect(page.totalPages, 3);
      expect(page.first, isFalse);
      expect(page.last, isTrue);
    });

    test('içerik yoksa boş liste, son sayfa', () {
      final page = ReceivedApplicationPage.fromJson(const {});

      expect(page.applications, isEmpty);
      expect(page.last, isTrue);
    });

    test('nesne olmayan satırlar atlanır', () {
      final page = ReceivedApplicationPage.fromJson(const {
        'content': ['x', _dto, 3],
      });

      expect(page.applications, hasLength(1));
    });
  });
}
