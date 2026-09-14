import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/maps_availability.dart';
import 'package:provider/provider.dart';

/// Harita bayrağını ağaca verir; üretimde `main.dart` aynı sağlayıcıyı kurar.
///
/// Harita çizen ekranlar (`MapExplorePage`, `MapFirstAddressPage`) bayrağı
/// `MapsAvailability.of` ile okur ve sağlayıcı yoksa `Provider` hata verir.
/// [available] `false` ise ekranlar `GoogleMap` yerine yer tutucu çizer
/// (is-koala/koala#172).
Widget withMapsAvailability(Widget child, {bool available = true}) {
  return Provider<MapsAvailability>.value(
    value: MapsAvailability(isAvailable: available),
    child: child,
  );
}

/// Yerel kanalın yerine geçer: `isAvailable` [available] döner. `null`
/// verilirse kanal cevapsız kalır ve `MapsAvailability.read` kapalı sayar.
///
/// Test bitince kaldırılır; testler arasında sızmaz.
void mockMapsAvailabilityChannel(bool? available) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    MapsAvailability.channel,
    available == null
        ? null
        : (MethodCall call) async => switch (call.method) {
            'isAvailable' => available,
            _ => throw MissingPluginException(),
          },
  );
  addTearDown(
    () => messenger.setMockMethodCallHandler(MapsAvailability.channel, null),
  );
}
