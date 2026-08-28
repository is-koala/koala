import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

import '../../../../../support/fake_api.dart';
import '../../services/employer_job_service_test.dart' show buildRequest;

/// `PageDto<JobSummaryDto>` biçiminde tek ilan.
Map<String, dynamic> jobJson(String id, {String status = 'OPEN'}) => {
  'id': id,
  'title': 'İlan $id',
  'salary': 800,
  'status': status,
  'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garsonluk'},
};

Map<String, dynamic> applicantJson(
  String id, {
  String status = 'APPLIED',
  String firstName = 'Ayşe',
}) => {
  'id': id,
  'status': status,
  'applicationDateTime': '2026-08-01T10:00:00Z',
  'applicant': {'id': 'u_$id', 'firstName': firstName, 'lastName': 'Yılmaz'},
};

/// İlan listesi ve başvuruları birlikte döndüren sahte sunucu.
///
/// [applicantsByJob] içinde olmayan ilan boş liste alıyor; `null` verilen
/// ilan ise 500 dönüyor, "tek ilanın başvurusu gelmezse ne olur" durumunu
/// kurmak için.
FakeApi buildApi({
  required List<Map<String, dynamic>> jobs,
  Map<String, List<Map<String, dynamic>>?> applicantsByJob = const {},
}) {
  return FakeApi(
    handler: (options) {
      if (options.path == '/users/me/jobs') {
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': jobs, 'totalElements': jobs.length},
          },
        );
      }

      final match = RegExp(
        r'^/jobs/([^/]+)/applications$',
      ).firstMatch(options.path);
      if (match != null) {
        final jobId = match.group(1)!;
        if (applicantsByJob.containsKey(jobId) &&
            applicantsByJob[jobId] == null) {
          return const FakeApiResponse(
            statusCode: 500,
            body: {'success': false, 'message': 'Sunucu hatası'},
          );
        }
        return FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': applicantsByJob[jobId] ?? const []},
        );
      }

      return const FakeApiResponse(statusCode: 200, body: {'success': true});
    },
  );
}

BJobsProvider providerFor(FakeApi api) =>
    BJobsProvider(service: EmployerJobService.withClient(api.client));

