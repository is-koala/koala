/// İlan keşfinin başlangıç günü süzgeci.
///
/// Çipler İstanbul takvimine bağlı: bugün/yarın o anın Türkiye günü, bu hafta
/// Pazartesi–Pazar, hafta sonu o haftanın Cumartesi–Pazar'ı, takvimden seçilen
/// gün tek bir gündür. Backend `startFrom`/`startTo` Instant bekliyor; dilim
/// `Europe/Istanbul` ve Türkiye DST kullanmıyor (UTC+3).
class JobStartOn {
  const JobStartOn._({this.preset, this.day})
    : assert(
        (preset != null) != (day != null),
        'Ya hazır çip ya da takvim günü',
      );

  const JobStartOn.preset(JobStartOnPreset preset) : this._(preset: preset);

  /// [day] yalnızca yıl-ay-gün olarak okunur; saat yok sayılır.
  JobStartOn.calendarDay(DateTime day)
    : this._(day: DateTime.utc(day.year, day.month, day.day));

  static const today = JobStartOn._(preset: JobStartOnPreset.today);
  static const tomorrow = JobStartOn._(preset: JobStartOnPreset.tomorrow);
  static const weekend = JobStartOn._(preset: JobStartOnPreset.weekend);
  static const thisWeek = JobStartOn._(preset: JobStartOnPreset.thisWeek);

  final JobStartOnPreset? preset;
  final DateTime? day;

  /// Çipin üzerinde yazan ad.
  String get label {
    final selected = preset;
    if (selected != null) return selected.label;
    return _calendarLabel(day!);
  }

  /// `GET /jobs` Instant penceresi.
  ///
  /// [now] testte dondurulabilsin diye dışarıdan alınır; üretim `DateTime.now()`.
  JobStartWindow toWindow({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = IstanbulCalendar.dateOf(clock);
    return switch (preset) {
      JobStartOnPreset.today => IstanbulCalendar.dayBounds(today),
      JobStartOnPreset.tomorrow => IstanbulCalendar.dayBounds(
        today.add(const Duration(days: 1)),
      ),
      JobStartOnPreset.thisWeek => IstanbulCalendar.rangeBounds(
        IstanbulCalendar.mondayOf(today),
        IstanbulCalendar.mondayOf(today).add(const Duration(days: 6)),
      ),
      JobStartOnPreset.weekend => IstanbulCalendar.rangeBounds(
        IstanbulCalendar.mondayOf(today).add(const Duration(days: 5)),
        IstanbulCalendar.mondayOf(today).add(const Duration(days: 6)),
      ),
      null => IstanbulCalendar.dayBounds(day!),
    };
  }

  static String _calendarLabel(DateTime day) {
    final d = day.day.toString().padLeft(2, '0');
    final m = day.month.toString().padLeft(2, '0');
    return '$d.$m.${day.year}';
  }

  @override
  bool operator ==(Object other) =>
      other is JobStartOn && other.preset == preset && other.day == day;

  @override
  int get hashCode => Object.hash(preset, day);
}

/// Kullanıcının seçtiği hazır başlangıç günü.
enum JobStartOnPreset {
  today('Bugün'),
  tomorrow('Yarın'),
  weekend('Hafta sonu'),
  thisWeek('Bu hafta');

  const JobStartOnPreset(this.label);

  /// Çipin üzerinde yazan ad.
  final String label;
}

/// `startFrom`/`startTo` Instant çifti.
class JobStartWindow {
  const JobStartWindow({required this.startFrom, required this.startTo});

  final DateTime startFrom;
  final DateTime startTo;
}

/// Türkiye takvimi: UTC+3, DST yok.
abstract final class IstanbulCalendar {
  static const Duration offset = Duration(hours: 3);

  /// UTC Instant'ın İstanbul duvar saati (DST yok).
  static DateTime wallClockOf(DateTime instant) {
    final shifted = instant.toUtc().add(offset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  /// [now] anının İstanbul takvim günü (saat sıfır, UTC etiketli).
  static DateTime dateOf(DateTime now) {
    final wall = now.toUtc().add(offset);
    return DateTime.utc(wall.year, wall.month, wall.day);
  }

  /// Pazartesi = 1. [day] tarih-only UTC kabul edilir.
  static DateTime mondayOf(DateTime day) {
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static JobStartWindow dayBounds(DateTime day) => rangeBounds(day, day);

  static JobStartWindow rangeBounds(DateTime from, DateTime to) {
    return JobStartWindow(
      startFrom: DateTime.parse('${_isoDate(from)}T00:00:00+03:00'),
      startTo: DateTime.parse('${_isoDate(to)}T23:59:59.999+03:00'),
    );
  }

  static String _isoDate(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$d';
  }
}
