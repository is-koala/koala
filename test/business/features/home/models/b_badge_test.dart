import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/b_badge.dart';

void main() {
  group('BBadge', () {
    test('BadgeDto alanlarını okur', () {
      final badge = BBadge.fromJson(const {
        'code': 'GEZGIN_GOLD',
        'family': 'GEZGIN',
        'tier': 'GOLD',
        'name': 'Gezgin',
        'description': 'Farklı ilçelerde iş tamamladı.',
        'iconUrl': 'https://cdn.example/gezgin.png',
        'earnedAt': '2026-09-01T10:00:00Z',
      });

      expect(badge.code, 'GEZGIN_GOLD');
      expect(badge.family, 'GEZGIN');
      expect(badge.tierLabel, 'Altın');
      expect(badge.name, 'Gezgin');
      expect(badge.iconUrl, 'https://cdn.example/gezgin.png');
      expect(badge.earnedAt, DateTime.utc(2026, 9, 1, 10));
    });

    test('kademesiz rozette kademe etiketi yok', () {
      final badge = BBadge.fromJson(const {
        'code': 'IDENTITY',
        'tier': 'NONE',
        'name': 'Kimliği Doğrulandı',
      });

      expect(badge.tierLabel, isNull);
    });

    test('tanınmayan kademe etiketsiz kalır, çökmez', () {
      final badge = BBadge.fromJson(const {
        'code': 'X',
        'tier': 'PLATINUM',
        'name': 'Yeni',
      });

      expect(badge.tierLabel, isNull);
    });

    test('listFromJson liste olmayan veriyi boş sayar', () {
      expect(BBadge.listFromJson(null), isEmpty);
      expect(BBadge.listFromJson('x'), isEmpty);
      expect(
        BBadge.listFromJson(const [
          {'code': 'A', 'name': 'A'},
          'bozuk',
          {'code': 'B', 'name': 'B'},
        ]).map((badge) => badge.code),
        ['A', 'B'],
      );
    });
  });
}
