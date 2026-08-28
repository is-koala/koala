import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/product/network/realtime_event.dart';

void main() {
  group('RealtimeEvent', () {
    test('mesaj olayı ham gövdeyi taşır', () {
      final event = RealtimeEvent.fromJson({
        'type': 'MESSAGE',
        'conversationId': 'conv_1',
        'userId': 'user_1',
        'message': {'id': 'msg_1', 'body': 'Merhaba'},
        'at': '2026-03-05T10:00:00Z',
      });

      expect(event.type, RealtimeEventType.message);
      expect(event.conversationId, 'conv_1');
      expect(event.message?['body'], 'Merhaba');
      expect(event.at, isNotNull);
    });

    test('presence olayında sohbet kimliği yok', () {
      final event = RealtimeEvent.fromJson({
        'type': 'PRESENCE',
        'userId': 'user_1',
        'online': true,
      });

      expect(event.type, RealtimeEventType.presence);
      expect(event.conversationId, isNull);
      expect(event.online, isTrue);
    });

    // Backend yeni bir olay türü eklerse istemci çökmemeli.
    test('tanınmayan tür unknown olur', () {
      final event = RealtimeEvent.fromJson({'type': 'UZAYLI'});

      expect(event.type, RealtimeEventType.unknown);
    });
  });

  group('ApiConfig.websocketUrl', () {
    // Adres `--dart-define` ile değiştiği için şema dönüşümü koddan
    // doğrulanıyor; varsayılan yayın adresi https.
    test('şema ws/wss olarak çevrilir ve yol /ws olur', () {
      final url = ApiConfig.websocketUrl;

      expect(url, anyOf(startsWith('wss://'), startsWith('ws://')));
      expect(url, endsWith(ApiConfig.websocketPath));
      expect(
        Uri.parse(ApiConfig.baseUrl).host,
        Uri.parse(url).host,
        reason: 'sunucu adresi değişmemeli',
      );
    });
  });
}
