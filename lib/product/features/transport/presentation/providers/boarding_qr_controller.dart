import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/network/api_exception.dart';

typedef BoardingQrLoader = Future<BoardingQr> Function();

/// Ekrandaki biniş QR'ını sunucunun `refreshAt`'ine göre yenileyen
/// denetleyici (is-koala/koala#217). İşçinin kendi QR'ı ve işverenin servis
/// QR'ı aynı döngüyü kullanıyor.
///
/// Zamanlama cihaz saatine değil sunucunun verdiği süreye bağlı: yeni QR
/// yanıtın geldiği andan `refreshAt - issuedAt` sonra istenir, böylece saati
/// kaymış bir telefon da QR'ı zamanında yeniler. Yenileme düşerse eldeki QR
/// sunucunun kabul ettiği süre boyunca (`expiresAt`) gösterilmeye devam
/// eder, [retryDelay] sonra yeniden denenir; süre dolunca [isExpired] olur
/// ve ekran QR'ı geçersiz diye işaretler.
class BoardingQrController extends ChangeNotifier {
  BoardingQrController({
    required BoardingQrLoader load,
    DateTime Function()? clock,
  }) : _load = load,
       _clock = clock ?? DateTime.now;

  /// Geçici bir hatayla düşen yenilemeden sonra bekleme.
  static const Duration retryDelay = Duration(seconds: 10);

  BoardingQrLoader _load;
  final DateTime Function() _clock;

  BoardingQr? _qr;
  DateTime? _receivedAt;
  ApiException? _error;
  bool _loading = false;
  int _generation = 0;
  Timer? _refreshTimer;
  Timer? _expiryTimer;
  bool _disposed = false;

  BoardingQr? get qr => _qr;
  ApiException? get error => _error;
  bool get isLoading => _loading;

  /// Gösterilen QR'ın sunucu tarafında kabul süresi doldu mu. Statik QR hiç
  /// dolmaz.
  bool get isExpired {
    final lifetime = _lifetime;
    final receivedAt = _receivedAt;
    if (lifetime == null || receivedAt == null) return false;
    return !_clock().isBefore(receivedAt.add(lifetime));
  }

  Duration? get _lifetime {
    final qr = _qr;
    final expiresAt = qr?.expiresAt;
    if (qr == null || qr.isStatic || expiresAt == null) return null;
    return expiresAt.difference(qr.issuedAt);
  }

  /// Yükleyiciyi değiştirir (işverenin dönen/sabit QR seçimi) ve hemen
  /// yeniden okur. Eski QR yeni gelene kadar gösterilmez: iki türü
  /// karıştırmak yanlış QR'ı bastırırdı.
  Future<void> switchTo(BoardingQrLoader load) {
    _load = load;
    _qr = null;
    _receivedAt = null;
    return refresh();
  }

  /// Sunucudan yeni QR ister.
  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_generation;
    _refreshTimer?.cancel();
    _loading = true;
    notifyListeners();
    try {
      final qr = await _load();
      if (_disposed || generation != _generation) return;
      _accept(qr);
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return;
      _error = error;
      _loading = false;
      // Yalnız geçici hatalar kendiliğinden yeniden denenir; koltuk yok ya
      // da yetki yok gibi bir cevap beklemekle değişmez.
      if (BoardingFailure.classify(error).isRetryable) _schedule(retryDelay);
      notifyListeners();
    }
  }

  /// Başka bir yoldan gelen QR'ı (anahtar yenileme yanıtı) gösterir.
  void replace(BoardingQr qr) {
    if (_disposed) return;
    _generation++;
    _accept(qr);
  }

  /// Uygulama arka plandayken zamanlayıcılar durur.
  void pause() {
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
  }

  void _accept(BoardingQr qr) {
    _qr = qr;
    _receivedAt = _clock();
    _error = null;
    _loading = false;
    final delay = qr.refreshDelay;
    if (delay != null) _schedule(delay);
    _expiryTimer?.cancel();
    final lifetime = _lifetime;
    if (lifetime != null) {
      _expiryTimer = Timer(lifetime, () {
        if (!_disposed) notifyListeners();
      });
    }
    notifyListeners();
  }

  void _schedule(Duration delay) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(delay, () => unawaited(refresh()));
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
