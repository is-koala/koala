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
      checkInLatitude: (json['checkInLatitude'] as num?)?.toDouble(),
      checkInLongitude: (json['checkInLongitude'] as num?)?.toDouble(),
      checkOutLatitude: (json['checkOutLatitude'] as num?)?.toDouble(),
      checkOutLongitude: (json['checkOutLongitude'] as num?)?.toDouble(),
      minutes: (json['minutes'] as num?)?.toInt(),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
