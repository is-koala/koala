import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/models/canonical_address.dart';

/// `PUT /jobs/{jobId}/transport-plan` gövdesi (`TransportPlanWriteDto`).
///
/// Plan **bütünüyle** yazılıyor: listede `id` taşıyan servis/durak yerinde
/// güncelleniyor ve koltuklar korunuyor, `id`'siz olan yeni açılıyor, listede
/// olmayan mevcut kayıt koltuklarıyla birlikte siliniyor.
class TransportPlanWrite {
  const TransportPlanWrite({
    required this.outboundMethod,
    required this.returnMethod,
    this.allowanceAmount,
    this.allowanceNote,
    this.notes,
    this.shuttles = const [],
  });

  final TransportMethod outboundMethod;
  final TransportMethod returnMethod;

  /// Yalnız bir yön `CASH_ALLOWANCE` iken gönderiliyor; sunucu aksini `400`
  /// ile çeviriyor.
  final double? allowanceAmount;
  final String? allowanceNote;
  final String? notes;
  final List<ShuttleWrite> shuttles;

  Map<String, dynamic> toJson() => {
    'outboundMethod': outboundMethod.code,
    'returnMethod': returnMethod.code,
    'allowanceAmount': ?allowanceAmount,
    'allowanceNote': ?_trimmed(allowanceNote),
    'notes': ?_trimmed(notes),
    'shuttles': [for (final shuttle in shuttles) shuttle.toJson()],
  };
}

/// `ShuttleWriteDto`.
class ShuttleWrite {
  const ShuttleWrite({
    required this.direction,
    required this.name,
    required this.capacity,
    required this.stops,
    this.id,
    this.plate,
    this.driverName,
    this.driverPhone,
  });

  /// Var olan servisin kimliği; verilirse yerinde güncelleme.
  final String? id;
  final ShuttleDirection direction;
  final String name;
  final String? plate;
  final int capacity;
  final String? driverName;
  final String? driverPhone;
  final List<ShuttleStopWrite> stops;

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'direction': direction.code,
    'name': name.trim(),
    'plate': ?_trimmed(plate),
    'capacity': capacity,
    'driverName': ?_trimmed(driverName),
    'driverPhone': ?_trimmed(driverPhone),
    'stops': [for (final stop in stops) stop.toJson()],
  };
}

/// `ShuttleStopWriteDto`.
class ShuttleStopWrite {
  const ShuttleStopWrite({
    required this.scheduledAt,
    this.id,
    this.label,
    this.address,
  });

  final String? id;
  final String? label;

  /// Kalkış anı; gövdeye UTC yazılıyor.
  final DateTime scheduledAt;

  /// Yeni durakta zorunlu; var olan durakta verilmezse mevcut adres kalıyor.
  final AddressWrite? address;

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'label': ?_trimmed(label),
    'scheduledAt': scheduledAt.toUtc().toIso8601String(),
    'address': ?address?.toJson(),
  };
}

String? _trimmed(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
