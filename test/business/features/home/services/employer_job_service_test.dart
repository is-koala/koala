import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/create_job_request.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/models/canonical_address.dart';

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
    salary: '1500',
    startDateTime: DateTime(2026, 9, 1, 9),
    endDateTime: DateTime(2026, 9, 1, 18),
    minAge: 18,
    maxAge: 40,
    experienceRequired: false,
    insuranceRequired: true,
    address: const AddressWrite(
      countryId: 'country-1',
      cityId: 'city-1',
      districtId: 'district-1',
      components: AddressComponents(
        neighborhood: 'Kızılay Mahallesi',
        thoroughfare: 'Atatürk Bulvarı',
        buildingNumber: '1',
        postalCode: '06420',
      ),
      position: AddressPosition(
        latitude: 39.92,
        longitude: 32.85,
        source: AddressPositionSource.userConfirmedPin,
      ),
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
            .having((e) => e.type, 'type', ApiErrorType.dataConflict)
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

  group('EmployerJobService atama', () {
    test(
      'ödeme oturumu yalnız checkout adresini istemci modeline alır',
      () async {
        final api = FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'paymentPageUrl':
                    'https://sandbox-cpp.iyzipay.com?token=token&lang=tr',
                'token': 'iyzi-token',
              },
            },
          ),
        );

        final session = await EmployerJobService.withClient(
          api.client,
        ).createPaymentSession('asg_1');

        expect(
          api.requests.single.path,
          '/job-assignments/asg_1/payment-session',
        );
        expect(session.paymentPageUrl.host, 'sandbox-cpp.iyzipay.com');
      },
    );

    // Aynı uç iki tarafa hizmet ediyor; işveren tarafını ayıran bayrak bu.
    test('atamalar asEmployer bayrağıyla çekilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {
                  'id': 'asg_1',
                  'status': 'IN_PROGRESS',
                  'paymentStatus': 'HELD_IN_ESCROW',
                  'job': {
                    'id': 'job_1',
                    'title': 'Garson',
                    'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garson'},
                    'salary': 1500,
                  },
                },
              ],
              'last': true,
            },
          },
        ),
      );

      final page = await EmployerJobService.withClient(
        api.client,
      ).fetchMyAssignments();

      final request = api.requests.single;
      expect(request.path, '/users/me/assignments');
      expect(request.queryParameters['asEmployer'], isTrue);
      expect(page.assignments.single.job.id, 'job_1');
    });

    test('tamamlama doğru yola gider', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'asg_1',
              'status': 'COMPLETED',
              'paymentStatus': 'HELD_IN_ESCROW',
              'job': {
                'id': 'job_1',
                'title': 'Garson',
                'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garson'},
                'salary': 1500,
              },
            },
          },
        ),
      );

      final assignment = await EmployerJobService.withClient(
        api.client,
      ).completeAssignment('asg_1');

      expect(api.requests.single.path, '/job-assignments/asg_1/complete');
      expect(api.requests.single.method, 'POST');
      expect(assignment.status, AssignmentStatus.completed);
    });

    Map<String, Object?> assignmentJson({
      required String id,
      required String jobId,
      String workerName = 'Ayşe',
      Map<String, Object?> extra = const {},
    }) => {
      'id': id,
      'status': 'CONFIRMED',
      'paymentStatus': 'PENDING_COLLECTION',
      'worker': {
        'id': 'worker-$id',
        'firstName': workerName,
        'lastName': 'Çalışan',
      },
      'job': {
        'id': jobId,
        'title': 'Garson',
        'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garson'},
        'salary': 1500,
      },
      ...extra,
    };

    test(
      'bir ilanın atamalarını ilan başına uçtan tüm sayfalarıyla toplar',
      () async {
        final api = FakeApi(
          handler: (request) {
            final page = request.queryParameters['page'];
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [
                    assignmentJson(id: 'target-$page', jobId: 'job_1'),
                  ],
                  'page': page,
                  'last': page == 1,
                },
              },
            );
          },
        );

        final assignments = await EmployerJobService.withClient(
          api.client,
        ).fetchAssignmentsForJob('job_1');

        expect(assignments.map((assignment) => assignment.id), [
          'target-0',
          'target-1',
        ]);
        expect(assignments.first.worker?.fullName, 'Ayşe Çalışan');
        expect(api.requests.map((request) => request.path), [
          '/jobs/job_1/assignments',
          '/jobs/job_1/assignments',
        ]);
        expect(api.requests.map((request) => request.queryParameters['page']), [
          0,
          1,
        ]);
        // İlan başına uç zaten süzülmüş döndürüyor; asEmployer bayrağı yok.
        expect(
          api.requests.first.queryParameters.containsKey('asEmployer'),
          isFalse,
        );
      },
    );

    test('zaman çizelgesi damgalarını atamayla birlikte okur', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                assignmentJson(
                  id: 'asg_1',
                  jobId: 'job_1',
                  extra: {
                    'application': {
                      'id': 'app_1',
                      'applicationDateTime': '2026-09-10T08:00:00Z',
                      'answeredDateTime': '2026-09-10T09:30:00Z',
                    },
                    'createdAt': '2026-09-10T09:30:01Z',
                    'confirmedAt': '2026-09-10T10:00:00Z',
                    'paymentSecuredAt': '2026-09-10T11:00:00Z',
                    'expectedCompletionDateTime': '2026-09-12T18:00:00Z',
                    'payout': {
                      'id': 'payout_1',
                      'status': 'COMPLETED',
                      'completedAt': '2026-09-13T12:00:00Z',
                    },
                  },
                ),
              ],
              'last': true,
            },
          },
        ),
      );

      final assignment = await EmployerJobService.withClient(
        api.client,
      ).fetchAssignmentsForJob('job_1').then((list) => list.single);

      expect(
        assignment.application?.applicationDateTime,
        DateTime.utc(2026, 9, 10, 8),
      );
      expect(
        assignment.application?.answeredDateTime,
        DateTime.utc(2026, 9, 10, 9, 30),
      );
      expect(assignment.confirmedAt, DateTime.utc(2026, 9, 10, 10));
      expect(assignment.paymentSecuredAt, DateTime.utc(2026, 9, 10, 11));
      expect(assignment.payout?.completedAt, DateTime.utc(2026, 9, 13, 12));
    });

    // Eski sunucu ilan başına ucu tanımıyor; o zaman işverenin bütün
    // atamaları taranıp ilana göre süzülüyor — bu ucun gelmesinden önceki yol.
    test(
      'ucu tanımayan sunucuda işveren atamalarını tarayıp ilana göre süzer',
      () async {
        final api = FakeApi(
          handler: (request) {
            if (request.path == '/jobs/job_1/assignments') {
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
            final page = request.queryParameters['page'];
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [
                    assignmentJson(
                      id: page == 0 ? 'other-assignment' : 'target-$page',
                      jobId: page == 0 ? 'other-job' : 'job_1',
                      workerName: page == 0 ? 'Başka' : 'Ayşe',
                    ),
                  ],
                  'page': page,
                  'last': page == 1,
                },
              },
            );
          },
        );

        final assignments = await EmployerJobService.withClient(
          api.client,
        ).fetchAssignmentsForJob('job_1');

        expect(assignments.map((assignment) => assignment.id), ['target-1']);
        expect(assignments.single.worker?.fullName, 'Ayşe Çalışan');
        expect(api.requests.map((request) => request.path), [
          '/jobs/job_1/assignments',
          '/users/me/assignments',
          '/users/me/assignments',
        ]);
        expect(api.requests[1].queryParameters['asEmployer'], isTrue);
        expect(api.requests.skip(1).map((r) => r.queryParameters['page']), [
          0,
          1,
        ]);
      },
    );

    // Aynı 404, farklı anlam: uç var ama ilan bu işverenin değil ya da yok.
    // Tarama da bir şey bulmazdı; hata gizlenmeden yükseliyor.
    test('JOB_NOT_FOUND yanıtında taramaya düşmez, hatayı yükseltir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'message': 'İlan bulunamadı.',
            'errorCode': 'JOB_NOT_FOUND',
            'errorCategory': 'RESOURCE_NOT_FOUND',
          },
        ),
      );

      await expectLater(
        EmployerJobService.withClient(
          api.client,
        ).fetchAssignmentsForJob('job_1'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.errorCode,
            'errorCode',
            'JOB_NOT_FOUND',
          ),
        ),
      );
      expect(api.requests.map((request) => request.path), [
        '/jobs/job_1/assignments',
      ]);
    });

    // Sunucu yalnızca CONFIRMED ve IN_PROGRESS durumlarından tamamlatıyor.
    test('tamamlanamayan durumda 409 yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {'success': false, 'message': 'Atama bu durumdan tamamlanamaz'},
        ),
      );

      await expectLater(
        EmployerJobService.withClient(api.client).completeAssignment('asg_1'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.dataConflict,
          ),
        ),
      );
    });
  });
}
