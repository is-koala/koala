/// Kimlik kartının makine okunabilir alanından (MRZ) türeyen çip anahtarı.
///
/// Çipi açan üç alan burada: **belge numarası, doğum tarihi ve son geçerlilik
/// tarihi**. BAC/PACE anahtarı bu üçünün her birinin kendi kontrol hanesiyle
/// birleştirilmesinden üretiliyor (ICAO Doc 9303 Part 11 §4.3.2); türetmeyi
/// `dmrtd` yapıyor, bizim işimiz üç alanı **doğru** okumak.
///
/// TCKK'nın MRZ'si kartın **arka yüzünde** ve **TD1** biçiminde: 3 satır ×
/// 30 karakter. Pasaportun TD3'ü (2 × 44) değil — alanların yeri bambaşka.
///
/// Bu dosyada Flutter'a ya da bir eklentiye bağımlılık **yok**; OCR'ın
/// kendisi [MrzScanner]'da. Ayrım bilerek: ayrıştırma ve kontrol hanesi
/// doğrulaması cihaz olmadan test edilebilmeli.
library;

/// TD1 MRZ'sinin bir satırındaki karakter sayısı.
const int _lineLength = 30;

/// TD1 MRZ'sindeki satır sayısı.
const int _lineCount = 3;

/// Çipi açan üç alan.
class MrzKey {
  const MrzKey({
    required this.documentNumber,
    required this.birthDate,
    required this.expiryDate,
    this.nationalIdentityNumber,
  });

  /// Belge (seri) numarası; `<` dolgusu temizlenmiş hâli. TCKK'da dokuz
  /// karakter ve `A01B23456` gibi harf-rakam karışık.
  final String documentNumber;

  final DateTime birthDate;

  final DateTime expiryDate;

  /// TCKK'da TC kimlik numarası MRZ'nin birinci satırındaki isteğe bağlı
  /// veri alanında taşınıyor. Her belgede dolu olmadığı için `null`
  /// olabilir; formu önden doldurmak dışında bir yerde güvenilmiyor —
  /// numaranın kartla eşleştiğini sunucu çipten okuyup kendisi doğruluyor.
  final String? nationalIdentityNumber;

  /// Elle girişten gelen anahtar.
  ///
  /// Yıpranmış ya da kötü ışıkta okunmayan kartı kurtaran tek yol bu; OCR
  /// yolunun yedeği olarak her hâlükârda açık kalıyor.
  factory MrzKey.manual({
    required String documentNumber,
    required DateTime birthDate,
    required DateTime expiryDate,
  }) {
    return MrzKey(
      documentNumber: documentNumber.trim().toUpperCase(),
      birthDate: birthDate,
      expiryDate: expiryDate,
    );
  }

