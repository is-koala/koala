/// Bir mesai oturumu: bir giriş, varsa bir çıkış.
///
/// Backend `WorkSessionDto` karşılığı. Bir atamada birden çok oturum
/// olabiliyor (ara verilip dönülüyor), ama aynı anda **açık** olan yalnızca
/// bir tane: sunucu ikinci girişi `409` ile reddediyor.
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

  /// Çıkış yapılmadıysa `null`; oturumun açık olması bu demek.
  final DateTime? checkOutAt;

  final String? checkInClientEventId;
  final DateTime? checkInCapturedAt;
  final DateTime? checkInReceivedAt;
  final Set<TimesheetPlausibility> checkInPlausibilityFlags;
  final String? checkOutClientEventId;
  final DateTime? checkOutCapturedAt;
  final DateTime? checkOutReceivedAt;
  final Set<TimesheetPlausibility> checkOutPlausibilityFlags;

  /// Giriş ve çıkış konumları. Konum isteğe bağlı — sunucu gövdesiz istek de
  /// kabul ediyor — o yüzden hepsi `null` olabiliyor.
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;

  /// Oturumun süresi, dakika. Çıkış yapılınca sunucu hesaplıyor.
  final int? minutes;

  /// Oturum hâlâ açık mı. Açıksa sıradaki eylem çıkış, değilse giriş.
  bool get isOpen => checkOutAt == null;

  bool get checkInNeedsReview => checkInPlausibilityFlags.isNotEmpty;

  bool get checkOutNeedsReview => checkOutPlausibilityFlags.isNotEmpty;

  /// Girişten bu yana geçen süre. Kapalı oturumda sunucunun yazdığı
  /// [minutes] kullanılıyor; açık oturumda saat işlediği için o an
  /// hesaplanıyor.
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

/// Sunucunun cihaz saati ve iş penceresi için verdiği inceleme işareti.
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
