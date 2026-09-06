/// Backend'den ondalık dize olarak gelen tutarları Türkçe gösterime çevirir.
///
/// Tutarı kayan noktaya dönüştürmez; ondalık basamakları ve sondaki sıfırları
/// aynen korur.
abstract final class TurkishMoneyFormatter {
  static final RegExp _decimalPattern = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$');

  static String format(String amount, String currency) {
    final match = _decimalPattern.firstMatch(amount);
    if (match == null) {
      throw FormatException('Geçersiz ondalık tutar: $amount');
    }

    final sign = match.group(1)!;
    final whole = match
        .group(2)!
        .replaceFirst(RegExp(r'^0+(?=\d)'), '')
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );
    final fraction = match.group(3);
    final localized = fraction == null
        ? '$sign$whole'
        : '$sign$whole,$fraction';
    final currencyLabel = currency == 'TRY' ? '₺' : currency;
    return '$localized $currencyLabel';
  }
}
