import 'package:koala/product/extensions/date_extensions.dart';

/// Haftalık şablonu tek bir tarih için geçersiz kılan müsaitlik kaydı.
class AvailabilityException {
  const AvailabilityException({
    required this.id,
    required this.date,
    required this.available,
    this.note,
  });

  final String id;
  final DateTime date;
  final bool available;
  final String? note;

  factory AvailabilityException.fromJson(Map<String, dynamic> json) {
    return AvailabilityException(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      available: json['available'] as bool,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toRequestJson() => {
    'date': date.asLocalDate,
    'available': available,
    'note': note,
  };
}
