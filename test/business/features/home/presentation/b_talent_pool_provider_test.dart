import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/business/features/home/services/talent_pool_service.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';

import '../../../../support/fake_api.dart';

const _workerJson = {
  'id': 'worker-1',
  'firstName': 'Ayşe',
  'lastName': 'Yılmaz',
  'username': 'ayse',
};

const _worker2Json = {
  'id': 'worker-2',
  'firstName': 'Mehmet',
  'lastName': 'Demir',
};

const _ayse = JobCreator(
  id: 'worker-1',
  firstName: 'Ayşe',
  lastName: 'Yılmaz',
  username: 'ayse',
);

Map<String, dynamic> entryJson({
  String id = 'entry-1',
  Map<String, dynamic> worker = _workerJson,
  String? note = 'Geçen hafta çok iyiydi',
}) {
  return {
    'id': id,
    'worker': worker,
    'note': note,
    'createdAt': '2026-09-10T08:00:00Z',
  };
}

FakeApiResponse okPage({
  List<Map<String, dynamic>> content = const [],
  int page = 0,
  bool last = true,
  int totalElements = 0,
}) {
  return FakeApiResponse(
    statusCode: 200,
    body: {
      'success': true,
      'data': {
        'content': content,
        'page': page,
        'size': 20,
        'totalElements': totalElements == 0 ? content.length : totalElements,
        'totalPages': last ? page + 1 : page + 2,
        'first': page == 0,
        'last': last,
      },
    },
  );
}

const _okPut = FakeApiResponse(
  statusCode: 200,
  body: {
    'success': true,
    'data': {
      'id': 'entry-1',
      'worker': _workerJson,
      'note': 'Güvenilir',
      'createdAt': '2026-09-10T08:00:00Z',
    },
  },
);

const _okDelete = FakeApiResponse(statusCode: 200, body: {'success': true});

const _fail = FakeApiResponse(
  statusCode: 500,
  body: {'success': false, 'message': 'Sunucu hatası'},
);

BTalentPoolProvider buildProvider(FakeApi api) {
  return BTalentPoolProvider(service: TalentPoolService.withClient(api.client));
}

