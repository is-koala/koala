import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/maps_availability.dart';
import 'package:provider/provider.dart';

import '../../support/fake_maps_availability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapsAvailability.resolve', () {
    test('okunmadan önce kapalı ve çözülmemiş', () {
      final availability = MapsAvailability();

      expect(availability.isResolved, isFalse);
      expect(availability.isAvailable, isFalse);
    });

    test('yerel taraf anahtarı verdiyse açık', () async {
      final channel = FakeMapsAvailabilityChannel(available: true);
      final availability = MapsAvailability();
      var notifications = 0;
      availability.addListener(() => notifications++);

      await availability.resolve();

      expect(availability.isResolved, isTrue);
      expect(availability.isAvailable, isTrue);
      expect(channel.calls, 1);
      expect(notifications, 1);
    });

    test('yerel taraf anahtar yok dediyse kapalı', () async {
      FakeMapsAvailabilityChannel(available: false);
      final availability = MapsAvailability();

      await availability.resolve();

      expect(availability.isAvailable, isFalse);
    });

    // Kanal motorla birlikte kaydoluyor; açılış ekranı ilk kareden sonra
    // soruyor ama yarış sıfır değil. İlk denemede kayıt yoksa kısa aralıkla
    // yeniden denenir, gerçek cevap gelince o geçerli olur.
    test('kanal geç kaydolursa yeniden dener ve açık okur', () async {
      final channel = FakeMapsAvailabilityChannel(
        available: true,
        missingFirst: 2,
      );
      final availability = MapsAvailability();

      await availability.resolve(retryDelay: Duration.zero);

      expect(channel.calls, 3);
      expect(availability.isAvailable, isTrue);
    });

    // Kanalın arkasında kimse yoksa (eski yerel derleme, eksik kayıt) bayrak
    // kapalı: bu sınıfın işi çökmeyi önlemek, belirsizlikte harita kurulmaz.
    // Denemeler sınırlı ki açılış ekranı beklemesin.
    test('kanal hiç cevap vermezse sınırlı dener ve kapalı sayar', () async {
      final channel = FakeMapsAvailabilityChannel(available: null);
      final availability = MapsAvailability();
      final logs = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = previous);

      await availability.resolve(retryDelay: Duration.zero);

      expect(channel.calls, MapsAvailability.missingPluginRetries + 1);
      expect(availability.isResolved, isTrue);
      expect(availability.isAvailable, isFalse);
      expect(logs.single, contains('kayıtlı değil'));
    });

    test('ikinci çözme yeniden okumaz', () async {
      final channel = FakeMapsAvailabilityChannel(available: true);
      final availability = MapsAvailability();

      await availability.resolve();
      await availability.resolve();

      expect(channel.calls, 1);
    });

    test('resolved kurucusu okumadan hazır', () {
      final availability = MapsAvailability.resolved(isAvailable: true);

      expect(availability.isResolved, isTrue);
      expect(availability.isAvailable, isTrue);
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
