import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/network/token_storage.dart';

import '../../support/fake_api.dart';

/// Yüklenen dosyanın içeriği. Gövdenin içinde aranabilsin diye okunur bir
/// metin; testin tamamı bu dizginin tekrar denenen isteğe de ulaşmasına bakıyor.
const String _fileContent = 'koala-galeri-gorseli';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `FakeApi` istek akışını hiç okumadığı için burada kendi kaydeden sahte
  // katmanı kullanılıyor; interceptor zincirini artık `ApiClient.withDio`
  // kendisi kuruyor (is-koala/koala#21).
  group('AuthInterceptor multipart tekrar denemesi', () {
    late Directory tempDir;
    late File uploadedFile;
    late TokenStorage tokenStorage;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      tokenStorage = TokenStorage.withStorage(
        const FlutterSecureStorage(),
        apiOrigin: 'https://test.local',
      );
      await tokenStorage.save(
        accessToken: 'suresi-dolmus-erisim',
        refreshToken: 'gecerli-yenileme',
      );

      tempDir = await Directory.systemTemp.createTemp('koala_retry_upload');
      uploadedFile = File('${tempDir.path}/galeri.jpg');
      await uploadedFile.writeAsString(_fileContent);
    });

    tearDown(() => tempDir.delete(recursive: true));

    for (final call in _multipartCalls) {
      test(
        '${call.name} 401 sonrası dosyasıyla birlikte tekrar gönderilir',
        () async {
          var sessionEnded = false;
          final adapter = _RecordingAdapter(_refreshOnceHandler());
          final client = _clientWithAuthInterceptor(
            adapter: adapter,
            tokenStorage: tokenStorage,
            onSessionExpired: () async => sessionEnded = true,
          );

          await call.invoke(client, uploadedFile.path);

          expect(sessionEnded, isFalse);
          expect(adapter.sent, hasLength(3));

          final first = adapter.sent[0];
          final refresh = adapter.sent[1];
          final retry = adapter.sent[2];

          expect(first.path, call.path);
          expect(refresh.path, ApiPaths.refreshToken);
          expect(retry.path, call.path);
          expect(retry.method, first.method);
          expect(retry.authorization, 'Bearer tazelenmis-erisim');
          expect(
            retry.contentType,
            startsWith(Headers.multipartFormDataContentType),
          );

          // Asıl mesele: `MultipartFile` akışı bir kez okunabiliyor, bu yüzden
          // aynı `FormData` tekrar gönderildiğinde gövde ya patlıyor ya da boş
          // gidiyordu. Tekrar denenen isteğin dosyayı gerçekten taşıdığını
          // yalnız akıtılan baytlara bakarak doğrulayabiliriz.
          expect(retry.body, contains('name="${call.fieldName}"'));
          expect(retry.body, contains(_fileContent));
          // `clone()` parçanın içerik tipini de taşımalı; kaybolsaydı sunucu
          // aynı dosyayı `application/octet-stream` olarak kaydederdi.
          expect(retry.body, contains('image/jpeg'));
          expect(retry.body.length, first.body.length);
        },
      );
    }

    test('JSON gövdeli istek tekrar denendiğinde gövdesini koruyor', () async {
      final adapter = _RecordingAdapter(_refreshOnceHandler());
      final client = _clientWithAuthInterceptor(
        adapter: adapter,
        tokenStorage: tokenStorage,
        onSessionExpired: () async {},
      );

      final result = await client.post<String>(
        ApiPaths.currentUser,
        body: {'about': 'merhaba'},
        parse: (data) => data! as String,
      );

      expect(result, 'tamam');
      expect(adapter.sent, hasLength(3));
      expect(adapter.sent.last.path, ApiPaths.currentUser);
      expect(adapter.sent.last.body, contains('merhaba'));
      expect(adapter.sent.last.authorization, 'Bearer tazelenmis-erisim');
    });
  });
}

