/// Strict readers for values crossing the JSON boundary.
///
/// They deliberately do not coerce numbers to strings. Financial DTOs use
/// JSON strings so the backend's decimal representation survives unchanged.
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
