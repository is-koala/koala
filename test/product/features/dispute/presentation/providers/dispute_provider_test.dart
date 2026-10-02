import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/features/dispute/presentation/providers/dispute_provider.dart';
import 'package:koala/product/features/dispute/services/dispute_evidence_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../../support/dispute_evidence_fixtures.dart';
import '../../../../../support/fake_api.dart';

/// Kanıt servisinin yerine geçer: her çağrının yanıtını testin eline verir.
class _FakeEvidenceService implements DisputeEvidenceService {
  final Map<String, List<DisputeEvidence>> lists = {};
  final List<String> fetched = [];
  final List<Completer<List<DisputeEvidence>>> heldFetches = [];
  bool holdFetches = false;
  Object? fetchError;

  Completer<DisputeEvidence>? uploadGate;
  Object? uploadError;
  final List<({String disputeId, EvidenceFile file})> uploads = [];
  EvidenceUploadProgress? lastProgress;

  Uri? downloadUrl;
  Object? downloadError;
  final List<({String disputeId, String evidenceId})> downloads = [];
  Completer<Uri?>? downloadGate;

  @override
  Future<List<DisputeEvidence>> fetchEvidence(String disputeId) {
    fetched.add(disputeId);
    final error = fetchError;
    if (error != null) return Future.error(error);
    if (holdFetches) {
      final gate = Completer<List<DisputeEvidence>>();
      heldFetches.add(gate);
      return gate.future;
    }
    return Future.value(List.of(lists[disputeId] ?? const []));
  }

  @override
  Future<DisputeEvidence> upload(
    String disputeId,
    EvidenceFile file, {
    EvidenceUploadProgress? onProgress,
  }) {
    uploads.add((disputeId: disputeId, file: file));
    lastProgress = onProgress;
    final error = uploadError;
    if (error != null) return Future.error(error);
    final gate = uploadGate;
    if (gate != null) return gate.future;
    final created = DisputeEvidence.fromJson(
      evidenceJson(
        'new-${uploads.length}',
        disputeId: disputeId,
        fileName: file.uploadName,
        contentType: file.format.mimeType,
        fileSize: file.bytes,
      ),
    );
    lists[disputeId] = [...?lists[disputeId], created];
    return Future.value(created);
  }

  @override
  Future<Uri?> resolveDownload(String disputeId, String evidenceId) {
    downloads.add((disputeId: disputeId, evidenceId: evidenceId));
    final error = downloadError;
    if (error != null) return Future.error(error);
    final gate = downloadGate;
    if (gate != null) return gate.future;
    return Future.value(downloadUrl);
  }
}

class _Fixture {
  _Fixture({List<Map<String, dynamic>>? disputes})
    : disputes = disputes ?? [disputeJson('dispute-1')] {
    assignmentApi = FakeApi(
      handler: (request) {
        disputeReads++;
        final gate = disputeGate;
        if (gate != null) return gate.future;
        if (disputeFailure) {
          return const FakeApiResponse(
            statusCode: 500,
            body: {'success': false, 'message': 'Uyuşmazlıklar alınamadı'},
          );
        }
        return dataResponse(this.disputes);
      },
    );
    provider = DisputeProvider(
      assignmentId: 'assignment-1',
      assignmentService: AssignmentService.withClient(assignmentApi.client),
      evidenceService: evidence,
    );
  }

  final List<Map<String, dynamic>> disputes;
  final _FakeEvidenceService evidence = _FakeEvidenceService();
  late final FakeApi assignmentApi;
  late final DisputeProvider provider;
  int disputeReads = 0;
  bool disputeFailure = false;
  Completer<FakeApiResponse>? disputeGate;

  DisputeCase get only => provider.cases.single;

  void seedEvidence(String disputeId, int count) {
    evidence.lists[disputeId] = [
      for (var i = 0; i < count; i++)
        DisputeEvidence.fromJson(
          evidenceJson('seed-$i', disputeId: disputeId, fileName: 'f$i.jpg'),
        ),
    ];
  }
}

