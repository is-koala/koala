/// JSON değerleri için katı okuyucular. Sayıları dizeye çevirmez; finansal
/// DTO'lar ondalığı dize olarak taşıyor.
abstract final class JsonField {
  static final RegExp _decimalPattern = RegExp(r'^[+-]?\d+(?:\.\d+)?$');

  static String requiredString(Object? value, String field) {
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('$field alanı eksik veya string değil.');
  }

  static String requiredDecimalString(Object? value, String field) {
    if (value is String && _decimalPattern.hasMatch(value)) return value;
    throw FormatException('$field alanı geçerli bir ondalık dize değil.');
  }

  static DateTime? dateOrNull(Object? value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime requiredDate(Object? value, String field) {
    final parsed = dateOrNull(value);
    if (parsed != null) return parsed;
    throw FormatException('$field alanı eksik veya geçersiz.');
  }

  /// Finansal dize sözleşmesi; geçiş döneminde eski backend'in sayılarını da
  /// kabul eder.
  static String rollingDecimalString(
    Object? value,
    String field, {
    String fallback = '0',
  }) {
    if (value == null) return fallback;
    if (value is String && _decimalPattern.hasMatch(value)) return value;
    if (value is num && value.isFinite) {
      final legacy = value.toString();
      if (_decimalPattern.hasMatch(legacy)) return legacy;
    }
    throw FormatException('$field alanı geçerli bir ondalık dize değil.');
  }
}
