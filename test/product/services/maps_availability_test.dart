import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/maps_availability.dart';
import 'package:provider/provider.dart';

import '../../support/fake_maps_availability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapsAvailability.read', () {
    test('yerel taraf anahtarı verdiyse açık', () async {
      mockMapsAvailabilityChannel(true);

      final availability = await MapsAvailability.read();

      expect(availability.isAvailable, isTrue);
    });

    test('yerel taraf anahtar yok dediyse kapalı', () async {
      mockMapsAvailabilityChannel(false);

      final availability = await MapsAvailability.read();

      expect(availability.isAvailable, isFalse);
    });

    // Kanalın arkasında kimse yoksa (eski yerel derleme, eksik kayıt) bayrak
    // kapalı: bu sınıfın işi çökmeyi önlemek, belirsizlikte harita kurulmaz.
    test('kanal cevap vermiyorsa kapalı sayılır', () async {
      mockMapsAvailabilityChannel(null);

      final availability = await MapsAvailability.read();

      expect(availability.isAvailable, isFalse);
    });
  });

  group('MapsAvailability.of', () {
    testWidgets('sağlayıcıdaki değeri okur', (tester) async {
      late MapsAvailability seen;
      await tester.pumpWidget(
        withMapsAvailability(
          Builder(
            builder: (context) {
              seen = MapsAvailability.of(context);
              return const SizedBox.shrink();
            },
          ),
          available: false,
        ),
      );

      expect(seen.isAvailable, isFalse);
    });

    // Bayrağı sormadan harita çizen bir ekran olmasın: sağlayıcı eksikse
    // sessizce "açık" sayılmaz, hata yüzeye çıkar.
    testWidgets('sağlayıcı yoksa hata verir', (tester) async {
      Object? error;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              MapsAvailability.of(context);
            } on ProviderNotFoundException catch (caught) {
              error = caught;
            }
            return const SizedBox.shrink();
          },
        ),
      );

      expect(error, isA<ProviderNotFoundException>());
    });
  });
}
