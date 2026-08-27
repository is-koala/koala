import 'package:flutter_test/flutter_test.dart';
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
