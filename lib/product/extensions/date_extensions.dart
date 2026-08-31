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

  /// `09:00`.
  String get asShortTime {
    final h = hour.toString().padLeft(2, '0');
    final min = minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  /// `15.02.2026 09:00`. İlanın başlangıç/bitiş anı gün ve saatin ikisini de
  /// taşıdığı için tek başına tarih yetmiyor.
  String get asShortDateTime => '$asShortDate $asShortTime';

  /// Bildirim listesindeki göreli zaman: "az önce", "5 dk önce",
  /// "2 saat önce", "3 gün önce".
  ///
  /// Bir haftadan eskisinde tarihe düşüyor — "37 gün önce" kimsenin
  /// kafasında bir tarihe karşılık gelmiyor.
  String get asRelative {
    final difference = DateTime.now().difference(this);

    if (difference.isNegative) return 'az önce';
    if (difference.inMinutes < 1) return 'az önce';
    if (difference.inHours < 1) return '${difference.inMinutes} dk önce';
    if (difference.inDays < 1) return '${difference.inHours} saat önce';
    if (difference.inDays < _relativeDayLimit) {
      return '${difference.inDays} gün önce';
    }

    return asShortDate;
  }

  /// Göreli zamanın tarihe döndüğü sınır, gün olarak.
  static const int _relativeDayLimit = 7;
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

/// Süre biçimleri.
extension DurationExtensions on Duration {
  /// Mesai süresi: "2s 15dk", bir saatin altında yalnızca "45dk".
  ///
  /// Saniye gösterilmiyor; mesai dakika hassasiyetinde tutuluyor, sunucu da
  /// oturumun süresini dakika olarak yazıyor.
  String get asWorkDuration {
    final hours = inHours;
    final minutes = inMinutes.remainder(Duration.minutesPerHour);

    return hours > 0 ? '${hours}s ${minutes}dk' : '${minutes}dk';
  }
}
