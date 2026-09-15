import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/core/directions_links.dart';

/// Kadıköy — pozitif iki koordinat; altı ondalıktan fazlası kırpılmalı.
const _moda = DirectionsTarget(latitude: 40.98765432, longitude: 29.02612345);

/// Varış saati verilen hedef; hiçbir bağlantıda saat parametresi olmamalı.
final _withArrival = DirectionsTarget(
  latitude: 41.0,
  longitude: 29.0,
  arrival: DateTime(2026, 9, 10, 9),
);

/// Üç üreticinin hepsi; "hiçbirinde şu yok" iddiaları bunun üstünden.
final _builders = <String, Uri Function(DirectionsTarget)>{
  'Apple': DirectionsLinks.appleMaps,
  'Google uygulama': DirectionsLinks.googleMapsApp,
  'Google web': DirectionsLinks.googleMapsWeb,
};

void main() {
  group('DirectionsLinks', () {
    test('Apple Haritalar: maps:// + daddr + dirflg=r (toplu taşıma)', () {
      final uri = DirectionsLinks.appleMaps(_moda);

      expect(uri.toString(), 'maps://?daddr=40.987654,29.026123&dirflg=r');
      expect(uri.scheme, 'maps');
      expect(uri.queryParameters['dirflg'], 'r');
    });

    test('Google uygulaması: comgooglemaps:// + directionsmode=transit', () {
      final uri = DirectionsLinks.googleMapsApp(_moda);

      expect(
        uri.toString(),
        'comgooglemaps://?daddr=40.987654,29.026123&directionsmode=transit',
      );
      expect(uri.scheme, 'comgooglemaps');
    });

    test('Google web: api=1 + destination + travelmode=transit', () {
      final uri = DirectionsLinks.googleMapsWeb(_moda);

      expect(
        uri.toString(),
        'https://www.google.com/maps/dir/?api=1'
        '&destination=40.987654,29.026123&travelmode=transit',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters, {
        'api': '1',
        'destination': '40.987654,29.026123',
        'travelmode': 'transit',
      });
    });

    // Koordinat biçimi: nokta ayırıcı (yerelden bağımsız), altı ondalık
    // (sunucuyla aynı kesinlik), negatif işaret korunur, virgül kaçırılmaz.
    test('koordinat: altı ondalık, nokta ayırıcı, işaret korunur', () {
      const southWest = DirectionsTarget(
        latitude: -33.8688197,
        longitude: -151.2092955,
      );

      final destination = DirectionsLinks.googleMapsWeb(
        southWest,
      ).queryParameters['destination'];

      expect(destination, '-33.868820,-151.209296');
      expect(destination, isNot(contains('%2C')));
    });

    test('tam sayı koordinat da altı ondalıkla yazılır', () {
      const target = DirectionsTarget(latitude: 41, longitude: 29);

      expect(
        DirectionsLinks.appleMaps(target).queryParameters['daddr'],
        '41.000000,29.000000',
      );
    });

    // Varış saati = iş başlangıcı kabul kriteri; ama üç şemanın hiçbiri
    // (`api=1`, `comgooglemaps://`, `maps://`) varış saati parametresi
    // belgelemiyor — yazılırsa sessizce düşer. Bağlantıya yazılmıyor ki
    // kullanıcı saati ayarlanmış sanmasın; ekran bunu metinle söylüyor.
    for (final entry in _builders.entries) {
      test('${entry.key}: varış saati bağlantıya yazılmıyor', () {
        final uri = entry.value(_withArrival);

        expect(uri.queryParameters.keys, isNot(contains('arrival_time')));
        expect(uri.queryParameters.keys, isNot(contains('time')));
        expect(uri.queryParameters.keys, isNot(contains('ttype')));
        expect(uri.toString(), isNot(contains('2026')));
      });

      // Kullanıcının konumu URL'ye girmez: harita uygulaması başlangıcı
      // cihazdan kendisi okuyor.
      test('${entry.key}: başlangıç (saddr/origin) yok', () {
        final uri = entry.value(_moda);

        expect(uri.queryParameters.keys, isNot(contains('saddr')));
        expect(uri.queryParameters.keys, isNot(contains('origin')));
      });
    }
  });

  test('DirectionsApp etiketleri Türkçe uygulama adları', () {
    expect(DirectionsApp.apple.label, 'Apple Haritalar');
    expect(DirectionsApp.google.label, 'Google Haritalar');
  });
}
