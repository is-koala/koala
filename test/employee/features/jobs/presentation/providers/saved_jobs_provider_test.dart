import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/employee/features/jobs/services/saved_jobs_service.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/fixtures.dart';

Map<String, dynamic> jobBody({String id = 'job_1', String title = 'Garson'}) {
  return {
    'id': id,
    'title': title,
    'category': {'id': 'c', 'code': 'WAITER', 'name': 'Garsonluk'},
    'type': 'ONE_TIME',
    'salary': 800,
    'status': 'OPEN',
  };
}

FakeApiResponse okList(List<Map<String, dynamic>> jobs) {
  return FakeApiResponse(
    statusCode: 200,
    body: {'success': true, 'data': jobs},
  );
}

const _ok = FakeApiResponse(statusCode: 200, body: {'success': true});

const _fail = FakeApiResponse(
  statusCode: 500,
  body: {'success': false, 'message': 'Sunucu hatası'},
);

SavedJobsProvider buildProvider(FakeApi api) {
  return SavedJobsProvider(service: SavedJobsService.withClient(api.client));
}

void main() {
  group('başlangıç', () {
    test('liste boş', () {
      final provider = buildProvider(FakeApi(handler: (_) => okList(const [])));

      expect(provider.savedJobs, isEmpty);
      expect(provider.isSaved('job_1'), isFalse);
    });
  });

  group('SavedJobsProvider.load', () {
    test('kayıtlı ilanlar çekilir', () async {
      final api = FakeApi(handler: (_) => okList([jobBody()]));
      final provider = buildProvider(api);

      await provider.load();

      expect(api.requests.single.path, '/users/me/saved-jobs');
      expect(provider.savedJobs.single.title, 'Garson');
      expect(provider.isSaved('job_1'), isTrue);
    });

    test('ikinci çağrı ağa çıkmaz, force ile çıkar', () async {
      final api = FakeApi(handler: (_) => okList(const []));
      final provider = buildProvider(api);

      await provider.load();
      await provider.load();
      expect(api.requests, hasLength(1));

      await provider.load(force: true);
      expect(api.requests, hasLength(2));
    });

    test('hata mesajı saklanır', () async {
      final api = FakeApi(handler: (_) => _fail);
      final provider = buildProvider(api);

      await provider.load();

      expect(provider.errorMessage, 'Sunucu hatası');
      expect(provider.savedJobs, isEmpty);
    });
  });

  group('SavedJobsProvider.toggleSave', () {
    test('kaydetme POST atar ve listeye ekler', () async {
      final api = FakeApi(handler: (_) => _ok);
      final provider = buildProvider(api);

      final ok = await provider.toggleSave(buildJob(id: 'job_1'));

      expect(ok, isTrue);
      expect(api.requests.single.method, 'POST');
      expect(api.requests.single.path, '/users/me/saved-jobs/job_1');
      expect(provider.isSaved('job_1'), isTrue);
    });

    test('ikinci çağrı DELETE atar ve listeden çıkarır', () async {
      final api = FakeApi(handler: (_) => _ok);
      final provider = buildProvider(api);
      final job = buildJob(id: 'job_1');

      await provider.toggleSave(job);
      await provider.toggleSave(job);

      expect(api.requests.map((r) => r.method), ['POST', 'DELETE']);
      expect(provider.isSaved('job_1'), isFalse);
    });

    // İkon dokunur dokunmaz değişmeli; istek arkada gidiyor.
    test('istek bitmeden liste güncellenir', () async {
      final api = FakeApi(handler: (_) => _ok);
      final provider = buildProvider(api);

      final pending = provider.toggleSave(buildJob(id: 'job_1'));

      expect(
        provider.isSaved('job_1'),
        isTrue,
        reason: 'iyimser güncelleme beklenmeden görünmeli',
      );
      await pending;
    });

    test('sunucu reddederse değişiklik geri alınır', () async {
      final api = FakeApi(handler: (_) => _fail);
      final provider = buildProvider(api);

      final ok = await provider.toggleSave(buildJob(id: 'job_1'));

      expect(ok, isFalse);
      expect(provider.isSaved('job_1'), isFalse, reason: 'geri alınmalı');
      expect(provider.errorMessage, 'Sunucu hatası');
    });

    test('kaldırma başarısız olursa ilan listede kalır', () async {
      var shouldFail = false;
      final api = FakeApi(handler: (_) => shouldFail ? _fail : _ok);
      final provider = buildProvider(api);
      final job = buildJob(id: 'job_1');

      await provider.toggleSave(job);
      shouldFail = true;
      final ok = await provider.toggleSave(job);

      expect(ok, isFalse);
      expect(provider.isSaved('job_1'), isTrue, reason: 'geri alınmalı');
    });

    test('aynı id\'li farklı nesne kopya kayıt açmaz', () async {
      final api = FakeApi(handler: (_) => _ok);
      final provider = buildProvider(api);

      await provider.toggleSave(buildJob(id: 'job_1', title: 'A'));
      await provider.toggleSave(buildJob(id: 'job_1', title: 'B'));

      expect(provider.savedJobs, isEmpty);
    });

    test('birden fazla ilan bağımsız tutulur', () async {
      final api = FakeApi(handler: (_) => _ok);
      final provider = buildProvider(api);

      await provider.toggleSave(buildJob(id: 'job_1'));
      await provider.toggleSave(buildJob(id: 'job_2'));

      expect(provider.savedJobs, hasLength(2));
      expect(provider.isSaved('job_1'), isTrue);
      expect(provider.isSaved('job_2'), isTrue);
    });
  });

  group('SavedJobsProvider.removeJob', () {
    test('kaydı siler', () async {
      final api = FakeApi(handler: (_) => _ok);
      final provider = buildProvider(api);
      await provider.toggleSave(buildJob(id: 'job_1'));

      final ok = await provider.removeJob('job_1');

      expect(ok, isTrue);
      expect(provider.savedJobs, isEmpty);
    });

    test('olmayan id ile çağrılınca listeyi bozmaz ve istek atmaz', () async {
      final api = FakeApi(handler: (_) => _ok);
      final provider = buildProvider(api);
      await provider.toggleSave(buildJob(id: 'job_1'));
      final istekSayisi = api.requests.length;

      final ok = await provider.removeJob('yok');

      expect(ok, isFalse);
      expect(provider.savedJobs, hasLength(1));
      expect(api.requests, hasLength(istekSayisi));
    });
  });

  group('kapsülleme', () {
    test('savedJobs dışarıdan değiştirilemez', () {
      final provider = buildProvider(FakeApi(handler: (_) => okList(const [])));

      expect(() => provider.savedJobs.clear(), throwsUnsupportedError);
    });

    test('clear çıkışta kayıtları düşürür', () async {
      final api = FakeApi(handler: (_) => okList([jobBody()]));
      final provider = buildProvider(api);
      await provider.load();

      provider.clear();

      expect(provider.savedJobs, isEmpty);
      expect(provider.hasLoaded, isFalse);
    });
  });
}
