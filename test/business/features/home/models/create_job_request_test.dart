import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/create_job_request.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/models/canonical_address.dart';

void main() {
  CreateJobRequest build() => CreateJobRequest(
    categoryId: 'cat_1',
    title: 'Garson',
    description: 'Açıklama',
    position: 'Garson',
    type: JobType.recurring,
    salaryType: SalaryType.hourly,
    salary: 250,
    startDateTime: DateTime(2026, 9, 1, 9, 30),
    endDateTime: DateTime(2026, 9, 1, 18),
    minAge: 18,
    maxAge: 40,
    experienceRequired: true,
    insuranceRequired: true,
    address: const AddressWrite(
      countryId: 'country-1',
      cityId: 'city-1',
      districtId: 'district-1',
      components: AddressComponents(
        neighborhood: 'Kızılay Mahallesi',
        thoroughfare: 'Atatürk Bulvarı',
        buildingNumber: '1',
        postalCode: '06420',
      ),
      position: AddressPosition(
        latitude: 39.92,
        longitude: 32.85,
        source: AddressPositionSource.userConfirmedPin,
      ),
    ),
  );

  test('tarihler saat dilimi eki olmadan gönderiliyor', () {
    // Backend `LocalDateTime` bekliyor; sondaki `Z` ya da milisaniye
    // ayrıştırmayı bozuyor.
    final json = build().toJson(forCompany: true);

    expect(json['startDateTime'], '2026-09-01T09:30:00');
    expect(json['endDateTime'], '2026-09-01T18:00:00');
  });

  test('enum alanları backend koduyla gidiyor', () {
    final json = build().toJson(forCompany: true);

    expect(json['type'], 'RECURRING');
    expect(json['salaryType'], 'HOURLY');
  });

  test('bireysel ilanda sigorta alanı gönderilmiyor', () {
    expect(
      build().toJson(forCompany: false).containsKey('insuranceRequired'),
      isFalse,
    );
    expect(build().toJson(forCompany: true)['insuranceRequired'], isTrue);
  });

  test('doldurulmamış isteğe bağlı alanlar gövdeye girmiyor', () {
    final json = build().toJson(forCompany: true);

    expect(json.containsKey('sector'), isFalse);
    expect(json.containsKey('duties'), isFalse);
    expect(json.containsKey('dressCode'), isFalse);
    expect(
      ((json['address'] as Map)['components'] as Map).containsKey('siteName'),
      isFalse,
    );
  });

  test('adres zorunlu alanları taşıyor', () {
    final address = build().toJson(forCompany: true)['address'] as Map;

    expect(address['countryId'], 'country-1');
    expect(address['cityId'], 'city-1');
    expect(address['districtId'], 'district-1');
    expect((address['components'] as Map)['postalCode'], '06420');
    expect((address['position'] as Map)['latitude'], 39.92);
    expect((address['position'] as Map)['source'], 'USER_CONFIRMED_PIN');
  });
}
