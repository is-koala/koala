import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/features/dispute/services/dispute_evidence_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/dispute_evidence_fixtures.dart';
import '../../../../support/fake_api.dart';

/// Multipart parçasının gövdesi; dio gövdeyi bir kez akıttığı için kopyasından.
Future<List<int>> _partBytes(MultipartFile part) {
  return part.clone().finalize().fold<List<int>>(
    <int>[],
    (all, chunk) => all..addAll(chunk),
  );
}

DisputeEvidenceService _serviceOn(FakeApi api) =>
    DisputeEvidenceService.withClient(api.client);

void main() {
  group('fetchEvidence', () {
    test('metadata dizisini okur', () async {
      final api = FakeApi(
        handler: (_) => dataResponse([
          evidenceJson('ev-1'),
          evidenceJson(
            'ev-2',
            fileName: 'tutanak.pdf',
            contentType: 'application/pdf',
          ),
        ]),
      );

      final list = await _serviceOn(api).fetchEvidence('dispute-1');

      final request = api.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/disputes/dispute-1/evidence');
      expect(list.map((e) => e.id), ['ev-1', 'ev-2']);
      expect(list.last.fileName, 'tutanak.pdf');
    });

    test('data dizi değilse boş liste', () async {
      final api = FakeApi(handler: (_) => dataResponse(<String, dynamic>{}));

      expect(await _serviceOn(api).fetchEvidence('d'), isEmpty);
    });

    test('404 (taraf değil) ApiException olarak çıkar', () async {
      final api = FakeApi(
        handler: (_) => errorResponse(
          404,
          'DISPUTE_NOT_FOUND',
          category: 'RESOURCE_NOT_FOUND',
        ),
      );

      await expectLater(
        _serviceOn(api).fetchEvidence('d'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.notFound)
              .having((e) => e.errorCode, 'errorCode', 'DISPUTE_NOT_FOUND'),
        ),
      );
    });
  });

  group('upload', () {
    test(
      'tek `file` parçası, ad ve içerik tipi içerikten, bayt birebir',
      () async {
        final api = FakeApi(
          handler: (_) => dataResponse(
            evidenceJson('ev-9', fileName: 'foto.jpg'),
            statusCode: 201,
          ),
        );
        // Dosya adı `.heic`, içerik JPEG: gönderilen ad ve tip içerikten.
        final path = writeEvidenceFile('IMG_7.heic', jpegSignatureBytes);
        final file = DisputeEvidencePolicy.accept(
          EvidenceCandidate(
            path: path,
            bytes: jpegSignatureBytes.length,
            head: jpegSignatureBytes.take(12).toList(),
            displayName: 'IMG_7.heic',
          ),
          now: DateTime(2026, 10, 3, 10, 42, 31),
        ).file!;

        final saved = await _serviceOn(api).upload('dispute-1', file);

        final request = api.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/disputes/dispute-1/evidence');
        expect(request.contentType, startsWith('multipart/form-data'));

        final form = request.data as FormData;
        expect(form.fields, isEmpty);
        expect(form.files.map((part) => part.key), ['file']);
        final part = form.files.single.value;
        expect(part.filename, 'IMG_7.jpg');
        expect(part.contentType?.mimeType, 'image/jpeg');
        expect(await _partBytes(part), jpegSignatureBytes);
        expect(saved.id, 'ev-9');
      },
    );

    test('PDF `application/pdf` olarak gider', () async {
      final api = FakeApi(
        handler: (_) => dataResponse(evidenceJson('ev-1'), statusCode: 201),
      );
      final path = writeEvidenceFile('tutanak.pdf', pdfBytes);
      final file = EvidenceFile(
        path: path,
        bytes: pdfBytes.length,
        format: EvidenceFormat.pdf,
        uploadName: 'tutanak.pdf',
      );

      await _serviceOn(api).upload('d', file);

      final part = (api.requests.single.data as FormData).files.single.value;
      expect(part.filename, 'tutanak.pdf');
      expect(part.contentType?.mimeType, 'application/pdf');
    });

    test('sunucunun reddi errorCode ile ApiException', () async {
      final api = FakeApi(
        handler: (_) => errorResponse(
          409,
          'DISPUTE_EVIDENCE_LIMIT_REACHED',
          category: 'DATA_CONFLICT',
        ),
      );
      final path = writeEvidenceFile('a.pdf', pdfBytes);
      final file = EvidenceFile(
        path: path,
        bytes: pdfBytes.length,
        format: EvidenceFormat.pdf,
        uploadName: 'a.pdf',
      );

      await expectLater(
        _serviceOn(api).upload('d', file),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e.errorCode,
                'errorCode',
                'DISPUTE_EVIDENCE_LIMIT_REACHED',
              )
              .having((e) => e.type, 'type', ApiErrorType.dataConflict),
        ),
      );
    });
  });

  group('resolveDownload', () {
    test('302 yönlendirmesini izlemeden Location adresini verir', () async {
      final tokens = FakeTokenStorage(accessToken: 'erisim-token');
      final api = FakeApi(
        tokenStorage: tokens,
        handler: (_) => const FakeApiResponse(
          statusCode: 302,
          headers: {
            'location':
                'https://bucket.s3.eu-central-1.amazonaws.com/k?X-Amz-Expires=180',
          },
        ),
      );

      final url = await _serviceOn(api).resolveDownload('dispute-1', 'ev-1');

      final request = api.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/disputes/dispute-1/evidence/ev-1/download');
      // Yönlendirme izlenseydi `Authorization` depoya da giderdi.
      expect(request.followRedirects, isFalse);
      expect(request.headers['Authorization'], 'Bearer erisim-token');
      expect(url, isNotNull);
      expect(url!.host, 'bucket.s3.eu-central-1.amazonaws.com');
      expect(url.queryParameters['X-Amz-Expires'], '180');
    });

    test('200 (sunucu baytları kendisi akıtıyor) null döner', () async {
      final api = FakeApi(handler: (_) => dataResponse(<String, dynamic>{}));

      expect(await _serviceOn(api).resolveDownload('d', 'e'), isNull);
    });

    test(
      'Location olmayan ya da göreli 302 beklenmeyen yanıt sayılır',
      () async {
        for (final headers in [
          const <String, String>{},
          const {'location': '/uploads/files/x'},
          const {'location': 'javascript-degil'},
        ]) {
          final api = FakeApi(
            handler: (_) => FakeApiResponse(statusCode: 302, headers: headers),
          );

          await expectLater(
            _serviceOn(api).resolveDownload('d', 'e'),
            throwsA(isA<ApiException>()),
            reason: '$headers',
          );
        }
      },
    );

    test('404 zarfıyla ApiException (kanıt yok ya da taraf değil)', () async {
      final api = FakeApi(
        handler: (_) => errorResponse(
          404,
          'DISPUTE_EVIDENCE_NOT_FOUND',
          category: 'RESOURCE_NOT_FOUND',
        ),
      );

      await expectLater(
        _serviceOn(api).resolveDownload('d', 'e'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.notFound)
              .having(
                (e) => e.errorCode,
                'errorCode',
                'DISPUTE_EVIDENCE_NOT_FOUND',
              ),
        ),
      );
    });

    test('ağ hatası ApiException.network', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse.connectionError(),
      );

      await expectLater(
        _serviceOn(api).resolveDownload('d', 'e'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.type,
            'type',
            ApiErrorType.network,
          ),
        ),
      );
    });
  });

  // Dio çok parçalı gövdeyi kendisi kodluyor; `filename` UTF-8 baytları olarak
  // gitmeli (Spring isteği UTF-8 çözüyor). Gövde sonuna kadar akıtılıp başlık
  // satırındaki baytlar okunuyor — adı yalnız `part.filename` ile karşılaştırmak
  // kodlamayı hiç sınamazdı.
  test('UTF-8 dosya adı gövdede UTF-8 baytlarıyla gider', () async {
    final api = FakeApi(
      handler: (_) => dataResponse(evidenceJson('e'), statusCode: 201),
    );
    final path = writeEvidenceFile('x.pdf', pdfBytes);
    final file = EvidenceFile(
      path: path,
      bytes: pdfBytes.length,
      format: EvidenceFormat.pdf,
      uploadName: 'şikâyet-çağrı.pdf',
    );

    await _serviceOn(api).upload('d', file);

    final form = api.requests.single.data as FormData;
    final body = await form.clone().finalize().fold<List<int>>(
      <int>[],
      (all, chunk) => all..addAll(chunk),
    );
    final expected = utf8.encode('filename="şikâyet-çağrı.pdf"');
    expect(_indexOf(body, expected), isNonNegative, reason: 'UTF-8 başlık');
    // Yüzde-kodlu bir ad (`%C5%9F…`) Spring'de olduğu gibi saklanırdı.
    expect(_indexOf(body, ascii.encode('filename="%C5')), -1);
  });

  group('dosya okunamazsa', () {
    // Seçicinin geçici kopyası iOS `tmp` temizliğiyle silinmiş olabilir.
    // `FileSystemException` değil `ApiException` çıkmalı: servisler yalnız onu
    // yükseltir ve sayfa tek hata yolu yönetir.
    test('yükleme ApiException ile döner, sunucuya hiç gitmez', () async {
      final api = FakeApi(handler: (_) => dataResponse(evidenceJson('e')));
      final path = writeEvidenceFile('gecici.pdf', pdfBytes);
      File(path).deleteSync();
      final file = EvidenceFile(
        path: path,
        bytes: pdfBytes.length,
        format: EvidenceFormat.pdf,
        uploadName: 'gecici.pdf',
      );

      await expectLater(
        _serviceOn(api).upload('d', file),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', contains('yeniden seçin'))
              .having((e) => e.type, 'type', ApiErrorType.unknown),
        ),
      );
      expect(api.requests, isEmpty);
    });
  });
}

int _indexOf(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}
