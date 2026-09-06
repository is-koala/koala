import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_job_templates_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_job_templates_provider.dart';
import 'package:koala/business/features/home/services/job_template_service.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

const _template = {
  'id': 'template-1',
  'templateName': 'Cumartesi garson',
  'category': {
    'id': 'category-1',
    'name': 'Garson',
    'code': 'GARSON',
    'requiresInsurance': false,
  },
  'title': 'Hafta sonu garson',
  'position': 'Garson',
  'type': 'ONE_TIME',
  'salaryType': 'DAILY',
  'salary': 1500,
};

Future<void> pumpPage(
  WidgetTester tester,
  FakeApi api, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpInApp(
    tester,
    ChangeNotifierProvider(
      create: (_) => BJobTemplatesProvider(
        service: JobTemplateService.withClient(api.client),
      ),
      child: BJobTemplatesPage(key: UniqueKey()),
    ),
    brightness: brightness,
  );
  await tester.pumpAndSettle();
}

FakeApi listOf(List<Map<String, dynamic>> templates) => FakeApi(
  handler: (_) => FakeApiResponse(
    statusCode: 200,
    body: {'success': true, 'data': templates},
  ),
);

void main() {
  testWidgets('boş liste ile ağ hatası ayrı durumlar gösteriyor', (
    tester,
  ) async {
    await pumpPage(tester, listOf(const []));
    expect(find.text('Henüz ilan şablonunuz yok'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsNothing);

    final failedApi = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Şablonlar alınamadı.'},
      ),
    );
    await pumpPage(tester, failedApi);
    expect(find.text('Şablonlar alınamadı.'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(find.text('Henüz ilan şablonunuz yok'), findsNothing);
  });

  testWidgets('şablon satırı adı ve özetini yazıyor', (tester) async {
    await pumpPage(tester, listOf(const [_template]));

    expect(find.text('Cumartesi garson'), findsOneWidget);
    expect(find.textContaining('Garson'), findsWidgets);
    expect(find.textContaining('1.500'), findsOneWidget);
    // Adres ve tarih şablona dahil değil; sayfa bunu söylemeli.
    expect(find.textContaining('Adres ve tarih'), findsOneWidget);
  });

  testWidgets('koyu temada da çiziliyor', (tester) async {
    await pumpPage(
      tester,
      listOf(const [_template]),
      brightness: Brightness.dark,
    );

    expect(find.text('Cumartesi garson'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('silme onaylanınca satır listeden kalkıyor', (tester) async {
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': [_template],
              },
            )
          : const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );
    await pumpPage(tester, api);

    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    // Kartın düğmesi de "Sil" yazıyor; onay kutusundaki olan hedefleniyor.
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Sil')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cumartesi garson'), findsNothing);
    expect(find.text('Henüz ilan şablonunuz yok'), findsOneWidget);
    expect(api.requests.last.method, 'DELETE');
  });
}
