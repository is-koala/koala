import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/user_block_service.dart';
import 'package:koala/product/widgets/blocked_users_view.dart';
import 'package:koala/product/widgets/empty_state.dart';

import '../../support/fake_api.dart';
import '../../support/pump.dart';

const Map<String, dynamic> _oneBlock = {
  'success': true,
  'data': [
    {
      'id': 'blk_1',
      'blocked': {'id': 'u9', 'firstName': 'Ayşe', 'lastName': 'Yılmaz'},
      'createdAt': '2026-02-15T09:00:00',
    },
  ],
};

const Map<String, dynamic> _noBlocks = {'success': true, 'data': <Object?>[]};

/// Listeyi sahte sunucuyla çizer ve ilk isteğin bitmesini bekler.
Future<FakeApi> pumpBlocks(
  WidgetTester tester, {
  Map<String, dynamic> body = _noBlocks,
  Brightness brightness = Brightness.light,
}) async {
  final api = FakeApi(
    handler: (_) => FakeApiResponse(statusCode: 200, body: body),
  );

  await pumpInApp(
    tester,
    BlockedUsersView(service: UserBlockService.withClient(api.client)),
    brightness: brightness,
  );
  await tester.pumpAndSettle();

  return api;
}

void main() {
  group('BlockedUsersView', () {
    testWidgets('boş listede boş durum çiziliyor', (tester) async {
      await pumpBlocks(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Engellediğin kimse yok'), findsOneWidget);
    });

    testWidgets('liste sunucudan gelen kaydı gösteriyor', (tester) async {
      await pumpBlocks(tester, body: _oneBlock);

      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Engeli Kaldır'), findsOneWidget);
    });

    testWidgets('liste tek istekte çekiliyor; sayfalama yok', (tester) async {
      final api = await pumpBlocks(tester, body: _oneBlock);

      expect(api.requests.single.path, '/users/me/blocks');
      expect(api.requests.single.queryParameters, isEmpty);
    });

    testWidgets('onay kutusu iptal edilince engel kalkmıyor', (tester) async {
      final api = await pumpBlocks(tester, body: _oneBlock);

      await tester.tap(find.text('Engeli Kaldır'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      // Yalnızca ilk listeleme isteği atılmış olmalı.
      expect(api.requests, hasLength(1));
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    });

    testWidgets('onaylanınca engel kalkıyor ve satır düşüyor', (tester) async {
      final api = await pumpBlocks(tester, body: _oneBlock);

      await tester.tap(find.text('Engeli Kaldır'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaldır'));
      await tester.pumpAndSettle();

      expect(api.requests.last.path, '/users/me/blocks/u9');
      expect(api.requests.last.method, 'DELETE');
      expect(find.text('Ayşe Yılmaz'), findsNothing);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('liste açılamazsa hata ayrı çiziliyor', (tester) async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Sunucu hatası'},
        ),
      );

      await pumpInApp(
        tester,
        BlockedUsersView(service: UserBlockService.withClient(api.client)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Engellediklerin açılamadı'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
    });

    testWidgets('her iki temada da hatasız çizilir', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpBlocks(tester, body: _oneBlock, brightness: brightness);

        expect(tester.takeException(), isNull, reason: '$brightness patladı');
        expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      }
    });
  });
}
