import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/core/directions_links.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/work_transport_card.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';

import '../../../../../support/pump.dart';
import '../../../../../support/transport_fixtures.dart';

AssignmentTransport _transport({
  String outboundMethod = 'SHUTTLE',
  String returnMethod = 'CASH_ALLOWANCE',
  double? allowanceAmount = 150,
  String? allowanceNote,
  String? notes,
  List<Map<String, Object?>>? shuttles,
  List<Map<String, Object?>> seats = const [],
}) => AssignmentTransport.parse(
  assignmentTransportJson(
    outboundMethod: outboundMethod,
    returnMethod: returnMethod,
    allowanceAmount: allowanceAmount,
    allowanceNote: allowanceNote,
    notes: notes,
    shuttles: shuttles,
    seats: seats,
  ),
)!;

/// İki servis: seçilen (plakalı) ve seçilmeyen (sunucu plakayı vermiyor).
List<Map<String, Object?>> _twoShuttles() => [
  shuttleJson(),
  shuttleJson(
    id: 'shuttle-2',
    name: 'Avrupa yakası servisi',
    plate: null,
    driverName: null,
    driverPhone: null,
    stops: [stopJson(id: 'stop-2', label: 'Taksim')],
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required AssignmentTransport transport,
  bool canSelectSeat = true,
  bool seatDropped = false,
  ShuttleDirection? busyDirection,
  void Function(ShuttleDirection)? onSelectSeat,
  void Function(String)? onCall,
  void Function(DirectionsTarget)? onDirections,
  Brightness brightness = Brightness.light,
}) {
  return pumpInApp(
    tester,
    SingleChildScrollView(
      child: WorkTransportCard(
        transport: transport,
        canSelectSeat: canSelectSeat,
        seatDropped: seatDropped,
        busyDirection: busyDirection,
        onSelectSeat: onSelectSeat,
        onCall: onCall,
        onDirections: onDirections,
      ),
    ),
    brightness: brightness,
  );
}

