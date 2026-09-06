/// JSON sınırından geçen değerler için katı okuyucular.
///
/// Sayıları bilerek dizeye dönüştürmez. Finansal DTO'lar JSON dizeleri
/// kullandığı için backend'in ondalık gösterimi değişmeden korunur.
abstract final class JsonField {
  static String requiredString(Object? value, String field) {
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('$field alanı eksik veya string değil.');
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
}
