/// TC kimlik numarası kuralı — **tek yerde**.
///
/// Numara üç yoldan geliyor ve üçü de buraya bakıyor: canlı MRZ taraması
/// (`MrzKey`), çipteki DG1'in MRZ'si (`ChipHolder`) ve elle yazılan beyan
/// (`ManualDeclaration`). Kural üç kopyaya ayrıştığında iki farklı
/// temizlemeyle sapmıştı: biri bütün `<`'leri atıyor, öteki yalnız
/// kırpıyordu; ayırıcı `<` ile başlayan geçerli bir kart çipten okunamaz
/// sayılırken taramadan okunuyordu. `PasswordRule` ile aynı gerekçe: aynı
/// kuralı üç ekranın farklı uygulaması kullanıcıyı şaşırtır.
///
/// Sunucu (`MachineReadableZone.nationalIdentityNumber`) da aynı şeyi
/// yapıyor: dolgu karakterlerini atıp **tam** on bir hane arıyor; ayırıcı
/// `<` ile başlayan da başlamayan da kabul ediliyor.
abstract final class NationalIdentityNumber {
  /// TC kimlik numarası tam on bir hane. Elle girişin uzunluk sınırı da bu.
  static const int length = 11;

  /// Tam on bir rakam; sunucunun aradığı desen.
  static final RegExp _pattern = RegExp('^\\d{$length}\$');

  /// MRZ'nin isteğe bağlı veri alanındaki dolgu: `<` ve boşluk. Hepsi
  /// atılıyor, yalnız sondakiler değil — `dmrtd` sondaki `<`'leri zaten
  /// temizliyor, baştaki ayırıcı ise okumaya kalıyor.
  static final RegExp _padding = RegExp(r'[<\s]');

  /// [value] tam on bir rakam mı.
  static bool isValid(String value) => _pattern.hasMatch(value);

  /// TD1 MRZ'sinin isteğe bağlı veri alanından TC kimlik numarası; dolgu
  /// atıldıktan sonra tam on bir hane kalmıyorsa `null`.
  ///
  /// TCKK sahada iki düzenle geliyor: `12345678950<<<<` ve `<12345678950<<<`.
  /// İkisi de aynı numarayı veriyor. On birden fazla hane kalırsa da `null`:
  /// kırpıp göstermek kartta olmayan bir numarayı beyan etmek olurdu.
  static String? fromMrzOptionalData(String optionalData) {
    final digits = optionalData.replaceAll(_padding, '');
    return isValid(digits) ? digits : null;
  }
}
