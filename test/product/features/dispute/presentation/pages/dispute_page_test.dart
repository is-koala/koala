import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/features/dispute/presentation/pages/dispute_page.dart';
import 'package:koala/product/features/dispute/services/dispute_evidence_service.dart';
import 'package:koala/product/features/dispute/services/evidence_picker.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/dispute_evidence_fixtures.dart';
import '../../../../../support/fake_api.dart';

/// Sahte sunucu: atamanın uyuşmazlıkları, uyuşmazlık başına kanıtlar, yükleme
/// ve indirme. Durum testin elinde değişebiliyor.
class _Backend {
  _Backend({List<Map<String, dynamic>>? disputes})
    : disputes = disputes ?? [disputeJson('dispute-1')] {
    api = FakeApi(handler: _handle);
  }

  final List<Map<String, dynamic>> disputes;
  final Map<String, List<Map<String, dynamic>>> evidence = {};
  late final FakeApi api;

  /// Doluysa yükleme yanıtını bekletir.
  Completer<FakeApiResponse>? uploadGate;
  FakeApiResponse? uploadOverride;
  FakeApiResponse downloadResponse = const FakeApiResponse(
    statusCode: 302,
    headers: {'location': 'https://depo.example/k?imza=1'},
  );
  bool failDisputes = false;
  bool failEvidence = false;

  List<RequestOptions> get uploads => [
    for (final request in api.requests)
      if (request.method == 'POST') request,
  ];

  int get disputeReads => api.requests
      .where((r) => r.method == 'GET' && r.path.endsWith('/disputes'))
      .length;

  FutureOr<FakeApiResponse> _handle(RequestOptions request) {
    final path = request.path;
    if (path == '/job-assignments/assignment-1/disputes') {
      if (failDisputes) {
        return const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Uyuşmazlıklar alınamadı'},
        );
      }
      return dataResponse(disputes);
    }
    final download = RegExp(r'^/disputes/([^/]+)/evidence/([^/]+)/download$');
    if (download.hasMatch(path)) return downloadResponse;

    final match = RegExp(r'^/disputes/([^/]+)/evidence$').firstMatch(path);
    if (match != null) {
      final id = match.group(1)!;
      if (request.method == 'GET') {
        if (failEvidence) {
          return const FakeApiResponse(
            statusCode: 500,
            body: {'success': false, 'message': 'Kanıtlar alınamadı'},
          );
        }
        return dataResponse(evidence[id] ?? const []);
      }
      final gate = uploadGate;
      final override = uploadOverride;
      if (override != null) return override;
      FakeApiResponse create() {
        final form = request.data as FormData;
        final part = form.files.single.value;
        final created = evidenceJson(
          'created-${evidence[id]?.length ?? 0}',
          disputeId: id,
          fileName: part.filename!,
          contentType: part.contentType?.mimeType ?? 'application/octet-stream',
          fileSize: part.length,
          uploader: 'Ayşe',
        );
        evidence[id] = [...?evidence[id], created];
        return dataResponse(created, statusCode: 201);
      }

      return gate == null ? create() : gate.future.then((_) => create());
    }
    return const FakeApiResponse(statusCode: 404, body: {'success': false});
  }
}

