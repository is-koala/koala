import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:koala/product/network/realtime_client.dart';

/// Canlı bağlantıyı uygulamanın yaşam döngüsüne ve ağa bağlar.
///
/// STOMP kütüphanesi kopan soketi kendi zamanlayıcısıyla yeniden deniyor,
/// ama iki durumu göremiyor: işletim sistemi arka plandaki soketi sessizce
/// öldürdüğünde kalp atışı bekçisi bunu ancak on saniyeler sonra anlıyor,
/// ağ değiştiğinde (Wi-Fi → hücresel) eski TCP bağlantısı "kapandı" demeden
/// ölü kalabiliyor. Bu sınıf o iki anda [RealtimeClient.resume] çağırıyor:
///
/// - **Ön plana dönüş.** Kısa bir ayrılıştan (bildirim çekmecesi, uygulama
///   değiştirici) sonra bağlantı büyük olasılıkla sağlam; yalnızca
///   `resumed` duyurulur ve ekranlar bir kez REST'ten tamamlar.
///   [staleAfter]'dan uzun kalınmışsa soket şüpheli sayılır ve yeniden
///   kurulur.
/// - **Ağ geri geldi / değişti.** Her seferinde yeniden kurulur; art arda
///   gelen olaylar (Wi-Fi ve hücresel aynı anda) [networkDebounce] içinde
///   tek sayılır.
///
/// Dinleyen ekran yoksa istemci zaten hiçbir şey yapmıyor; bağlantıyı
/// ekranlar açıyor, bu sınıf yalnızca ayakta tutuyor.
class RealtimeConnectionKeeper with WidgetsBindingObserver {
  RealtimeConnectionKeeper({
    RealtimeClient? client,
    Stream<void>? networkAvailable,
    DateTime Function()? now,
    this.onResumed,
  }) : _client = client ?? RealtimeClient(),
       _networkAvailable = networkAvailable ?? _connectivityChanges(),
       _now = now ?? DateTime.now;

  /// Arka planda bundan uzun kalınmışsa soket ölü sayılıp yeniden kuruluyor.
  ///
  /// Kalp atışı 10 s; kütüphanenin bekçisi iki kayıp atıştan sonra kapatıyor.
  /// Bu süreden kısa ayrılışlarda soket ya sağlam ya da bekçi zaten
  /// yakalamak üzere.
  static const Duration staleAfter = Duration(seconds: 20);

  /// Ağ olaylarının tek sayıldığı pencere.
  static const Duration networkDebounce = Duration(seconds: 2);

  final RealtimeClient _client;
  final Stream<void> _networkAvailable;
  final DateTime Function() _now;

  /// Uygulama ön plana döndüğünde çağrılır; bağlantıdan bağımsız tazelemeler
  /// (bildirim rozeti) buraya bağlanıyor.
  final VoidCallback? onResumed;

  StreamSubscription<void>? _network;
  DateTime? _pausedAt;
  DateTime? _lastNetworkEventAt;
  bool _started = false;

  static Stream<void> _connectivityChanges() {
    return Connectivity().onConnectivityChanged
        .where(
          (results) =>
              results.any((result) => result != ConnectivityResult.none),
        )
        .map((_) {});
  }

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _network = _networkAvailable.listen(
      (_) => _onNetworkAvailable(),
      onError: (Object error) => debugPrint('Ağ durumu dinlenemedi: $error'),
    );
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_network?.cancel());
    _network = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _pausedAt ??= _now();
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
        // Geçiş durumu: gelen arama, kontrol merkezi. Ne kopuş ne dönüş.
        break;
    }
  }

  void _onResumed() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null) return;

    final away = _now().difference(pausedAt);
    _client.resume(suspectStale: away >= staleAfter);
    onResumed?.call();
  }

  void _onNetworkAvailable() {
    final now = _now();
    final last = _lastNetworkEventAt;
    if (last != null && now.difference(last) < networkDebounce) return;
    _lastNetworkEventAt = now;
    _client.resume(suspectStale: true);
  }
}
