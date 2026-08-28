import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/realtime_client.dart';

void main() {
  group('RealtimeClient.disconnect', () {
    test('dinleyicisi olan kanallar kapatılırken patlamıyor', () async {
      final client = RealtimeClient.forTesting();
      final first = client.conversationEvents('a').listen((_) {});
      final second = client.conversationEvents('b').listen((_) {});
      final personal = client.userMessageEvents().listen((_) {});

      // `close()` dinleyicileri iptal ediyor, iptal `onCancel` üzerinden
      // aynı map'ten siliyor. Map üzerinde doğrudan gezinen eski hâli burada
      // `ConcurrentModificationError` fırlatıyordu ve kullanıcı çıkış
      // yapamıyordu.
      await expectLater(client.disconnect(), completes);

      await first.cancel();
      await second.cancel();
      await personal.cancel();
    });

    test('kapanan akışlar tüketiciye biter', () async {
      final client = RealtimeClient.forTesting();
      final done = client.conversationEvents('a').isEmpty;

      await client.disconnect();

      expect(await done, isTrue);
    });

    test('kapanıştan sonra yeni abonelik açılabiliyor', () async {
      final client = RealtimeClient.forTesting();
      client.conversationEvents('a').listen((_) {});

      await client.disconnect();

      // Map'ler boşaldığı için eski, kapanmış controller geri verilmemeli.
      final stream = client.conversationEvents('a');
      final subscription = stream.listen((_) {});
      addTearDown(subscription.cancel);

      expect(client.isConnected, isFalse);
    });

    test('boşken çağrılmak zararsız', () async {
      final client = RealtimeClient.forTesting();

      await expectLater(client.disconnect(), completes);
      await expectLater(client.disconnect(), completes);
    });
  });
}
