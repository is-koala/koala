import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/message.dart';

/// Sunucudan gelen `MessageDto`'nun tipik hâli.
Map<String, dynamic> buildJson({String? readAt}) => {
  'id': 'msg-1',
  'senderId': 'worker-1',
  'body': 'Merhaba, müsaitim.',
  'sentAt': '2026-08-27T10:00:00.000Z',
  'readAt': readAt,
};

void main() {
  group('Message.fromJson', () {
    test('alanlar okunur, sohbet kimliği dışarıdan verilir', () {
      final message = Message.fromJson(
        buildJson(),
        conversationId: 'conv-1',
        currentUserId: 'worker-1',
      );

      expect(message.id, 'msg-1');
      expect(message.conversationId, 'conv-1');
      expect(message.body, 'Merhaba, müsaitim.');
      expect(message.sentAt, DateTime.utc(2026, 8, 27, 10));
    });

    test('gönderen oturumdaki kullanıcıysa isMe true olur', () {
      final message = Message.fromJson(
        buildJson(),
        conversationId: 'conv-1',
        currentUserId: 'worker-1',
      );

      expect(message.isMe, isTrue);
    });

    test('gönderen karşı tarafsa isMe false olur', () {
      final message = Message.fromJson(
        buildJson(),
        conversationId: 'conv-1',
        currentUserId: 'employer-1',
      );

      expect(message.isMe, isFalse);
    });

    test('readAt doluysa durum read olur', () {
      final message = Message.fromJson(
        buildJson(readAt: '2026-08-27T10:05:00.000Z'),
        conversationId: 'conv-1',
        currentUserId: 'employer-1',
      );

      expect(message.readAt, DateTime.utc(2026, 8, 27, 10, 5));
      expect(message.status, MessageStatus.read);
    });

    test('readAt boşsa durum sent kalır', () {
      final message = Message.fromJson(
        buildJson(),
        conversationId: 'conv-1',
        currentUserId: 'employer-1',
      );

      expect(message.readAt, isNull);
      expect(message.status, MessageStatus.sent);
    });
  });
}
