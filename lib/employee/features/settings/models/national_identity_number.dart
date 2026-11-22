/// TC kimlik numarası kuralı, **tek yerde**: MRZ taraması, çipteki DG1 ve elle
/// beyan buraya bakıyor. Üç kopya farklı temizlemeyle sapmıştı. Sunucu da
/// dolguyu atıp tam on bir hane arıyor.
abstract final class NationalIdentityNumber {
  static const int length = 11;

  static final RegExp _pattern = RegExp('^\\d{$length}\$');

  /// Hepsi atılıyor, yalnız sondakiler değil: `dmrtd` sondakileri temizliyor,
  /// baştaki ayırıcı kalıyor.
  static final RegExp _padding = RegExp(r'[<\s]');

  static bool isValid(String value) => _pattern.hasMatch(value);

  /// `12345678950<<<<` ve `<12345678950<<<` aynı numarayı verir. On birden
  /// fazla hane kalırsa `null`: kırpmak kartta olmayan numara beyan etmek olur.
  static String? fromMrzOptionalData(String optionalData) {
    final digits = optionalData.replaceAll(_padding, '');
    return isValid(digits) ? digits : null;
  }
}
