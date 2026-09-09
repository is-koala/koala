import 'dart:async';

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

    test('geç eski yanıt yeni hesabın başvurularını ezmez', () async {
      final accountAResponse = Completer<FakeApiResponse>();
      final accountBResponse = Completer<FakeApiResponse>();
      var call = 0;
      final api = FakeApi(
        handler: (_) {
          call++;
          return call == 1 ? accountAResponse.future : accountBResponse.future;
        },
      );
      final provider = buildProvider(api);

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
              'content': [applicationBody(id: 'hesap_a', jobId: 'is_a')],
            },
          },
        ),
      );
      await accountALoad;

      expect(provider.applications, isEmpty);
      expect(provider.isLoading, isTrue);
      expect(provider.hasLoaded, isFalse);
      expect(provider.errorMessage, isNull);

      accountBResponse.complete(
        FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [applicationBody(id: 'hesap_b', jobId: 'is_b')],
            },
          },
        ),
      );
      await accountBLoad;

      expect(provider.applications.map((application) => application.id), [
        'hesap_b',
      ]);
      expect(provider.isLoading, isFalse);
      expect(provider.hasLoaded, isTrue);
      expect(provider.errorMessage, isNull);
    });

    test('eski başvuru yanıtı yeni hesabın listesine eklenmez', () async {
      final accountAApply = Completer<FakeApiResponse>();
      final api = FakeApi(
        handler: (options) => options.method == 'POST'
            ? accountAApply.future
            : FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'content': [applicationBody(id: 'hesap_b', jobId: 'is_b')],
                  },
                },
              ),
      );
      final provider = buildProvider(api);

      final accountAResult = provider.applyToJob(buildJob(id: 'is_a'));
      await api.requestsReach(1);

      provider.clear();
      await provider.load();

      accountAApply.complete(
        FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': applicationBody(id: 'hesap_a', jobId: 'is_a'),
          },
        ),
      );

      expect(await accountAResult, isFalse);
      expect(provider.applications.map((application) => application.id), [
        'hesap_b',
      ]);
      expect(provider.errorMessage, isNull);
    });
  });

  group('ApplicationStatus', () {
    // Tanınmayan kod eskiden `applied`'a düşüyordu: sunucu yeni bir durum
    // eklediğinde o başvuru "yanıt bekliyor" gibi görünüyor, iki taraf da
    // sunucunun reddedeceği bir işlemi deniyordu. Var olan bir duruma
    // benzemek, bilinmediğini söylemekten tehlikeli.
    test('tanınmayan durum bilinmiyor sayılır', () {
      expect(ApplicationStatus.fromCode('UZAYLI'), ApplicationStatus.unknown);
      expect(
        ApplicationStatus.fromCode('REJECTED'),
        ApplicationStatus.rejected,
      );
      expect(
        ApplicationStatus.fromCode('WITHDRAWN'),
        ApplicationStatus.withdrawn,
      );
    });

    // Eylem gösterme kararının tek yeri: `applied` dışında hiçbir durum —
    // bilinmeyen dahil — yanıt bekliyor sayılmıyor.
    test('yalnızca APPLIED yanıt bekliyor', () {
      expect(ApplicationStatus.applied.isPending, isTrue);
      expect(ApplicationStatus.withdrawn.isPending, isFalse);
      expect(ApplicationStatus.unknown.isPending, isFalse);
      expect(ApplicationStatus.accepted.isPending, isFalse);
      expect(ApplicationStatus.rejected.isPending, isFalse);
    });

    // Sunucunun kuralı: geri çekilmiş olmayan her kayıt yeniden başvurmayı
    // engelliyor. Bilinmeyen durum da engelliyor — istek atıp `409` yemektense
    // düğmeyi kapalı tutmak doğru taraf.
    test('yalnızca geri çekilen kayıt yeniden başvurmaya izin verir', () {
      expect(ApplicationStatus.withdrawn.blocksReapplication, isFalse);
      expect(ApplicationStatus.applied.blocksReapplication, isTrue);
      expect(ApplicationStatus.accepted.blocksReapplication, isTrue);
      expect(ApplicationStatus.rejected.blocksReapplication, isTrue);
      expect(ApplicationStatus.unknown.blocksReapplication, isTrue);
    });
  });

  // Sunucu geri çekilen ilana yeniden başvuruyu kabul ediyor
  // (`existsByJobIdAndUserIdAndStatusNot(jobId, userId, WITHDRAWN)`); istemci
  // saymaya devam ederse o kural uygulamadan erişilemez kalıyordu.
  group('ApplyProvider.hasApplied', () {
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

    test('geri çekilen başvuru sayılmaz', () async {
      final provider = await loadWith([applicationBody(status: 'WITHDRAWN')]);

      expect(provider.hasApplied('job_1'), isFalse);
    });

    test('aynı ilanda geri çekilenin yanında duran başvuru sayılır', () async {
      final provider = await loadWith([
        applicationBody(id: 'app_1', status: 'WITHDRAWN'),
        applicationBody(id: 'app_2'),
      ]);

      expect(provider.hasApplied('job_1'), isTrue);
    });

    test('geri çekilen ilana yeniden başvuru isteği gider', () async {
      var listed = false;
      final api = FakeApi(
        handler: (options) {
          if (!listed) {
            listed = true;
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [applicationBody(status: 'WITHDRAWN')],
                  'last': true,
                },
              },
            );
          }
          return FakeApiResponse(
            statusCode: 201,
            body: {
              'success': true,
              'data': applicationBody(id: 'app_2'),
            },
          );
        },
      );
      final provider = buildProvider(api);
      await provider.load();

      final ok = await provider.applyToJob(buildJob(id: 'job_1'));

      expect(ok, isTrue);
      expect(api.requests.last.path, '/jobs/job_1/applications');
    });
  });

  group('ApplyProvider.withdraw', () {
    /// Önce listeyi doldurur, sonra geri çekme isteğine [onWithdraw] yanıtını
    /// verir. Geri çekme `409` dönerse provider listeyi tazelediği için
    /// listeleme yanıtı birden çok kez istenebiliyor.
    (ApplyProvider, FakeApi) buildWith({
      required FakeApiResponse onWithdraw,
      String listedStatus = 'APPLIED',
    }) {
      final api = FakeApi(
        handler: (options) => options.path.endsWith('/withdraw')
            ? onWithdraw
            : FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'content': [applicationBody(status: listedStatus)],
                    'last': true,
                  },
                },
              ),
      );
      return (buildProvider(api), api);
    }

    test('başarılı geri çekmede satır durumu değişir', () async {
      final (provider, api) = buildWith(
        onWithdraw: const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'app_1',
              'status': 'WITHDRAWN',
              'job': {'id': 'job_1', 'title': 'Deneyimli Barista'},
            },
          },
        ),
      );
      await provider.load();

      final ok = await provider.withdraw('app_1');

      expect(ok, isTrue);
      expect(api.requests.last.path, '/job-applications/app_1/withdraw');
      expect(provider.applications.single.status, ApplicationStatus.withdrawn);
      expect(provider.appliedJobs.single.status, MyJobStatus.withdrawn);
      // Geri çekilen ilana yeniden başvurulabiliyor.
      expect(provider.hasApplied('job_1'), isFalse);
    });

    // Uç `ShortJobDto` döndürüyor (yalnızca id ve başlık): dönen kayıt olduğu
    // gibi listedekinin yerine konsaydı satırın ücreti, şirketi ve özeti
    // silinirdi. Sunucudan alınan tek şey durum.
    test('satırın ilan özeti korunur', () async {
      final (provider, _) = buildWith(
        onWithdraw: const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'app_1',
              'status': 'WITHDRAWN',
              'job': {'id': 'job_1', 'title': 'Deneyimli Barista'},
            },
          },
        ),
      );
      await provider.load();

      await provider.withdraw('app_1');

      final job = provider.appliedJobs.single;
      expect(job.price, 15000);
      expect(job.company, 'Koala Cafe');
      expect(job.description, 'Barista');
    });

    // 409: başvuru araya girip kabul ya da reddedilmiş demektir; ekrandaki
    // durum bayat, doğrusunu göstermek için liste yeniden çekiliyor.
    test('409 alınırsa hata taşınır ve liste tazelenir', () async {
      final (provider, api) = buildWith(
        onWithdraw: const FakeApiResponse(
          statusCode: 409,
          body: {
            'success': false,
            'message': 'Bu başvuru geri çekilemez.',
            'errorCode': 'JOB_APPLICATION_NOT_WITHDRAWABLE',
          },
        ),
      );
      await provider.load();

      final ok = await provider.withdraw('app_1');

      expect(ok, isFalse);
      expect(provider.errorCode, 'JOB_APPLICATION_NOT_WITHDRAWABLE');
      expect(provider.errorMessage, 'Bu başvuru geri çekilemez.');
      // İlk listeleme + geri çekme + tazeleme.
      expect(api.requests, hasLength(3));
      expect(api.requests.last.path, '/users/me/applications');
    });

    // İki çakışma kategorisi de ekrandaki listeyi bayat yapıyor; tazeleme
    // yalnız birine bağlanırsa diğerinde kullanıcı yanlış durumu görmeye
    // devam eder.
    for (final category in ['DATA_CONFLICT', 'BUSINESS_RULE_VIOLATION']) {
      test('$category alınırsa liste yine tazeleniyor', () async {
        final (provider, api) = buildWith(
          onWithdraw: FakeApiResponse(
            statusCode: 409,
            body: {
              'success': false,
              'message': 'Bu başvuru geri çekilemez.',
              'errorCategory': category,
            },
          ),
        );
        await provider.load();

        expect(await provider.withdraw('app_1'), isFalse);
        expect(api.requests, hasLength(3));
        expect(api.requests.last.path, '/users/me/applications');
      });
    }

    // 404 kaydın olmadığını değil, kullanıcının sahibi olmadığını da
    // anlatabiliyor; her hâlükârda liste tazelenmiyor, mesaj gösteriliyor.
    test('404 alınırsa liste tazelenmez', () async {
      final (provider, api) = buildWith(
        onWithdraw: const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'message': 'Başvuru bulunamadı.',
            'errorCode': 'JOB_APPLICATION_NOT_FOUND',
          },
        ),
      );
      await provider.load();

      final ok = await provider.withdraw('app_1');

      expect(ok, isFalse);
      expect(provider.errorCode, 'JOB_APPLICATION_NOT_FOUND');
      expect(api.requests, hasLength(2));
    });

    test('istek sürerken ikinci geri çekme isteği gitmez', () async {
      final (provider, api) = buildWith(
        onWithdraw: const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'app_1',
              'status': 'WITHDRAWN',
              'job': {'id': 'job_1', 'title': 'Deneyimli Barista'},
            },
          },
        ),
      );
      await provider.load();

      await Future.wait([
        provider.withdraw('app_1'),
        provider.withdraw('app_1'),
      ]);

      expect(
        api.requests.where((r) => r.path.endsWith('/withdraw')),
        hasLength(1),
      );
    });

    test('eski 409 yeni oturumda liste tazelemesi başlatmaz', () async {
      final accountAWithdraw = Completer<FakeApiResponse>();
      var listCall = 0;
      final api = FakeApi(
        handler: (options) {
          if (options.path.endsWith('/withdraw')) {
            return accountAWithdraw.future;
          }

          listCall++;
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'content': [
                  applicationBody(
                    id: listCall == 1 ? 'hesap_a' : 'hesap_b',
                    jobId: listCall == 1 ? 'is_a' : 'is_b',
                  ),
                ],
              },
            },
          );
        },
      );
      final provider = buildProvider(api);
      await provider.load();

      final accountAResult = provider.withdraw('hesap_a');
      await api.requestsReach(2);

      provider.clear();
      await provider.load();

      accountAWithdraw.complete(
        const FakeApiResponse(
          statusCode: 409,
          body: {
            'success': false,
            'message': 'Eski başvuru artık değiştirilemez',
          },
        ),
      );

      expect(await accountAResult, isFalse);
      expect(provider.applications.map((application) => application.id), [
        'hesap_b',
      ]);
      expect(provider.withdrawingId, isNull);
      expect(provider.errorMessage, isNull);
      expect(api.requests, hasLength(3));
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

    // Geri çekilen başvuru "Başvuru Bekliyor" çiziliyordu: kullanıcı kendi
    // geri çektiği başvuruyu hâlâ değerlendiriliyor sanıyordu.
    test('geri çekilen başvuru kendi durumunu taşır', () async {
      final provider = await loadWith([applicationBody(status: 'WITHDRAWN')]);

      final job = provider.appliedJobs.single;
      expect(job.status, MyJobStatus.withdrawn);
      expect(job.status.displayName, 'Geri Çektin');
      // Üzerinde yapılacak bir şey kalmadı; geçmiş bölümünde duruyor.
      expect(job.isClosed, isTrue);
    });

    // Bilinmeyen durum satırı listeden düşmüyor — kullanıcının sunucuda bir
    // kaydı var — ama hiçbir eylem önermiyor.
    test('tanınmayan durum kendi satırında ve kapalı görünür', () async {
      final provider = await loadWith([applicationBody(status: 'UZAYLI')]);

      final job = provider.appliedJobs.single;
      expect(job.status, MyJobStatus.unknown);
      expect(job.isClosed, isTrue);
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
