import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/transport/models/transport_plan_draft.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';

import '../../../../support/transport_fixtures.dart';

const _moda = ConfirmedAddress(
  country: ReferenceLocation(id: 'c-1', name: 'Türkiye'),
  city: ReferenceLocation(id: 'ct-1', name: 'İstanbul'),
  district: ReferenceLocation(id: 'd-1', name: 'Kadıköy'),
  components: AddressComponents(
    neighborhood: 'Caferağa',
    thoroughfare: 'Moda Caddesi',
    buildingNumber: '12',
    postalCode: '34710',
  ),
  position: AddressPosition(
    latitude: 40.98765432,
    longitude: 29.02612345,
    source: AddressPositionSource.userConfirmedPin,
  ),
);

TransportPlan _plan({List<Map<String, Object?>>? shuttles}) =>
    TransportPlan.fromJson(transportPlanJson(shuttles: shuttles));

void main() {
  group('TransportPlanDraft.fromPlan / toWrite', () {
    test('sunucudaki plan kimlikleriyle geri yazılır, adres gönderilmez', () {
      final draft = TransportPlanDraft.fromPlan(_plan());

      expect(draft.outboundMethod, TransportMethod.shuttle);
      expect(draft.returnMethod, TransportMethod.cashAllowance);
      expect(draft.allowanceAmount, 150);
      expect(draft.allowanceNote, 'Gün sonunda elden verilir.');
      expect(draft.notes, 'Servis 5 dk bekler.');
      final shuttle = draft.shuttles.single;
      expect(shuttle.id, 'shuttle-1');
      expect(shuttle.seatsTaken, 3);
      expect(shuttle.isNew, isFalse);
      final stop = shuttle.stops.single;
      expect(stop.id, 'stop-1');
      expect(stop.scheduledAt, DateTime.utc(2026, 9, 20, 3, 40).toLocal());
      expect(stop.existingAddress?.districtName, 'Kadıköy');
      expect(stop.hasAddress, isTrue);
      expect(
        stop.addressSummary,
        'Moda Caddesi 12, Caferağa, Kadıköy/İstanbul',
      );

      final json = draft.toWrite().toJson();
      final shuttleJson = (json['shuttles'] as List).single as Map;
      expect(shuttleJson['id'], 'shuttle-1');
      expect(shuttleJson['capacity'], 12);
      final stopJson = (shuttleJson['stops'] as List).single as Map;
      expect(stopJson['id'], 'stop-1');
      expect(stopJson['scheduledAt'], '2026-09-20T03:40:00.000Z');
      // Yeniden seçilmeyen adres gövdede yok; sunucu eskisini koruyor.
      expect(stopJson.containsKey('address'), isFalse);
    });

    test('yeni durak seçilen adresi yazar, var olan durak yeni adresi de', () {
      final draft = TransportPlanDraft.fromPlan(_plan());
      draft.shuttles.single.stops.single.pickedAddress = _moda;
      draft.shuttles.single.stops.add(
        StopDraft(
          label: 'Bostancı',
          scheduledAt: DateTime(2026, 9, 20, 7),
          pickedAddress: _moda,
        ),
      );

      final stops =
          ((draft.toWrite().toJson()['shuttles'] as List).single
                  as Map)['stops']
              as List;
      expect((stops[0] as Map)['address'], isA<Map>());
      expect((stops[1] as Map).containsKey('id'), isFalse);
      expect((stops[1] as Map)['label'], 'Bostancı');
      expect(((stops[1] as Map)['address'] as Map)['districtId'], 'd-1');
    });

    test('yol parası olmayan planda tutar ve not gönderilmez', () {
      final draft = TransportPlanDraft(
        outboundMethod: TransportMethod.self,
        returnMethod: TransportMethod.none,
        allowanceAmount: 150,
        allowanceNote: 'kalıntı',
      );

      final json = draft.toWrite().toJson();
      expect(json.containsKey('allowanceAmount'), isFalse);
      expect(json.containsKey('allowanceNote'), isFalse);
    });
  });

  group('isBlank', () {
    test('boş taslak', () {
      expect(TransportPlanDraft().isBlank, isTrue);
      expect(
        TransportPlanDraft(outboundMethod: TransportMethod.self).isBlank,
        isFalse,
      );
      expect(TransportPlanDraft(notes: 'x').isBlank, isFalse);
    });
  });

  group('validate', () {
    test('geçerli plan null döner', () {
      expect(TransportPlanDraft.fromPlan(_plan()).validate(), isNull);
    });

    test('yol parası seçili ama tutar yok', () {
      final draft = TransportPlanDraft(
        outboundMethod: TransportMethod.cashAllowance,
      );
      expect(draft.validate(), 'Yol parası tutarını girin');
    });

    test('servis yönteminde servis yok', () {
      final draft = TransportPlanDraft(outboundMethod: TransportMethod.shuttle);
      expect(draft.validate(), 'Gidiş için en az bir servis ekleyin');
    });

    test('yöntem servis değilken servis listesi dolu', () {
      final draft = TransportPlanDraft.fromPlan(_plan())
        ..outboundMethod = TransportMethod.self;
      expect(draft.validate(), contains('servisleri silin'));
    });

    test('servis alanları: ad, kapasite aralığı, koltuk alt sınırı, durak', () {
      final draft = TransportPlanDraft(outboundMethod: TransportMethod.shuttle);
      final shuttle = ShuttleDraft(direction: ShuttleDirection.outbound);
      draft.shuttles.add(shuttle);

      expect(draft.validate(), 'Servis adı zorunlu');

      shuttle.name = 'Servis A';
      expect(draft.validate(), contains('kapasite 1 ile 100 arasında'));

      shuttle.capacity = 101;
      expect(draft.validate(), contains('kapasite 1 ile 100 arasında'));

      shuttle.capacity = 10;
      expect(draft.validate(), 'Servis A: en az bir durak ekleyin');

      shuttle.stops.add(StopDraft(label: 'İskele'));
      expect(draft.validate(), 'Servis A: durağın kalkış saatini seçin');

      shuttle.stops.single.scheduledAt = DateTime(2026, 9, 20, 6);
      expect(draft.validate(), 'Servis A: durağın adresini haritadan seçin');

      shuttle.stops.single.pickedAddress = _moda;
      expect(draft.validate(), isNull);
    });

    test('kapasite seçilmiş koltukların altına inemez', () {
      final draft = TransportPlanDraft.fromPlan(_plan());
      draft.shuttles.single.capacity = 2;

      expect(
        draft.validate(),
        'Anadolu yakası servisi: kapasite seçilmiş koltuk sayısının (3) '
        'altına inemez',
      );
    });
  });

  group('droppedSeats', () {
    test('silinen servisin ve durağın koltukları sayılır', () {
      final original = _plan(
        shuttles: [
          shuttleJson(
            seatsTaken: 3,
            stops: [
              stopJson(id: 'stop-1', seatsTaken: 2),
              stopJson(id: 'stop-2', label: 'Bostancı', seatsTaken: 1),
            ],
          ),
          shuttleJson(id: 'shuttle-2', name: 'Avrupa', seatsTaken: 4),
        ],
      );
      final draft = TransportPlanDraft.fromPlan(original);

      expect(draft.droppedSeats(original), 0);

      // Bir durak silindi: o durağı seçen 1 koltuk.
      draft.shuttles.first.stops.removeAt(1);
      expect(draft.droppedSeats(original), 1);

      // Bütün servis silindi: 4 koltuk daha.
      draft.shuttles.removeAt(1);
      expect(draft.droppedSeats(original), 5);

      // Yeni (id'siz) servis eklemek sayıyı değiştirmez.
      draft.shuttles.add(ShuttleDraft(direction: ShuttleDirection.outbound));
      expect(draft.droppedSeats(original), 5);
      expect(draft.droppedSeats(null), 0);
    });
  });

  test('ShuttleDraft.summaryLine ve StopDraft.displayName', () {
    final shuttle = ShuttleDraft.from(Shuttle.fromJson(shuttleJson()));
    expect(shuttle.summaryLine, '34 ABC 12 · 12 koltuk · 1 durak');
    expect(
      ShuttleDraft(direction: ShuttleDirection.outbound).summaryLine,
      '0 durak',
    );

    expect(StopDraft().displayName, 'Durak');
    expect(StopDraft(pickedAddress: _moda).displayName, 'Kadıköy');
    expect(StopDraft(label: ' İskele ').displayName, 'İskele');
  });
}
