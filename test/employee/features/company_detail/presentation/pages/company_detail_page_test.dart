import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/company_detail/presentation/pages/company_detail_page.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/home/services/job_service.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

void main() {
  testWidgets('şirket ilanları ada göre elenmeden kimlikle istenir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (request) => switch (request.path) {
        '/companies/company-7' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'id': 'company-7', 'name': 'Aynı Ad', 'approved': true},
          },
        ),
        '/jobs' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {
                  'id': 'job-1',
                  'title': 'Kimlikle Gelen İlan',
                  'position': 'Garson',
                  'companyName': 'Farklı Sunucu Adı',
                  'category': {
                    'id': 'cat-1',
                    'code': 'WAITER',
                    'name': 'Garson',
                  },
                  'type': 'ONE_TIME',
                  'salaryType': 'DAILY',
                  'salary': 1000,
                  'status': 'OPEN',
                },
              ],
              'last': true,
            },
          },
        ),
        _ => const FakeApiResponse(statusCode: 404),
      },
    );
    final client = api.client;

    await pumpInApp(
      tester,
      CompanyDetailPage(
        companyId: 'company-7',
        companyService: CompanyService.withClient(client),
        jobService: JobService.withClient(client),
      ),
    );
    await tester.pumpAndSettle();

    final request = api.requests.singleWhere(
      (request) => request.path == '/jobs',
    );
    expect(request.method, 'GET');
    expect(request.queryParameters['companyId'], 'company-7');
    expect(request.queryParameters.containsKey('query'), isFalse);
    expect(find.text('Kimlikle Gelen İlan'), findsOneWidget);
  });
}
