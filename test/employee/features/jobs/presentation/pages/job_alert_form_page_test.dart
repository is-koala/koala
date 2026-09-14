import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/employee/features/jobs/presentation/pages/job_alert_form_page.dart';
import 'package:koala/employee/features/jobs/presentation/providers/job_alerts_provider.dart';
import 'package:koala/employee/features/jobs/services/job_alert_service.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';
import '../../../../../support/keyboard.dart';
import 'package:flutter/material.dart';
import '../../../../../support/finders.dart';

void main() {
  testWidgets('düzenleme formu opsiyonel ölçütleri temizleyebilir', (
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
        '/users/me/job-alerts/alert-1' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'alert-1',
              'alertName': 'Hafta içi alarmı',
              'minSalary': 1250.5,
              'active': true,
            },
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

    await pumpInApp(
      tester,
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
        child: JobAlertFormPage(
          alert: const JobAlert(
            id: 'alert-1',
            name: 'Hafta içi alarmı',
            category: category,
            cityName: 'Ankara',
            districtName: 'Çankaya',
            minimumSalary: 1250.5,
            isActive: true,
          ),
          locationService: ReferenceLocationService.withClient(api.client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hafta içi alarmı'), findsOneWidget);
    expect(find.text('Barista'), findsOneWidget);
    expect(find.text('Ankara'), findsOneWidget);
    expect(find.text('Çankaya'), findsOneWidget);
    expect(find.text('1250.5'), findsOneWidget);

    await tester.tap(find.byTooltip('Kategori seçimini temizle'));
    await tester.tap(find.byTooltip('İl seçimini temizle'));
    final saveButton = find.text('Kaydet');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final updateRequest = api.requests.last;
    expect(updateRequest.path, '/users/me/job-alerts/alert-1');
    expect(updateRequest.data, containsPair('categoryId', null));
    expect(updateRequest.data, containsPair('cityName', null));
    expect(updateRequest.data, containsPair('districtName', null));
    expect(updateRequest.data, containsPair('minSalary', 1250.5));
  });

  group('klavye (is-koala/koala#190)', () {
    Future<void> pumpCreateForm(
      WidgetTester tester,
      Brightness brightness,
    ) async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );
      await pumpInApp(
        tester,
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
          child: JobAlertFormPage(
            locationService: ReferenceLocationService.withClient(api.client),
          ),
        ),
        brightness: brightness,
      );
      await tester.pumpAndSettle();
    }

    for (final brightness in Brightness.values) {
      testWidgets(
        '${brightness.name} tema: Alarmı Oluştur kaydırılarak klavyenin '
        'üstüne gelir, boş alana dokununca odak düşer',
        (tester) async {
          await pumpCreateForm(tester, brightness);
          await showKeyboard(tester);

          await expectAboveKeyboard(tester, find.text('Alarmı Oluştur'));
          await expectTapOutsideDropsFocus(
            tester,
            findFieldLabelled('Alarm adı'),
          );
        },
      );

      testWidgets(
        '${brightness.name} tema, iOS: asgari ücret alanında Bitti şeridi '
        'çıkar, Alarmı Oluştur şeridin üstüne kaydırılır ve basılır',
        (tester) async {
          await pumpCreateForm(tester, brightness);

          await tester.enterText(findFieldLabelled('Asgari ücret'), '1.2.3');
          await expectDoneBarLayout(
            tester,
            numericField: findFieldLabelled('Asgari ücret'),
            cta: find.text('Alarmı Oluştur'),
          );

          // Geçersiz ücret doğrulamaya takılır; hata satırı geldiyse dokunuş
          // şeride değil düğmeye gitmiştir.
          await tester.tap(find.text('Alarmı Oluştur'));
          await tester.pump();
          expect(
            find.text('Asgari ücret geçerli bir sayı olmalıdır.'),
            findsOneWidget,
            reason: 'Alarmı Oluştur dokunuşu şeride gitti',
          );

          await tapDoneBar(tester);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  });
}
