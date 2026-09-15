import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/seat_picker_sheet.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';

import '../../../../../support/pump.dart';
import '../../../../../support/transport_fixtures.dart';

List<Shuttle> _shuttles() => [
  Shuttle.fromJson(
    shuttleJson(
      stops: [
        stopJson(),
        stopJson(id: 'stop-1b', label: 'Bostancı'),
      ],
    ),
  ),
  Shuttle.fromJson(
    shuttleJson(
      id: 'shuttle-full',
      name: 'Dolu servis',
      capacity: 4,
      seatsTaken: 4,
      stops: [stopJson(id: 'stop-full', label: 'Pendik')],
    ),
  ),
];

Future<List<SeatChoice?>> _open(
  WidgetTester tester, {
  SeatAssignment? selected,
  Brightness brightness = Brightness.light,
}) async {
  final results = <SeatChoice?>[];
  await pumpInApp(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          results.add(
            await SeatPickerSheet.show(
              context,
              direction: ShuttleDirection.outbound,
              shuttles: _shuttles(),
              selected: selected,
            ),
          );
        },
        child: const Text('aç'),
      ),
    ),
    brightness: brightness,
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    group('SeatPickerSheet ($themeName tema)', () {
      testWidgets('durağa dokunmak servis+durak çiftini döndürür', (
        tester,
      ) async {
        final results = await _open(tester, brightness: brightness);

        expect(find.text('Gidiş için koltuk seçin'), findsOneWidget);
        expect(find.text('3/12 dolu'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('seat-picker-stop-stop-1b')),
        );
        await tester.pumpAndSettle();

        expect(results, [(shuttleId: 'shuttle-1', stopId: 'stop-1b')]);
      });

      testWidgets('dolu servisin durakları dokunulamaz', (tester) async {
        final results = await _open(tester, brightness: brightness);

        expect(find.text('Dolu · 4/4 dolu'), findsOneWidget);
        final row = tester.widget<InkWell>(
          find.byKey(const ValueKey('seat-picker-stop-stop-full')),
        );
        expect(row.onTap, isNull);

        await tester.tap(
          find.byKey(const ValueKey('seat-picker-stop-stop-full')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        // Sheet hâlâ açık, sonuç yok.
        expect(results, isEmpty);
        expect(find.text('Gidiş için koltuk seçin'), findsOneWidget);
      });

      testWidgets('seçili durak işaretli, dolu serviste bile dokunulabilir', (
        tester,
      ) async {
        final results = await _open(
          tester,
          selected: const SeatAssignment(
            id: 'seat-1',
            direction: ShuttleDirection.outbound,
            shuttleId: 'shuttle-full',
            stopId: 'stop-full',
          ),
          brightness: brightness,
        );

        final row = tester.widget<InkWell>(
          find.byKey(const ValueKey('seat-picker-stop-stop-full')),
        );
        expect(row.onTap, isNotNull);
        await tester.tap(
          find.byKey(const ValueKey('seat-picker-stop-stop-full')),
        );
        await tester.pumpAndSettle();
        expect(results, [(shuttleId: 'shuttle-full', stopId: 'stop-full')]);
      });
    });
  }
}
