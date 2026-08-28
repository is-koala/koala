import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/create_job_request.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

/// İlan açma isteklerinde kullanılan hazır gövde.
CreateJobRequest buildRequest() {
  return CreateJobRequest(
    categoryId: 'cat_1',
    title: 'Garson',
    description: 'Hafta sonu garson aranıyor.',
    position: 'Garson',
    type: JobType.oneTime,
    salaryType: SalaryType.daily,
    salary: 1500,
    startDateTime: DateTime(2026, 9, 1, 9),
    endDateTime: DateTime(2026, 9, 1, 18),
    minAge: 18,
    maxAge: 40,
    experienceRequired: false,
    insuranceRequired: true,
    address: const CreateJobAddress(
      countryCode: 'TR',
      cityName: 'Ankara',
      districtName: 'Çankaya',
      addressLine: 'Kızılay Meydanı 1',
      latitude: 39.92,
      longitude: 32.85,
    ),
  );
}

void main() {
  group('fetchMyJobs', () {
    test('kendi ilanları sayfalı olarak çekiliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {
                  'id': 'job_1',
                  'title': 'Garson',
                  'salary': 800,
                  'status': 'OPEN',
                  'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garson'},
                },
              ],
              'totalElements': 1,
              'last': true,
            },
          },
        ),
      );

      final page = await EmployerJobService.withClient(
        api.client,
      ).fetchMyJobs();

      expect(api.requests.single.path, '/users/me/jobs');
      expect(page.jobs.single.id, 'job_1');
    });
  });

  group('createJob', () {
    test('şirket kimliği verilince kurumsal uca gidiyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {
              'id': 'job_9',
              'title': 'Garson',
              'salary': 1500,
              'status': 'OPEN',
              'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garson'},
            },
          },
        ),
      );

      final detail = await EmployerJobService.withClient(
        api.client,
      ).createJob(buildRequest(), companyId: 'company_1');

      final request = api.requests.single;
      expect(request.path, '/companies/company_1/jobs');
      // Sigorta alanı yalnızca kurumsal uçta var.
      expect((request.data as Map)['insuranceRequired'], isTrue);
      expect(detail.id, 'job_9');
    });

    test(
      'şirket yoksa bireysel uca gidiyor ve sigorta gönderilmiyor',
      () async {
        final api = FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 201,
            body: {
              'success': true,
              'data': {
                'id': 'job_9',
                'title': 'Garson',
                'salary': 1500,
                'status': 'OPEN',
                'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garson'},
              },
            },
          ),
        );

        await EmployerJobService.withClient(
          api.client,
        ).createJob(buildRequest());

        final request = api.requests.single;
        expect(request.path, '/users/me/jobs');
        expect((request.data as Map).containsKey('insuranceRequired'), isFalse);
      },
    );
  });

  test('cancelJob iptal ucuna gidiyor', () async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );

    await EmployerJobService.withClient(api.client).cancelJob('job_1');

    expect(api.requests.single.path, '/jobs/job_1/cancel');
    expect(api.requests.single.method, 'POST');
  });

  test('devam eden atama varsa iptal hatası taşınıyor', () async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 409,
        body: {'success': false, 'message': 'İlanın devam eden bir işi var'},
      ),
    );

    await expectLater(
      EmployerJobService.withClient(api.client).cancelJob('job_1'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.conflict)
            .having(
              (e) => e.message,
              'message',
              'İlanın devam eden bir işi var',
            ),
      ),
    );
  });

  test('closeJob ilanı kapatma ucuna gidiyor', () async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );

    await EmployerJobService.withClient(api.client).closeJob('job_1');

    expect(api.requests.single.path, '/jobs/job_1/close');
    expect(api.requests.single.method, 'POST');
  });

  group('başvurular', () {
    test('ilanın başvuranları modele çevriliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'app_1',
                'status': 'APPLIED',
                'applicationDateTime': '2026-08-01T10:00:00Z',
                'notes': 'Deneyimliyim',
                'applicant': {
                  'id': 'user_1',
                  'firstName': 'Ayşe',
                  'lastName': 'Yılmaz',
                },
              },
            ],
          },
        ),
      );

      final applicants = await EmployerJobService.withClient(
        api.client,
      ).fetchApplicants('job_1');

      expect(api.requests.single.path, '/jobs/job_1/applications');
      expect(applicants.single.fullName, 'Ayşe Yılmaz');
      expect(applicants.single.isPending, isTrue);
      expect(applicants.single.notes, 'Deneyimliyim');
    });

    test('kabul isteği ACCEPTED gönderiyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await EmployerJobService.withClient(
        api.client,
      ).acceptApplication('app_1');

      final request = api.requests.single;
      expect(request.path, '/job-applications/app_1/respond');
      expect((request.data as Map)['status'], ApplicationStatus.accepted.code);
    });

    test('ret isteği gerekçeyi taşıyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await EmployerJobService.withClient(
        api.client,
      ).rejectApplication('app_1', reason: 'Deneyim yetersiz');

      final body = api.requests.single.data as Map;
      expect(body['status'], ApplicationStatus.rejected.code);
      expect(body['rejectionReason'], 'Deneyim yetersiz');
    });

    test('gerekçe verilmezse alan hiç gönderilmiyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await EmployerJobService.withClient(
        api.client,
      ).rejectApplication('app_1');

      final body = api.requests.single.data as Map;
      expect(body.containsKey('rejectionReason'), isFalse);
    });
  });
}
