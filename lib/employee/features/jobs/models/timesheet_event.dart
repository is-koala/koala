/// Cihazda yakalanan mesai eylemi.
enum TimesheetEventAction {
  checkIn('CHECK_IN'),
  checkOut('CHECK_OUT');

  const TimesheetEventAction(this.code);

  final String code;

  static TimesheetEventAction fromCode(Object? value) {
    return values.firstWhere(
      (action) => action.code == value,
      orElse: () => throw FormatException('Bilinmeyen mesai eylemi: $value'),
    );
  }
}

/// Kalıcı kaydın gönderim durumu.
enum TimesheetEventStatus {
  pending('PENDING'),
  requiresSupport('REQUIRES_SUPPORT');

  const TimesheetEventStatus(this.code);

  final String code;

  static TimesheetEventStatus fromCode(Object? value) {
    return values.firstWhere(
      (status) => status.code == value,
      orElse: () => throw FormatException('Bilinmeyen kuyruk durumu: $value'),
    );
  }
}

/// Sunucuya ulaşana kadar cihazda saklanan tek giriş veya çıkış olayı.
class TimesheetEvent {
  const TimesheetEvent({
    required this.clientEventId,
    required this.userId,
    required this.assignmentId,
    required this.action,
    required this.capturedAt,
    required this.monotonicMicros,
    this.latitude,
    this.longitude,
    this.status = TimesheetEventStatus.pending,
    this.supportMessage,
  });

  final String clientEventId;
  final String userId;
  final String assignmentId;
  final TimesheetEventAction action;
  final DateTime capturedAt;

  /// Yalnız cihaz içindeki sıra ve yeniden başlatma teşhisi içindir.
  final int monotonicMicros;

  final double? latitude;
  final double? longitude;
  final TimesheetEventStatus status;
  final String? supportMessage;

  bool get requiresSupport => status == TimesheetEventStatus.requiresSupport;

  TimesheetEvent copyWith({
    TimesheetEventStatus? status,
    String? supportMessage,
  }) {
    return TimesheetEvent(
      clientEventId: clientEventId,
      userId: userId,
      assignmentId: assignmentId,
      action: action,
      capturedAt: capturedAt,
      monotonicMicros: monotonicMicros,
      latitude: latitude,
      longitude: longitude,
      status: status ?? this.status,
      supportMessage: supportMessage ?? this.supportMessage,
    );
  }

  Map<String, Object?> toDatabase() => {
    'client_event_id': clientEventId,
    'user_id': userId,
    'assignment_id': assignmentId,
    'action': action.code,
    'captured_at': capturedAt.toUtc().toIso8601String(),
    'monotonic_micros': monotonicMicros,
    'latitude': latitude,
    'longitude': longitude,
    'status': status.code,
    'support_message': supportMessage,
  };

  factory TimesheetEvent.fromDatabase(Map<String, Object?> row) {
    return TimesheetEvent(
      clientEventId: row['client_event_id']! as String,
      userId: row['user_id']! as String,
      assignmentId: row['assignment_id']! as String,
      action: TimesheetEventAction.fromCode(row['action']),
      capturedAt: DateTime.parse(row['captured_at']! as String),
      monotonicMicros: row['monotonic_micros']! as int,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      status: TimesheetEventStatus.fromCode(row['status']),
      supportMessage: row['support_message'] as String?,
    );
  }
}

enum TimesheetSubmission { sent, pending, requiresSupport }
