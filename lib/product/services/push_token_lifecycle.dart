import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/services/push_token_service.dart';
import 'package:koala/product/services/push_token_source.dart';

/// Token'ı oturuma göre sunucuya yazar ve siler. Yazım hatası kullanıcıya
/// gösterilmez; çıkışta silme düşse de çıkış tamamlanır.
class PushTokenLifecycle {
  PushTokenLifecycle._(this._service, this._source, this._session);

  static final PushTokenLifecycle _instance = PushTokenLifecycle._(
    PushTokenService(),
    const UnavailablePushTokenSource(),
    SessionManager(),
  );

  factory PushTokenLifecycle() => _instance;

  /// Testler ve [AuthService] aynı oturumu paylaşsın diye.
  factory PushTokenLifecycle.withDependencies({
    required PushTokenService service,
    required PushTokenSource source,
    required SessionManager session,
  }) {
    return PushTokenLifecycle._(service, source, session);
  }

  final PushTokenService _service;
  PushTokenSource _source;
  final SessionManager _session;

  String? _pending;
  StreamSubscription<String>? _refreshSub;

  /// Üretim tekili Firebase'den önce kuruluyor; splash gerçek FCM kaynağına
  /// geçirir.
  void useSource(PushTokenSource source) {
    _source = source;
    final subscription = _refreshSub;
    _refreshSub = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  Future<void> syncQuietly() async {
    final token = _pending ?? await _source.currentToken();
    if (token == null || token.isEmpty) return;

    if (!_session.isLoggedIn) {
      _pending = token;
      return;
    }

    try {
      await _service.save(token);
      _pending = null;
    } on ApiException catch (error, stackTrace) {
      debugPrint('Push token yazılamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> clearQuietly() async {
    try {
      await _service.clear();
    } on ApiException catch (error, stackTrace) {
      debugPrint('Push token silinemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    _pending = null;
  }

  void listen() {
    _refreshSub ??= _source.onRefresh.listen((token) {
      _pending = token;
      unawaited(syncQuietly());
    });
  }
}
