import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/user_block_service.dart';
import 'package:koala/product/widgets/block_user_action.dart';

import '../../support/fake_api.dart';
import '../../support/pump.dart';

const _successResult = FakeApiResponse(
  statusCode: 200,
  body: {'success': true, 'data': null},
);

/// Akışı başlatan düğme. Etiketi onay kutusunun düğmesiyle karışmasın diye
/// "Engelle" değil.
Future<void> pumpTrigger(WidgetTester tester, FakeApi api) async {
  await pumpInApp(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => BlockUserAction.confirmAndBlock(
          context,
          userId: 'u9',
          name: 'Ayşe Yılmaz',
          service: UserBlockService.withClient(api.client),
        ),
        child: const Text('Tetikle'),
      ),
    ),
  );

  await tester.tap(find.text('Tetikle'));
  await tester.pumpAndSettle();
}

void main() {
  group('BlockUserAction.confirmAndBlock', () {
    testWidgets('onay kutusu geçilmeden istek gitmez', (tester) async {
      final api = FakeApi(handler: (_) => _successResult);

      await pumpTrigger(tester, api);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(api.requests, isEmpty);
    });

    testWidgets('onay metni engelin iki yönlü olduğunu söyler', (tester) async {
      final api = FakeApi(handler: (_) => _successResult);

      await pumpTrigger(tester, api);

      // Kullanıcı yalnızca "ben ona yazamayacağım" sanmamalı: karşı taraf da
      // yazamaz hâle geliyor.
      expect(
        find.textContaining('o da sana yazamaz'),
        findsOneWidget,
        reason: 'onay metni engelin iki yönlü olduğunu söylemiyor',
      );
    });

    testWidgets('onaylanınca engelleme isteği gider', (tester) async {
      final api = FakeApi(handler: (_) => _successResult);

      await pumpTrigger(tester, api);
      await tester.tap(find.text('Engelle'));
      await tester.pumpAndSettle();

      expect(api.requests.single.path, '/users/me/blocks/u9');
      expect(api.requests.single.method, 'POST');
    });
  });
}
