import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/employee/features/jobs/presentation/pages/job_alert_form_page.dart';
import 'package:koala/employee/features/jobs/presentation/providers/job_alerts_provider.dart';
import 'package:koala/employee/features/jobs/services/job_alert_service.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';

void main() {
  testWidgets('düzenleme formu referans listesindeki il ve ilçeyi gösterir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (request) => switch (request.path) {
        '/reference/job-categories' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'category-1', 'name': 'Barista', 'code': 'BARISTA'},
            ],
          },
        ),
        '/reference/countries' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'country-1', 'name': 'Türkiye', 'code': 'TR'},
            ],
          },
        ),
        '/reference/countries/country-1/cities' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'city-1', 'name': 'Ankara'},
            ],
          },
        ),
        '/reference/cities/city-1/districts' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'district-1', 'name': 'Çankaya'},
            ],
          },
        ),
        _ => const FakeApiResponse(statusCode: 200, body: {'success': true}),
      },
    );
    const category = JobCategory(
      id: 'category-1',
      name: 'Barista',
      code: 'BARISTA',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => JobCategoryProvider(
              service: JobCategoryService.withClient(api.client),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => JobAlertsProvider(
              service: JobAlertService.withClient(api.client),
            ),
          ),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: JobAlertFormPage(
            alert: const JobAlert(
              id: 'alert-1',
              name: 'Hafta içi alarmı',
              category: category,
              cityName: 'Ankara',
              districtName: 'Çankaya',
              isActive: true,
            ),
            locationService: ReferenceLocationService.withClient(api.client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hafta içi alarmı'), findsOneWidget);
    expect(find.text('Barista'), findsOneWidget);
    expect(find.text('Ankara'), findsOneWidget);
    expect(find.text('Çankaya'), findsOneWidget);
  });
}
