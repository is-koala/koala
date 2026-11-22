enum RealtimeEventType {
  message('MESSAGE'),
  typing('TYPING'),
  read('READ'),
  presence('PRESENCE'),

  /// Backend yeni bir olay eklerse istemci çökmesin diye; dinleyiciler yok
  /// sayıyor.
  unknown('');

  const RealtimeEventType(this.code);

  final String code;

  static RealtimeEventType fromCode(Object? value) {
    return RealtimeEventType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => RealtimeEventType.unknown,
    );
  }
}

/// STOMP kanallarından gelen olay; dolu alanlar [type]'a bağlı. [message] ham
/// JSON, çünkü `Message`'a çevirmek oturum sahibinin kimliğini istiyor.
class RealtimeEvent {
  const RealtimeEvent({
    required this.type,
    this.conversationId,
    this.userId,
    this.message,
    this.online,
    this.at,
    this.lastReadAt,
  });

  final RealtimeEventType type;

  /// `PRESENCE` olaylarında `null`.
  final String? conversationId;

  /// Mesajı gönderen, yazan ya da okuyan.
  final String? userId;

  final Map<String, dynamic>? message;

  final bool? online;

  final DateTime? at;

  /// `READ` olayında okundu damgası; eski sunucuda `null`, o zaman [at].
  final DateTime? lastReadAt;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    final at = json['at'];
    final lastReadAt = json['lastReadAt'];

    return RealtimeEvent(
      type: RealtimeEventType.fromCode(json['type']),
      conversationId: json['conversationId'] == null
          ? null
          : '${json['conversationId']}',
      userId: json['userId'] == null ? null : '${json['userId']}',
      message: message is Map<String, dynamic> ? message : null,
      online: json['online'] as bool?,
      at: at is String ? DateTime.tryParse(at) : null,
      lastReadAt: lastReadAt is String ? DateTime.tryParse(lastReadAt) : null,
    );
  }
}
