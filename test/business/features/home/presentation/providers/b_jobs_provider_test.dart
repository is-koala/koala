import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

import '../../../../../support/fake_api.dart';
import '../../services/employer_job_service_test.dart' show buildRequest;

/// `PageDto<JobSummaryDto>` biçiminde tek ilan.
Map<String, dynamic> jobJson(
  String id, {
  String? title,
  String status = 'OPEN',
  int applicationCount = 0,
}) => {
  'id': id,
  'title': title ?? 'İlan $id',
  'salary': 800,
  'status': status,
  'applicationCount': applicationCount,
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
          jobJson('b', status: 'CANCELLED'),
          jobJson('c', status: 'CLOSED'),
          jobJson('d', status: 'CANCELLED'),
        ],
      );
      final provider = providerFor(api);

      await provider.load();

      expect(provider.activePosts.map((p) => p.job.id), ['a']);
      expect(provider.pastPosts.map((p) => p.job.id), ['b', 'c', 'd']);
    });

    test('liste yüklenirken başvuru isteği atılmıyor', () async {
      final api = buildApi(
        jobs: [jobJson('a'), jobJson('b')],
        applicantsByJob: {
          'a': [applicantJson('app_1')],
        },
      );
      final provider = providerFor(api);

      await provider.load();

      // Sayı `applicationCount` ile geldiği için liste artık N+1 atmıyor.
      expect(api.requests.map((r) => r.path), ['/users/me/jobs']);
      expect(provider.allPosts.every((post) => post.applicantsLoaded), isFalse);
    });

    test('başvuru sayısı ilanla birlikte geliyor', () async {
      final provider = providerFor(
        buildApi(
          jobs: [
            jobJson('a', applicationCount: 3),
            jobJson('b', applicationCount: 1),
            jobJson('c', status: 'CLOSED', applicationCount: 5),
          ],
        ),
      );

      await provider.load();

      expect(provider.getPostByJobId('a')!.job.applicationCount, 3);
      // Geçmiş ilan toplama girmiyor.
      expect(provider.totalApplicantCount, 4);
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
        await provider.ensureApplicants('a');
        final post = provider.getPostByJobId('a')!;

        expect(post.applicants.map((a) => a.id), ['app_1']);
        expect(post.acceptedApplicants.map((a) => a.id), ['app_2']);
        expect(post.worker!.fullName, 'Mehmet Yılmaz');
        expect(post.worker!.status, ApplicationStatus.accepted);
      },
    );

    // Geri çekilen aday `applied` sanılıyordu: işverene "yanıt bekliyor"
    // görünüyor, "Kabul Et"e basınca sunucudan `409` geliyordu. Artık
    // bekleyen sayılmıyor ama listeden de düşmüyor — sunucu kaydı silmiyor
    // ve işverenin listesinde tutuyor.
    test(
      'geri çekilen aday yanıt bekleyen değil ama listede kalıyor',
      () async {
        final api = buildApi(
          jobs: [jobJson('a')],
          applicantsByJob: {
            'a': [
              applicantJson('app_1'),
              applicantJson('app_2', status: 'WITHDRAWN'),
              applicantJson('app_3', status: 'UZAYLI'),
              applicantJson('app_4', status: 'REJECTED'),
              applicantJson('app_5', status: 'ACCEPTED'),
            ],
          },
        );
        final provider = providerFor(api);

        await provider.load();
        await provider.ensureApplicants('a');
        final post = provider.getPostByJobId('a')!;

        // "Son Başvurular" bir eylem çağrısı: yalnızca yanıt bekleyenler.
        expect(post.applicants.map((a) => a.id), ['app_1']);
        // İlan detayındaki "Başvuranlar": işverenin yanıtlamadığı her kayıt.
        // Geri çekilen ve durumu tanınmayan burada duruyor, butonsuz.
        expect(post.unansweredApplicants.map((a) => a.id), [
          'app_1',
          'app_2',
          'app_3',
        ]);
        expect(post.acceptedApplicants.map((a) => a.id), ['app_5']);
        expect(post.applications[1].status, ApplicationStatus.withdrawn);
        expect(post.applications[2].status, ApplicationStatus.unknown);
      },
    );

    test(
      'başvuru hatası boş başarı değildir ve tekrar deneme düzelir',
      () async {
        var applicantRequestCount = 0;
        final api = FakeApi(
          handler: (options) {
            if (options.path == '/users/me/jobs') {
              return FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'content': [jobJson('a')],
                  },
                },
              );
            }

            applicantRequestCount++;
            if (applicantRequestCount == 1) {
              return const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'Başvurular alınamadı'},
              );
            }
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': [applicantJson('app_1')],
              },
            );
          },
        );
        final provider = providerFor(api);

        await provider.load();
        await provider.ensureApplicants('a');

        expect(provider.errorMessage, isNull);
        expect(provider.applicantErrorFor('a'), 'Başvurular alınamadı');
        expect(provider.getPostByJobId('a')!.applicantsLoaded, isFalse);
        expect(provider.getPostByJobId('a')!.applicants, isEmpty);

        await provider.ensureApplicants('a', force: true);

        expect(provider.applicantErrorFor('a'), isNull);
        expect(provider.getPostByJobId('a')!.applicantsLoaded, isTrue);
        expect(provider.getPostByJobId('a')!.applicants, hasLength(1));
      },
    );

    test('başarısız yenileme mevcut başvuru listesini koruyor', () async {
      var applicantRequestCount = 0;
      final api = FakeApi(
        handler: (options) {
          if (options.path == '/users/me/jobs') {
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [jobJson('a')],
                },
              },
            );
          }

          applicantRequestCount++;
          if (applicantRequestCount == 1) {
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': [applicantJson('app_1')],
              },
            );
          }
          return const FakeApiResponse(
            statusCode: 500,
            body: {'success': false, 'message': 'Yenileme başarısız'},
          );
        },
      );
      final provider = providerFor(api);

      await provider.load();
      await provider.ensureApplicants('a');
      await provider.ensureApplicants('a', force: true);

      final post = provider.getPostByJobId('a')!;
      expect(post.applicantsLoaded, isTrue);
      expect(post.applicants.single.id, 'app_1');
      expect(provider.applicantErrorFor('a'), 'Yenileme başarısız');
    });

    test('bir ilana birden çok aday kabul edilebiliyor', () async {
      final api = buildApi(
        jobs: [jobJson('a')],
        applicantsByJob: {
          'a': [
            applicantJson('app_1', status: 'ACCEPTED'),
            applicantJson('app_2', status: 'ACCEPTED', firstName: 'Mehmet'),
            applicantJson('app_3'),
          ],
        },
      );
      final provider = providerFor(api);

      await provider.load();
      await provider.ensureApplicants('a');
      final post = provider.getPostByJobId('a')!;

      // Kabul ilanı kapatmıyor; ikinci bir aday da kabul edilebiliyor ve
      // ikisi de "Onaylananlar" bölümünde görünmeli.
      expect(post.acceptedApplicants, hasLength(2));
      expect(post.worker!.id, 'app_1');
      expect(post.applicants.map((a) => a.id), ['app_3']);
      // Kabul edilen ilan hâlâ aktif.
      expect(post.isActive, isTrue);
    });

    test('kabul edilen yoksa çalışan yok', () async {
      final api = buildApi(
        jobs: [jobJson('a')],
        applicantsByJob: {
          'a': [
            applicantJson('app_1'),
            applicantJson('app_2', status: 'REJECTED'),
          ],
        },
      );
      final provider = providerFor(api);

      await provider.load();
      await provider.ensureApplicants('a');
      final post = provider.getPostByJobId('a')!;

      expect(post.acceptedApplicants, isEmpty);
      expect(post.worker, isNull);
    });

    test('boş liste hata değil', () async {
      final provider = providerFor(buildApi(jobs: const []));

      await provider.load();

      expect(provider.isEmpty, isTrue);
      expect(provider.errorMessage, isNull);
    });

    test('başvuru ucundaki 200 boş liste gerçek boş başarıdır', () async {
      final provider = providerFor(buildApi(jobs: [jobJson('a')]));

      await provider.load();
      await provider.ensureApplicants('a');

      final post = provider.getPostByJobId('a')!;
      expect(post.applicantsLoaded, isTrue);
      expect(post.applicantsLoading, isFalse);
      expect(post.applicantsError, isNull);
      expect(post.applications, isEmpty);
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

    test(
      'uçuştaki forced yenileme yenisini yutmaz ve eski yanıt kazanmaz',
      () async {
        final staleResponse = Completer<FakeApiResponse>();
        addTearDown(() {
          if (!staleResponse.isCompleted) {
            staleResponse.complete(const FakeApiResponse.connectionError());
          }
        });
        var listRequestCount = 0;
        final api = FakeApi(
          handler: (options) {
            if (options.path != '/users/me/jobs') {
              return const FakeApiResponse(statusCode: 404);
            }

            listRequestCount++;
            if (listRequestCount == 2) return staleResponse.future;
            final title = listRequestCount == 1 ? 'İlk' : 'En yeni';
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [jobJson('a', title: title)],
                },
              },
            );
          },
        );
        final provider = providerFor(api);
        await provider.load();

        final olderLoad = provider.load(force: true);
        await api.requestsReach(2);
        await provider.load(force: true);

        expect(listRequestCount, 3);
        expect(provider.getPostByJobId('a')!.job.title, 'En yeni');

        staleResponse.complete(
          FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'content': [jobJson('a', title: 'Eski')],
              },
            },
          ),
        );
        await olderLoad;

        expect(provider.getPostByJobId('a')!.job.title, 'En yeni');
      },
    );

    test('liste yenilemesi bu arada gelen başvuruyu silmiyor', () async {
      final listRefresh = Completer<FakeApiResponse>();
      addTearDown(() {
        if (!listRefresh.isCompleted) {
          listRefresh.complete(const FakeApiResponse.connectionError());
        }
      });
      var listRequestCount = 0;
      final api = FakeApi(
        handler: (options) {
          if (options.path == '/users/me/jobs') {
            listRequestCount++;
            if (listRequestCount == 2) return listRefresh.future;
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [jobJson('a', title: 'İlk')],
                },
              },
            );
          }
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [applicantJson('app_1')],
            },
          );
        },
      );
      final provider = providerFor(api);
      await provider.load();

      final loadingList = provider.load(force: true);
      await api.requestsReach(2);
      await provider.ensureApplicants('a', force: true);
      listRefresh.complete(
        FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [jobJson('a', title: 'Güncel')],
            },
          },
        ),
      );
      await loadingList;

      final post = provider.getPostByJobId('a')!;
      expect(post.job.title, 'Güncel');
      expect(post.applicantsLoaded, isTrue);
      expect(post.applicants.single.id, 'app_1');
    });

    test('eski başvuru hatası yeni tekrar deneme sonucunu ezmiyor', () async {
      final firstResponse = Completer<FakeApiResponse>();
      addTearDown(() {
        if (!firstResponse.isCompleted) {
          firstResponse.complete(const FakeApiResponse.connectionError());
        }
      });
      var applicantRequestCount = 0;
      final api = FakeApi(
        handler: (options) {
          if (options.path == '/users/me/jobs') {
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [jobJson('a')],
                },
              },
            );
          }

          applicantRequestCount++;
          if (applicantRequestCount == 1) return firstResponse.future;
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [applicantJson('new_applicant')],
            },
          );
        },
      );
      final provider = providerFor(api);
      await provider.load();

      final olderLoad = provider.ensureApplicants('a');
      await api.requestsReach(2);
      await provider.ensureApplicants('a', force: true);

      expect(applicantRequestCount, 2);
      firstResponse.complete(
        const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Eski istek hatası'},
        ),
      );
      await olderLoad;

      expect(
        provider.getPostByJobId('a')!.applicants.single.id,
        'new_applicant',
      );
      expect(provider.applicantErrorFor('a'), isNull);
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

      expect(created, isNotNull);
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

    test('kabul sonrası o ilanın başvuranları tazeleniyor', () async {
      final api = buildApi(jobs: [jobJson('a')]);
      final provider = providerFor(api);

      final approved = await provider.approveApplicant(
        jobId: 'a',
        applicationId: 'app_1',
      );

      expect(approved, isTrue);
      final paths = api.requests.map((r) => r.path).toList();
      expect(paths, contains('/job-applications/app_1/respond'));
      // Liste yenileniyor ve o ilanın başvuranları yeniden çekiliyor;
      // diğer ilanlar için istek atılmıyor.
      expect(paths, contains('/jobs/a/applications'));
    });

    test(
      'kabul sonrası başvuru yenilemesi bozulursa mevcut aday korunuyor',
      () async {
        var applicantRequestCount = 0;
        final api = FakeApi(
          handler: (options) {
            if (options.path == '/users/me/jobs') {
              return FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'content': [jobJson('a')],
                  },
                },
              );
            }
            if (options.path == '/jobs/a/applications') {
              applicantRequestCount++;
              if (applicantRequestCount == 1) {
                return FakeApiResponse(
                  statusCode: 200,
                  body: {
                    'success': true,
                    'data': [applicantJson('app_1')],
                  },
                );
              }
              return const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'Başvurular yenilenemedi'},
              );
            }
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true},
            );
          },
        );
        final provider = providerFor(api);
        await provider.load();
        await provider.ensureApplicants('a');

        final approved = await provider.approveApplicant(
          jobId: 'a',
          applicationId: 'app_1',
        );

        final post = provider.getPostByJobId('a')!;
        expect(approved, isTrue);
        expect(post.applicantsLoaded, isTrue);
        expect(post.applicants.single.id, 'app_1');
        expect(provider.applicantErrorFor('a'), 'Başvurular yenilenemedi');
      },
    );

    test('ensureApplicants aynı ilan için ikinci kez ağa çıkmıyor', () async {
      final api = buildApi(
        jobs: [jobJson('a')],
        applicantsByJob: {
          'a': [applicantJson('app_1')],
        },
      );
      final provider = providerFor(api);
      await provider.load();

      await provider.ensureApplicants('a');
      final after = api.requests.length;
      await provider.ensureApplicants('a');
      expect(api.requests, hasLength(after));

      await provider.ensureApplicants('a', force: true);
      expect(api.requests.length, greaterThan(after));
    });

    test('bilinmeyen ilan için ensureApplicants istek atmıyor', () async {
      final api = buildApi(jobs: [jobJson('a')]);
      final provider = providerFor(api);
      await provider.load();
      final before = api.requests.length;

      await provider.ensureApplicants('yok');

      expect(api.requests, hasLength(before));
    });

    test(
      'eski başvuran isteği yeni oturumun aynı ilan isteğini bozmaz',
      () async {
        final accountAApplicants = Completer<FakeApiResponse>();
        final accountBApplicants = Completer<FakeApiResponse>();
        var applicantsCall = 0;
        final api = FakeApi(
          handler: (options) {
            if (options.path == '/users/me/jobs') {
              return FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'content': [jobJson('ortak')],
                  },
                },
              );
            }

            if (options.path == '/jobs/ortak/applications') {
              applicantsCall++;
              return applicantsCall == 1
                  ? accountAApplicants.future
                  : accountBApplicants.future;
            }

            throw StateError('Beklenmeyen istek: ${options.path}');
          },
        );
        final provider = providerFor(api);
        await provider.load();

        final accountARequest = provider.ensureApplicants('ortak');
        await api.requestsReach(2);

        provider.clear();
        await provider.load();
        final accountBRequest = provider.ensureApplicants('ortak');
        await api.requestsReach(4);

        accountAApplicants.complete(
          FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [applicantJson('hesap_a')],
            },
          ),
        );
        await accountARequest;

        expect(provider.getPostByJobId('ortak')!.applications, isEmpty);
        expect(provider.getPostByJobId('ortak')!.applicantsLoaded, isFalse);
        // Normal yeniden çizim çağrısı, B oturumunun uçuşta olan isteğini
        // paylaşmalı. `force: true` bilinçli olarak aynı oturumdaki eski
        // isteği supersede eder ve bu invariantı ölçmez.
        await provider.ensureApplicants('ortak');
        expect(
          api.requests,
          hasLength(4),
          reason: 'Eski istek B oturumunun pending kilidini kaldırmamalı',
        );

        accountBApplicants.complete(
          FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [applicantJson('hesap_b')],
            },
          ),
        );
        await accountBRequest;

        expect(
          provider
              .getPostByJobId('ortak')!
              .applications
              .map((application) => application.id),
          ['hesap_b'],
        );
      },
    );

    test('eski ilan işlemi yeni oturumda zorunlu yükleme başlatmaz', () async {
      final accountAClose = Completer<FakeApiResponse>();
      final api = FakeApi(
        handler: (options) {
          if (options.path == '/jobs/hesap_a/close') {
            return accountAClose.future;
          }
          if (options.path == '/users/me/jobs') {
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [jobJson('hesap_b')],
                },
              },
            );
          }
          throw StateError('Beklenmeyen istek: ${options.path}');
        },
      );
      final provider = providerFor(api);

      final accountAResult = provider.closePost('hesap_a');
      await api.requestsReach(1);

      provider.clear();
      await provider.load();

      accountAClose.complete(
        const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      expect(await accountAResult, isFalse);
      expect(provider.allPosts.map((post) => post.job.id), ['hesap_b']);
      expect(provider.errorMessage, isNull);
      expect(api.requests, hasLength(2));
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

        final approved = await provider.approveApplicant(
          jobId: 'a',
          applicationId: 'app_1',
        );

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

  test('geç eski yanıt yeni hesabın ilanlarını ezmez', () async {
    final accountAResponse = Completer<FakeApiResponse>();
    final accountBResponse = Completer<FakeApiResponse>();
    var call = 0;
    final api = FakeApi(
      handler: (_) {
        call++;
        return call == 1 ? accountAResponse.future : accountBResponse.future;
      },
    );
    final provider = providerFor(api);

    final accountALoad = provider.load();
    await api.requestsReach(1);

    provider.clear();
    final accountBLoad = provider.load();
    final bStarted = await Future.any([
      api.requestsReach(2).then((_) => true),
      accountBLoad.then((_) => false),
    ]);
    expect(bStarted, isTrue, reason: 'Yeni oturumun isteği engellenmemeli');

    accountAResponse.complete(
      FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'content': [jobJson('hesap_a')],
          },
        },
      ),
    );
    await accountALoad;

    expect(provider.allPosts, isEmpty);
    expect(provider.isLoading, isTrue);
    expect(provider.hasLoaded, isFalse);
    expect(provider.errorMessage, isNull);

    accountBResponse.complete(
      FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'content': [jobJson('hesap_b')],
          },
        },
      ),
    );
    await accountBLoad;

    expect(provider.allPosts.map((post) => post.job.id), ['hesap_b']);
    expect(provider.isLoading, isFalse);
    expect(provider.hasLoaded, isTrue);
    expect(provider.errorMessage, isNull);
  });
}
