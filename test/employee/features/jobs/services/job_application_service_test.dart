import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('JobApplicationService.fetchMyApplications', () {
    test('sayfalı yanıt modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {
                  'id': 'app_1',
                  'status': 'APPLIED',
                  'job': {
                    'id': 'job_1',
                    'title': 'Garson',
                    'category': {
                      'id': 'c',
                      'code': 'WAITER',
                      'name': 'Garsonluk',
                    },
                    'salary': 1500,
                  },
                },
              ],
              'totalElements': 1,
              'last': true,
            },
          },
        ),
      );

      final page = await JobApplicationService.withClient(
        api.client,
      ).fetchMyApplications();

      expect(api.requests.single.path, '/users/me/applications');
      expect(page.applications.single.id, 'app_1');
    });

    test('boş sayfa hata değil', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );

      final page = await JobApplicationService.withClient(
        api.client,
      ).fetchMyApplications();

      expect(page.applications, isEmpty);
    });

    // `UNKNOWN` sunucunun enum'unda yok; süzgeç olarak gitseydi `400` gelirdi.
    // Sentinel bir süzgeç değeri değil, süzgeçsiz sayılıyor.
    test('bilinmeyen durum süzgeç olarak gönderilmez', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );

      await JobApplicationService.withClient(
        api.client,
      ).fetchMyApplications(status: ApplicationStatus.unknown);

      expect(
        api.requests.single.queryParameters.containsKey('status'),
        isFalse,
      );
    });

    test('bilinen durum süzgeç olarak gönderilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );

      await JobApplicationService.withClient(
        api.client,
      ).fetchMyApplications(status: ApplicationStatus.withdrawn);

      expect(api.requests.single.queryParameters['status'], 'WITHDRAWN');
    });
  });

  group('JobApplicationService.withdraw', () {
    // Uç `SuccessDataResult<JobApplicationDetailDto>` döndürüyor; gövdesiz bir
    // `POST` değil, dönen kayıt okunuyor.
    test('doğru yola gider ve WITHDRAWN yanıtı modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'app_1',
              'status': 'WITHDRAWN',
              'applicationDateTime': '2026-03-05T10:00:00Z',
              // Uç `ShortJobDto` döndürüyor: yalnızca id ve başlık.
              'job': {'id': 'job_1', 'title': 'Deneyimli Barista'},
            },
          },
        ),
      );

      final application = await JobApplicationService.withClient(
        api.client,
      ).withdraw('app_1');

      expect(api.requests.single.path, '/job-applications/app_1/withdraw');
      expect(api.requests.single.method, 'POST');
      expect(application.id, 'app_1');
      expect(application.status, ApplicationStatus.withdrawn);
    });

    test('sunucu 409 dönerse ApiException yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {
            'success': false,
            'message': 'Bu başvuru geri çekilemez.',
            'errorCode': 'JOB_APPLICATION_NOT_WITHDRAWABLE',
          },
        ),
      );

      await expectLater(
        JobApplicationService.withClient(api.client).withdraw('app_1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.dataConflict)
              .having(
                (e) => e.errorCode,
                'errorCode',
                'JOB_APPLICATION_NOT_WITHDRAWABLE',
              ),
        ),
      );
    });
  });
}
