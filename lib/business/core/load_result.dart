import 'package:koala/product/network/api_exception.dart';

/// Birlikte başlatılan birkaç isteğin her birinin sonucu: değer ya da hata.
///
/// `Future.wait` ilk hatada bütün grubu düşürür; işveren ekranları ise bir
/// yardımcı kayıt gelmediğinde diğerlerini yine çizmek istiyor (ilan
/// detayında mesai/uyuşmazlık/ödeme denemeleri, aday profilinde
/// puan/yorum/rozet). [capture] her isteği kendi zarfına alıyor, çağıran
/// sonuçları tek tek okuyor.
class LoadResult<T> {
  const LoadResult.success(this.value) : error = null;

  const LoadResult.failure(this.error) : value = null;

  final T? value;
  final ApiException? error;

  /// İstek sunucudan hatayla döndü mü. `value == null` bunu söylemez:
  /// `data: null` dönen bir uç (puan özeti gibi) başarılı ve boştur.
  bool get failed => error != null;

  /// [operation]'ı çalıştırır; [ApiException] dışındaki hatalar yükselir.
  static Future<LoadResult<T>> capture<T>(Future<T> operation) async {
    try {
      return LoadResult.success(await operation);
    } on ApiException catch (error) {
      return LoadResult.failure(error);
    }
  }
}
