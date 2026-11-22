/// Kimlik kartının MRZ'sinden türeyen çip anahtarı: belge no, doğum tarihi, son
/// geçerlilik (ICAO 9303 Part 11 §4.3.2). Türetmeyi `dmrtd` yapıyor; bizim
/// işimiz üç alanı **doğru** okumak.
///
/// TCKK'nın MRZ'si arka yüzde ve **TD1** (3 × 30); pasaportun TD3'ü değil.
/// Flutter bağımlılığı yok ki cihaz olmadan test edilsin.
library;

import 'package:koala/employee/features/settings/models/national_identity_number.dart';

const int _lineLength = 30;

const int _lineCount = 3;

class MrzKey {
  const MrzKey({
    required this.documentNumber,
    required this.birthDate,
    required this.expiryDate,
    this.nationalIdentityNumber,
    this.normalizedTd1,
  });

  /// `<` dolgusu temizlenmiş; TCKK'da `A01B23456` gibi dokuz karakter.
  final String documentNumber;

  final DateTime birthDate;

  final DateTime expiryDate;

  /// Birinci satırın isteğe bağlı alanındaki TCKN; her belgede yok. Formu
  /// **doldurmuyor** (OCR kanıt değil); `MrzScanSession`'ın kararlılık imzası
  /// için duruyor.
  final String? nationalIdentityNumber;

  /// Canlı taramada kararlılığı ölçen düzeltilmiş üç satır; elle girişte
  /// `null`.
  final String? normalizedTd1;

  /// Yıpranmış ya da kötü ışıktaki kartı kurtaran yol; her zaman açık.
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

  /// Ham OCR metninden TD1 ayrıştırır. Kontrol hanelerinden biri tutmazsa
  /// `null` — **kasıtlı güvenlik ağı**: yanlış alanla çipe gitmek anlaşılmaz
  /// bir oturum hatası verir, burada elenen tarama yalnız bir tekrar olur.
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

  /// ICAO 9303 Part 3 §4.9: ağırlıklar 7-3-1, `A`-`Z` 10-35, `<` sıfır.
  /// Tanımsız karakterde `null`; sıfır saymak hatalı okumayı geçerli
  /// gösterirdi.
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

  static bool isCheckDigitValid(String field, String digit) {
    final expected = checkDigit(field);
    if (expected == null) return false;
    return digit == '$expected';
  }

  static int? _characterValue(String character) {
    final code = character.codeUnitAt(0);

    if (character == '<') return 0;
    if (code >= 0x30 && code <= 0x39) return code - 0x30;
    if (code >= 0x41 && code <= 0x5A) return code - 0x41 + 10;
    return null;
  }

  /// OCR satırları ayrı ya da tek blok verebiliyor. `«` `<`'e düzeltiliyor; `K`
  /// **düzeltilmiyor**, isim alanında meşru harf.
  static List<String> _candidateLines(String rawText) {
    final lines = <String>[];

    for (final rawLine in rawText.split('\n')) {
      final sanitized = _sanitize(rawLine);
      if (sanitized.length == _lineLength) {
        lines.add(sanitized);
      } else if (sanitized.length > _lineLength &&
          sanitized.length % _lineLength == 0) {
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
    // Ad satırına bakılmıyor ama TD1 olduğunu doğrulamak için varlığı aranıyor.
    if (third.length != _lineLength) return null;
    // Kimlik kartı `I`, ikamet belgesi `A` ya da `C`.
    if (!RegExp(r'^[IAC]').hasMatch(rawFirst)) return null;

    // Yalnız rakam olabilen konumlar **doğrulamadan önce** düzeltiliyor:
    // bileşik hane satırın tamamından hesaplanıyor. Haneler de düzeltiliyor;
    // hane ile alan **birlikte** tutmalı, güvenlik ağı zayıflamıyor.
    final first = _repairAt(rawFirst, const [14]);
    final second = _repairAt(rawSecond, const [
      0, 1, 2, 3, 4, 5, 6, // doğum tarihi ve kontrol hanesi
      8, 9, 10, 11, 12, 13, 14, // son geçerlilik ve kontrol hanesi
      29, // bileşik kontrol hanesi
    ]);

    final documentNumberField = first.substring(5, 14);
    final documentNumberDigit = first[14];

    // Dokuzdan uzun belge numarası TCKK'da yok; yanlış ayrıştırmaktansa elle
    // girişe düşülür.
    if (documentNumberDigit == '<') return null;
    if (!isCheckDigitValid(documentNumberField, documentNumberDigit)) {
      return null;
    }

    final birthField = second.substring(0, 6);
    if (!isCheckDigitValid(birthField, second[6])) return null;

    final expiryField = second.substring(8, 14);
    if (!isCheckDigitValid(expiryField, second[14])) return null;

    // Bileşik hane: tek alanlar tutup bu tutmuyorsa başka yerde okuma hatası
    // var.
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
      normalizedTd1: '$first\n$second\n$third',
    );
  }

  /// OCR'ın en sık karıştırdığı harfleri rakama çevirir; yanlış düzeltme
  /// kontrol hanesinde yakalanır.
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

  static String? _optionalIdentityNumber(String first) =>
      NationalIdentityNumber.fromMrzOptionalData(first.substring(15));

  /// `YYMMDD` → tarih. Son geçerlilik hep 2000'li; doğum tarihinde yıl bugünün
  /// iki hanesinden büyükse 19xx, yoksa 2043 doğumlu üretirdik.
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
    // `DateTime(2025, 2, 30)` 2 Mart'a taşar; taşma okuma hatası demek.
    if (date.month != month || date.day != day) return null;
    return date;
  }
}
