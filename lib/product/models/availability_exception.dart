import 'package:koala/product/extensions/date_extensions.dart';

/// Haftalık şablonu tek bir tarih için geçersiz kılan müsaitlik kaydı.
class AvailabilityException {
  const AvailabilityException({
    this.id,
    required this.date,
    required this.available,
    this.note,
  });

  /// Sunucudan okunmuş kayıtlarda doludur; PUT isteği hazırlanırken yoktur.
  final String? id;
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

  Map<String, dynamic> toRequestJson() {
    final normalizedNote = note?.trim();
    return {
      'date': date.asLocalDate,
      'available': available,
      'note': normalizedNote == null || normalizedNote.isEmpty
          ? null
          : normalizedNote,
    };
  }
}
