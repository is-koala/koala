import 'package:dio/dio.dart';
import 'package:koala/product/network/device_hints.dart';
import 'package:koala/product/network/device_identity.dart';

/// Her isteğe cihaz kimliği ve cihaz ipucu başlıklarını ekler.
///
/// Ayrı bir interceptor olmasının sebebi, başlıkların oturumdan bağımsız
/// olması: giriş yapılmamış isteklerde de gidiyor, çünkü backend cihazı
/// `/auth/login` ve `/auth/complete-registration` sırasında oluşturuyor ve
/// adını da o anda gelen [DeviceHints]'ten yazıyor.
class DeviceInterceptor extends Interceptor {
  DeviceInterceptor(this._deviceIdentity, {required DeviceHints hints})
    : _hints = hints;

  final DeviceIdentity _deviceIdentity;

  final DeviceHints _hints;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers[DeviceIdentity.deviceIdHeader] = await _deviceIdentity
        .deviceId();
    options.headers.addAll(_hints.headers);
    handler.next(options);
  }
}
