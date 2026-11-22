/// Tarih biçimleri; yalnız ay adları için `intl` eklemeye değmiyor.
extension DateExtensions on DateTime {
  /// İlk eleman boş: `DateTime.month` 1'den başlıyor.
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

  /// `Ocak 2023`.
  String get asMonthYear => '${_monthNames[month]} $year';

  String get asShortDate {
    final d = day.toString().padLeft(2, '0');
    final m = month.toString().padLeft(2, '0');
    return '$d.$m.$year';
  }

  String get asShortTime {
    final h = hour.toString().padLeft(2, '0');
    final min = minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  /// `15.02.2026 09:00`.
  String get asShortDateTime => '$asShortDate $asShortTime';

  /// Sunucunun `LocalDate` alanları için `yyyy-MM-dd`; `toIso8601String`'in
  /// saat kısmını backend reddediyor.
  String get asLocalDate {
    final month = this.month.toString().padLeft(2, '0');
    final day = this.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Göreli zaman ("5 dk önce"); bir haftadan eskisinde tarihe düşer.
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

  static const int _relativeDayLimit = 7;
}

/// Bitiş yoksa "Halen".
String formatDateRange(DateTime? start, DateTime? end) {
  final startLabel = start?.asMonthYear;
  final endLabel = end?.asMonthYear ?? 'Halen';

  if (startLabel == null) return end == null ? '' : endLabel;
  return '$startLabel - $endLabel';
}

extension DurationExtensions on Duration {
  /// Mesai süresi: "2s 15dk", saatin altında "45dk". Sunucu dakika
  /// hassasiyetinde tutuyor.
  String get asWorkDuration {
    final hours = inHours;
    final minutes = inMinutes.remainder(Duration.minutesPerHour);

    return hours > 0 ? '${hours}s ${minutes}dk' : '${minutes}dk';
  }
}