EvidenceCandidate _jpeg([String name = 'foto.jpg']) =>
    candidateFrom(name, jpegSignatureBytes);

ApiException _conflict(String code) => ApiException(
  message: 'Sunucu mesajı',
  type: ApiErrorType.dataConflict,
  statusCode: 409,
  errorCode: code,
);

void main() {
  group('start', () {
    test(
      'uyuşmazlıkları en yeni önde okur, her birinin kanıtını ayrı ister',
      () async {
        final fx = _Fixture(
          disputes: [
            disputeJson(
              'old',
              status: 'RESOLVED',
              createdAt: '2026-09-01T09:00:00Z',
            ),
            disputeJson('new', createdAt: '2026-09-20T09:00:00Z'),
            disputeJson('none', createdAt: '2026-09-10T09:00:00Z')
              ..['createdAt'] = null,
          ],
        );
        fx.seedEvidence('new', 2);

        await fx.provider.start();

        expect(fx.provider.load, DisputeLoad.ready);
        expect(fx.provider.cases.map((c) => c.dispute.id), [
          'new',
          'old',
          'none',
        ]);
        expect(fx.provider.cases.first.evidence, hasLength(2));
        expect(fx.provider.cases.first.isEvidenceKnown, isTrue);
        expect(fx.evidence.fetched.toSet(), {'new', 'old', 'none'});
      },
    );

    test('uyuşmazlık yoksa hata değil, boş liste', () async {
      final fx = _Fixture(disputes: const []);

      await fx.provider.start();

      expect(fx.provider.load, DisputeLoad.ready);
      expect(fx.provider.cases, isEmpty);
    });

    test('uyuşmazlık okunamazsa hata durumu; Tekrar Dene çalışır', () async {
      final fx = _Fixture()..disputeFailure = true;

      await fx.provider.start();
      expect(fx.provider.load, DisputeLoad.failed);
      expect(fx.provider.errorMessage, 'Uyuşmazlıklar alınamadı');

      fx.disputeFailure = false;
      await fx.provider.start();
      expect(fx.provider.load, DisputeLoad.ready);
      expect(fx.provider.errorMessage, isNull);
      expect(fx.provider.cases, hasLength(1));
    });

    test(
      'kanıt listesi okunamazsa o uyuşmazlık "bilinmiyor", ekleme kapalı',
      () async {
        final fx = _Fixture();
        fx.evidence.fetchError = const ApiException(
          message: 'Kanıtlar alınamadı',
          type: ApiErrorType.server,
          statusCode: 500,
        );

        await fx.provider.start();

        final entry = fx.only;
        expect(fx.provider.load, DisputeLoad.ready);
        expect(entry.evidenceError, 'Kanıtlar alınamadı');
        expect(entry.isEvidenceKnown, isFalse);
        // Sayı bilinmiyorken düğme açılmıyor: "0/5" demek yanlış olurdu.
        expect(entry.canAttach, isFalse);

        fx.evidence.fetchError = null;
        await fx.provider.reloadEvidence('dispute-1');
        expect(fx.only.evidenceError, isNull);
        expect(fx.only.canAttach, isTrue);
      },
    );
  });

  group('canAttach', () {
    test('açıkken ve sınırın altında true', () async {
      final fx = _Fixture();
      fx.seedEvidence('dispute-1', 4);
      await fx.provider.start();

      expect(fx.only.canAttach, isTrue);
      expect(fx.only.isLimitReached, isFalse);
    });

    test('beş dosyada sınır, sonuçlanmışta kapalı', () async {
      final limit = _Fixture();
      limit.seedEvidence('dispute-1', 5);
      await limit.provider.start();
      expect(limit.only.canAttach, isFalse);
      expect(limit.only.isLimitReached, isTrue);

      final closed = _Fixture(
        disputes: [disputeJson('dispute-1', status: 'RESOLVED')],
      );
      await closed.provider.start();
      expect(closed.only.canAttach, isFalse);
      expect(closed.only.isLimitReached, isFalse);
    });

    test('incelenen uyuşmazlığa da eklenir', () async {
      final fx = _Fixture(
        disputes: [disputeJson('dispute-1', status: 'UNDER_REVIEW')],
      );
      await fx.provider.start();

      expect(fx.only.canAttach, isTrue);
    });
  });

  group('attach', () {
    test('yükler, listeye ekler, sunucudan yeniden okur', () async {
      final fx = _Fixture();
      await fx.provider.start();
      final reads = fx.evidence.fetched.length;

      final result = await fx.provider.attach('dispute-1', _jpeg());

      expect(result.isAttached, isTrue);
      expect(fx.evidence.uploads.single.disputeId, 'dispute-1');
      expect(fx.evidence.uploads.single.file.format, EvidenceFormat.jpeg);
      expect(fx.only.evidence.map((e) => e.id), ['new-1']);
      expect(fx.provider.isUploading, isFalse);
      // Yükleme sonrası liste sunucudan bir kez daha okundu.
      expect(fx.evidence.fetched.length, reads + 1);
    });

    test('ilerleme oranı bildirilir, bitince yükleme kalkar', () async {
      final fx = _Fixture();
      await fx.provider.start();
      fx.evidence.uploadGate = Completer<DisputeEvidence>();

      final pending = fx.provider.attach('dispute-1', _jpeg('kanit.jpg'));
      await Future<void>.delayed(Duration.zero);

      final upload = fx.provider.upload!;
      expect(upload.disputeId, 'dispute-1');
      expect(upload.fileName, 'kanit.jpg');
      expect(upload.fraction, isNull, reason: 'boyut henüz bilinmiyor');

      fx.evidence.lastProgress!(30, 120);
      expect(fx.provider.upload!.fraction, closeTo(0.25, 1e-9));
      fx.evidence.lastProgress!(500, 120);
      expect(fx.provider.upload!.fraction, 1.0, reason: 'oran 1\'i aşmaz');

      fx.evidence.uploadGate!.complete(
        DisputeEvidence.fromJson(evidenceJson('ev-new')),
      );
      expect((await pending).isAttached, isTrue);
      expect(fx.provider.upload, isNull);
    });

    test('sınırlardan dönen dosya sunucuya gitmez', () async {
      final fx = _Fixture();
      await fx.provider.start();
      final heic = candidateFrom('IMG.heic', heicSignatureBytes);

      final result = await fx.provider.attach('dispute-1', heic);

      expect(result.rejection, EvidenceRejection.heic);
      expect(result.message, contains('HEIC'));
      expect(fx.evidence.uploads, isEmpty);
      expect(fx.provider.isUploading, isFalse);
    });

    test('ikinci yükleme sürerken başlamaz', () async {
      final fx = _Fixture();
      await fx.provider.start();
      fx.evidence.uploadGate = Completer<DisputeEvidence>();

      final first = fx.provider.attach('dispute-1', _jpeg('bir.jpg'));
      await Future<void>.delayed(Duration.zero);
      final second = await fx.provider.attach('dispute-1', _jpeg('iki.jpg'));

      expect(second.isAttached, isFalse);
      expect(second.message, isNull, reason: 'busy sessizdir');
      expect(fx.evidence.uploads, hasLength(1));

      fx.evidence.uploadGate!.complete(
        DisputeEvidence.fromJson(evidenceJson('ev-1')),
      );
      await first;
    });

    test(
      'sonuçlanmış uyuşmazlık 409: mesaj söyler, sayfa kendini yeniden okur',
      () async {
        final fx = _Fixture();
        await fx.provider.start();
        fx.evidence.uploadError = _conflict('DISPUTE_EVIDENCE_DISPUTE_CLOSED');
        // Sunucu bu arada uyuşmazlığı sonuçlandırmış.
        fx.disputes
          ..clear()
          ..add(disputeJson('dispute-1', status: 'RESOLVED'));
        final readsBefore = fx.disputeReads;

        final result = await fx.provider.attach('dispute-1', _jpeg());

        expect(result.failure!.message, contains('sonuçlanmış'));
        expect(fx.disputeReads, readsBefore + 1);
        expect(fx.only.dispute.isOpen, isFalse);
        expect(fx.only.canAttach, isFalse);
        expect(fx.provider.isUploading, isFalse);
      },
    );

    test('sınır dolu 409: yeniden okur', () async {
      final fx = _Fixture();
      await fx.provider.start();
      fx.evidence.uploadError = _conflict('DISPUTE_EVIDENCE_LIMIT_REACHED');
      fx.seedEvidence('dispute-1', 5);
      final readsBefore = fx.disputeReads;

      final result = await fx.provider.attach('dispute-1', _jpeg());

      expect(result.failure!.message, contains('5'));
      expect(fx.disputeReads, readsBefore + 1);
      expect(fx.only.isLimitReached, isTrue);
    });

    test('dosya hatası ve 429 sayfayı yeniden okutmaz', () async {
      final fx = _Fixture();
      await fx.provider.start();
      final readsBefore = fx.disputeReads;

      fx.evidence.uploadError = const ApiException(
        message: 'x',
        type: ApiErrorType.validation,
        statusCode: 400,
        errorCode: 'STORAGE_UNSUPPORTED_TYPE',
      );
      final unsupported = await fx.provider.attach('dispute-1', _jpeg());
      expect(unsupported.message, contains('PDF, PNG, JPG'));

      fx.evidence.uploadError = const ApiException(
        message: 'x',
        type: ApiErrorType.tooManyRequests,
        statusCode: 429,
      );
      final limited = await fx.provider.attach('dispute-1', _jpeg());
      expect(limited.message, contains('bekleyip'));

      expect(fx.disputeReads, readsBefore);
      expect(fx.provider.isUploading, isFalse);
    });

    // Yükleme biterken başlamış eski bir okuma yeni dosyayı silmemeli.
    test('eski kanıt okuması yeni yüklenen dosyayı silmez', () async {
      final fx = _Fixture();
      await fx.provider.start();

      fx.evidence.holdFetches = true;
      final stale = fx.provider.reloadEvidence('dispute-1');
      await Future<void>.delayed(Duration.zero);
      expect(fx.evidence.heldFetches, hasLength(1));

      // Yükleme tamamlanıyor, ardından kendi okumasını başlatıyor.
      final attached = fx.provider.attach('dispute-1', _jpeg());
      await Future<void>.delayed(Duration.zero);
      expect(fx.evidence.heldFetches, hasLength(2));

      // Eski okuma (yüklemeden önceki liste) en son dönüyor.
      fx.evidence.heldFetches[1].complete([
        DisputeEvidence.fromJson(evidenceJson('new-1')),
      ]);
      await attached;
      fx.evidence.heldFetches[0].complete(const []);
      await stale;

      expect(fx.only.evidence.map((e) => e.id), ['new-1']);
    });

    test('sayfa kapanırken biten yükleme dinleyiciyi uyandırmaz', () async {
      final fx = _Fixture();
      await fx.provider.start();
      fx.evidence.uploadGate = Completer<DisputeEvidence>();
      var notifications = 0;
      fx.provider.addListener(() => notifications++);

      final pending = fx.provider.attach('dispute-1', _jpeg());
      await Future<void>.delayed(Duration.zero);
      final before = notifications;
      fx.provider.dispose();
      fx.evidence.uploadGate!.complete(
        DisputeEvidence.fromJson(evidenceJson('ev-1')),
      );
      await pending;

      expect(notifications, before);
    });
  });

  group('refresh', () {
    test('satırlar ve kanıtlar yenisi gelene kadar yerinde kalır', () async {
      final fx = _Fixture();
      fx.seedEvidence('dispute-1', 2);
      await fx.provider.start();
      fx.disputeGate = Completer<FakeApiResponse>();

      final refreshing = fx.provider.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(fx.provider.isRefreshing, isTrue);
      expect(fx.provider.load, DisputeLoad.ready);
      expect(fx.only.evidence, hasLength(2));

      fx.disputeGate!.complete(
        dataResponse([disputeJson('dispute-1', status: 'UNDER_REVIEW')]),
      );
      await refreshing;

      expect(fx.provider.isRefreshing, isFalse);
      expect(fx.only.dispute.status.code, 'UNDER_REVIEW');
      expect(fx.only.evidence, hasLength(2));
    });

    test('başarısız yenileme eldeki listeyi korur', () async {
      final fx = _Fixture();
      fx.seedEvidence('dispute-1', 1);
      await fx.provider.start();
      fx.disputeFailure = true;

      await fx.provider.refresh();

      expect(fx.provider.load, DisputeLoad.ready);
      expect(fx.provider.errorMessage, 'Uyuşmazlıklar alınamadı');
      expect(fx.only.evidence, hasLength(1));
    });

    test('eski okumanın geç dönen yanıtı yeni listeyi ezmez', () async {
      final fx = _Fixture();
      fx.disputeGate = Completer<FakeApiResponse>();
      final first = fx.provider.start();
      await Future<void>.delayed(Duration.zero);

      final firstGate = fx.disputeGate!;
      fx.disputeGate = null;
      final second = fx.provider.start();
      await second;

      // Eski istek (tek uyuşmazlık: `old`) en son dönüyor.
      firstGate.complete(dataResponse([disputeJson('old')]));
      await first;

      expect(fx.provider.cases.map((c) => c.dispute.id), ['dispute-1']);
    });
  });

  group('download', () {
    test('imzalı adresi verir ve indirme bitince kilidi açar', () async {
      final fx = _Fixture();
      fx.seedEvidence('dispute-1', 1);
      await fx.provider.start();
      fx.evidence.downloadUrl = Uri.parse('https://depo.example/k?imza=1');

      final result = await fx.provider.download(fx.only.evidence.single);

      expect(result.url, Uri.parse('https://depo.example/k?imza=1'));
      expect(fx.evidence.downloads.single, (
        disputeId: 'dispute-1',
        evidenceId: 'seed-0',
      ));
      expect(fx.provider.downloadingId, isNull);
    });

    test('sunucu baytları akıtıyorsa "streamed"', () async {
      final fx = _Fixture();
      fx.seedEvidence('dispute-1', 1);
      await fx.provider.start();

      final result = await fx.provider.download(fx.only.evidence.single);

      expect(result.isStreamed, isTrue);
      expect(result.url, isNull);
    });

    test('ikinci indirme sürerken başlamaz', () async {
      final fx = _Fixture();
      fx.seedEvidence('dispute-1', 2);
      await fx.provider.start();
      fx.evidence.downloadGate = Completer<Uri?>();

      final first = fx.provider.download(fx.only.evidence.first);
      await Future<void>.delayed(Duration.zero);
      expect(fx.provider.downloadingId, 'seed-0');

      final second = await fx.provider.download(fx.only.evidence.last);
      expect(second.url, isNull);
      expect(second.failure, isNull);
      expect(second.isStreamed, isFalse);
      expect(fx.evidence.downloads, hasLength(1));

      fx.evidence.downloadGate!.complete(Uri.parse('https://depo.example/x'));
      await first;
      expect(fx.provider.downloadingId, isNull);
    });

    test('kanıt bulunamazsa mesaj söyler ve listeyi yeniden okur', () async {
      final fx = _Fixture();
      fx.seedEvidence('dispute-1', 1);
      await fx.provider.start();
      fx.evidence.downloadError = const ApiException(
        message: 'x',
        type: ApiErrorType.notFound,
        statusCode: 404,
        errorCode: 'DISPUTE_EVIDENCE_NOT_FOUND',
      );
      final reads = fx.evidence.fetched.length;

      final result = await fx.provider.download(fx.only.evidence.single);

      expect(result.failure!.message, contains('Kanıt dosyası bulunamadı'));
      expect(fx.evidence.fetched.length, reads + 1);
    });
  });
}
