import 'fake_api.dart';

/// `ReferenceLocationService`'in üç ucuna tek ülke / il / ilçe döndürür;
/// eşleşmeyen yolda `null`, testin kendi sunucusu devam etsin diye.
///
/// `CanonicalAddressForm` önceden dolu bir adresi bile ancak seçenek
/// listeleri gelince "seçilmiş" sayıyor: listeler boş dönerse form
/// "Ülke seçin" der ve kayıt sunucuya hiç gitmez. Şirket formunu süren her
/// test bu üç yanıtı vermek zorunda.
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