/// Dört multipart yardımcısının hepsi tek tekrar deneme yolundan geçiyor;
/// dördü de aynı testle korunuyor.
final List<_MultipartCall> _multipartCalls = [
  _MultipartCall(
    name: 'postFile',
    path: ApiPaths.companyImages('c-1'),
    fieldName: 'image',
    invoke: (client, filePath) => client.postFile<String>(
      ApiPaths.companyImages('c-1'),
      fieldName: 'image',
      filePath: filePath,
      parse: (data) => data! as String,
    ),
  ),
  _MultipartCall(
    name: 'putFile',
    path: ApiPaths.currentUserCv,
    fieldName: 'file',
    invoke: (client, filePath) => client.putFile<String>(
      ApiPaths.currentUserCv,
      fieldName: 'file',
      filePath: filePath,
      parse: (data) => data! as String,
    ),
  ),
  _MultipartCall(
    name: 'putFileWithoutData',
    path: ApiPaths.currentUserProfilePicture,
    fieldName: 'image',
    invoke: (client, filePath) => client.putFileWithoutData(
      ApiPaths.currentUserProfilePicture,
      fieldName: 'image',
      filePath: filePath,
    ),
  ),
  _MultipartCall(
    name: 'postMultipartJson',
    path: ApiPaths.companies,
    fieldName: 'logo',
    invoke: (client, filePath) => client.postMultipartJson<String>(
      ApiPaths.companies,
      jsonFieldName: 'company',
      jsonBody: const {'name': 'Koala'},
      fileFieldName: 'logo',
      filePath: filePath,
      parse: (data) => data! as String,
    ),
  ),
];

/// İlk iş isteğine `401`, yenilemeye yeni token, sonrasına başarı döner.
_FakeResponse Function(RequestOptions options) _refreshOnceHandler() {
  var businessCalls = 0;

  return (options) {
    if (options.path == ApiPaths.refreshToken) {
      return const _FakeResponse(200, {
        'success': true,
        'data': {'token': 'tazelenmis-erisim'},
      });
    }

    businessCalls++;
    if (businessCalls == 1) {
      return const _FakeResponse(401, {
        'success': false,
        'message': 'Oturum bulunamadı',
      });
    }
    return const _FakeResponse(200, {'success': true, 'data': 'tamam'});
  };
}

/// Zinciri `ApiClient.withDio` kuruyor; yenileme istemcisi de aynı sahte
/// katmandan geçtiği için tekrar denenen istek de kaydediliyor.
ApiClient _clientWithAuthInterceptor({
  required _RecordingAdapter adapter,
  required TokenStorage tokenStorage,
  required Future<void> Function() onSessionExpired,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
    ..httpClientAdapter = adapter;

  return ApiClient.withDio(
    dio,
    tokenStorage: tokenStorage,
    deviceIdentity: FakeDeviceIdentity(),
    onSessionExpired: onSessionExpired,
  );
}

class _MultipartCall {
  const _MultipartCall({
    required this.name,
    required this.path,
    required this.fieldName,
    required this.invoke,
  });

  final String name;
  final String path;

  /// Dosyayı taşıyan parçanın adı.
  final String fieldName;

  final Future<void> Function(ApiClient client, String filePath) invoke;
}

class _FakeResponse {
  const _FakeResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

/// Sunucuya giden baytları da saklayan sahte HTTP katmanı.
///
/// `test/support/fake_api.dart` istek akışını hiç okumuyor; multipart bir
/// gövdenin gerçekten dolu gittiğini ancak akıtılan baytlar okunarak
/// doğrulanabilir.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._respond);

  final _FakeResponse Function(RequestOptions options) _respond;

  final List<_SentRequest> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }

    // Tekrar denenen istek aynı `RequestOptions` nesnesini kullanıyor; başlığı
    // sonradan okumak tazelenmiş token'ı ilk isteğe de yazmış gibi gösterirdi.
    sent.add(
      _SentRequest(
        path: options.path,
        method: options.method,
        authorization: options.headers['Authorization'] as String?,
        contentType: options.headers[Headers.contentTypeHeader] as String?,
        body: latin1.decode(bytes),
      ),
    );

    final response = _respond(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SentRequest {
  const _SentRequest({
    required this.path,
    required this.method,
    required this.authorization,
    required this.contentType,
    required this.body,
  });

  final String path;
  final String method;
  final String? authorization;
  final String? contentType;

  /// Sunucuya fiilen akıtılan gövde.
  final String body;
}
