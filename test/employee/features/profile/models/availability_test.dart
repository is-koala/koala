import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/profile/models/availability.dart';

void main() {
  test('haftalık aralıkları ve tarih istisnalarını sunucu yanıtından okur', () {
    final availability = Availability.fromJson(const {
      'slots': [
        {
          'id': 'slot_1',
          'dayOfWeek': 'MONDAY',
          'startTime': '09:00:00',
          'endTime': '17:30:00',
        },
      ],
      'exceptions': [
        {
          'id': 'exception_1',
          'date': '2026-09-12',
          'available': false,
          'note': 'Şehir dışında',
        },
      ],
    });

    expect(availability.slots.single.dayOfWeek, 'MONDAY');
    expect(availability.slots.single.dayLabel, 'Pazartesi');
    expect(availability.slots.single.startTime, '09:00');
    expect(availability.slots.single.endTime, '17:30');
    expect(availability.exceptions.single.date, DateTime(2026, 9, 12));
    expect(availability.exceptions.single.available, isFalse);
    expect(availability.isEmpty, isFalse);
  });

  test('boş şablon hata değil boş müsaitliktir', () {
    final availability = Availability.fromJson(const {
      'slots': <Map<String, dynamic>>[],
      'exceptions': <Map<String, dynamic>>[],
    });

    expect(availability.isEmpty, isTrue);
  });
}
