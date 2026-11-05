import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';

import '../../../../support/boarding_fixtures.dart';

void main() {
  group('BoardingToken.parse', () {
    test('akışın şemasıyla gelen servis bağlantısını çözer', () {
      final token = BoardingToken.parse(
        'koala-staging://board?t=$shuttleTokenValue',
        appScheme: 'koala-staging',
      );

      expect(token, isNotNull);
      expect(token!.kind, BoardingTokenKind.shuttle);
      expect(token.subjectId, shuttleUuid);
      expect(token.value, shuttleTokenValue);
    });

    test('çıplak işçi token\'ını çözer, kimliği küçük harfe indirir', () {
      final token = BoardingToken.parse(
        'w1.${seatUuid.toUpperCase()}.2934001.mac_-1',
        appScheme: 'koala-staging',
      );

      expect(token!.kind, BoardingTokenKind.worker);
      expect(token.subjectId, seatUuid);
    });

    test('statik servis token\'ı kabul edilir', () {
      expect(
        BoardingToken.fromValue('s1.$shuttleUuid.static.abc')?.kind,
        BoardingTokenKind.shuttle,
      );
    });

    test('sözleşmeye uymayan her şey reddedilir', () {
      for (final raw in [
        '',
        'https://example.com',
        'merhaba dünya',
        'koala://board?t=$shuttleTokenValue',
        'koala-staging://board/shuttle?t=$shuttleTokenValue',
        'koala-staging://board?t=$shuttleTokenValue&t=$shuttleTokenValue',
        'koala-staging://board',
        'x1.$shuttleUuid.1.mac',
        's1.not-a-uuid.1.mac',
        's1.$shuttleUuid.1',
        's1.$shuttleUuid.1.mac.extra',
        's1.$shuttleUuid.1.ma c',
        's1.$shuttleUuid.${'9' * 260}.mac',
      ]) {
        expect(
          BoardingToken.parse(raw, appScheme: 'koala-staging'),
          isNull,
          reason: raw,
        );
      }
    });

    test('toString token\'ı yazdırmaz', () {
      final token = BoardingToken.fromValue(shuttleTokenValue)!;

      expect(token.toString(), isNot(contains(shuttleUuid)));
      expect(token.toString(), isNot(contains('mac')));
    });
  });

  group('BoardingQr', () {
    test('yanıtı okur, yenileme süresini sunucu saatinden hesaplar', () {
      final qr = BoardingQr.fromJson(
        boardingQrJson(
          issuedAt: '2026-09-20T03:30:00Z',
          refreshAt: '2026-09-20T03:40:00Z',
          expiresAt: '2026-09-20T03:50:00Z',
        ),
      );

      expect(qr.isStatic, isFalse);
      expect(qr.refreshDelay, const Duration(minutes: 10));
      expect(qr.uri, 'koala-staging://board?t=$shuttleTokenValue');
    });

    test('pencere sınırında basılan QR döngüye girmez', () {
      final qr = BoardingQr.fromJson(
        boardingQrJson(
          issuedAt: '2026-09-20T03:40:00Z',
          refreshAt: '2026-09-20T03:40:00Z',
        ),
      );

      expect(qr.refreshDelay, BoardingQr.minimumRefresh);
    });

    test('statik QR yenilenmez', () {
      final qr = BoardingQr.fromJson(
        boardingQrJson(isStatic: true, refreshAt: null, expiresAt: null),
      );

      expect(qr.isStatic, isTrue);
      expect(qr.refreshDelay, isNull);
    });

    test('eksik yanıt FormatException, toString token yazmaz', () {
      expect(
        () => BoardingQr.fromJson({'static': false}),
        throwsFormatException,
      );
      final qr = BoardingQr.fromJson(boardingQrJson());
      expect(qr.toString(), isNot(contains(shuttleUuid)));
    });
  });

  group('BoardingEvent ve liste satırı', () {
    test('olay bayrakları ve replayed okunur; bilinmeyen bayrak atlanır', () {
      final event = BoardingEvent.fromJson(
        boardingEventJson(
          flags: ['LATE_SYNC', 'STATIC_QR', 'NEW_FLAG'],
          replayed: true,
        ),
      );

      expect(event.kind, BoardingKind.boarded);
      expect(event.flags, {BoardingFlag.lateSync, BoardingFlag.staticQr});
      expect(event.replayed, isTrue);
      expect(event.scannedByWorker, isTrue);
    });

    test('satır adı yoksa "Adı olmayan çalışan", NO_SHOW ayırt edilir', () {
      final row = ShuttleBoardingRow.fromJson(
        boardingRowJson(
          firstName: null,
          lastName: null,
          boarded: false,
          event: boardingEventJson(kind: 'NO_SHOW', source: 'EMPLOYER_MARKED'),
        ),
      );

      expect(row.displayName, 'Adı olmayan çalışan');
      expect(row.isNoShow, isTrue);
      expect(row.stopName, 'Kadıköy İskele');

      final boarded = row.withEvent(
        BoardingEvent.fromJson(boardingEventJson()),
      );
      expect(boarded.boarded, isTrue);
      expect(boarded.isNoShow, isFalse);
    });
  });

  test('koltuk biniş durumu okunur; alan yoksa null', () {
    final seat = SeatAssignment.parse({
      'id': 'seat-1',
      'direction': 'OUTBOUND',
      'shuttleId': 'shuttle-1',
      'stopId': 'stop-1',
      'boarding': {'kind': 'BOARDED', 'occurredAt': '2026-09-20T03:41:00Z'},
    })!;
    final old = SeatAssignment.parse({
      'id': 'seat-2',
      'direction': 'RETURN',
      'shuttleId': 'shuttle-2',
      'stopId': 'stop-2',
    })!;

    expect(seat.boarding!.boarded, isTrue);
    expect(seat.boarding!.occurredAt, DateTime.utc(2026, 9, 20, 3, 41));
    expect(old.boarding, isNull);
  });

  test('clientEventId UUID v4 biçiminde ve her çağrıda farklı', () {
    final first = newBoardingClientEventId();
    final second = newBoardingClientEventId();

    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
    expect(first, isNot(second));
  });
}
