import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Harita SDK'sı bu derlemede kullanılabilir mi (#172).
///
/// iOS'ta `MAPS_API_KEY` boşsa ilk `GoogleMap` uygulamayı **çökertiyor**.
/// Splash [resolve] çağırıyor; harita çizen her ekran önce [of] ile sorar ve
/// kapalıysa yer tutucu çizer.
class MapsAvailability extends ChangeNotifier {
  /// Henüz okunmamış: kapalı sayılır.
  MapsAvailability();

  MapsAvailability.resolved({required this._isAvailable}) : _isResolved = true;

  /// iOS'ta `AppDelegate`, Android'de `MainActivity` kaydediyor.
  static const MethodChannel channel = MethodChannel(
    'com.iskoala.koala/maps_availability',
  );

  /// Yerel kanal kaydı motorla geliyor; küçük bir yarış için kısa yeniden
  /// deneme, toplam bir saniyenin altında.
  static const int missingPluginRetries = 3;
  static const Duration missingPluginRetryDelay = Duration(milliseconds: 300);

  bool _isAvailable = false;
  bool _isResolved = false;

  bool get isAvailable => _isAvailable;

  bool get isResolved => _isResolved;

  /// Yerel taraftan bir kez okur. Kanal cevap vermezse harita **kapalı**
  /// sayılır: yer tutucu fark edilir, çökme kullanıcıyı uygulamadan atar.
  Future<void> resolve({Duration retryDelay = missingPluginRetryDelay}) async {
    if (_isResolved) return;
    _isAvailable = await _read(retryDelay);
    _isResolved = true;
    notifyListeners();
  }

  static Future<bool> _read(Duration retryDelay) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final available = await channel.invokeMethod<bool>('isAvailable');
        return available ?? false;
      } on MissingPluginException catch (error) {
        if (attempt < missingPluginRetries) {
          await Future<void>.delayed(retryDelay);
          continue;
        }
        debugPrint(
          'Harita bayrağı okunamadı, harita kapalı sayılıyor: '
          '${channel.name} kanalı ${attempt + 1} denemede de kayıtlı '
          'değil ($error).',
        );
        return false;
      } on PlatformException catch (error) {
        debugPrint('Harita bayrağı okunamadı, harita kapalı sayılıyor: $error');
        return false;
      }
    }
  }

  /// Sağlayıcı yoksa hata fırlar; harita ekranı bayrağı sormadan açılmamalı.
  static MapsAvailability of(BuildContext context) =>
      Provider.of<MapsAvailability>(context, listen: false);
}
