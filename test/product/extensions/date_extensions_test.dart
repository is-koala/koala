import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/extensions/date_extensions.dart';

void main() {
  group('asMonthYear', () {
    test('Türkçe ay adıyla yazılır', () {
      expect(DateTime(2023, 1, 15).asMonthYear, 'Ocak 2023');
      expect(DateTime(2020, 12, 1).asMonthYear, 'Aralık 2020');
    });

    test('yılın her ayı bir ada karşılık gelir', () {
      for (var month = 1; month <= 12; month++) {
        expect(DateTime(2024, month).asMonthYear, isNot(startsWith(' ')));
      }
    });
  });

  group('asShortDate', () {
    test('gün ve ay iki haneye tamamlanır', () {
      expect(DateTime(2026, 2, 5).asShortDate, '05.02.2026');
      expect(DateTime(2026, 11, 15).asShortDate, '15.11.2026');
    });
  });

  group('formatDateRange', () {
    test('iki tarih arasına tire konur', () {
      expect(
        formatDateRange(DateTime(2021, 3), DateTime(2022, 12)),
        'Mart 2021 - Aralık 2022',
      );
    });

    test('bitiş yoksa Halen yazılır', () {
      expect(formatDateRange(DateTime(2023, 1), null), 'Ocak 2023 - Halen');
    });

    test('başlangıç yoksa yalnızca bitiş döner', () {
      expect(formatDateRange(null, DateTime(2023, 1)), 'Ocak 2023');
    });

    test('ikisi de yoksa boş metin', () {
      expect(formatDateRange(null, null), '');
    });
  });
}
