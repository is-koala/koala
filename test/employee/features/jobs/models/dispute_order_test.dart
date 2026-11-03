import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/dispute.dart';

Dispute _dispute(String id, String? createdAt) => Dispute.fromJson({
  'id': id,
  'jobAssignmentId': 'a',
  'status': 'OPEN',
  'createdAt': createdAt,
});

void main() {
  group('Dispute.newestFirst', () {
    test('en yeni önde', () {
      final ordered = Dispute.newestFirst([
        _dispute('eski', '2026-08-01T09:00:00Z'),
        _dispute('yeni', '2026-09-20T09:00:00Z'),
        _dispute('orta', '2026-09-01T09:00:00Z'),
      ]);

      expect(ordered.map((d) => d.id), ['yeni', 'orta', 'eski']);
    });

    test('tarihi olmayan en sona', () {
      final ordered = Dispute.newestFirst([
        _dispute('tarihsiz', null),
        _dispute('var', '2026-09-20T09:00:00Z'),
      ]);

      expect(ordered.map((d) => d.id), ['var', 'tarihsiz']);
    });

    // İki ekran aynı sıralamayı göstermeli: eşitlikte sunucunun sırası.
    test('eşitlikte sunucunun sırası korunur', () {
      final ordered = Dispute.newestFirst([
        _dispute('a', '2026-09-20T09:00:00Z'),
        _dispute('b', '2026-09-20T09:00:00Z'),
        _dispute('c', null),
        _dispute('d', null),
      ]);

      expect(ordered.map((d) => d.id), ['a', 'b', 'c', 'd']);
    });

    test('girdiyi değiştirmez, boş listede boş döner', () {
      final input = [
        _dispute('eski', '2026-08-01T09:00:00Z'),
        _dispute('yeni', '2026-09-20T09:00:00Z'),
      ];

      Dispute.newestFirst(input);

      expect(input.map((d) => d.id), ['eski', 'yeni']);
      expect(Dispute.newestFirst(const []), isEmpty);
    });
  });
}
