/// Mesai oturumu. Atamada birden çok olabilir ama aynı anda tek **açık**;
/// ikinci giriş `409`.
class WorkSession {
  const WorkSession({
    required this.id,
    required this.assignmentId,
    this.checkInAt,
    this.checkOutAt,
    this.checkInClientEventId,
    this.checkInCapturedAt,
    this.checkInReceivedAt,
    this.checkInPlausibilityFlags = const {},
    this.checkOutClientEventId,
    this.checkOutCapturedAt,
    this.checkOutReceivedAt,
    this.checkOutPlausibilityFlags = const {},
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.minutes,
  });

  final String id;

  final String assignmentId;

  final DateTime? checkInAt;

  final DateTime? checkOutAt;

  final String? checkInClientEventId;
  final DateTime? checkInCapturedAt;
  final DateTime? checkInReceivedAt;
  final Set<TimesheetPlausibility> checkInPlausibilityFlags;
  final String? checkOutClientEventId;
  final DateTime? checkOutCapturedAt;
  final DateTime? checkOutReceivedAt;
  final Set<TimesheetPlausibility> checkOutPlausibilityFlags;

  /// Konum isteğe bağlı.
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;

  /// Çıkışta sunucu hesaplar.
  final int? minutes;

  bool get isOpen => checkOutAt == null;

  bool get checkInNeedsReview => checkInPlausibilityFlags.isNotEmpty;

  bool get checkOutNeedsReview => checkOutPlausibilityFlags.isNotEmpty;

  /// Kapalıda sunucunun [minutes]'ı, açıkta o an hesaplanır.
  Duration get elapsed {
    final start = checkInAt;
    if (start == null) return Duration.zero;

    final end = checkOutAt;
    if (end != null) {
      return minutes != null
          ? Duration(minutes: minutes!)
          : end.difference(start);
    }

    return DateTime.now().difference(start);
  }

  factory WorkSession.fromJson(Map<String, dynamic> json) {
    return WorkSession(
      id: '${json['id']}',
      assignmentId: '${json['jobAssignmentId']}',
      checkInAt: _parseDate(json['checkInAt']),
      checkOutAt: _parseDate(json['checkOutAt']),
      checkInClientEventId: json['checkInClientEventId'] as String?,
      checkInCapturedAt: _parseDate(json['checkInCapturedAt']),
      checkInReceivedAt: _parseDate(json['checkInReceivedAt']),
      checkInPlausibilityFlags: _parseFlags(json['checkInPlausibilityFlags']),
      checkOutClientEventId: json['checkOutClientEventId'] as String?,
      checkOutCapturedAt: _parseDate(json['checkOutCapturedAt']),
      checkOutReceivedAt: _parseDate(json['checkOutReceivedAt']),
      checkOutPlausibilityFlags: _parseFlags(json['checkOutPlausibilityFlags']),
      checkInLatitude: (json['checkInLatitude'] as num?)?.toDouble(),
      checkInLongitude: (json['checkInLongitude'] as num?)?.toDouble(),
      checkOutLatitude: (json['checkOutLatitude'] as num?)?.toDouble(),
      checkOutLongitude: (json['checkOutLongitude'] as num?)?.toDouble(),
      minutes: (json['minutes'] as num?)?.toInt(),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static Set<TimesheetPlausibility> _parseFlags(Object? value) => value is List
      ? value.map(TimesheetPlausibility.fromCode).toSet()
      : const {};
}

enum TimesheetPlausibility {
  deviceTimeImplausible('DEVICE_TIME_IMPLAUSIBLE'),
  outsideJobWindow('OUTSIDE_JOB_WINDOW'),
  nonMonotonic('NON_MONOTONIC'),
  unknown('');

  const TimesheetPlausibility(this.code);

  final String code;

  static TimesheetPlausibility fromCode(Object? value) {
    return values.firstWhere(
      (flag) => flag.code == value,
      orElse: () => unknown,
    );
  }
}
