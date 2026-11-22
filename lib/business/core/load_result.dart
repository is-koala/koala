import 'package:koala/product/network/api_exception.dart';

/// Birlikte başlatılan isteklerin tek tek sonucu. `Future.wait` ilk hatada
/// grubu düşürür; işveren ekranları bir yardımcı kayıt gelmese de diğerlerini
/// çizmek istiyor.
class LoadResult<T> {
  const LoadResult.success(this.value) : error = null;

  const LoadResult.failure(this.error) : value = null;

  final T? value;
  final ApiException? error;

  /// `value == null` bunu söylemez: `data: null` dönen uç başarılı ve boştur.
  bool get failed => error != null;

  /// [ApiException] dışındaki hatalar yükselir.
  static Future<LoadResult<T>> capture<T>(Future<T> operation) async {
    try {
      return LoadResult.success(await operation);
    } on ApiException catch (error) {
      return LoadResult.failure(error);
    }
  }
}
