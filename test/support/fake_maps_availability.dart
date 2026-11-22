import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/maps_availability.dart';
import 'package:provider/provider.dart';

/// Harita bayrağını çözülmüş hâlde ağaca verir; [available] `false` ise
/// ekranlar yer tutucu çizer (#172).
Widget withMapsAvailability(Widget child, {bool available = true}) {
  return ChangeNotifierProvider<MapsAvailability>(
    create: (_) => MapsAvailability.resolved(isAvailable: available),
    child: child,
  );
}

/// Yerel kanal sahtesi: ilk [missingFirst] çağrıda kanal yokmuş gibi davranır,
/// sonra [available] döner; `null` ise hep cevapsız.
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
