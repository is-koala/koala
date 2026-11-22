import 'package:dio/dio.dart';
import 'package:koala/product/network/device_hints.dart';
import 'package:koala/product/network/device_identity.dart';

/// Her isteğe cihaz kimliği ve ipucu başlıklarını ekler. Oturumdan bağımsız,
/// çünkü backend cihazı giriş ve kayıt sırasında oluşturuyor.
class DeviceInterceptor extends Interceptor {
  DeviceInterceptor(this._deviceIdentity, {required this._hints});

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
