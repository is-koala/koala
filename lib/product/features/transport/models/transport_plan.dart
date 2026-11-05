import 'package:koala/product/extensions/num_extensions.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/models/canonical_address.dart';

/// Bir yöndeki ulaşım yöntemi. Backend `TransportMethod` karşılığı.
enum TransportMethod {
  shuttle('SHUTTLE', 'Servis'),
  cashAllowance('CASH_ALLOWANCE', 'Yol parası'),
  self('SELF', 'Kendi imkânı'),
  none('NONE', 'Sağlanmıyor');

  const TransportMethod(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Tanınmayan ya da boş değerde `null`: eski sunucu alanı hiç
  /// göndermiyor, planı "yok" saymak gerekiyor.
  static TransportMethod? fromCode(Object? value) {
    for (final method in values) {
      if (method.code == value) return method;
    }
    return null;
  }
}

/// Servisin yönü. Backend `ShuttleDirection` karşılığı.
enum ShuttleDirection {
  outbound('OUTBOUND', 'Gidiş'),
  returnTrip('RETURN', 'Dönüş');

  const ShuttleDirection(this.code, this.displayName);

  final String code;
  final String displayName;

  static ShuttleDirection? fromCode(Object? value) {
    for (final direction in values) {
      if (direction.code == value) return direction;
    }
    return null;
  }
}

/// Servisin bir durağı (`ShuttleStopDto`).
///
/// [address] yalnız işverene ve atanmış işçiye geliyor; ilan detayındaki
/// herkese açık görünüm [PublicStop]'ta.
class ShuttleStop {
  const ShuttleStop({
    required this.id,
    required this.scheduledAt,
    this.label,
    this.sortOrder = 0,
    this.address,
    this.seatsTaken = 0,
  });

  final String id;
  final String? label;

  /// Servisin bu duraktan kalkacağı an (UTC).
  final DateTime scheduledAt;
  final int sortOrder;
  final CanonicalAddress? address;

  /// Bu durağı seçen koltuk sayısı.
  final int seatsTaken;

  /// Listede yazılan ad: etiket, yoksa ilçe/il, o da yoksa "Durak".
  String get displayName {
    final text = label;
    if (text != null && text.trim().isNotEmpty) return text.trim();
    return address?.shortLabel ?? 'Durak';
  }

  /// Tam adres satırı; sunucu adresi göndermediyse `null`.
  String? get addressLine {
    final line = address?.displayAddress;
    if (line != null && line.isNotEmpty) return line;
    return address?.shortLabel;
  }

