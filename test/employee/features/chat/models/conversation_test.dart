import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';

/// Sunucudan gelen `ConversationDto`'nun tipik hâli.
Map<String, dynamic> buildJson() => {
  'id': 'conv-1',
  'jobId': 'job-1',
  'jobTitle': 'Hafta Sonu Garson',
  'employer': {
    'id': 'employer-1',
    'firstName': 'Kahve',
    'lastName': 'Durağı',
    'profilePictureUrl': 'https://example.com/employer.png',
  },
  'worker': {
    'id': 'worker-1',
    'firstName': 'Yakup',
    'lastName': 'Kahraman',
    'profilePictureUrl': null,
  },
  'lastMessageAt': '2026-08-27T10:00:00.000Z',
};

void main() {
  group('Conversation.fromJson', () {
    test('çalışan bakınca karşı taraf işveren olur', () {
      final conversation = Conversation.fromJson(
        buildJson(),
        currentUserId: 'worker-1',
      );

      expect(conversation.counterpartId, 'employer-1');
      expect(conversation.name, 'Kahve Durağı');
      expect(conversation.avatar, 'KD');
      expect(conversation.avatarUrl, 'https://example.com/employer.png');
    });

    test('işveren bakınca karşı taraf çalışan olur', () {
      final conversation = Conversation.fromJson(
        buildJson(),
        currentUserId: 'employer-1',
      );

      expect(conversation.counterpartId, 'worker-1');
      expect(conversation.name, 'Yakup Kahraman');
      expect(conversation.avatarUrl, isNull);
    });

    test('ilan bilgisi ve son mesaj zamanı okunur', () {
      final conversation = Conversation.fromJson(
        buildJson(),
        currentUserId: 'worker-1',
      );

      expect(conversation.jobId, 'job-1');
      expect(conversation.jobTitle, 'Hafta Sonu Garson');
      expect(conversation.lastMessageAt, DateTime.utc(2026, 8, 27, 10));
    });

    test('sunucunun taşımadığı alanlar boş başlar', () {
      final conversation = Conversation.fromJson(
        buildJson(),
        currentUserId: 'worker-1',
      );

      // ConversationDto son mesajın metnini, okunmamış sayısını ve
      // çevrimiçilik bilgisini döndürmüyor.
      expect(conversation.lastMessage, isNull);
      expect(conversation.unreadCount, 0);
      expect(conversation.isOnline, isFalse);
    });

    test('son mesaj zamanı yoksa zaman etiketi boş kalır', () {
      final json = buildJson()..remove('lastMessageAt');

      final conversation = Conversation.fromJson(
        json,
        currentUserId: 'worker-1',
      );

      expect(conversation.lastMessageAt, isNull);
      expect(conversation.timeString, '');
    });

    // `kind`, `participants` ve `closed` backend PR 261 ile geldi; eski
    // sunucunun göndermediği alanlar ikili ve açık sohbet demek.
    test('kind gelmeyen sohbet ikili ve açık sayılır', () {
      final conversation = Conversation.fromJson(
        buildJson(),
        currentUserId: 'worker-1',
      );

      expect(conversation.kind, ConversationKind.direct);
      expect(conversation.isGroup, isFalse);
      expect(conversation.participantCount, 0);
      expect(conversation.closed, isFalse);
    });

    test('closed bayrağı okunur', () {
      final conversation = Conversation.fromJson(
        buildJson()..['closed'] = true,
        currentUserId: 'worker-1',
      );

      expect(conversation.closed, isTrue);
    });
  });

  group('Conversation.fromJson (grup)', () {
    Map<String, dynamic> groupJson() => {
      'id': 'conv-crew',
      'jobId': 'job-1',
      'jobTitle': 'Hafta Sonu Garson',
      'kind': 'GROUP',
      'employer': {
        'id': 'employer-1',
        'firstName': 'Kahve',
        'lastName': 'Durağı',
        'profilePictureUrl': 'https://example.com/employer.png',
      },
      'worker': null,
      'participants': [
        {'id': 'employer-1', 'firstName': 'Kahve', 'lastName': 'Durağı'},
        {'id': 'officer-1', 'firstName': 'Yetkili', 'lastName': 'Kişi'},
        {'id': 'worker-1', 'firstName': 'Yakup', 'lastName': 'Kahraman'},
      ],
      'lastMessageBody': 'Yarın 9\'da buluşalım.',
      'unreadCount': 2,
      'closed': false,
    };

    test('satır ilan başlığı ve katılımcı sayısıyla kurulur', () {
      final conversation = Conversation.fromJson(
        groupJson(),
        currentUserId: 'worker-1',
      );

      expect(conversation.isGroup, isTrue);
      expect(conversation.name, 'Hafta Sonu Garson');
      expect(conversation.participantCount, 3);
      expect(conversation.participantLabel, '3 katılımcı');
      expect(conversation.avatar, 'HG');
      expect(conversation.lastMessage, 'Yarın 9\'da buluşalım.');
      expect(conversation.unreadCount, 2);
    });

    // İşveren kendi grubuna bakınca `worker` boş; eski mantık karşı tarafı
    // boş bırakıp adı "" yapardı. Grupta karşı taraf kavramı hiç yok.
    test('işveren bakınca da başlık ilan, karşı taraf yok', () {
      final conversation = Conversation.fromJson(
        groupJson(),
        currentUserId: 'employer-1',
      );

      expect(conversation.name, 'Hafta Sonu Garson');
      expect(conversation.counterpartId, '');
      expect(conversation.avatarUrl, isNull);
    });

    // Presence kişiye bağlı; grupta kimseye abone olunmamalı.
    test('çalışan bakınca da karşı taraf boş', () {
      final conversation = Conversation.fromJson(
        groupJson(),
        currentUserId: 'worker-1',
      );

      expect(conversation.counterpartId, '');
      expect(conversation.avatarUrl, isNull);
    });

    test('katılımcı listesi gelmezse sayı sıfır', () {
      final conversation = Conversation.fromJson(
        groupJson()..remove('participants'),
        currentUserId: 'worker-1',
      );

      expect(conversation.participantCount, 0);
      expect(conversation.participants, isEmpty);
    });

    // Eski sunucu yalnız kimlik ve adı gönderiyor; katılımcılar yine
    // kuruluyor, rol ve tarihler boş.
    test('katılımcılar eski gövdeden de kurulur', () {
      final conversation = Conversation.fromJson(
        groupJson(),
        currentUserId: 'worker-1',
      );

      expect(conversation.participants, hasLength(3));
      expect(conversation.participants.first.id, 'employer-1');
      expect(conversation.participants.first.fullName, 'Kahve Durağı');
      expect(conversation.participants.first.role, ChatParticipantRole.unknown);
      expect(conversation.participants.first.lastReadAt, isNull);
    });

    // is-koala/koala-backend#281: rol, katılma ve okundu damgası, ayrılma.
    test('katılımcıların rolü, tarihleri ve ayrılma bilgisi okunur', () {
      final json = groupJson()
        ..['participants'] = [
          {
            'id': 'employer-1',
            'firstName': 'Kahve',
            'lastName': 'Durağı',
            'role': 'EMPLOYER',
            'joinedAt': '2026-09-01T08:00:00Z',
            'lastReadAt': '2026-09-14T09:00:00Z',
            'left': false,
          },
          {
            'id': 'officer-1',
            'firstName': 'Yetkili',
            'lastName': 'Kişi',
            'role': 'COMPANY_CONTACT',
            'joinedAt': '2026-09-02T08:00:00Z',
            'lastReadAt': null,
            'left': true,
          },
        ];
      final conversation = Conversation.fromJson(
        json,
        currentUserId: 'worker-1',
      );

      final employer = conversation.participants[0];
      final officer = conversation.participants[1];
      expect(employer.role, ChatParticipantRole.employer);
      expect(employer.joinedAt, DateTime.utc(2026, 9, 1, 8));
      expect(employer.lastReadAt, DateTime.utc(2026, 9, 14, 9));
      expect(employer.left, isFalse);
      expect(officer.role, ChatParticipantRole.companyContact);
      expect(officer.lastReadAt, isNull);
      expect(officer.left, isTrue);
      // Ayrılan da sayıya dahil: sunucu onu listede tutuyor.
      expect(conversation.participantCount, 2);
    });

    test('copyWith grup alanlarını korur', () {
      final conversation = Conversation.fromJson(
        groupJson()..['closed'] = true,
        currentUserId: 'worker-1',
      ).copyWith(unreadCount: 0);

      expect(conversation.isGroup, isTrue);
      expect(conversation.participantCount, 3);
      expect(conversation.participants, hasLength(3));
      expect(conversation.closed, isTrue);
    });
  });

  group('Conversation.initialsOf', () {
    test('iki kelimeden iki harf alır', () {
      expect(Conversation.initialsOf('Yakup Kahraman'), 'YK');
    });

    test('tek kelimeden tek harf alır', () {
      expect(Conversation.initialsOf('Koala'), 'K');
    });

    test('araya giren fazla boşluk sorun olmuyor', () {
      expect(Conversation.initialsOf('  Kahve   Durağı  '), 'KD');
    });

    test('boş isim soru işaretine düşer', () {
      expect(Conversation.initialsOf('   '), '?');
    });
  });
}
