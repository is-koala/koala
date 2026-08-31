import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/fixtures.dart';

Map<String, dynamic> applicationBody({
  String id = 'app_1',
  String jobId = 'job_1',
  String status = 'APPLIED',
  String? notes,
  String company = 'Koala Cafe',
  String? rejectionReason,
}) {
  return {
    'id': id,
    'status': status,
    'notes': notes,
    'rejectionReason': rejectionReason,
    'applicationDateTime': '2026-03-05T10:00:00Z',
    'job': {
      'id': jobId,
      'title': 'Deneyimli Barista',
      'position': 'Barista',
      'category': {'id': 'cat-1', 'code': 'BARISTA', 'name': 'Barista'},
      'type': 'ONE_TIME',
      'salary': 15000,
      'companyName': company,
    },
  };
}

ApplyProvider buildProvider(FakeApi api) {
  return ApplyProvider(service: JobApplicationService.withClient(api.client));
}

void main() {
  group('başlangıç', () {
    test('başvuru yok', () {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(statusCode: 200),
      );
      final provider = buildProvider(api);

      expect(provider.applications, isEmpty);
      expect(provider.appliedJobs, isEmpty);
      expect(provider.hasApplied('job_1'), isFalse);
    });
  });

  group('ApplyProvider.load', () {
    test('başvurular çekilir ve MyJob\'a çevrilir', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [applicationBody()],
              'last': true,
            },
          },
        ),
      );
      final provider = buildProvider(api);

      await provider.load();

      expect(api.requests.single.path, '/users/me/applications');
      expect(provider.hasApplied('job_1'), isTrue);

      final myJob = provider.appliedJobs.single;
      expect(myJob.title, 'Deneyimli Barista');
      expect(myJob.company, 'Koala Cafe');
      expect(myJob.description, 'Barista');
      expect(myJob.price, 15000);
      expect(myJob.date, '05.03.2026');
    });

    test('bireysel ilanda şirket yerine yer tutucu yazılır', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {
                  ...applicationBody(),
                  'job': {
                    'id': 'job_1',
                    'title': 'Garson',
                    'category': {
                      'id': 'c',
                      'code': 'WAITER',
                      'name': 'Garsonluk',
                    },
                    'salary': 500,
                  },
                },
              ],
            },
          },
        ),
      );
      final provider = buildProvider(api);

      await provider.load();

      expect(provider.appliedJobs.single.company, 'Bireysel İlan');
    });

    test('ikinci çağrı ağa çıkmaz, force ile çıkar', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );
      final provider = buildProvider(api);

      await provider.load();
      await provider.load();
      expect(api.requests, hasLength(1));

      await provider.load(force: true);
      expect(api.requests, hasLength(2));
    });

    test('hata mesajı saklanır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      );
      final provider = buildProvider(api);

      await provider.load();

      expect(provider.errorMessage, 'Sunucu hatası');
      expect(provider.applications, isEmpty);
    });
  });

  group('ApplyProvider.applyToJob', () {
    test('ön yazı gövdeye konur ve başvuru listeye eklenir', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': applicationBody(notes: 'Merhaba'),
          },
        ),
      );
      final provider = buildProvider(api);

      final ok = await provider.applyToJob(
        buildJob(id: 'job_1'),
        coverLetter: 'Merhaba',
      );

      expect(ok, isTrue);
      expect(api.requests.single.path, '/jobs/job_1/applications');
      expect(api.requests.single.data, {'notes': 'Merhaba'});
      expect(provider.hasApplied('job_1'), isTrue);
    });

    test('ön yazı yoksa gövde boş gider', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 201,
          body: {'success': true, 'data': applicationBody()},
        ),
      );
      final provider = buildProvider(api);

      await provider.applyToJob(buildJob(id: 'job_1'));

      expect(api.requests.single.data, isEmpty);
    });

    test('sunucu reddederse false döner ve liste değişmez', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {'success': false, 'message': 'Bu ilana zaten başvurdunuz'},
        ),
      );
      final provider = buildProvider(api);

      final ok = await provider.applyToJob(buildJob(id: 'job_1'));

      expect(ok, isFalse);
      expect(provider.errorMessage, 'Bu ilana zaten başvurdunuz');
      expect(provider.applications, isEmpty);
    });

    // Aynı ilana ikinci kez basılırsa istek hiç atılmamalı: sunucu zaten
    // reddediyor ama boşuna gidip gelmenin anlamı yok.
    test('zaten başvurulmuş ilana istek atılmaz', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 201,
          body: {'success': true, 'data': applicationBody()},
        ),
      );
      final provider = buildProvider(api);

      await provider.applyToJob(buildJob(id: 'job_1'));
      final ok = await provider.applyToJob(buildJob(id: 'job_1'));

      expect(ok, isFalse);
      expect(api.requests, hasLength(1));
    });
  });

  group('ApplyProvider.clear', () {
    test('çıkışta başvurular düşer', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [applicationBody()],
            },
          },
        ),
      );
      final provider = buildProvider(api);
      await provider.load();

      provider.clear();

      expect(provider.applications, isEmpty);
      expect(provider.hasLoaded, isFalse);
    });
  });

  group('ApplicationStatus', () {
    test('tanınmayan durum başvuruldu sayılır', () {
      expect(ApplicationStatus.fromCode('UZAYLI'), ApplicationStatus.applied);
      expect(
        ApplicationStatus.fromCode('REJECTED'),
        ApplicationStatus.rejected,
      );
    });
  });

  group('appliedJobs', () {
    Future<ApplyProvider> loadWith(List<Map<String, dynamic>> content) async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': content, 'last': true},
          },
        ),
      );
      final provider = buildProvider(api);
      await provider.load();
      return provider;
    }

    test('bekleyen başvuru beklemede görünür', () async {
      final provider = await loadWith([applicationBody()]);

      expect(provider.appliedJobs.single.status, MyJobStatus.pending);
    });

    // Kullanıcı reddedildiğini öğrenemiyordu: satır "beklemede" çiziliyordu.
    test('reddedilen başvuru kendi durumunu taşır', () async {
      final provider = await loadWith([
        applicationBody(
          status: 'REJECTED',
          rejectionReason: 'Deneyim aradığımız alanda değil',
        ),
      ]);

      final job = provider.appliedJobs.single;
      expect(job.status, MyJobStatus.applicationRejected);
      expect(job.isClosed, isTrue);
      // Gerekçe ilanın özetinden değerli; alt satırda o gösteriliyor.
      expect(job.subtitle, 'Deneyim aradığımız alanda değil');
    });

    test('gerekçe yoksa ilanın özeti gösterilir', () async {
      final provider = await loadWith([applicationBody(status: 'REJECTED')]);

      final job = provider.appliedJobs.single;
      expect(job.status, MyJobStatus.applicationRejected);
      expect(job.subtitle, job.description);
    });

    // Kabul edilen başvuru artık bir atama; atamalar ayrı uçtan geliyor ve
    // ikisini birden çizmek aynı işi listede iki kez gösterirdi.
    test('kabul edilen başvuru listeye girmez', () async {
      final provider = await loadWith([
        applicationBody(id: 'app_1', status: 'ACCEPTED'),
        applicationBody(id: 'app_2'),
      ]);

      expect(provider.applications, hasLength(2));
      expect(provider.appliedJobs, hasLength(1));
      expect(provider.appliedJobs.single.id, 'app_2');
    });
  });
}
