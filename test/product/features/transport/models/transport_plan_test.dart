import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/models/transport_plan_write.dart';
import 'package:koala/product/models/canonical_address.dart';

import '../../../../support/transport_fixtures.dart';
import '../../../../support/work_test_support.dart';

void main() {
  group('TransportPlan.parse', () {
    test('dolu gövdeyi bütün alanlarıyla okur', () {
      final plan = TransportPlan.parse(transportPlanJson())!;

      expect(plan.id, 'plan-1');
      expect(plan.jobId, 'job-1');
      expect(plan.outboundMethod, TransportMethod.shuttle);
      expect(plan.returnMethod, TransportMethod.cashAllowance);
      expect(plan.allowanceAmount, 150);
      expect(plan.allowanceNote, 'Gün sonunda elden verilir.');
      expect(plan.notes, 'Servis 5 dk bekler.');
      expect(plan.updatedAt, DateTime.utc(2026, 9, 14, 10));
      expect(plan.hasCashAllowance, isTrue);
      expect(plan.usesShuttle(ShuttleDirection.outbound), isTrue);
      expect(plan.usesShuttle(ShuttleDirection.returnTrip), isFalse);

      final shuttle = plan.shuttles.single;
      expect(shuttle.id, 'shuttle-1');
      expect(shuttle.direction, ShuttleDirection.outbound);
      expect(shuttle.name, 'Anadolu yakası servisi');
      expect(shuttle.plate, '34 ABC 12');
      expect(shuttle.capacity, 12);
      expect(shuttle.seatsTaken, 3);
      expect(shuttle.remainingSeats, 9);
      expect(shuttle.isFull, isFalse);
      expect(shuttle.occupancyLabel, '3/12 dolu');
      expect(shuttle.driverName, 'Mehmet Usta');
      expect(shuttle.driverPhone, '+905551112233');

      final stop = shuttle.stops.single;
      expect(stop.id, 'stop-1');
      expect(stop.label, 'Kadıköy İskele');
      expect(stop.displayName, 'Kadıköy İskele');
      expect(stop.scheduledAt, DateTime.utc(2026, 9, 20, 3, 40));
      expect(stop.address?.districtName, 'Kadıköy');
      expect(stop.addressLine, 'Moda Caddesi 12, Caferağa, Kadıköy/İstanbul');
      expect(stop.address?.position?.latitude, 40.98765432);
    });

    test('yöntemi olmayan ya da tanınmayan gövde null', () {
      expect(TransportPlan.parse(null), isNull);
      expect(TransportPlan.parse(const <String, dynamic>{}), isNull);
      expect(
        TransportPlan.parse(transportPlanJson(outboundMethod: 'TELEPORT')),
        isNull,
      );
      expect(
        () => TransportPlan.fromJson(const {}),
        throwsA(isA<FormatException>()),
      );
    });

    test('boş alanlar varsayılanlara düşer', () {
      final plan = TransportPlan.parse({
        'outboundMethod': 'SELF',
        'returnMethod': 'NONE',
      })!;

      expect(plan.allowanceAmount, isNull);
      expect(plan.shuttles, isEmpty);
      expect(plan.hasCashAllowance, isFalse);
      expect(plan.updatedAt, isNull);
    });

    test('adresi olmayan durak ilçeye, o da yoksa "Durak"a düşer', () {
      final stop = ShuttleStop.fromJson(
        stopJson(label: null, includeAddress: false),
      );

      expect(stop.displayName, 'Durak');
      expect(stop.addressLine, isNull);

      final withAddress = ShuttleStop.fromJson(
        stopJson(label: '  ', address: stopAddressJson(displayAddress: null)),
      );
      expect(withAddress.displayName, 'Kadıköy/İstanbul');
      expect(withAddress.addressLine, 'Kadıköy/İstanbul');
    });

    test('dolu servis', () {
      final shuttle = Shuttle.fromJson(shuttleJson(capacity: 3, seatsTaken: 3));

      expect(shuttle.isFull, isTrue);
      expect(shuttle.remainingSeats, 0);
    });
  });

  group('AssignmentTransport.parse', () {
    test('koltuklar servis ve durağa çözülür', () {
      final transport = AssignmentTransport.parse(
        assignmentTransportJson(seats: [seatJson()]),
      )!;

      final seat = transport.seatFor(ShuttleDirection.outbound)!;
      expect(seat.id, 'seat-1');
      expect(seat.shuttleId, 'shuttle-1');
      expect(
        transport.selectedShuttle(ShuttleDirection.outbound)?.name,
        'Anadolu yakası servisi',
      );
      expect(
        transport.selectedStop(ShuttleDirection.outbound)?.label,
        'Kadıköy İskele',
      );
      expect(transport.needsSeat(ShuttleDirection.outbound), isFalse);
      expect(transport.seatFor(ShuttleDirection.returnTrip), isNull);
      // Dönüş yol parası: koltuk gerekmiyor.
      expect(transport.needsSeat(ShuttleDirection.returnTrip), isFalse);
    });

    test('koltuksuz servis yönü koltuk ister', () {
      final transport = AssignmentTransport.parse(assignmentTransportJson())!;

      expect(transport.needsSeat(ShuttleDirection.outbound), isTrue);
      expect(transport.selectedShuttle(ShuttleDirection.outbound), isNull);
    });

    test('plandan düşmüş servise işaret eden koltuk yeniden seçim ister', () {
      final transport = AssignmentTransport.parse(
        assignmentTransportJson(seats: [seatJson(shuttleId: 'shuttle-gone')]),
      )!;

      expect(transport.seatFor(ShuttleDirection.outbound), isNotNull);
      expect(transport.selectedShuttle(ShuttleDirection.outbound), isNull);
      expect(transport.needsSeat(ShuttleDirection.outbound), isTrue);
    });

    test('yönü tanınmayan koltuk atlanır, gövde null ise görünüm null', () {
      final transport = AssignmentTransport.parse(
        assignmentTransportJson(seats: [seatJson(direction: 'SIDEWAYS')]),
      )!;

      expect(transport.seats, isEmpty);
      expect(AssignmentTransport.parse(null), isNull);
      expect(
        () => AssignmentTransport.fromJson(const {}),
        throwsA(isA<FormatException>()),
      );
    });

    test('işçi görünümünde seçilmeyen servisin plakası null kalır', () {
      final transport = AssignmentTransport.parse(
        assignmentTransportJson(
          shuttles: [
            shuttleJson(),
            shuttleJson(
              id: 'shuttle-2',
              name: 'Avrupa yakası',
              plate: null,
              driverName: null,
              driverPhone: null,
            ),
          ],
          seats: [seatJson()],
        ),
      )!;

      expect(transport.shuttles[1].plate, isNull);
      expect(transport.shuttles[1].driverPhone, isNull);
      expect(
        transport.selectedShuttle(ShuttleDirection.outbound)?.plate,
        '34 ABC 12',
      );
    });
  });

  group('JobTransport.parse', () {
    test('herkese açık özet: ilçe/semt ve saat, plaka yok', () {
      final transport = JobTransport.parse(jobTransportJson())!;

      expect(transport.shuttleCount, 1);
      expect(transport.allowanceAmount, 150);
      final shuttle = transport.shuttlesFor(ShuttleDirection.outbound).single;
      expect(shuttle.name, 'Anadolu yakası servisi');
      final stop = shuttle.stops.single;
      expect(stop.placeLabel, 'Kadıköy · Caferağa');
      expect(stop.scheduledAt, DateTime.utc(2026, 9, 20, 3, 40));
    });

    test('semtsiz durak yalnız ilçe yazar; shuttleCount yoksa listeden', () {
      final transport = JobTransport.parse({
        'outboundMethod': 'SHUTTLE',
        'returnMethod': 'SHUTTLE',
        'shuttles': [
          {
            'direction': 'RETURN',
            'name': 'Dönüş',
            'stops': [
              {
                'districtName': 'Üsküdar',
                'scheduledAt': '2026-09-20T15:00:00Z',
              },
            ],
          },
        ],
      })!;

      expect(transport.shuttleCount, 1);
      expect(transport.shuttles.single.stops.single.placeLabel, 'Üsküdar');
    });

    test('alan yoksa null', () {
      expect(JobTransport.parse(null), isNull);
      expect(JobTransport.parse({'outboundMethod': 'SHUTTLE'}), isNull);
    });
  });

  group('sahip modeller', () {
    test('JobDetail.transport dolu ve null', () {
      final withPlan = JobDetail.fromJson({
        ...jobSummaryJson(),
        'transport': jobTransportJson(),
      });
      expect(withPlan.transport?.shuttleCount, 1);

      final without = JobDetail.fromJson({...jobSummaryJson()});
      expect(without.transport, isNull);

      final explicitNull = JobDetail.fromJson({
        ...jobSummaryJson(),
        'transport': null,
      });
      expect(explicitNull.transport, isNull);
    });

    test('Assignment.transport dolu ve null', () {
      final withPlan = Assignment.fromJson(
        assignmentJson(
          extra: {
            'transport': assignmentTransportJson(seats: [seatJson()]),
          },
        ),
      );
      expect(withPlan.transport?.seats, hasLength(1));

      expect(Assignment.fromJson(assignmentJson()).transport, isNull);
    });

    test('Job.hasShuttle alan yoksa false', () {
      expect(Job.fromJson(jobSummaryJson()).hasShuttle, isFalse);
      expect(
        Job.fromJson({...jobSummaryJson(), 'hasShuttle': true}).hasShuttle,
        isTrue,
      );
    });
  });

  group('TransportPlanWrite.toJson', () {
    test('id taşıyan servis/durak yerinde, boş alanlar gövdede yok', () {
      final write = TransportPlanWrite(
        outboundMethod: TransportMethod.shuttle,
        returnMethod: TransportMethod.cashAllowance,
        allowanceAmount: 150,
        allowanceNote: '  ',
        notes: 'Not',
        shuttles: [
          ShuttleWrite(
            id: 'shuttle-1',
            direction: ShuttleDirection.outbound,
            name: ' Anadolu ',
            capacity: 12,
            plate: '34 ABC 12',
            driverName: null,
            driverPhone: '',
            stops: [
              ShuttleStopWrite(
                id: 'stop-1',
                label: 'İskele',
                scheduledAt: DateTime.utc(2026, 9, 20, 3, 40),
              ),
              ShuttleStopWrite(
                scheduledAt: DateTime(2026, 9, 20, 7, 0).toUtc(),
                address: const AddressWrite(
                  countryId: 'c-1',
                  cityId: 'ct-1',
                  districtId: 'd-1',
                  components: AddressComponents(
                    neighborhood: 'Caferağa',
                    thoroughfare: 'Moda Caddesi',
                    postalCode: '34710',
                  ),
                  position: AddressPosition(
                    latitude: 40.98765432,
                    longitude: 29.02612345,
                    source: AddressPositionSource.userConfirmedPin,
                  ),
                ),
              ),
            ],
          ),
        ],
      );

      final json = write.toJson();

      expect(json['outboundMethod'], 'SHUTTLE');
      expect(json['returnMethod'], 'CASH_ALLOWANCE');
      expect(json['allowanceAmount'], 150);
      expect(json.containsKey('allowanceNote'), isFalse);
      expect(json['notes'], 'Not');

      final shuttle = (json['shuttles'] as List).single as Map;
      expect(shuttle['id'], 'shuttle-1');
      expect(shuttle['name'], 'Anadolu');
      expect(shuttle['direction'], 'OUTBOUND');
      expect(shuttle.containsKey('driverName'), isFalse);
      expect(shuttle.containsKey('driverPhone'), isFalse);

      final stops = shuttle['stops'] as List;
      final existing = stops[0] as Map;
      expect(existing['id'], 'stop-1');
      expect(existing['scheduledAt'], '2026-09-20T03:40:00.000Z');
      expect(existing.containsKey('address'), isFalse);

      final fresh = stops[1] as Map;
      expect(fresh.containsKey('id'), isFalse);
      expect(fresh.containsKey('label'), isFalse);
      expect((fresh['address'] as Map)['districtId'], 'd-1');
      expect((fresh['address'] as Map)['position'], isA<Map>());
    });

    test('yol parası olmayan planda tutar gövdede yok', () {
      final json = const TransportPlanWrite(
        outboundMethod: TransportMethod.self,
        returnMethod: TransportMethod.none,
      ).toJson();

      expect(json.containsKey('allowanceAmount'), isFalse);
      expect(json['shuttles'], isEmpty);
    });
  });

  test('formatAllowance', () {
    expect(formatAllowance(150), '₺150');
    expect(formatAllowance(1250.5), '₺1.250,5');
  });
}
