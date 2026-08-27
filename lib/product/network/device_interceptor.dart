import 'package:dio/dio.dart';
import 'package:koala/product/network/device_identity.dart';

/// Her isteğe cihaz kimliği başlığını ekler.
///
/// Ayrı bir interceptor olmasının sebebi, başlığın oturumdan bağımsız
/// olması: giriş yapılmamış isteklerde de gidiyor, çünkü backend cihazı
/// `/auth/login` ve `/auth/complete-registration` sırasında oluşturuyor.
class DeviceInterceptor extends Interceptor {
  DeviceInterceptor(this._deviceIdentity);

  final DeviceIdentity _deviceIdentity;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers[DeviceIdentity.deviceIdHeader] = await _deviceIdentity
        .deviceId();
    handler.next(options);
  }
}
