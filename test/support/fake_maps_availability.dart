import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/maps_availability.dart';
import 'package:provider/provider.dart';

/// Harita bayrağını çözülmüş hâliyle ağaca verir; üretimde `main.dart` aynı
/// sağlayıcıyı okunmamış kurar ve açılış ekranı çözer.
///
/// Harita çizen ekranlar (`MapExplorePage`, `MapFirstAddressPage`) bayrağı
/// `MapsAvailability.of` ile okur ve sağlayıcı yoksa `Provider` hata verir.
/// [available] `false` ise ekranlar `GoogleMap` yerine yer tutucu çizer
/// (is-koala/koala#172).
Widget withMapsAvailability(Widget child, {bool available = true}) {
  return ChangeNotifierProvider<MapsAvailability>(
    create: (_) => MapsAvailability.resolved(isAvailable: available),
    child: child,
  );
}

/// Yerel kanalın yerine geçen sahte: çağrıları sayar, ilk [missingFirst]
/// çağrıda kanal kayıtlı değilmiş gibi davranır (`MissingPluginException`),
/// sonra `isAvailable`'a [available] döner. [available] `null` ise kanal hep
/// cevapsızdır.
///
/// Test bitince kaldırılır; testler arasında sızmaz.
class FakeMapsAvailabilityChannel {
  FakeMapsAvailabilityChannel({
    required this.available,
    this.missingFirst = 0,
  }) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(MapsAvailability.channel, _handle);
    addTearDown(
      () => messenger.setMockMethodCallHandler(MapsAvailability.channel, null),
    );
  }

  final bool? available;
  final int missingFirst;

  /// `isAvailable` kaç kez soruldu; yeniden denemeler de sayılır.
  int calls = 0;

  Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'isAvailable') throw MissingPluginException();
    calls++;
    final value = available;
    if (value == null || calls <= missingFirst) throw MissingPluginException();
    return value;
  }
}
