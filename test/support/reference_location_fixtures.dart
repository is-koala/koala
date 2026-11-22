import 'fake_api.dart';

/// Tek ülke / il / ilçe; eşleşmeyen yolda `null`. Yalnız elle giriş yolu bu
/// uçlara gidiyor.
FakeApiResponse? istanbulReferenceResponse(String path) {
  return switch (path) {
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
    _ => null,
  };
}
