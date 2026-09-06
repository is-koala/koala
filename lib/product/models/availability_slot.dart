import 'package:koala/product/models/availability_day.dart';

/// Haftalık müsaitlik şablonundaki tek saat aralığı.
///
/// Saatler modelde `HH:mm` dizesidir; `TimeOfDay` yalnız arayüzde kullanılır.
class AvailabilitySlot {
  const AvailabilitySlot({
    this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  final String? id;
  final AvailabilityDay day;
  final String startTime;
  final String endTime;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      id: json['id'] as String?,
      day: AvailabilityDay.fromCode(json['dayOfWeek']),
      startTime: _readTime(json['startTime']),
      endTime: _readTime(json['endTime']),
    );
  }

  /// PUT gövdesi kimlik taşımaz; sunucu bütün şablonu silip yeniden yazar.
  Map<String, dynamic> toRequestJson() => {
    'dayOfWeek': day.code,
    'startTime': startTime,
    'endTime': endTime,
  };

  AvailabilitySlot copyWith({
    String? id,
    AvailabilityDay? day,
    String? startTime,
    String? endTime,
  }) {
    return AvailabilitySlot(
      id: id ?? this.id,
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  String get dayLabel => day.label;

  String get timeLabel => '$startTime–$endTime';

  int get startMinutes => _minutes(startTime);

  int get endMinutes => _minutes(endTime);

  static String _readTime(Object? value) {
    final raw = value as String;
    if (!RegExp(r'^\d{2}:\d{2}').hasMatch(raw)) {
      throw const FormatException('Saat HH:mm biçiminde değil.');
    }
    final normalized = raw.substring(0, 5);
    _minutes(normalized);
    return normalized;
  }

  static int _minutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      throw const FormatException('Saat HH:mm biçiminde değil.');
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      throw const FormatException('Saat geçerli değil.');
    }
    return hour * Duration.minutesPerHour + minute;
  }
}
