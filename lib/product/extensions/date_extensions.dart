/// Tarih biçimlendirme yardımcıları.
///
/// `intl` paketi projede yok ve yalnızca ay adları için bağımlılık eklemeye
/// değmiyor; ihtiyaç duyulan iki biçim burada elle kuruluyor.
extension DateExtensions on DateTime {
  /// Türkçe ay adları. Dizinin ilk elemanı boş: `DateTime.month` 1'den
  /// başlıyor, böylece indis kaydırmaya gerek kalmıyor.
  static const List<String> _monthNames = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  /// `Ocak 2023`. Deneyim ve eğitim satırlarında kullanılıyor.
  String get asMonthYear => '${_monthNames[month]} $year';

  /// `15.02.2026`.
  String get asShortDate {
    final d = day.toString().padLeft(2, '0');
    final m = month.toString().padLeft(2, '0');
    return '$d.$m.$year';
  }
}

/// Bir tarih aralığını okunur hâle getirir.
///
/// Bitiş yoksa "Halen" yazılıyor — devam eden deneyim/eğitim için.
String formatDateRange(DateTime? start, DateTime? end) {
  final startLabel = start?.asMonthYear;
  final endLabel = end?.asMonthYear ?? 'Halen';

  if (startLabel == null) return end == null ? '' : endLabel;
  return '$startLabel - $endLabel';
}
