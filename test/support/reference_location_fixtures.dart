import 'fake_api.dart';

/// `ReferenceLocationService`'in üç ucuna tek ülke / il / ilçe döndürür;
/// eşleşmeyen yolda `null`, testin kendi sunucusu devam etsin diye.
///
/// Harita-öncelikli adres ekranı bu listeleri yalnız elle giriş yolunda,
/// il/ilçe seçicisi açılınca çekiyor; ters geokod ya da arama adayı gelmişse
/// kimliği adaydan alıyor ve bu uçlara hiç gitmiyor. Elle giriş yolunu süren
/// testler bu üç yanıtı verir.
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