Future<List<Uri>> _pump(
  WidgetTester tester,
  _Backend backend, {
  FakeEvidencePicker? picker,
  Brightness brightness = Brightness.light,
  bool opensExternally = true,
}) async {
  tester.view.physicalSize = const Size(1170, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final opened = <Uri>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? darkTheme : lightTheme,
      home: DisputePage(
        assignmentId: 'assignment-1',
        assignmentService: AssignmentService.withClient(backend.api.client),
        evidenceService: DisputeEvidenceService.withClient(backend.api.client),
        picker: picker ?? FakeEvidencePicker([]),
        openExternalUrl: (url) async {
          opened.add(url);
          return opensExternally;
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Future<void> _chooseSource(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('evidence-add-dispute-1')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    group('DisputePage (${brightness.name})', () {
      testWidgets('uyuşmazlığı, gerekçeyi ve kanıtları çizer', (tester) async {
        final backend =
            _Backend(
                disputes: [
                  disputeJson('dispute-1', reason: 'Ücret eksik ödendi'),
                  disputeJson(
                    'dispute-0',
                    status: 'RESOLVED',
                    reason: 'Eski sorun',
                    createdAt: '2026-08-01T09:00:00Z',
                    resolution: 'REFUND_EMPLOYER',
                    resolutionNote: 'Destek ekibi iade etti',
                  ),
                ],
              )
              ..evidence['dispute-1'] = [
                evidenceJson('ev-1', fileName: 'vardiya.jpg', fileSize: 1536),
                evidenceJson(
                  'ev-2',
                  fileName: 'tutanak.pdf',
                  contentType: 'application/pdf',
                  fileSize: 2 * 1024 * 1024,
                  uploader: 'Mehmet',
                ),
              ]
              ..evidence['dispute-0'] = [
                evidenceJson(
                  'ev-0',
                  disputeId: 'dispute-0',
                  fileName: 'eski.png',
                ),
              ];

        await _pump(tester, backend, brightness: brightness);

        expect(find.text('Sorun Bildirimi'), findsOneWidget);
        expect(find.text('Açık'), findsOneWidget);
        expect(find.text('Sonuçlandı'), findsOneWidget);
        expect(find.text('Ücret eksik ödendi'), findsOneWidget);
        // En yeni önde.
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('dispute-dispute-1'))).dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const ValueKey('dispute-dispute-0')))
                .dy,
          ),
        );

        expect(find.text('Kanıtlar (2/5)'), findsOneWidget);
        expect(find.text('vardiya.jpg'), findsOneWidget);
        expect(find.textContaining('1,5 KB'), findsOneWidget);
        expect(find.text('tutanak.pdf'), findsOneWidget);
        expect(find.textContaining('Mehmet Yılmaz · 2 MB'), findsOneWidget);

        // Sonuçlanmış uyuşmazlığın sonucu ve dosyası da görünüyor.
        expect(find.text('Ücret işverene iade edildi'), findsOneWidget);
        expect(find.text('Destek ekibi iade etti'), findsOneWidget);
        expect(find.text('eski.png'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('açık uyuşmazlıkta ekleme, sınır ve metadata uyarısı var', (
        tester,
      ) async {
        final backend = _Backend();
        await _pump(tester, backend, brightness: brightness);

        expect(
          find.byKey(const ValueKey('evidence-add-dispute-1')),
          findsOneWidget,
        );
        expect(find.text('Henüz kanıt eklenmedi.'), findsOneWidget);
        expect(
          find.textContaining('dosya başına en fazla 10 MB'),
          findsOneWidget,
        );
        // EXIF/konum bilgisinin dosyayla gittiği ve karşı tarafın gördüğü.
        final note = find.byKey(const ValueKey('evidence-metadata-note'));
        expect(note, findsOneWidget);
        expect(
          (tester.widget(note) as Text).data,
          allOf(contains('konum'), contains('Karşı taraf')),
        );
      });

      testWidgets('sonuçlanmış uyuşmazlıkta ekleme yok, neden yazıyor', (
        tester,
      ) async {
        final backend = _Backend(
          disputes: [disputeJson('dispute-1', status: 'RESOLVED')],
        )..evidence['dispute-1'] = [evidenceJson('ev-1')];
        await _pump(tester, backend, brightness: brightness);

        expect(
          find.byKey(const ValueKey('evidence-add-dispute-1')),
          findsNothing,
        );
        expect(find.textContaining('yeni kanıt eklenemez'), findsOneWidget);
        // Mevcut dosya hâlâ indirilebilir.
        expect(find.text('vardiya.jpg'), findsOneWidget);
      });

      testWidgets('beş dosyada sınır notu çıkar, düğme kalkar', (tester) async {
        final backend = _Backend()
          ..evidence['dispute-1'] = [
            for (var i = 0; i < 5; i++)
              evidenceJson('ev-$i', fileName: 'f$i.jpg'),
          ];
        await _pump(tester, backend, brightness: brightness);

        expect(find.text('Kanıtlar (5/5)'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('evidence-limit-note')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('evidence-add-dispute-1')),
          findsNothing,
        );
      });

      testWidgets('galeriden seçilen fotoğraf yüklenir ve listeye girer', (
        tester,
      ) async {
        final backend = _Backend();
        final picker = FakeEvidencePicker([
          candidateFrom(
            'IMG_1.heic',
            jpegSignatureBytes,
            displayName: 'foto-20261003-104231',
          ),
        ]);
        await _pump(tester, backend, picker: picker, brightness: brightness);

        await _chooseSource(tester, 'Galeriden seç');

        expect(picker.sources, [EvidenceSource.gallery]);
        final upload = backend.uploads.single;
        final part = (upload.data as FormData).files.single;
        expect(part.key, 'file');
        expect(part.value.filename, 'foto-20261003-104231.jpg');
        expect(part.value.contentType?.mimeType, 'image/jpeg');

        expect(find.text('Kanıt eklendi.'), findsOneWidget);
        expect(find.text('foto-20261003-104231.jpg'), findsOneWidget);
        expect(find.text('Kanıtlar (1/5)'), findsOneWidget);
      });

      testWidgets('kamera ve PDF seçenekleri kendi kaynaklarını çağırır', (
        tester,
      ) async {
        final backend = _Backend();
        final picker = FakeEvidencePicker([
          candidateFrom('a.jpg', jpegSignatureBytes, displayName: 'foto-1'),
          candidateFrom('tutanak.pdf', pdfBytes),
        ]);
        await _pump(tester, backend, picker: picker, brightness: brightness);

        await _chooseSource(tester, 'Fotoğraf çek');
        await _chooseSource(tester, 'PDF belgesi seç');

        expect(picker.sources, [
          EvidenceSource.camera,
          EvidenceSource.document,
        ]);
        expect(find.text('tutanak.pdf'), findsOneWidget);
        expect(find.text('Kanıtlar (2/5)'), findsOneWidget);
      });

      testWidgets('yükleme sürerken ilerleme şeridi çıkar, ekleme kilitlenir', (
        tester,
      ) async {
        final backend = _Backend()..uploadGate = Completer<FakeApiResponse>();
        final picker = FakeEvidencePicker([
          candidateFrom('a.jpg', jpegSignatureBytes, displayName: 'kanit-foto'),
        ]);
        await _pump(tester, backend, picker: picker, brightness: brightness);

        await tester.tap(find.byKey(const ValueKey('evidence-add-dispute-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Galeriden seç'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byKey(const ValueKey('evidence-upload')), findsOneWidget);
        expect(find.textContaining('kanit-foto.jpg'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('evidence-upload-bar')),
          findsOneWidget,
        );
        final add = tester.widget<OutlinedButton>(
          find.byKey(const ValueKey('evidence-add-dispute-1')),
        );
        expect(add.onPressed, isNull, reason: 'ikinci yükleme başlamasın');

        backend.uploadGate!.complete(dataResponse(<String, dynamic>{}));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('evidence-upload')), findsNothing);
      });

      testWidgets('HEIC sunucuya gitmeden reddedilir', (tester) async {
        final backend = _Backend();
        final picker = FakeEvidencePicker([
          candidateFrom('IMG.heic', heicSignatureBytes),
        ]);
        await _pump(tester, backend, picker: picker, brightness: brightness);

        await _chooseSource(tester, 'Galeriden seç');

        expect(find.textContaining('HEIC biçiminde'), findsOneWidget);
        expect(backend.uploads, isEmpty);
      });

      testWidgets('seçici vazgeçilirse hiçbir şey olmaz', (tester) async {
        final backend = _Backend();
        await _pump(
          tester,
          backend,
          picker: FakeEvidencePicker([null]),
          brightness: brightness,
        );

        await _chooseSource(tester, 'Galeriden seç');

        expect(backend.uploads, isEmpty);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('kamera izni reddedilince yönlendiren mesaj çıkar', (
        tester,
      ) async {
        final backend = _Backend();
        final picker = FakeEvidencePicker(
          [],
          error: PlatformException(code: 'camera_access_denied'),
        );
        await _pump(tester, backend, picker: picker, brightness: brightness);

        await _chooseSource(tester, 'Fotoğraf çek');

        expect(find.textContaining('Kameraya erişim izni'), findsOneWidget);
        expect(backend.uploads, isEmpty);
      });

      testWidgets('sunucu "sonuçlandı" derse mesaj çıkar ve sayfa yenilenir', (
        tester,
      ) async {
        final backend = _Backend();
        backend.uploadOverride = errorResponse(
          409,
          'DISPUTE_EVIDENCE_DISPUTE_CLOSED',
          category: 'DATA_CONFLICT',
        );
        final picker = FakeEvidencePicker([candidateFrom('a.pdf', pdfBytes)]);
        await _pump(tester, backend, picker: picker, brightness: brightness);
        final readsBefore = backend.disputeReads;

        // Sunucu bu arada uyuşmazlığı sonuçlandırmış.
        backend.disputes
          ..clear()
          ..add(disputeJson('dispute-1', status: 'RESOLVED'));
        await _chooseSource(tester, 'PDF belgesi seç');

        expect(
          find.textContaining('Bu uyuşmazlık sonuçlanmış'),
          findsOneWidget,
        );
        expect(backend.disputeReads, readsBefore + 1);
        expect(
          find.byKey(const ValueKey('evidence-add-dispute-1')),
          findsNothing,
        );
        expect(find.text('Sonuçlandı'), findsOneWidget);
      });

      testWidgets('sınır doldu 409: mesaj ve sınır notu', (tester) async {
        final backend = _Backend();
        backend.uploadOverride = errorResponse(
          409,
          'DISPUTE_EVIDENCE_LIMIT_REACHED',
          category: 'DATA_CONFLICT',
        );
        final picker = FakeEvidencePicker([candidateFrom('a.pdf', pdfBytes)]);
        await _pump(tester, backend, picker: picker, brightness: brightness);
        backend.evidence['dispute-1'] = [
          for (var i = 0; i < 5; i++)
            evidenceJson('ev-$i', fileName: 'f$i.jpg'),
        ];

        await _chooseSource(tester, 'PDF belgesi seç');

        expect(find.textContaining('en fazla 5 kanıt'), findsWidgets);
        expect(
          find.byKey(const ValueKey('evidence-limit-note')),
          findsOneWidget,
        );
      });

      testWidgets('dosyaya dokunmak imzalı adresi harici tarayıcıda açar', (
        tester,
      ) async {
        final backend = _Backend()
          ..evidence['dispute-1'] = [
            evidenceJson('ev-1', fileName: 'vardiya.jpg'),
          ];
        final opened = await _pump(tester, backend, brightness: brightness);

        await tester.tap(find.byKey(const ValueKey('evidence-ev-1')));
        await tester.pumpAndSettle();

        expect(opened, [Uri.parse('https://depo.example/k?imza=1')]);
        final download = backend.api.requests.last;
        expect(download.path, '/disputes/dispute-1/evidence/ev-1/download');
        expect(download.followRedirects, isFalse);
      });

      testWidgets('adres açılamazsa toast söyler', (tester) async {
        final backend = _Backend()
          ..evidence['dispute-1'] = [evidenceJson('ev-1')];
        await _pump(
          tester,
          backend,
          brightness: brightness,
          opensExternally: false,
        );

        await tester.tap(find.byKey(const ValueKey('evidence-ev-1')));
        await tester.pumpAndSettle();

        expect(find.text('Dosya açılamadı.'), findsOneWidget);
      });

      testWidgets(
        'sunucu baytları akıtıyorsa uygulama içinde açılamadığını söyler',
        (tester) async {
          final backend = _Backend()
            ..evidence['dispute-1'] = [evidenceJson('ev-1')]
            ..downloadResponse = dataResponse(<String, dynamic>{});
          final opened = await _pump(tester, backend, brightness: brightness);

          await tester.tap(find.byKey(const ValueKey('evidence-ev-1')));
          await tester.pumpAndSettle();

          expect(opened, isEmpty);
          expect(
            find.textContaining('uygulamadan indirilemiyor'),
            findsOneWidget,
          );
        },
      );

      testWidgets('indirme 404 ise mesaj çıkar', (tester) async {
        final backend = _Backend()
          ..evidence['dispute-1'] = [evidenceJson('ev-1')]
          ..downloadResponse = errorResponse(
            404,
            'DISPUTE_EVIDENCE_NOT_FOUND',
            category: 'RESOURCE_NOT_FOUND',
          );
        await _pump(tester, backend, brightness: brightness);

        await tester.tap(find.byKey(const ValueKey('evidence-ev-1')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Kanıt dosyası bulunamadı'), findsOneWidget);
      });

      testWidgets('kanıt listesi okunamazsa o kartta Tekrar Dene çıkar', (
        tester,
      ) async {
        final backend = _Backend()..failEvidence = true;
        await _pump(tester, backend, brightness: brightness);

        expect(find.text('Kanıtlar alınamadı'), findsOneWidget);
        // Sayı bilinmiyor: ekleme düğmesi çizilmiyor.
        expect(
          find.byKey(const ValueKey('evidence-add-dispute-1')),
          findsNothing,
        );
        expect(find.text('Henüz kanıt eklenmedi.'), findsNothing);

        backend.failEvidence = false;
        await tester.tap(
          find.byKey(const ValueKey('evidence-retry-dispute-1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Henüz kanıt eklenmedi.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('evidence-add-dispute-1')),
          findsOneWidget,
        );
      });

      testWidgets('uyuşmazlık yoksa boş durum', (tester) async {
        await _pump(
          tester,
          _Backend(disputes: const []),
          brightness: brightness,
        );

        expect(find.text('Bildirilmiş bir sorun yok'), findsOneWidget);
        expect(find.text('Tekrar Dene'), findsNothing);
      });

      testWidgets('uyuşmazlıklar okunamazsa hata ve Tekrar Dene', (
        tester,
      ) async {
        final backend = _Backend()..failDisputes = true;
        await _pump(tester, backend, brightness: brightness);

        expect(find.text('Uyuşmazlıklar alınamadı'), findsOneWidget);
        expect(find.text('Bildirilmiş bir sorun yok'), findsNothing);

        backend.failDisputes = false;
        await tester.tap(find.byKey(const ValueKey('dispute-retry')));
        await tester.pumpAndSettle();

        expect(find.text('Ücret eksik ödendi'), findsOneWidget);
      });

      testWidgets('çekip yenileme uyuşmazlıkları yeniden okur', (tester) async {
        final backend = _Backend();
        await _pump(tester, backend, brightness: brightness);
        final reads = backend.disputeReads;

        await tester.drag(find.byType(ListView).first, const Offset(0, 400));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(backend.disputeReads, reads + 1);
      });
    });
  }
}
