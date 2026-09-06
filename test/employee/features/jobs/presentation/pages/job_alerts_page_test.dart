import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/presentation/pages/job_alerts_page.dart';
import 'package:koala/employee/features/jobs/presentation/providers/job_alerts_provider.dart';
import 'package:koala/employee/features/jobs/services/job_alert_service.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

Future<void> pumpPage(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpInApp(
    tester,
    ChangeNotifierProvider(
      create: (_) =>
          JobAlertsProvider(service: JobAlertService.withClient(api.client)),
      child: JobAlertsPage(key: UniqueKey()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('boş liste ve ağ hatası farklı durumlar gösterir', (
    tester,
  ) async {
    final emptyApi = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': []},
      ),
    );
    await pumpPage(tester, emptyApi);
    expect(find.text('Henüz iş alarmınız yok'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsNothing);

    final failedApi = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Alarm listesi alınamadı.'},
      ),
    );
    await pumpPage(tester, failedApi);
    expect(find.text('Alarm listesi alınamadı.'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(find.text('Henüz iş alarmınız yok'), findsNothing);
  });

  testWidgets('kriter özeti küsuratlı asgari ücreti yuvarlamaz', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': [
            {
              'id': 'alert-1',
              'alertName': 'Küsuratlı ücret',
              'minSalary': 1250.5,
              'active': true,
            },
          ],
        },
      ),
    );

    await pumpPage(tester, api);

    expect(find.text('En az 1.250,5 ₺'), findsOneWidget);
    expect(find.text('En az 1.251 ₺'), findsNothing);
  });
}
