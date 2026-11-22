extension PriceExtension on num {
  /// `1500` → `1.500`; ilan ücretleri tam sayı.
  String get asPrice => _withThousandsSeparator(toStringAsFixed(0));

  /// Yuvarlamadan Türkçe biçim: `1250.5` → `1.250,5` (iş alarmı ondalık kabul
  /// ediyor).
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
