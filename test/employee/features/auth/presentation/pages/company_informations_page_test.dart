import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/presentation/pages/company_informations_page.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/fake_api.dart';

const _companyResponse = {
  'success': true,
  'data': {'id': 'company_1', 'name': 'Moda Kahve Atölyesi', 'approved': false},
};

void main() {
  testWidgets('şirket formu gerçek oluşturma servisini çağırır', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 201, body: _companyResponse),
    );
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: CompanyInformationsPage(
          service: BCompanyService.withClient(api.client),
          initialLocation: const LatLng(40.9819, 29.0263),
          onSaved: () => saved = true,
        ),
      ),
    );

    Future<void> enter(String label, String value) async {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.enterText(field, value);
    }

    await enter('Firma Adı*', 'Moda Kahve Atölyesi');
    await enter('Firma Adresi*', 'Caferağa Mah. Moda Cad. No: 12');
    await enter('İlçe*', 'KADIKÖY');
    await enter('Vergi Numarası*', '1234567890');
    await enter('Şirket Numarası*', '+905551112233');
    await enter('Şirket E-posta*', 'merhaba@modakahve.test');

    final save = find.text('KAYDET');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(api.requests.single.path, '/companies');
  });
}