void main() {
  group('load', () {
    test('aktif ve geçmiş ilanlar sunucudaki duruma göre ayrışıyor', () async {
      final api = buildApi(
        jobs: [
          jobJson('a'),
          jobJson('b', status: 'IN_PROGRESS'),
          jobJson('c', status: 'CLOSED'),
          jobJson('d', status: 'COMPLETED'),
        ],
      );
      final provider = providerFor(api);

      await provider.load();

      expect(provider.activePosts.map((p) => p.job.id), ['a', 'b']);
      expect(provider.pastPosts.map((p) => p.job.id), ['c', 'd']);
    });

    test('başvurular her ilan için ayrı istekle dolduruluyor', () async {
      final api = buildApi(
        jobs: [jobJson('a'), jobJson('b')],
        applicantsByJob: {
          'a': [applicantJson('app_1')],
          'b': [],
        },
      );
      final provider = providerFor(api);

      await provider.load();

      final paths = api.requests.map((r) => r.path).toList();
      expect(paths, contains('/jobs/a/applications'));
      expect(paths, contains('/jobs/b/applications'));
      expect(provider.allPosts.every((p) => p.applicantsLoaded), isTrue);
      expect(provider.getPostByJobId('a')!.applicants, hasLength(1));
      expect(provider.getPostByJobId('b')!.applicants, isEmpty);
    });

    test(
      'bekleyen başvuru listede, kabul edilen çalışan olarak duruyor',
      () async {
        final api = buildApi(
          jobs: [jobJson('a')],
          applicantsByJob: {
            'a': [
              applicantJson('app_1'),
              applicantJson('app_2', status: 'ACCEPTED', firstName: 'Mehmet'),
              applicantJson('app_3', status: 'REJECTED'),
            ],
          },
        );
        final provider = providerFor(api);

        await provider.load();
        final post = provider.getPostByJobId('a')!;

        expect(post.applicants.map((a) => a.id), ['app_1']);
        expect(post.worker!.fullName, 'Mehmet Yılmaz');
        expect(post.worker!.status, ApplicationStatus.accepted);
      },
    );

    test('tek ilanın başvuruları gelmezse liste ayakta kalıyor', () async {
      final api = buildApi(
        jobs: [jobJson('a'), jobJson('b')],
        applicantsByJob: {
          'a': null,
          'b': [applicantJson('app_1')],
        },
      );
      final provider = providerFor(api);

      await provider.load();

      expect(provider.errorMessage, isNull);
      expect(provider.getPostByJobId('a')!.applicants, isEmpty);
      expect(provider.getPostByJobId('b')!.applicants, hasLength(1));
    });

    test('bekleyen başvurular sayılırken kabul edilenler dışarıda', () async {
      final api = buildApi(
        jobs: [
          jobJson('a'),
          jobJson('b', status: 'CLOSED'),
        ],
        applicantsByJob: {
          'a': [
            applicantJson('app_1'),
            applicantJson('app_2', status: 'ACCEPTED'),
          ],
          // Geçmiş ilanın başvurusu sayıma girmemeli.
          'b': [applicantJson('app_3')],
        },
      );
      final provider = providerFor(api);

      await provider.load();

      expect(provider.pendingApplicantCount, 1);
    });

    test('boş liste hata değil', () async {
      final provider = providerFor(buildApi(jobs: const []));

      await provider.load();

      expect(provider.isEmpty, isTrue);
      expect(provider.errorMessage, isNull);
    });

    test('ikinci çağrı ağa çıkmıyor, force ile çıkıyor', () async {
      final api = buildApi(jobs: [jobJson('a')]);
      final provider = providerFor(api);

      await provider.load();
      final afterFirst = api.requests.length;
      await provider.load();
      expect(api.requests, hasLength(afterFirst));

      await provider.load(force: true);
      expect(api.requests.length, greaterThan(afterFirst));
    });
  });

  group('hata', () {
    test('ilan listesi alınamazsa mesaj taşınıyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      );
      final provider = providerFor(api);

      await provider.load();

      expect(provider.errorMessage, 'Sunucu hatası');
      expect(provider.allPosts, isEmpty);
      expect(provider.isEmpty, isFalse);
    });
  });

  group('ilan işlemleri', () {
    test('createJobPost başarılıysa liste yenileniyor', () async {
      final api = buildApi(jobs: [jobJson('a')]);
      final provider = providerFor(api);
      await provider.load();
      final before = api.requests.length;

      final created = await provider.createJobPost(buildRequest());

      expect(created, isTrue);
      final paths = api.requests.skip(before).map((r) => r.path);
      expect(paths, contains('/users/me/jobs'));
    });

    test('closePost ilanı kapatma ucunu çağırıyor', () async {
      final api = buildApi(jobs: [jobJson('a')]);
      final provider = providerFor(api);

      final closed = await provider.closePost('a');

      expect(closed, isTrue);
      expect(api.requests.map((r) => r.path), contains('/jobs/a/close'));
    });

    test('kabul isteği yanıt ucuna gidiyor', () async {
      final api = buildApi(jobs: [jobJson('a')]);
      final provider = providerFor(api);

      final approved = await provider.approveApplicant('app_1');

      expect(approved, isTrue);
      expect(
        api.requests.map((r) => r.path),
        contains('/job-applications/app_1/respond'),
      );
    });

    test(
      'yanıtlanmış başvuru ikinci kez yanıtlanınca hata taşınıyor',
      () async {
        final api = FakeApi(
          handler: (RequestOptions options) {
            if (options.path.endsWith('/respond')) {
              return const FakeApiResponse(
                statusCode: 400,
                body: {
                  'success': false,
                  'message': 'Bu başvuru zaten cevaplanmış',
                },
              );
            }
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'content': []},
              },
            );
          },
        );
        final provider = providerFor(api);

        final approved = await provider.approveApplicant('app_1');

        expect(approved, isFalse);
        expect(provider.errorMessage, 'Bu başvuru zaten cevaplanmış');
      },
    );
  });

  test('allPosts dışarıdan değiştirilemez', () async {
    final provider = providerFor(buildApi(jobs: [jobJson('a')]));
    await provider.load();

    expect(() => provider.allPosts.clear(), throwsUnsupportedError);
  });
}
