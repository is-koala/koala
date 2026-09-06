/// Sayı biçimlendirme yardımcıları.
extension PriceExtension on num {
  /// Ücreti binlik ayracıyla yazar: `1500` → `1.500`.
  ///
  /// Kuruş gösterilmiyor; ilan ücretleri tam sayı olarak giriliyor.
  String get asPrice => _withThousandsSeparator(toStringAsFixed(0));

  /// Küsuratı yuvarlamadan Türkçe sayı biçiminde yazar.
  ///
  /// İlan ücretleri tam sayı olsa da iş alarmı sözleşmesi ondalık asgari ücret
  /// kabul eder: `1250.5` → `1.250,5`.
  String get asExactPrice {
    final parts = toString().split('.');
    final whole = _withThousandsSeparator(parts.first);
    if (parts.length == 1 || RegExp(r'^0+$').hasMatch(parts.last)) return whole;
    return '$whole,${parts.last}';
  }
}

String _withThousandsSeparator(String value) => value.replaceAllMapped(
  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]}.',
);
