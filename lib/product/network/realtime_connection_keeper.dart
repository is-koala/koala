import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:koala/product/network/realtime_client.dart';

/// Canlı bağlantıyı yaşam döngüsüne ve ağa bağlar.
///
/// STOMP kütüphanesi iki durumu göremiyor: işletim sisteminin arka planda
/// öldürdüğü soket ve ağ değişince ölü kalan TCP bağlantısı. Bu sınıf o anlarda
/// [RealtimeClient.resume] çağırıyor:
/// - **Ön plana dönüş:** kısa ayrılışta yalnız `resumed`; [staleAfter]'dan
///   uzunsa yeniden kurulur.
/// - **Ağ değişti:** yeniden kurulur; art arda olaylar [networkDebounce] içinde
///   tek sayılır.
class RealtimeConnectionKeeper with WidgetsBindingObserver {
  RealtimeConnectionKeeper({
    RealtimeClient? client,
    Stream<void>? networkAvailable,
    DateTime Function()? now,
    this.onResumed,
  }) : _client = client ?? RealtimeClient(),
       _networkAvailable = networkAvailable ?? _connectivityChanges(),
       _now = now ?? DateTime.now;

  /// Kalp atışı 10 sn ve bekçi iki kayıp atıştan sonra kapatıyor; bundan kısa
  /// ayrılışta soket ya sağlam ya da bekçi yakalamak üzere.
  static const Duration staleAfter = Duration(seconds: 20);

  static const Duration networkDebounce = Duration(seconds: 2);

  final RealtimeClient _client;
  final Stream<void> _networkAvailable;
  final DateTime Function() _now;

  /// Bağlantıdan bağımsız tazelemeler (bildirim rozeti) için.
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
        // Geçiş durumu (gelen arama, kontrol merkezi): ne kopuş ne dönüş.
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
