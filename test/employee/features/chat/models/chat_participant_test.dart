import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';

/// is-koala/koala-backend#281 sonrası `ConversationParticipantDto`.
Map<String, dynamic> buildJson() => {
  'id': 'worker-1',
  'firstName': 'Yakup',
  'lastName': 'Kahraman',
  'profilePictureUrl': 'https://example.com/yakup.png',
  'role': 'WORKER',
  'joinedAt': '2026-09-10T08:00:00Z',
  'lastReadAt': '2026-09-14T09:30:00Z',
  'left': false,
};

void main() {
  group('ChatParticipant.fromJson', () {
    test('yeni sunucunun bütün alanları okunur', () {
      final participant = ChatParticipant.fromJson(buildJson());

      expect(participant.id, 'worker-1');
      expect(participant.fullName, 'Yakup Kahraman');
      expect(participant.initials, 'YK');
      expect(participant.profilePictureUrl, 'https://example.com/yakup.png');
      expect(participant.role, ChatParticipantRole.worker);
      expect(participant.joinedAt, DateTime.utc(2026, 9, 10, 8));
      expect(participant.lastReadAt, DateTime.utc(2026, 9, 14, 9, 30));
      expect(participant.left, isFalse);
    });

    // Eski sunucu yalnız kimlik ve adı gönderiyor; eksik alan çökertmemeli
    // ve yanlış bir rol yazılmamalı.
    test('eski sunucunun kısa gövdesi boş alanlarla kurulur', () {
      final participant = ChatParticipant.fromJson({
        'id': 'employer-1',
        'firstName': 'Kahve',
        'lastName': 'Durağı',
      });

      expect(participant.role, ChatParticipantRole.unknown);
      expect(participant.role.label, isEmpty);
      expect(participant.joinedAt, isNull);
      expect(participant.lastReadAt, isNull);
      expect(participant.left, isFalse);
    });

    test('ayrılan katılımcı left ile gelir', () {
      final participant = ChatParticipant.fromJson(
        buildJson()..['left'] = true,
      );

      expect(participant.left, isTrue);
    });

    test('adı boş gelen katılımcı anonim yazılır', () {
      final participant = ChatParticipant.fromJson({
        'id': 'gone',
        'firstName': '',
        'lastName': null,
      });

      expect(participant.fullName, ChatParticipant.anonymousName);
    });
  });

  group('ChatParticipantRole', () {
    test('üç rolün etiketi Türkçe', () {
      expect(ChatParticipantRole.fromCode('EMPLOYER').label, 'İşveren');
      expect(
        ChatParticipantRole.fromCode('COMPANY_CONTACT').label,
        'Şirket yetkilisi',
      );
      expect(ChatParticipantRole.fromCode('WORKER').label, 'Çalışan');
    });

    test('tanınmayan ve boş değer unknown olur', () {
      expect(
        ChatParticipantRole.fromCode('ADMIN'),
        ChatParticipantRole.unknown,
      );
      expect(ChatParticipantRole.fromCode(null), ChatParticipantRole.unknown);
      // `unknown`'ın kodu boş; boş dize onunla eşleşip "tanındı" sayılmamalı.
      expect(ChatParticipantRole.fromCode(''), ChatParticipantRole.unknown);
    });
  });

  group('ChatParticipant.hasReadSince', () {
    final sentAt = DateTime.utc(2026, 9, 14, 10);

    test('damga gönderim anından sonraysa görmüş sayılır', () {
      final participant = ChatParticipant.fromJson(
        buildJson()..['lastReadAt'] = '2026-09-14T10:00:01Z',
      );

      expect(participant.hasReadSince(sentAt), isTrue);
    });

    test('damga gönderim anına eşitse görmüş sayılır', () {
      final participant = ChatParticipant.fromJson(
        buildJson()..['lastReadAt'] = '2026-09-14T10:00:00Z',
      );

      expect(participant.hasReadSince(sentAt), isTrue);
    });

    test('damga eskiyse ya da yoksa görmemiş', () {
      expect(
        ChatParticipant.fromJson(
          buildJson()..['lastReadAt'] = '2026-09-14T09:59:59Z',
        ).hasReadSince(sentAt),
        isFalse,
      );
      expect(
        ChatParticipant.fromJson(
          buildJson()..remove('lastReadAt'),
        ).hasReadSince(sentAt),
        isFalse,
      );
    });
  });

  test('copyWith yalnız okundu damgasını değiştirir', () {
    final participant = ChatParticipant.fromJson(buildJson()..['left'] = true);
    final updated = participant.copyWith(
      lastReadAt: DateTime.utc(2026, 9, 14, 12),
    );

    expect(updated.lastReadAt, DateTime.utc(2026, 9, 14, 12));
    expect(updated.id, participant.id);
    expect(updated.role, participant.role);
    expect(updated.left, isTrue);
  });
}
