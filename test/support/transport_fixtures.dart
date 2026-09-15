// Ulaşım planı gövdeleri (koala-backend#297); model, kart ve düzenleyici
// testleri aynı sözlükleri kullanıyor ki bir alan adı değiştiğinde hepsi
// birlikte kırılsın.

/// Durak adresi (`AddressDto`), Kadıköy Moda.
Map<String, Object?> stopAddressJson({
  String id = 'adr-stop-1',
  String districtName = 'Kadıköy',
  String? displayAddress = 'Moda Caddesi 12, Caferağa, Kadıköy/İstanbul',
  Map<String, Object?>? position = const {
    'latitude': 40.98765432,
    'longitude': 29.02612345,
    'source': 'USER_CONFIRMED_PIN',
  },
}) => {
  'id': id,
  'countryId': 'c-1',
  'countryName': 'Türkiye',
  'countryCode': 'TR',
  'cityId': 'ct-1',
  'cityName': 'İstanbul',
  'districtId': 'd-1',
  'districtName': districtName,
  'displayAddress': ?displayAddress,
  'position': ?position,
  'components': {
    'neighborhood': 'Caferağa',
    'thoroughfare': 'Moda Caddesi',
    'buildingNumber': '12',
    'postalCode': '34710',
  },
  'canonicalVersion': 1,
  'needsReview': false,
};

/// Durak (`ShuttleStopDto`).
Map<String, Object?> stopJson({
  String id = 'stop-1',
  String? label = 'Kadıköy İskele',
  String scheduledAt = '2026-09-20T03:40:00Z',
  int sortOrder = 0,
  Map<String, Object?>? address,
  bool includeAddress = true,
  int seatsTaken = 0,
}) => {
  'id': id,
  'label': label,
  'scheduledAt': scheduledAt,
  'sortOrder': sortOrder,
  if (includeAddress) 'address': address ?? stopAddressJson(),
  'seatsTaken': seatsTaken,
};

/// Servis (`ShuttleDto`). Plaka/şoför işçi görünümünde yalnız seçilen
/// serviste dolu; testler `plate: null` ile diğer servisi kuruyor.
Map<String, Object?> shuttleJson({
  String id = 'shuttle-1',
  String direction = 'OUTBOUND',
  String name = 'Anadolu yakası servisi',
  String? plate = '34 ABC 12',
  int capacity = 12,
  int seatsTaken = 3,
  String? driverName = 'Mehmet Usta',
  String? driverPhone = '+905551112233',
  int sortOrder = 0,
  List<Map<String, Object?>>? stops,
}) => {
  'id': id,
  'direction': direction,
  'name': name,
  'plate': plate,
  'capacity': capacity,
  'seatsTaken': seatsTaken,
  'driverName': driverName,
  'driverPhone': driverPhone,
  'sortOrder': sortOrder,
  'stops': stops ?? [stopJson()],
};

/// İşveren planı (`TransportPlanDto`).
Map<String, Object?> transportPlanJson({
  String outboundMethod = 'SHUTTLE',
  String returnMethod = 'CASH_ALLOWANCE',
  double? allowanceAmount = 150,
  String? allowanceNote = 'Gün sonunda elden verilir.',
  String? notes = 'Servis 5 dk bekler.',
  List<Map<String, Object?>>? shuttles,
}) => {
  'id': 'plan-1',
  'jobId': 'job-1',
  'outboundMethod': outboundMethod,
  'returnMethod': returnMethod,
  'allowanceAmount': allowanceAmount,
  'allowanceNote': allowanceNote,
  'notes': notes,
  'shuttles': shuttles ?? [shuttleJson()],
  'updatedAt': '2026-09-14T10:00:00Z',
};

/// Atamanın görünümü (`AssignmentTransportDto`).
Map<String, Object?> assignmentTransportJson({
  String outboundMethod = 'SHUTTLE',
  String returnMethod = 'CASH_ALLOWANCE',
  double? allowanceAmount = 150,
  String? allowanceNote,
  String? notes,
  List<Map<String, Object?>>? shuttles,
  List<Map<String, Object?>> seats = const [],
}) => {
  'outboundMethod': outboundMethod,
  'returnMethod': returnMethod,
  'allowanceAmount': allowanceAmount,
  'allowanceNote': allowanceNote,
  'notes': notes,
  'shuttles': shuttles ?? [shuttleJson()],
  'seats': seats,
};

/// Koltuk (`SeatAssignmentDto`).
Map<String, Object?> seatJson({
  String id = 'seat-1',
  String direction = 'OUTBOUND',
  String shuttleId = 'shuttle-1',
  String stopId = 'stop-1',
}) => {
  'id': id,
  'direction': direction,
  'shuttleId': shuttleId,
  'stopId': stopId,
};

/// İlan detayındaki herkese açık özet (`JobTransportDto`).
Map<String, Object?> jobTransportJson({
  String outboundMethod = 'SHUTTLE',
  String returnMethod = 'CASH_ALLOWANCE',
  double? allowanceAmount = 150,
  int? shuttleCount,
  List<Map<String, Object?>>? shuttles,
}) {
  final list =
      shuttles ??
      [
        {
          'direction': 'OUTBOUND',
          'name': 'Anadolu yakası servisi',
          'stops': [
            {
              'districtName': 'Kadıköy',
              'neighborhood': 'Caferağa',
              'scheduledAt': '2026-09-20T03:40:00Z',
            },
          ],
        },
      ];
  return {
    'outboundMethod': outboundMethod,
    'returnMethod': returnMethod,
    'allowanceAmount': allowanceAmount,
    'shuttleCount': shuttleCount ?? list.length,
    'shuttles': list,
  };
}
