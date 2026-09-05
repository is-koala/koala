import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/presentation/widgets/blocked_notice.dart';

import '../../../../../support/pump.dart';

/// Sunucunun engelli sohbette döndürdüğü metin
/// (`messages_tr.properties:319`).
const _serverMessage = 'Bu kullanıcıyla mesajlaşamazsınız.';

void main() {
  group('BlockedNotice', () {
    testWidgets('sunucunun kendi metnini gösterir', (tester) async {
      await pumpInApp(tester, const BlockedNotice(message: _serverMessage));

      // `403` genel bir "yetkin yok" metnine çevrilmiyor.
      expect(find.text(_serverMessage), findsOneWidget);
    });

    testWidgets('her iki temada da hatasız çizilir', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpInApp(
          tester,
          const BlockedNotice(message: _serverMessage),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull, reason: '$brightness patladı');
        expect(find.text(_serverMessage), findsOneWidget);
      }
    });
  });
}