  /// OCR'dan gelen ham metinden TD1 MRZ'sini ayrıştırır.
  ///
  /// Kontrol hanelerinden biri tutmazsa `null` döner — **bu kasıtlı bir
  /// güvenlik ağı**: yanlış okunmuş bir alanla çipe gidilirse kart oturumu
  /// açılmadan reddediyor ve kullanıcı nedenini anlamıyor. Burada elenen
  /// tarama, başarısız bir çip oturumuna değil bir tekrara dönüşüyor.
  static MrzKey? parseTd1(String rawText) {
    final lines = _candidateLines(rawText);

    for (var index = 0; index + _lineCount <= lines.length; index++) {
      final parsed = _parseTriplet(
        lines[index],
        lines[index + 1],
        lines[index + 2],
      );
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// ICAO Doc 9303 Part 3 §4.9 kontrol hanesi.
  ///
  /// Ağırlıklar 7-3-1 sırasıyla dönüyor; rakam kendi değeri, `A`-`Z`
  /// 10-35, `<` sıfır sayılıyor. Tanımsız bir karakter geçerse `null`
  /// dönüyor: sıfır saymak, hatalı okumayı geçerli göstermek olurdu.
  static int? checkDigit(String field) {
    const weights = [7, 3, 1];
    var sum = 0;

    for (var index = 0; index < field.length; index++) {
      final value = _characterValue(field[index]);
      if (value == null) return null;
      sum += value * weights[index % weights.length];
    }
    return sum % 10;
  }

  /// Alanın sonundaki kontrol hanesi doğru mu.
  static bool isCheckDigitValid(String field, String digit) {
    final expected = checkDigit(field);
    if (expected == null) return false;
    return digit == '$expected';
  }

  static int? _characterValue(String character) {
    final code = character.codeUnitAt(0);

    // '<'
    if (character == '<') return 0;
    // '0'-'9'
    if (code >= 0x30 && code <= 0x39) return code - 0x30;
    // 'A'-'Z'
    if (code >= 0x41 && code <= 0x5A) return code - 0x41 + 10;
    return null;
  }

  /// Ham OCR metnini MRZ satırı adaylarına indirger.
  ///
  /// OCR üç satırı ayrı ayrı da verebiliyor, hepsini tek bloğa da
  /// yapıştırabiliyor; ikisi de karşılanıyor. Ayrıca `<` karakteri sıkça
  /// `«` ya da `K` olarak okunuyor — ilkini düzeltiyoruz, ikincisini
  /// **düzeltmiyoruz** çünkü `K` isim alanında meşru bir harf.
  static List<String> _candidateLines(String rawText) {
    final lines = <String>[];

    for (final rawLine in rawText.split('\n')) {
      final sanitized = _sanitize(rawLine);
      if (sanitized.length == _lineLength) {
        lines.add(sanitized);
      } else if (sanitized.length > _lineLength &&
          sanitized.length % _lineLength == 0) {
        // Üç satırı tek satıra yapıştıran okuma.
        for (var start = 0; start < sanitized.length; start += _lineLength) {
          lines.add(sanitized.substring(start, start + _lineLength));
        }
      }
    }
    return lines;
  }

  static String _sanitize(String rawLine) {
    final buffer = StringBuffer();

    for (final character in rawLine.toUpperCase().runes) {
      final value = String.fromCharCode(character);
      if (value == '«' || value == '‹' || value == '〈' || value == '<') {
        buffer.write('<');
        continue;
      }
      if (RegExp(r'[A-Z0-9]').hasMatch(value)) buffer.write(value);
    }
    return buffer.toString();
  }

  static MrzKey? _parseTriplet(
    String rawFirst,
    String rawSecond,
    String third,
  ) {
    // Üçüncü satır ad-soyad; içeriğine bakmıyoruz ama TD1'in üç satırlı
    // olduğunu doğrulamak için varlığı aranıyor.
    if (third.length != _lineLength) return null;
    // Kimlik kartı `I`, ikamet belgesi `A` ya da `C` ile başlıyor.
    if (!RegExp(r'^[IAC]').hasMatch(rawFirst)) return null;

    // Yalnız rakam taşıyabilen konumlar **doğrulamadan önce** düzeltiliyor.
    // Sonradan düzeltmek yetmiyor: bileşik kontrol hanesi satırın tamamı
    // üzerinden hesaplanıyor, tek tek alanları düzeltip satırı ham
    // bırakmak bileşiği her seferinde düşürürdü.
    //
    // Kontrol hanelerinin kendisi de düzeltiliyor; onlar da rakam ve OCR
    // onları da karıştırıyor. Güvenlik ağı zayıflamıyor, çünkü hane ile
    // alanın **birlikte** tutması gerekiyor.
    final first = _repairAt(rawFirst, const [14]);
    final second = _repairAt(rawSecond, const [
      0, 1, 2, 3, 4, 5, 6, // doğum tarihi ve kontrol hanesi
      8, 9, 10, 11, 12, 13, 14, // son geçerlilik ve kontrol hanesi
      29, // bileşik kontrol hanesi
    ]);

    final documentNumberField = first.substring(5, 14);
    final documentNumberDigit = first[14];

    // Dokuz karakterden uzun belge numarası isteğe bağlı veri alanına
    // taşıyor ve kontrol hanesinin yerine `<` konuyor. TCKK'da böyle bir
    // numara yok; desteklemek yerine taramayı reddedip elle girişe
    // düşürüyoruz — yanlış ayrıştırmaktansa açıkça başarısız olsun.
    if (documentNumberDigit == '<') return null;
    if (!isCheckDigitValid(documentNumberField, documentNumberDigit)) {
      return null;
    }

    final birthField = second.substring(0, 6);
    if (!isCheckDigitValid(birthField, second[6])) return null;

    final expiryField = second.substring(8, 14);
    if (!isCheckDigitValid(expiryField, second[14])) return null;

    // Bileşik kontrol hanesi: üst satırın 6-30, orta satırın 1-7, 9-15 ve
    // 19-29 pozisyonları. Tek tek alanlar tutup bileşik tutmuyorsa satırın
    // başka bir yerinde okuma hatası var demektir.
    final composite =
        first.substring(5, 30) +
        second.substring(0, 7) +
        second.substring(8, 15) +
        second.substring(18, 29);
    if (!isCheckDigitValid(composite, second[29])) return null;

    final birthDate = _parseDate(birthField, isExpiry: false);
    final expiryDate = _parseDate(expiryField, isExpiry: true);
    if (birthDate == null || expiryDate == null) return null;

    return MrzKey(
      documentNumber: documentNumberField.replaceAll('<', ''),
      birthDate: birthDate,
      expiryDate: expiryDate,
      nationalIdentityNumber: _optionalIdentityNumber(first),
    );
  }

  /// Yalnız rakam taşıyabilen konumlarda OCR'ın en sık karıştırdığı
  /// harfleri rakama çeviriyor.
  ///
  /// Yanlış bir düzeltme kontrol hanesinde yakalanıyor, o yüzden bu adım
  /// riski değil tekrar sayısını azaltıyor.
  static String _repairAt(String line, List<int> indices) {
    const replacements = {
      'O': '0',
      'D': '0',
      'Q': '0',
      'I': '1',
      'L': '1',
      'Z': '2',
      'S': '5',
      'G': '6',
      'B': '8',
    };

    final characters = line.split('');
    for (final index in indices) {
      final replacement = replacements[characters[index]];
      if (replacement != null) characters[index] = replacement;
    }
    return characters.join();
  }

  /// TD1'in birinci satırındaki isteğe bağlı veri alanından TC kimlik
  /// numarası. Alan 11 haneli sayı taşımıyorsa `null`.
  static String? _optionalIdentityNumber(String first) {
    final optional = first.substring(15).replaceAll('<', '');
    return RegExp(r'^\d{11}$').hasMatch(optional) ? optional : null;
  }

  /// `YYMMDD`'yi tarihe çevirir.
  ///
  /// MRZ yüzyıl taşımıyor. Son geçerlilik her zaman 2000'li yıllar: 19xx'te
  /// biten bir kart zaten geçersiz. Doğum tarihinde ise iki haneli yıl
  /// bugünün iki hanesinden büyükse 19xx sayılıyor — aksi hâlde 2043
  /// doğumlu bir kullanıcı üretirdik.
  static DateTime? _parseDate(String field, {required bool isExpiry}) {
    if (!RegExp(r'^\d{6}$').hasMatch(field)) return null;

    final shortYear = int.parse(field.substring(0, 2));
    final month = int.parse(field.substring(2, 4));
    final day = int.parse(field.substring(4, 6));
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final currentShortYear = DateTime.now().year % 100;
    final year = isExpiry
        ? 2000 + shortYear
        : (shortYear > currentShortYear ? 1900 : 2000) + shortYear;

    final date = DateTime(year, month, day);
    // `DateTime(2025, 2, 30)` sessizce 2 Mart'a taşıyor; taşma olduysa
    // okuma hatalı demektir.
    if (date.month != month || date.day != day) return null;
    return date;
  }
}