  factory ShuttleStop.fromJson(Map<String, dynamic> json) {
    final address = json['address'];
    return ShuttleStop(
      id: '${json['id']}',
      label: json['label'] as String?,
      scheduledAt:
          _parseDate(json['scheduledAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      address: address is Map<String, dynamic>
          ? CanonicalAddress.fromJson(address)
          : null,
      seatsTaken: (json['seatsTaken'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Bir servis (`ShuttleDto`).
///
/// Plaka ve şoför bilgisi işverene her serviste, işçiye yalnız koltuk seçtiği
/// serviste geliyor; diğerlerinde `null`.
class Shuttle {
  const Shuttle({
    required this.id,
    required this.direction,
    required this.name,
    required this.capacity,
    this.plate,
    this.seatsTaken = 0,
    this.driverName,
    this.driverPhone,
    this.sortOrder = 0,
    this.stops = const [],
  });

  final String id;
  final ShuttleDirection direction;
  final String name;
  final String? plate;
  final int capacity;
  final int seatsTaken;
  final String? driverName;
  final String? driverPhone;
  final int sortOrder;
  final List<ShuttleStop> stops;

  bool get isFull => seatsTaken >= capacity;

  int get remainingSeats => (capacity - seatsTaken).clamp(0, capacity);

  /// Doluluk metni: `3/12 dolu`.
  String get occupancyLabel => '$seatsTaken/$capacity dolu';

  ShuttleStop? stopById(String stopId) =>
      stops.where((stop) => stop.id == stopId).firstOrNull;

  factory Shuttle.fromJson(Map<String, dynamic> json) {
    final stops = json['stops'];
    return Shuttle(
      id: '${json['id']}',
      direction:
          ShuttleDirection.fromCode(json['direction']) ??
          ShuttleDirection.outbound,
      name: json['name'] as String? ?? '',
      plate: json['plate'] as String?,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      seatsTaken: (json['seatsTaken'] as num?)?.toInt() ?? 0,
      driverName: json['driverName'] as String?,
      driverPhone: json['driverPhone'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      stops: stops is List
          ? stops
                .whereType<Map<String, dynamic>>()
                .map(ShuttleStop.fromJson)
                .toList()
          : const [],
    );
  }
}

/// Ulaşım planının iki yönü ve yol parası; üç görünümün ortak parçası.
mixin TransportMethods {
  TransportMethod get outboundMethod;
  TransportMethod get returnMethod;
  double? get allowanceAmount;

  TransportMethod methodFor(ShuttleDirection direction) => switch (direction) {
    ShuttleDirection.outbound => outboundMethod,
    ShuttleDirection.returnTrip => returnMethod,
  };

  bool usesShuttle(ShuttleDirection direction) =>
      methodFor(direction) == TransportMethod.shuttle;

  bool get hasCashAllowance =>
      outboundMethod == TransportMethod.cashAllowance ||
      returnMethod == TransportMethod.cashAllowance;

  /// Yöntem satırı, iki kabuğun kartlarında aynı:
  /// `Gidiş: Servis · Dönüş: Yol parası (₺150)`.
  String get methodsLine {
    String label(ShuttleDirection direction) {
      final method = methodFor(direction);
      final amount = allowanceAmount;
      final suffix = method == TransportMethod.cashAllowance && amount != null
          ? ' (${formatAllowance(amount)})'
          : '';
      return '${direction.displayName}: ${method.displayName}$suffix';
    }

    return '${label(ShuttleDirection.outbound)} · '
        '${label(ShuttleDirection.returnTrip)}';
  }
}

/// İşverenin gördüğü plan (`TransportPlanDto`): plaka, şoför, tam adres ve
/// `seatsTaken` dahil.
class TransportPlan with TransportMethods {
  const TransportPlan({
    required this.outboundMethod,
    required this.returnMethod,
    this.id,
    this.jobId,
    this.allowanceAmount,
    this.allowanceNote,
    this.notes,
    this.shuttles = const [],
    this.updatedAt,
  });

  final String? id;
  final String? jobId;
  @override
  final TransportMethod outboundMethod;
  @override
  final TransportMethod returnMethod;
  @override
  final double? allowanceAmount;
  final String? allowanceNote;
  final String? notes;
  final List<Shuttle> shuttles;
  final DateTime? updatedAt;

  List<Shuttle> shuttlesFor(ShuttleDirection direction) =>
      shuttles.where((shuttle) => shuttle.direction == direction).toList();

  /// Yöntemler okunamıyorsa `null`: eski sunucuda ya da planı olmayan
  /// ilanda kart çizilmiyor.
  static TransportPlan? parse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final outbound = TransportMethod.fromCode(value['outboundMethod']);
    final returnMethod = TransportMethod.fromCode(value['returnMethod']);
    if (outbound == null || returnMethod == null) return null;
    return TransportPlan(
      id: value['id'] as String?,
      jobId: value['jobId'] as String?,
      outboundMethod: outbound,
      returnMethod: returnMethod,
      allowanceAmount: (value['allowanceAmount'] as num?)?.toDouble(),
      allowanceNote: value['allowanceNote'] as String?,
      notes: value['notes'] as String?,
      shuttles: _parseShuttles(value['shuttles']),
      updatedAt: _parseDate(value['updatedAt']),
    );
  }

  factory TransportPlan.fromJson(Map<String, dynamic> json) {
    final plan = parse(json);
    if (plan == null) {
      throw const FormatException('Ulaşım planı yöntemleri okunamadı.');
    }
    return plan;
  }
}

/// Atamanın seçtiği koltuk (`SeatAssignmentDto`); yön başına en fazla bir.
class SeatAssignment {
  const SeatAssignment({
    required this.id,
    required this.direction,
    required this.shuttleId,
    required this.stopId,
    this.boarding,
  });

  final String id;
  final ShuttleDirection direction;
  final String shuttleId;
  final String stopId;

  /// Bu koltuğun güncel servisi ve kalkış günü için biniş durumu
  /// (is-koala/koala#217): BOARDED, yoksa son NO_SHOW; kayıt yoksa ya da
  /// sunucu alanı göndermiyorsa `null`.
  final SeatBoardingStatus? boarding;

  static SeatAssignment? parse(Map<String, dynamic> json) {
    final direction = ShuttleDirection.fromCode(json['direction']);
    if (direction == null) return null;
    return SeatAssignment(
      id: '${json['id']}',
      direction: direction,
      shuttleId: '${json['shuttleId']}',
      stopId: '${json['stopId']}',
      boarding: SeatBoardingStatus.parse(json['boarding']),
    );
  }
}

/// Atamanın ulaşım görünümü (`AssignmentTransportDto`): plan + servisler +
/// bu atamanın koltukları.
///
/// İşçi görünümünde plaka/şoför yalnız koltuk seçilen serviste dolu; kart
/// başka servisin plakasını hiç çizmiyor, sunucu zaten göndermiyor.
class AssignmentTransport with TransportMethods {
  const AssignmentTransport({
    required this.outboundMethod,
    required this.returnMethod,
    this.allowanceAmount,
    this.allowanceNote,
    this.notes,
    this.shuttles = const [],
    this.seats = const [],
  });

  @override
  final TransportMethod outboundMethod;
  @override
  final TransportMethod returnMethod;
  @override
  final double? allowanceAmount;
  final String? allowanceNote;
  final String? notes;
  final List<Shuttle> shuttles;
  final List<SeatAssignment> seats;

  List<Shuttle> shuttlesFor(ShuttleDirection direction) =>
      shuttles.where((shuttle) => shuttle.direction == direction).toList();

  SeatAssignment? seatFor(ShuttleDirection direction) =>
      seats.where((seat) => seat.direction == direction).firstOrNull;

  /// Seçili koltuğun servisi; koltuk yoksa ya da servis plandan düştüyse
  /// `null` — o zaman "yeniden seçin" durumu.
  Shuttle? selectedShuttle(ShuttleDirection direction) {
    final seat = seatFor(direction);
    if (seat == null) return null;
    return shuttles
        .where((shuttle) => shuttle.id == seat.shuttleId)
        .firstOrNull;
  }

  ShuttleStop? selectedStop(ShuttleDirection direction) {
    final seat = seatFor(direction);
    if (seat == null) return null;
    return selectedShuttle(direction)?.stopById(seat.stopId);
  }

  /// Yöntem servis ama bu yönde geçerli bir koltuk yok.
  bool needsSeat(ShuttleDirection direction) =>
      usesShuttle(direction) && selectedStop(direction) == null;

  static AssignmentTransport? parse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final outbound = TransportMethod.fromCode(value['outboundMethod']);
    final returnMethod = TransportMethod.fromCode(value['returnMethod']);
    if (outbound == null || returnMethod == null) return null;
    final seats = value['seats'];
    return AssignmentTransport(
      outboundMethod: outbound,
      returnMethod: returnMethod,
      allowanceAmount: (value['allowanceAmount'] as num?)?.toDouble(),
      allowanceNote: value['allowanceNote'] as String?,
      notes: value['notes'] as String?,
      shuttles: _parseShuttles(value['shuttles']),
      seats: seats is List
          ? seats
                .whereType<Map<String, dynamic>>()
                .map(SeatAssignment.parse)
                .nonNulls
                .toList()
          : const [],
    );
  }

  factory AssignmentTransport.fromJson(Map<String, dynamic> json) {
    final transport = parse(json);
    if (transport == null) {
      throw const FormatException('Ulaşım görünümü yöntemleri okunamadı.');
    }
    return transport;
  }
}

/// İlan detayındaki herkese açık durak (`PublicStopDto`): ilçe/semt ve saat.
class PublicStop {
  const PublicStop({
    required this.districtName,
    required this.scheduledAt,
    this.neighborhood,
  });

  final String districtName;
  final String? neighborhood;
  final DateTime scheduledAt;

  /// `Kadıköy · Caferağa`; semt yoksa yalnız ilçe.
  String get placeLabel {
    final parts = [
      districtName,
      neighborhood ?? '',
    ].where((part) => part.trim().isNotEmpty);
    return parts.join(' · ');
  }

  factory PublicStop.fromJson(Map<String, dynamic> json) {
    return PublicStop(
      districtName: json['districtName'] as String? ?? '',
      neighborhood: json['neighborhood'] as String?,
      scheduledAt:
          _parseDate(json['scheduledAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

/// Herkese açık servis (`PublicShuttleDto`): plaka, şoför, tam adres yok.
class PublicShuttle {
  const PublicShuttle({
    required this.direction,
    required this.name,
    this.stops = const [],
  });

  final ShuttleDirection direction;
  final String name;
  final List<PublicStop> stops;

  factory PublicShuttle.fromJson(Map<String, dynamic> json) {
    final stops = json['stops'];
    return PublicShuttle(
      direction:
          ShuttleDirection.fromCode(json['direction']) ??
          ShuttleDirection.outbound,
      name: json['name'] as String? ?? '',
      stops: stops is List
          ? stops
                .whereType<Map<String, dynamic>>()
                .map(PublicStop.fromJson)
                .toList()
          : const [],
    );
  }
}

/// İlan detayındaki ulaşım özeti (`JobDetailDto.transport`).
class JobTransport with TransportMethods {
  const JobTransport({
    required this.outboundMethod,
    required this.returnMethod,
    this.allowanceAmount,
    this.shuttleCount = 0,
    this.shuttles = const [],
  });

  @override
  final TransportMethod outboundMethod;
  @override
  final TransportMethod returnMethod;
  @override
  final double? allowanceAmount;
  final int shuttleCount;
  final List<PublicShuttle> shuttles;

  List<PublicShuttle> shuttlesFor(ShuttleDirection direction) =>
      shuttles.where((shuttle) => shuttle.direction == direction).toList();

  static JobTransport? parse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final outbound = TransportMethod.fromCode(value['outboundMethod']);
    final returnMethod = TransportMethod.fromCode(value['returnMethod']);
    if (outbound == null || returnMethod == null) return null;
    final shuttles = value['shuttles'];
    final parsedShuttles = shuttles is List
        ? shuttles
              .whereType<Map<String, dynamic>>()
              .map(PublicShuttle.fromJson)
              .toList()
        : const <PublicShuttle>[];
    return JobTransport(
      outboundMethod: outbound,
      returnMethod: returnMethod,
      allowanceAmount: (value['allowanceAmount'] as num?)?.toDouble(),
      shuttleCount:
          (value['shuttleCount'] as num?)?.toInt() ?? parsedShuttles.length,
      shuttles: parsedShuttles,
    );
  }
}

/// Yol parasının ekrana yazılan hâli: `₺150`, küsuratlıysa `₺1.250,5`.
String formatAllowance(double amount) => '₺${amount.asExactPrice}';

List<Shuttle> _parseShuttles(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().map(Shuttle.fromJson).toList()
    : const [];

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
