import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/presentation/providers/boarding_qr_controller.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../../support/boarding_fixtures.dart';

/// Zamanlayıcılar `testWidgets`'ın sahte saatinde işliyor; denetleyicinin
/// duvar saati de testin elinde.
void main() {
  late DateTime now;
  late List<Object> responses;
  late int loads;

  BoardingQrController controller() => BoardingQrController(
    clock: () => now,
    load: () async {
      loads++;
      final next = responses.isEmpty
          ? BoardingQr.fromJson(boardingQrJson())
          : responses.removeAt(0);
      if (next is ApiException) throw next;
      return next as BoardingQr;
    },
  );

  setUp(() {
    // Cihaz saati sunucudan bir saat ileride: yenileme yine 10 dk sonra.
    now = DateTime.utc(2026, 9, 20, 4, 30);
    responses = [];
    loads = 0;
  });

  testWidgets('QR sunucunun refreshAt - issuedAt süresinde yenilenir', (
    tester,
  ) async {
    final qr = controller();

    await qr.refresh();
    expect(loads, 1);
    expect(qr.qr, isNotNull);

    await tester.pump(const Duration(minutes: 9, seconds: 59));
    expect(loads, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(loads, 2);
    qr.dispose();
  });

  testWidgets('yenileme düşerse eski QR expiresAt\'e kadar gösterilir', (
    tester,
  ) async {
    final qr = controller();
    await qr.refresh();

    responses.add(offlineError);
    now = now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(minutes: 10));

    expect(qr.error, isNotNull);
    expect(qr.qr, isNotNull);
    expect(qr.isExpired, isFalse);

    // Geçici hata kendiliğinden yeniden denenir.
    responses.add(offlineError);
    now = now.add(BoardingQrController.retryDelay);
    await tester.pump(BoardingQrController.retryDelay);
    expect(loads, 3);

    // Kabul süresi (yanıttan 20 dk sonra) dolunca QR geçersiz sayılır.
    now = DateTime.utc(2026, 9, 20, 4, 50);
    expect(qr.isExpired, isTrue);
    qr.dispose();
  });

  testWidgets('kalıcı hata (koltuk yok) kendiliğinden yeniden denenmez', (
    tester,
  ) async {
    final qr = controller();
    responses.add(boardingError('TRANSPORT_SEAT_NOT_SELECTED'));

    await qr.refresh();
    await tester.pump(const Duration(minutes: 5));

    expect(loads, 1);
    expect(qr.error?.errorCode, 'TRANSPORT_SEAT_NOT_SELECTED');
    expect(qr.qr, isNull);
    qr.dispose();
  });

  testWidgets('statik QR hiç yenilenmez, süresi dolmaz', (tester) async {
    responses.add(
      BoardingQr.fromJson(
        boardingQrJson(isStatic: true, refreshAt: null, expiresAt: null),
      ),
    );
    final qr = controller();

    await qr.refresh();
    now = now.add(const Duration(days: 1));
    await tester.pump(const Duration(hours: 1));

    expect(loads, 1);
    expect(qr.isExpired, isFalse);
    qr.dispose();
  });

  testWidgets('switchTo eski QR\'ı bırakır ve yeni türü okur', (tester) async {
    final qr = controller();
    await qr.refresh();

    var staticLoads = 0;
    await qr.switchTo(() async {
      staticLoads++;
      return BoardingQr.fromJson(
        boardingQrJson(isStatic: true, refreshAt: null, expiresAt: null),
      );
    });

    expect(staticLoads, 1);
    expect(qr.qr!.isStatic, isTrue);
    await tester.pump(const Duration(minutes: 30));
    expect(staticLoads, 1);
    qr.dispose();
  });
}
