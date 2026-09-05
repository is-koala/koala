import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/presentation/pages/company_informations_page.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/services/reference_location_service.dart';

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
      handler: (request) => switch (request.path) {
        '/reference/countries' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'country-1', 'name': 'TÜRKİYE', 'code': 'TR'},
            ],
          },
        ),
        '/reference/countries/country-1/cities' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'city-1', 'name': 'İSTANBUL'},
            ],
          },
        ),
        '/reference/cities/city-1/districts' => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'district-1', 'name': 'KADIKÖY'},
            ],
          },
        ),
        _ => const FakeApiResponse(statusCode: 201, body: _companyResponse),
      },
    );
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: CompanyInformationsPage(
          service: BCompanyService.withClient(api.client),
          referenceService: ReferenceLocationService.withClient(api.client),
          initialLocation: const LatLng(40.9819, 29.0263),
          initialAddress: const CanonicalAddress(
            id: 'address-1',
            countryId: 'country-1',
            countryName: 'TÜRKİYE',
            countryCode: 'TR',
            cityId: 'city-1',
            cityName: 'İSTANBUL',
            districtId: 'district-1',
            districtName: 'KADIKÖY',
            components: AddressComponents(
              neighborhood: 'Caferağa Mahallesi',
              thoroughfare: 'Moda Caddesi',
              buildingNumber: '12',
              postalCode: '34710',
            ),
            canonicalVersion: 1,
            needsReview: false,
          ),
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
    await enter('Vergi Numarası*', '1234567890');
    await enter('Şirket Numarası*', '+905551112233');
    await enter('Şirket E-posta*', 'merhaba@modakahve.test');

    final save = find.text('KAYDET');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(api.requests.last.path, '/companies');
  });
}