void main() {
  group('başlangıç', () {
    test('liste boş ve üyelik bilinmiyor', () {
      final provider = buildProvider(FakeApi(handler: (_) => okPage()));

      expect(provider.entries, isEmpty);
      expect(provider.isInPool('worker-1'), TalentPoolMembership.unknown);
    });
  });

  group('BTalentPoolProvider.load', () {
    test('havuz çekilir ve üyelik evet olur', () async {
      final api = FakeApi(
        handler: (_) => okPage(content: [entryJson()], last: true),
      );
      final provider = buildProvider(api);

      await provider.load();

      expect(api.requests.single.path, '/users/me/talent-pool');
      expect(api.requests.single.queryParameters, {'page': 0, 'size': 20});
      expect(provider.entries.single.worker.firstName, 'Ayşe');
      expect(provider.isInPool('worker-1'), TalentPoolMembership.yes);
      expect(provider.isInPool('worker-yok'), TalentPoolMembership.no);
    });

    test('son sayfa gelmeden listede olmayan üyelik bilinmiyor', () async {
      final api = FakeApi(
        handler: (_) => okPage(content: [entryJson()], last: false),
      );
      final provider = buildProvider(api);

      await provider.load();

      expect(provider.isInPool('worker-1'), TalentPoolMembership.yes);
      expect(provider.isInPool('worker-yok'), TalentPoolMembership.unknown);
    });

    test('hata mesajı saklanır', () async {
      final api = FakeApi(handler: (_) => _fail);
      final provider = buildProvider(api);

      await provider.load();

      expect(provider.errorMessage, 'Sunucu hatası');
      expect(provider.entries, isEmpty);
    });
  });

  group('BTalentPoolProvider.loadMore', () {
    test('sonraki sayfa listenin sonuna eklenir', () async {
      final api = FakeApi(
        handler: (options) {
          final page = options.queryParameters['page'];
          if (page == 0) {
            return okPage(
              content: [entryJson()],
              last: false,
              totalElements: 2,
            );
          }
          return okPage(
            content: [
              entryJson(id: 'entry-2', worker: _worker2Json, note: null),
            ],
            page: 1,
            last: true,
            totalElements: 2,
          );
        },
      );
      final provider = buildProvider(api);

      await provider.load();
      await provider.loadMore();

      expect(api.requests.map((r) => r.queryParameters['page']), [0, 1]);
      expect(provider.entries.map((e) => e.worker.id), [
        'worker-1',
        'worker-2',
      ]);
      expect(provider.isInPool('worker-2'), TalentPoolMembership.yes);
    });

    test('last true iken sonraki sayfa istenmez', () async {
      final api = FakeApi(
        handler: (_) => okPage(content: [entryJson()], last: true),
      );
      final provider = buildProvider(api);

      await provider.load();
      await provider.loadMore();

      expect(api.requests, hasLength(1));
    });
  });

  group('BTalentPoolProvider.addWorker', () {
    test('ekleme PUT atar ve listeye ekler', () async {
      final api = FakeApi(handler: (_) => _okPut);
      final provider = buildProvider(api);

      final ok = await provider.addWorker(_ayse, note: 'Güvenilir');

      expect(ok, isTrue);
      expect(api.requests.single.method, 'PUT');
      expect(api.requests.single.path, '/users/me/talent-pool/worker-1');
      expect(api.requests.single.data, {'note': 'Güvenilir'});
      expect(provider.isInPool('worker-1'), TalentPoolMembership.yes);
      expect(provider.entries.single.note, 'Güvenilir');
    });

    test('istek bitmeden liste güncellenir', () async {
      final api = FakeApi(handler: (_) => _okPut);
      final provider = buildProvider(api);

      final pending = provider.addWorker(_ayse, note: 'Güvenilir');

      expect(
        provider.isInPool('worker-1'),
        TalentPoolMembership.yes,
        reason: 'iyimser güncelleme beklenmeden görünmeli',
      );
      await pending;
    });

    test('sunucu reddederse değişiklik geri alınır', () async {
      final api = FakeApi(handler: (_) => _fail);
      final provider = buildProvider(api);

      final ok = await provider.addWorker(_ayse, note: 'Güvenilir');

      expect(ok, isFalse);
      expect(provider.isInPool('worker-1'), TalentPoolMembership.unknown);
      expect(provider.errorMessage, 'Sunucu hatası');
    });

    test('kendini eklemek Türkçe mesaj verir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Cannot add self',
            'errorCode': 'TALENT_CANNOT_ADD_SELF',
            'errorCategory': 'BUSINESS_RULE_VIOLATION',
          },
        ),
      );
      final provider = buildProvider(api);

      final ok = await provider.addWorker(_ayse, note: 'Ben');

      expect(ok, isFalse);
      expect(
        provider.errorMessage,
        'Kendinizi yetenek havuzuna ekleyemezsiniz.',
      );
      expect(provider.entries, isEmpty);
    });
  });

  group('BTalentPoolProvider.toggleWorker', () {
    test(
      'havuzdaki işçiye ikinci dokunuş DELETE atar, gövdesiz PUT atmaz',
      () async {
        final api = FakeApi(
          handler: (options) {
            if (options.method == 'GET') {
              return okPage(
                content: [entryJson(note: 'Silinmemeli')],
                last: true,
              );
            }
            if (options.method == 'DELETE') return _okDelete;
            return _okPut;
          },
        );
        final provider = buildProvider(api);
        await provider.load();
        expect(provider.entries.single.note, 'Silinmemeli');

        final ok = await provider.toggleWorker(_ayse);

        expect(ok, isTrue);
        expect(api.requests.map((r) => r.method), ['GET', 'DELETE']);
        expect(
          api.requests.where((r) => r.method == 'PUT'),
          isEmpty,
          reason: 'gövdesiz PUT var olan notu siler',
        );
        expect(provider.isInPool('worker-1'), TalentPoolMembership.no);
      },
    );

    test(
      'üyelik bilinmiyorken gövdesiz PUT atılmaz, sayfalar yüklenir',
      () async {
        final api = FakeApi(
          handler: (options) {
            if (options.method == 'GET') {
              final page = options.queryParameters['page'];
              if (page == 0) {
                return okPage(
                  content: [entryJson(id: 'entry-2', worker: _worker2Json)],
                  last: false,
                  totalElements: 2,
                );
              }
              return okPage(
                content: [entryJson(note: 'Korunmalı')],
                page: 1,
                last: true,
                totalElements: 2,
              );
            }
            if (options.method == 'DELETE') return _okDelete;
            return _okPut;
          },
        );
        final provider = buildProvider(api);

        expect(provider.isInPool('worker-1'), TalentPoolMembership.unknown);
        final ok = await provider.toggleWorker(_ayse);

        expect(ok, isTrue);
        expect(api.requests.first.method, 'GET');
        expect(
          api.requests.where((r) => r.method == 'PUT'),
          isEmpty,
          reason: 'bilinmeyen üyelik notu silen PUT atmamalı',
        );
        expect(api.requests.last.method, 'DELETE');
        expect(provider.isInPool('worker-1'), TalentPoolMembership.no);
      },
    );
  });

  group('BTalentPoolProvider.removeWorker', () {
    test('kaldırma iyimser çalışır', () async {
      final api = FakeApi(
        handler: (options) {
          if (options.method == 'GET') {
            return okPage(content: [entryJson()], last: true);
          }
          return _okDelete;
        },
      );
      final provider = buildProvider(api);
      await provider.load();

      final pending = provider.removeWorker('worker-1');
      expect(provider.isInPool('worker-1'), TalentPoolMembership.no);
      expect(await pending, isTrue);
    });

    test('olmayan id istek atmaz ve hata göstermez', () async {
      final api = FakeApi(
        handler: (_) => okPage(content: [entryJson()], last: true),
      );
      final provider = buildProvider(api);
      await provider.load();
      final istekSayisi = api.requests.length;

      final ok = await provider.removeWorker('yok');

      expect(ok, isTrue);
      expect(provider.errorMessage, isNull);
      expect(api.requests, hasLength(istekSayisi));
    });

    test('kaldırma başarısız olursa satır listede kalır', () async {
      final api = FakeApi(
        handler: (options) {
          if (options.method == 'GET') {
            return okPage(content: [entryJson()], last: true);
          }
          return _fail;
        },
      );
      final provider = buildProvider(api);
      await provider.load();

      final ok = await provider.removeWorker('worker-1');

      expect(ok, isFalse);
      expect(provider.isInPool('worker-1'), TalentPoolMembership.yes);
      expect(provider.errorMessage, 'Sunucu hatası');
    });
  });

  group('kapsülleme', () {
    test('entries dışarıdan değiştirilemez', () {
      final provider = buildProvider(FakeApi(handler: (_) => okPage()));

      expect(() => provider.entries.clear(), throwsUnsupportedError);
    });

    test('clear çıkışta kayıtları düşürür', () async {
      final api = FakeApi(
        handler: (_) => okPage(content: [entryJson()], last: true),
      );
      final provider = buildProvider(api);
      await provider.load();

      provider.clear();

      expect(provider.entries, isEmpty);
      expect(provider.hasLoaded, isFalse);
      expect(provider.isInPool('worker-1'), TalentPoolMembership.unknown);
    });

    test('geç eski yanıt yeni hesabın havuzunu ezmez', () async {
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
        okPage(
          content: [entryJson(id: 'hesap_a', worker: _workerJson)],
          last: true,
        ),
      );
      await accountALoad;

      expect(provider.entries, isEmpty);
      expect(provider.isLoading, isTrue);
      expect(provider.hasLoaded, isFalse);
      expect(provider.errorMessage, isNull);

      accountBResponse.complete(
        okPage(
          content: [entryJson(id: 'hesap_b', worker: _worker2Json, note: null)],
          last: true,
        ),
      );
      await accountBLoad;

      expect(provider.entries.single.worker.id, 'worker-2');
      expect(provider.isLoading, isFalse);
      expect(provider.hasLoaded, isTrue);
    });
  });
}
