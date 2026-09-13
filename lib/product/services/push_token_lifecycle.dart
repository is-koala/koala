import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/services/push_token_service.dart';
import 'package:koala/product/services/push_token_source.dart';

/// Token'ı oturuma göre sunucuya yazar, bekletir, siler.
///
/// Yenileme olayı `currentToken`'dan önce gelir: FCM olayı geldiğinde
/// `getToken` henüz eski değeri dönebilir. Yazım başarısızlığı kullanıcıya
/// gösterilmez ve oturumu düşürmez. Çıkışta silme düşse bile çıkış
/// tamamlanır — çağıran `clearQuietly` kullanır, sonra `/auth/logout` gider.
class PushTokenLifecycle {
  PushTokenLifecycle._(this._service, this._source, this._session);

  static final PushTokenLifecycle _instance = PushTokenLifecycle._(
    PushTokenService(),
    const UnavailablePushTokenSource(),
    SessionManager(),
  );

  factory PushTokenLifecycle() => _instance;

  /// Verilen bağımlılıklarla kurulu örnek.
  ///
  /// Testlerde sahte kaynak ve istemci bağlamak için, [AuthService]
  /// test fabrikasında da aynı oturumu paylaşmak için kullanılıyor.
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

  /// Firebase ayağa kalktıktan sonra gerçek FCM kaynağına geçmek için.
  ///
  /// Üretim tekili [AuthService] yüklenirken kurulur; o anda Firebase
  /// henüz yok. Splash başlatınca kaynak değişir, dinleyici yeniden bağlanır.
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