const _selectOutbound = ValueKey('work-transport-select-OUTBOUND');
const _plateOutbound = ValueKey('work-transport-plate-OUTBOUND');

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    group('WorkTransportCard ($themeName tema)', () {
      testWidgets('koltuk seçilmemiş servis yönü düğme ve açıklama çizer', (
        tester,
      ) async {
        final picked = <ShuttleDirection>[];
        await _pump(
          tester,
          transport: _transport(),
          onSelectSeat: picked.add,
          brightness: brightness,
        );

        expect(find.text('Ulaşım'), findsOneWidget);
        expect(find.text('Gidiş · Servis'), findsOneWidget);
        expect(find.text('Henüz koltuk seçmediniz.'), findsOneWidget);
        expect(find.text('Koltuk seçin'), findsOneWidget);
        // Koltuk seçilmeden plaka ve şoför yok.
        expect(find.textContaining('Plaka'), findsNothing);
        expect(find.textContaining('Şoför'), findsNothing);

        await tester.tap(find.byKey(_selectOutbound));
        expect(picked, [ShuttleDirection.outbound]);
      });

      testWidgets('seçilen serviste plaka, şoför, durak adresi ve saat var', (
        tester,
      ) async {
        final calls = <String>[];
        final targets = <DirectionsTarget>[];
        await _pump(
          tester,
          transport: _transport(shuttles: _twoShuttles(), seats: [seatJson()]),
          onCall: calls.add,
          onDirections: targets.add,
          brightness: brightness,
        );

        expect(find.text('Anadolu yakası servisi'), findsOneWidget);
        expect(find.byKey(_plateOutbound), findsOneWidget);
        expect(find.text('Plaka: 34 ABC 12'), findsOneWidget);
        expect(find.text('Şoför: Mehmet Usta'), findsOneWidget);
        expect(find.text('+905551112233'), findsOneWidget);
        expect(
          find.text(
            'Kadıköy İskele · Moda Caddesi 12, Caferağa, Kadıköy/İstanbul',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Kalkış: '), findsOneWidget);
        // Seçilmeyen servis kartta hiç yok; plakası zaten gelmiyor.
        expect(find.text('Avrupa yakası servisi'), findsNothing);
        expect(find.text('Değiştir'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('work-transport-call-OUTBOUND')),
        );
        expect(calls, ['+905551112233']);

        await tester.tap(
          find.byKey(const ValueKey('work-transport-directions-OUTBOUND')),
        );
        expect(targets, hasLength(1));
        expect(targets.single.latitude, 40.98765432);
        expect(targets.single.longitude, 29.02612345);
        expect(targets.single.arrival, DateTime.utc(2026, 9, 20, 3, 40));
      });

      testWidgets('durağın koordinatı yoksa yol tarifi düğmesi yok', (
        tester,
      ) async {
        await _pump(
          tester,
          transport: _transport(
            shuttles: [
              shuttleJson(
                stops: [stopJson(address: stopAddressJson(position: null))],
              ),
            ],
            seats: [seatJson()],
          ),
          onDirections: (_) {},
          brightness: brightness,
        );

        expect(
          find.byKey(const ValueKey('work-transport-directions-OUTBOUND')),
          findsNothing,
        );
      });

      testWidgets('yol parası satırı "siz" diliyle tutarı yazar', (
        tester,
      ) async {
        await _pump(
          tester,
          transport: _transport(allowanceNote: 'Gün sonunda elden.'),
          brightness: brightness,
        );

        expect(find.text('Dönüş · Yol parası'), findsOneWidget);
        expect(
          find.text('İşvereniniz ₺150 yol parası verecek.'),
          findsOneWidget,
        );
        expect(find.text('Gün sonunda elden.'), findsOneWidget);
      });

      testWidgets('kendi imkânı ve sağlanmıyor tek cümle; not yazılır', (
        tester,
      ) async {
        await _pump(
          tester,
          transport: _transport(
            outboundMethod: 'SELF',
            returnMethod: 'NONE',
            allowanceAmount: null,
            notes: 'Servis 5 dk bekler.',
            shuttles: const [],
          ),
          brightness: brightness,
        );

        expect(find.text('Gidiş ulaşımı size ait.'), findsOneWidget);
        expect(find.text('Dönüş için ulaşım sağlanmıyor.'), findsOneWidget);
        expect(find.text('Not: Servis 5 dk bekler.'), findsOneWidget);
        expect(find.text('Koltuk seçin'), findsNothing);
      });

      testWidgets('koltuğu düşmüş yön "yeniden seçin" uyarısı çizer', (
        tester,
      ) async {
        // Sunucudaki koltuk artık planda olmayan bir servise işaret ediyor.
        await _pump(
          tester,
          transport: _transport(seats: [seatJson(shuttleId: 'gone')]),
          onSelectSeat: (_) {},
          brightness: brightness,
        );

        expect(
          find.byKey(const ValueKey('work-transport-dropped-OUTBOUND')),
          findsOneWidget,
        );
        expect(find.text(WorkTransportCard.seatDroppedText), findsOneWidget);
        expect(find.text('Koltuk seçin'), findsOneWidget);
      });

      testWidgets('SEAT_DROPPED bağlamı koltuksuz yönü uyarıyla açar', (
        tester,
      ) async {
        await _pump(
          tester,
          transport: _transport(),
          seatDropped: true,
          brightness: brightness,
        );

        expect(find.text(WorkTransportCard.seatDroppedText), findsOneWidget);
        expect(find.text('Henüz koltuk seçmediniz.'), findsNothing);
      });

      testWidgets('kapanmış atamada düğmeler yok, bilgi duruyor', (
        tester,
      ) async {
        await _pump(
          tester,
          transport: _transport(seats: [seatJson()]),
          canSelectSeat: false,
          onSelectSeat: (_) {},
          brightness: brightness,
        );

        expect(find.text('Plaka: 34 ABC 12'), findsOneWidget);
        expect(find.text('Değiştir'), findsNothing);
        expect(find.text('Koltuk seçin'), findsNothing);
      });

      testWidgets('istek sürerken düğme kilitli', (tester) async {
        await _pump(
          tester,
          transport: _transport(),
          busyDirection: ShuttleDirection.outbound,
          onSelectSeat: (_) {},
          brightness: brightness,
        );

        final button = tester.widget<OutlinedButton>(
          find.byKey(_selectOutbound),
        );
        expect(button.onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('yönde servis yoksa açıklama', (tester) async {
        await _pump(
          tester,
          transport: _transport(shuttles: const []),
          brightness: brightness,
        );

        expect(
          find.text('Bu yön için henüz servis tanımlanmadı.'),
          findsOneWidget,
        );
      });
    });
  }
}
