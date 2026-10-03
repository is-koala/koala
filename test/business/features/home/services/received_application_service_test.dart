import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/services/received_application_service.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

const _row = {
  'id': 'app-1',
  'status': 'APPLIED',
  'applicationDateTime': '2026-09-15T08:00:00Z',
  'applicant': {'id': 'worker-1', 'firstName': 'Ayşe', 'lastName': 'Yılmaz'},
  'jobId': 'job-1',
  'postingTitle': 'Barista',
  'jobStatus': 'OPEN',
};

FakeApi _apiReturning(Map<String, dynamic> data) => FakeApi(
  handler: (_) =>
      FakeApiResponse(statusCode: 200, body: {'success': true, 'data': data}),
);

Map<String, dynamic> _page({
  List<Map<String, dynamic>> content = const [_row],
  int page = 0,
  bool last = true,
}) => {
  'content': content,
  'page': page,
  'size': 20,
  'totalElements': content.length,
  'totalPages': 1,
  'first': page == 0,
  'last': last,
};

void main() {
  group('ReceivedApplicationService.fetchReceivedApplications', () {
    test('süzgeçsiz istek yalnız sayfa ve boyut taşır', () async {
      final api = _apiReturning(_page());

      final result = await ReceivedApplicationService.withClient(
        api.client,
      ).fetchReceivedApplications();

      final request = api.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/users/me/received-applications');
      expect(request.queryParameters, {'page': 0, 'size': 20});
      expect(result.applications.single.postingTitle, 'Barista');
      expect(result.last, isTrue);
    });

    // Sunucu bilinmeyen durum değerine 400 veriyor; durum yalnız seçildiyse ve
    // sunucunun adıyla gidiyor.
    test(
      'durum, ilan ve şirket süzgeçleri sunucunun adlarıyla gider',
      () async {
        final api = _apiReturning(_page());

        await ReceivedApplicationService.withClient(
          api.client,
        ).fetchReceivedApplications(
          status: ApplicationStatus.accepted,
          jobId: 'job-1',
          companyId: 'company-1',
          page: 2,
          size: 60,
        );

        expect(api.requests.single.queryParameters, {
          'status': 'ACCEPTED',
          'jobId': 'job-1',
          'companyId': 'company-1',
          'page': 2,
          'size': 60,
        });
      },
    );

    // `sort` verilince sunucunun "bekleyen önce" sırası tümüyle yerini
    // bırakıyor; istemci hiçbir koşulda göndermemeli.
    test('sort hiçbir zaman gönderilmez', () async {
      final api = _apiReturning(_page());
      final service = ReceivedApplicationService.withClient(api.client);

      await service.fetchReceivedApplications();
      await service.fetchReceivedApplications(
        status: ApplicationStatus.applied,
        page: 1,
      );

      for (final request in api.requests) {
        expect(request.queryParameters.containsKey('sort'), isFalse);
      }
    });

    test('bilinmeyen durum süzgeci programlama hatası sayılır', () {
      final api = _apiReturning(_page());

      expect(
        () => ReceivedApplicationService.withClient(
          api.client,
        ).fetchReceivedApplications(status: ApplicationStatus.unknown),
        throwsA(isA<AssertionError>()),
      );
      expect(api.requests, isEmpty);
    });

    test('boş sayfa hata değil', () async {
      final api = _apiReturning(_page(content: const []));

      final result = await ReceivedApplicationService.withClient(
        api.client,
      ).fetchReceivedApplications(companyId: 'someone-elses');

      expect(result.applications, isEmpty);
      expect(result.last, isTrue);
    });

    test('sunucu hatası ApiException olarak çıkar', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {
            'success': false,
            'message': 'Sıralama alanı desteklenmiyor',
            'errorCategory': 'VALIDATION_FAILED',
          },
        ),
      );

      await expectLater(
        ReceivedApplicationService.withClient(
          api.client,
        ).fetchReceivedApplications(),
        throwsA(
          isA<ApiException>()
              .having(
                (error) => error.message,
                'message',
                'Sıralama alanı desteklenmiyor',
              )
              // Gerçek kategori adı: yanlış yazılan bir kategori sessizce
              // durum koduna düşer ve test yine yeşil kalırdı.
              .having((error) => error.type, 'type', ApiErrorType.validation)
              .having((error) => error.statusCode, 'statusCode', 400),
        ),
      );
    });
  });
}
